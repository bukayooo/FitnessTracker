//
//  WorkoutManager.swift
//  FitnessTracker
//
//  Created by Bukayo Odedele on 2/25/25.
//

import Foundation
import CoreData
import SwiftUI

class WorkoutManager: ObservableObject {
    private let viewContext: NSManagedObjectContext
    
    // Add a published property to trigger view updates
    @Published var templateCount: Int = 0
    @Published var templates: [NSManagedObject] = []
    
    init(context: NSManagedObjectContext) {
        self.viewContext = context
        
        // Initialize template count and fetch templates
        self.updateTemplateCount()
        
        // Set up notification observer for refreshing templates when the app comes to foreground
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refreshTemplates),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
        
        // Initial fetch of templates
        DispatchQueue.main.async {
            self.templates = self.fetchTemplatesFromStore()
            print("DEBUG: Initial templates loaded: \(self.templates.count)")
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc func refreshTemplates() {
        print("DEBUG: Refreshing templates from WorkoutManager")
        // Clear the templates cache
        self.templates = []
        
        // Fetch fresh templates and update the count
        self.templates = self.fetchTemplatesFromStore()
        self.updateTemplateCount()
        
        print("DEBUG: Templates refreshed, count: \(self.templateCount)")
    }
    
    // MARK: - Template Operations
    
    func createTemplate(name: String) -> NSManagedObject {
        guard let entity = NSEntityDescription.entity(forEntityName: "WorkoutTemplate", in: viewContext) else {
            fatalError("Failed to find WorkoutTemplate entity")
        }
        
        let template = NSManagedObject(entity: entity, insertInto: viewContext)
        template.setValue(name, forKey: "name")
        template.setValue(Date(), forKey: "createdAt")
        
        saveContext()
        
        // Force refresh templates immediately to ensure the new template shows up
        DispatchQueue.main.async {
            self.templates = self.fetchTemplatesFromStore()
            self.updateTemplateCount()
        }
        
        return template
    }
    
    func deleteTemplate(_ template: NSManagedObject) {
        viewContext.delete(template)
        saveContext()
        // Update template count to trigger UI refresh
        updateTemplateCount()
    }
    
    func updateTemplate(_ template: NSManagedObject, name: String) {
        template.setValue(name, forKey: "name")
        saveContext()
    }
    
    // Private method to update the template count
    private func updateTemplateCount() {
        let request = NSFetchRequest<NSManagedObject>(entityName: "WorkoutTemplate")
        do {
            let count = try viewContext.count(for: request)
            // Trigger UI update by changing published property
            DispatchQueue.main.async {
                self.templateCount = count
                print("DEBUG: Updated templateCount to \(count)")
            }
        } catch {
            print("DEBUG: Error counting templates: \(error)")
        }
    }
    
    // MARK: - Exercise Operations
    
    func addExercise(to template: NSManagedObject, name: String, sets: Int16 = 3) -> NSManagedObject {
        guard let entity = NSEntityDescription.entity(forEntityName: "Exercise", in: viewContext) else {
            fatalError("Failed to find Exercise entity")
        }
        
        // Compute the highest order value from existing exercises
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "Exercise")
        fetchRequest.predicate = NSPredicate(format: "template == %@", template)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "order", ascending: false)]
        fetchRequest.fetchLimit = 1
        
        var nextOrder: Int16 = 0
        do {
            if let highestOrderExercise = try viewContext.fetch(fetchRequest).first,
               let highestOrder = highestOrderExercise.value(forKey: "order") as? Int16 {
                nextOrder = highestOrder + 1
            }
        } catch {
            print("Error fetching exercises: \(error)")
        }
        
        let exercise = NSManagedObject(entity: entity, insertInto: viewContext)
        exercise.setValue(name, forKey: "name")
        exercise.setValue(nextOrder, forKey: "order")
        exercise.setValue(sets, forKey: "sets")
        exercise.setValue(template, forKey: "template")
        
        saveContext()
        return exercise
    }
    
    func updateExercise(_ exercise: NSManagedObject, name: String, sets: Int16) {
        exercise.setValue(name, forKey: "name")
        exercise.setValue(sets, forKey: "sets")
        saveContext()
    }
    
    func deleteExercise(_ exercise: NSManagedObject) {
        if let template = exercise.value(forKey: "template") as? NSManagedObject,
           let exercises = template.value(forKey: "exercises") as? Set<NSManagedObject> {
            let exerciseOrder = exercise.value(forKey: "order") as? Int16 ?? 0
            
            // Reorder remaining exercises
            for remainingExercise in exercises {
                let order = remainingExercise.value(forKey: "order") as? Int16 ?? 0
                if order > exerciseOrder {
                    remainingExercise.setValue(order - 1, forKey: "order")
                }
            }
        }
        
        viewContext.delete(exercise)
        saveContext()
    }
    
    func moveExercise(in template: NSManagedObject, from source: IndexSet, to destination: Int) {
        // Get exercises sorted by order
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "Exercise")
        fetchRequest.predicate = NSPredicate(format: "template == %@", template)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "order", ascending: true)]
        
        do {
            var exercises = try viewContext.fetch(fetchRequest)
            
            // Convert IndexSet to index
            guard let sourceIndex = source.first else { return }
            
            // Reorder array
            let element = exercises.remove(at: sourceIndex)
            exercises.insert(element, at: destination)
            
            // Update order properties
            for (index, exercise) in exercises.enumerated() {
                exercise.setValue(Int16(index), forKey: "order")
            }
            
            saveContext()
        } catch {
            print("Error moving exercises: \(error)")
        }
    }
    
    // MARK: - Workout Operations
    
    func startWorkout(from template: NSManagedObject) -> NSManagedObject? {
        guard let entity = NSEntityDescription.entity(forEntityName: "Workout", in: viewContext) else {
            fatalError("Failed to find Workout entity")
        }
        
        print("DEBUG: Starting workout from template ID: \(template.objectID)")
        
        // Verify the template is valid and has a context
        guard template.managedObjectContext != nil else {
            print("DEBUG: ⚠️ Template has nil context, attempting to fetch fresh object")
            // Try to get a fresh copy of the template - removing unreachable catch block
            guard let freshTemplate = try? viewContext.existingObject(with: template.objectID) else {
                print("DEBUG: ⚠️ Could not retrieve fresh template")
                return nil
            }
            print("DEBUG: Successfully retrieved fresh template")
            return startWorkout(from: freshTemplate)
        }
        
        // Refresh the template object to ensure we have the latest data
        viewContext.refresh(template, mergeChanges: true)
        
        let workout = NSManagedObject(entity: entity, insertInto: viewContext)
        workout.setValue(Date(), forKey: "date")
        workout.setValue(template, forKey: "template")
        
        // Get exercises from template with better error handling
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "Exercise")
        fetchRequest.predicate = NSPredicate(format: "template == %@", template)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "order", ascending: true)]
        
        do {
            let exercises = try viewContext.fetch(fetchRequest)
            print("DEBUG: Found \(exercises.count) exercises in template")
            
            if exercises.isEmpty {
                print("DEBUG: ⚠️ No exercises found for template. Template might be corrupted.")
            }
            
            // Create workout exercises
            for (index, exercise) in exercises.enumerated() {
                guard let exerciseEntity = NSEntityDescription.entity(forEntityName: "WorkoutExercise", in: viewContext) else {
                    fatalError("Failed to find WorkoutExercise entity")
                }
                
                let workoutExercise = NSManagedObject(entity: exerciseEntity, insertInto: viewContext)
                workoutExercise.setValue(exercise.value(forKey: "name"), forKey: "name")
                workoutExercise.setValue(Int16(index), forKey: "order")
                workoutExercise.setValue(exercise, forKey: "exercise")
                workoutExercise.setValue(workout, forKey: "workout")
                
                // Find previous workout data
                let previousSetsCount = self.getLastWorkoutSetsCount(for: exercise)
                let setsToCreate = max(Int(exercise.value(forKey: "sets") as? Int16 ?? 3), previousSetsCount)
                
                print("DEBUG: Creating \(setsToCreate) sets for exercise: \(exercise.value(forKey: "name") as? String ?? "unknown")")
                
                // Create sets
                for setIndex in 0..<setsToCreate {
                    guard let setEntity = NSEntityDescription.entity(forEntityName: "ExerciseSet", in: viewContext) else {
                        fatalError("Failed to find ExerciseSet entity")
                    }
                    
                    let exerciseSet = NSManagedObject(entity: setEntity, insertInto: viewContext)
                    exerciseSet.setValue(Int16(setIndex), forKey: "setNumber")
                    exerciseSet.setValue(workoutExercise, forKey: "workoutExercise")
                    
                    // Initialize isComplete property if it exists
                    if setEntity.propertiesByName["isComplete"] != nil {
                        exerciseSet.setValue(false, forKey: "isComplete")
                    }
                    
                    // Populate with previous data if available
                    if setIndex < previousSetsCount {
                        if let previousData = self.getLastWorkoutSetData(for: exercise, setNumber: Int16(setIndex)) {
                            exerciseSet.setValue(previousData.reps, forKey: "reps")
                            exerciseSet.setValue(previousData.weight, forKey: "weight")
                            
                            // Mark as complete if we have valid reps (greater than 0) and isComplete exists
                            if previousData.reps > 0 && setEntity.propertiesByName["isComplete"] != nil {
                                exerciseSet.setValue(true, forKey: "isComplete")
                            }
                        }
                    }
                }
            }
            
            // Save context before returning
            saveContext()
            
            // Ensure the workout is properly loaded in the context
            viewContext.refresh(workout, mergeChanges: true)
            
            print("DEBUG: Successfully created workout with ID: \(workout.objectID)")
            return workout
        } catch {
            print("ERROR: Error creating workout: \(error)")
            viewContext.delete(workout)
            saveContext()
            fatalError("Failed to create workout: \(error)")
        }
    }
    
    func createBlankWorkout(name: String = "Blank Workout") -> NSManagedObject {
        print("DEBUG: Creating blank workout")
        
        guard let entity = NSEntityDescription.entity(forEntityName: "Workout", in: viewContext) else {
            fatalError("Failed to find Workout entity")
        }
        
        let workout = NSManagedObject(entity: entity, insertInto: viewContext)
        workout.setValue(Date(), forKey: "date")
        
        // Save the context to ensure the workout is persisted
        saveContext()
        
        // Ensure the workout is properly loaded in the context
        viewContext.refresh(workout, mergeChanges: true)
        
        print("DEBUG: Created blank workout with ID: \(workout.objectID)")
        return workout
    }
    
    func completeWorkout(_ workout: NSManagedObject, duration: Int) {
        workout.setValue(Int32(duration), forKey: "duration")
        saveContext()
    }
    
    func deleteWorkout(_ workout: NSManagedObject) {
        viewContext.delete(workout)
        saveContext()
    }
    
    func updateSet(_ set: NSManagedObject, reps: Int16, weight: Double) {
        set.setValue(reps, forKey: "reps")
        set.setValue(weight, forKey: "weight")
        
        // Only set isComplete if the property exists
        if set.entity.propertiesByName["isComplete"] != nil {
            // Mark as complete if we have valid reps (greater than 0)
            if reps > 0 {
                set.setValue(true, forKey: "isComplete")
            }
        }
        
        saveContext()
    }
    
    func updateSetCompletion(_ set: NSManagedObject, isComplete: Bool) {
        // Safely handle the isComplete property
        if set.entity.propertiesByName["isComplete"] != nil {
            set.setValue(isComplete, forKey: "isComplete")
            saveContext()
        } else {
            // Use fallback for older database versions without this property
            let setId = set.objectID.uriRepresentation().absoluteString
            UserDefaults.standard.set(isComplete, forKey: "set_complete_\(setId)")
        }
    }
    
    func addSet(to workoutExercise: NSManagedObject) -> NSManagedObject {
        print("DEBUG: addSet called with object of type: \(type(of: workoutExercise))")
        print("DEBUG: Entity name: \(workoutExercise.entity.name ?? "unknown")")
        
        // Check if we're dealing with an Exercise (from template) instead of a WorkoutExercise
        if workoutExercise.entity.name == "Exercise" {
            print("DEBUG: Error - Cannot add sets directly to a template Exercise. Must be a WorkoutExercise.")
            fatalError("Cannot add sets to template Exercise objects. First create a workout from the template.")
        }
        
        // Get highest set number
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "ExerciseSet")
        fetchRequest.predicate = NSPredicate(format: "workoutExercise == %@", workoutExercise)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "setNumber", ascending: false)]
        fetchRequest.fetchLimit = 1
        
        let highestSetNumber: Int16
        do {
            let results = try viewContext.fetch(fetchRequest)
            highestSetNumber = results.first?.value(forKey: "setNumber") as? Int16 ?? -1
        } catch {
            print("Error fetching sets: \(error)")
            highestSetNumber = -1
        }
        
        guard let entity = NSEntityDescription.entity(forEntityName: "ExerciseSet", in: viewContext) else {
            fatalError("Failed to find ExerciseSet entity")
        }
        
        let exerciseSet = NSManagedObject(entity: entity, insertInto: viewContext)
        exerciseSet.setValue(highestSetNumber + 1, forKey: "setNumber")
        exerciseSet.setValue(workoutExercise, forKey: "workoutExercise")
        
        // Initialize isComplete property if it exists
        if entity.propertiesByName["isComplete"] != nil {
            exerciseSet.setValue(false, forKey: "isComplete")
        }
        
        // If there are previous sets, copy the last one's values
        if let lastSet = self.getLastSet(for: workoutExercise), 
           (lastSet.value(forKey: "setNumber") as? Int16) != highestSetNumber {
            let reps = lastSet.value(forKey: "reps") as? Int16 ?? 0
            exerciseSet.setValue(reps, forKey: "reps")
            exerciseSet.setValue(lastSet.value(forKey: "weight"), forKey: "weight")
            
            // Mark as complete if reps > 0 and isComplete property exists
            if reps > 0 && entity.propertiesByName["isComplete"] != nil {
                exerciseSet.setValue(false, forKey: "isComplete") // Start as incomplete despite copied values
            }
        }
        
        saveContext()
        return exerciseSet
    }
    
    // MARK: - Utility Methods
    
    private func saveContext() {
        if viewContext.hasChanges {
            print("DEBUG: Saving view context with changes")
            do {
                try viewContext.save()
                print("DEBUG: Context saved successfully")
            } catch {
                let nsError = error as NSError
                print("DEBUG: Failed to save context: \(nsError), \(nsError.userInfo)")
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        } else {
            print("DEBUG: No changes to save in context")
        }
    }
    
    private func getLastWorkoutSetsCount(for exercise: NSManagedObject) -> Int {
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "WorkoutExercise")
        fetchRequest.predicate = NSPredicate(format: "exercise == %@", exercise)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "workout.date", ascending: false)]
        fetchRequest.fetchLimit = 1
        
        do {
            guard let lastWorkoutExercise = try viewContext.fetch(fetchRequest).first else {
                return 0
            }
            
            let setsFetchRequest = NSFetchRequest<NSManagedObject>(entityName: "ExerciseSet")
            setsFetchRequest.predicate = NSPredicate(format: "workoutExercise == %@", lastWorkoutExercise)
            
            return try viewContext.fetch(setsFetchRequest).count
        } catch {
            print("Error fetching last workout data: \(error)")
            return 0
        }
    }
    
    func getLastWorkoutSetData(for exercise: NSManagedObject, setNumber: Int16) -> (reps: Int16, weight: Double)? {
        // Get the exercise name
        let exerciseName = exercise.value(forKey: "name") as? String ?? ""
        print("DEBUG: Looking for previous data for exercise: \(exerciseName), set: \(setNumber)")
        
        // First, find the most recent completed workout containing this exercise
        let workoutRequest = NSFetchRequest<NSManagedObject>(entityName: "Workout")
        workoutRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        workoutRequest.fetchLimit = 5 // Check the last 5 workouts to find relevant data
        
        do {
            let recentWorkouts = try viewContext.fetch(workoutRequest)
            
            // Look through recent workouts for matching exercise data
            for workout in recentWorkouts {
                if let exercises = workout.value(forKey: "exercises") as? NSSet {
                    for case let workoutExercise as NSManagedObject in exercises {
                        let currentExName = workoutExercise.value(forKey: "name") as? String ?? ""
                        
                        // If we found a matching exercise name
                        if currentExName == exerciseName {
                            print("DEBUG: Found matching exercise '\(exerciseName)' in previous workout")
                            
                            // Get sets for this exercise
                            if let sets = workoutExercise.value(forKey: "sets") as? NSSet {
                                // Find matching set by number
                                for case let setObj as NSManagedObject in sets {
                                    let currentSetNum = setObj.value(forKey: "setNumber") as? Int16 ?? -1
                                    
                                    if currentSetNum == setNumber {
                                        let reps = setObj.value(forKey: "reps") as? Int16 ?? 0
                                        let weight = setObj.value(forKey: "weight") as? Double ?? 0.0
                                        
                                        // Only return non-zero values
                                        if reps > 0 || weight > 0 {
                                            print("DEBUG: Found previous data: \(reps) reps, \(weight) weight")
                                            return (reps, weight)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
            print("DEBUG: No previous non-zero data found for \(exerciseName), set \(setNumber)")
            return nil
        } catch {
            print("ERROR: Failed to fetch previous workout data: \(error)")
            return nil
        }
    }
    
    private func getLastSet(for workoutExercise: NSManagedObject) -> NSManagedObject? {
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "ExerciseSet")
        fetchRequest.predicate = NSPredicate(format: "workoutExercise == %@", workoutExercise)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "setNumber", ascending: false)]
        fetchRequest.fetchLimit = 1
        
        do {
            return try viewContext.fetch(fetchRequest).first
        } catch {
            print("Error fetching last set: \(error)")
            return nil
        }
    }
    
    // MARK: - Fetch Requests
    
    func fetchAllTemplates() -> [NSManagedObject] {
        // Return cached templates if available
        if !templates.isEmpty {
            return templates
        }
        
        // Otherwise fetch from store and update cache
        let fetchedTemplates = fetchTemplatesFromStore()
        
        // Update templates without triggering a publisher during the view update cycle
        DispatchQueue.main.async {
            self.templates = fetchedTemplates
        }
        
        return fetchedTemplates
    }
    
    // Private method to fetch templates from the store
    private func fetchTemplatesFromStore() -> [NSManagedObject] {
        print("DEBUG: Fetching all templates from store")
        let request = NSFetchRequest<NSManagedObject>(entityName: "WorkoutTemplate")
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        
        // Ensure fetch request includes relationships to avoid faulting issues
        request.relationshipKeyPathsForPrefetching = ["exercises"]
        
        do {
            // Fetch with error handling
            let results = try viewContext.fetch(request)
            print("DEBUG: Fetched \(results.count) templates")
            
            if !results.isEmpty {
                print("DEBUG: First template name: \(results[0].value(forKey: "name") as? String ?? "nil")")
                
                // Force refresh any stale objects
                for template in results {
                    if template.managedObjectContext != nil {
                        viewContext.refresh(template, mergeChanges: true)
                    }
                }
                
                // Handle potential nil managed object contexts
                results.forEach { template in
                    if template.managedObjectContext == nil {
                        print("DEBUG: ⚠️ Template has nil context: \(template.objectID)")
                    }
                }
            }
            
            // Update template count - but NOT during a view update cycle
            DispatchQueue.main.async {
                self.templateCount = results.count
            }
            
            return results
        } catch {
            print("ERROR: Error fetching templates: \(error)")
            return []
        }
    }
    
    func fetchAllWorkouts() -> [NSManagedObject] {
        let request = NSFetchRequest<NSManagedObject>(entityName: "Workout")
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        
        do {
            return try viewContext.fetch(request)
        } catch {
            print("Error fetching workouts: \(error)")
            return []
        }
    }
    
    func fetchWorkoutsForTemplate(_ template: NSManagedObject) -> [NSManagedObject] {
        let request = NSFetchRequest<NSManagedObject>(entityName: "Workout")
        request.predicate = NSPredicate(format: "template == %@", template)
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        
        do {
            return try viewContext.fetch(request)
        } catch {
            print("Error fetching workouts for template: \(error)")
            return []
        }
    }
    
    func fetchWorkoutsContainingExercise(named name: String) -> [NSManagedObject] {
        let request = NSFetchRequest<NSManagedObject>(entityName: "Workout")
        
        // Use exact match instead of CONTAINS to avoid partial matches
        request.predicate = NSPredicate(format: "ANY exercises.name == %@", name)
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        
        do {
            return try viewContext.fetch(request)
        } catch {
            print("Error fetching workouts with exercise: \(error)")
            return []
        }
    }
    
    // MARK: - Exercise Progress Utilities
    
    func fetchUniqueExerciseNames() -> [String] {
        print("DEBUG: Fetching unique exercise names")
        var uniqueNames = Set<String>()
        
        // Only include exercises that have been used in actual completed workouts with real data
        let workoutExerciseRequest = NSFetchRequest<NSManagedObject>(entityName: "WorkoutExercise")
        
        do {
            let workoutExercises = try viewContext.fetch(workoutExerciseRequest)
            for exercise in workoutExercises {
                if let name = exercise.value(forKey: "name") as? String, !name.isEmpty {
                    // Only add exercises that have at least one completed set with non-zero values
                    if let sets = exercise.value(forKey: "sets") as? NSSet {
                        var hasCompletedSet = false
                        
                        for case let setObj as NSManagedObject in sets {
                            let reps = setObj.value(forKey: "reps") as? Int16 ?? 0
                            let weight = setObj.value(forKey: "weight") as? Double ?? 0.0
                            
                            if reps > 0 && weight > 0 {
                                hasCompletedSet = true
                                break
                            }
                        }
                        
                        if hasCompletedSet {
                            uniqueNames.insert(name)
                            print("DEBUG: Found completed exercise: \(name)")
                        } else {
                            print("DEBUG: Skipping exercise with no completed sets: \(name)")
                        }
                    }
                }
            }
        } catch {
            print("ERROR: Failed to fetch workout exercises: \(error)")
        }
        
        // Sort the unique names alphabetically
        let sortedNames = Array(uniqueNames).sorted()
        print("DEBUG: Found \(sortedNames.count) unique exercises with completed sets")
        return sortedNames
    }
} 