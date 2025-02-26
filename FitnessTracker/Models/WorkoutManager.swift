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
    
    init(context: NSManagedObjectContext) {
        self.viewContext = context
        // Initialize template count
        self.updateTemplateCount()
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
        // Update template count to trigger UI refresh
        updateTemplateCount()
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
        // Get the highest order
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "Exercise")
        fetchRequest.predicate = NSPredicate(format: "template == %@", template)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "order", ascending: false)]
        fetchRequest.fetchLimit = 1
        
        let highestOrder: Int16
        do {
            let results = try viewContext.fetch(fetchRequest)
            highestOrder = results.first?.value(forKey: "order") as? Int16 ?? -1
        } catch {
            print("Error fetching exercises: \(error)")
            highestOrder = -1
        }
        
        guard let entity = NSEntityDescription.entity(forEntityName: "Exercise", in: viewContext) else {
            fatalError("Failed to find Exercise entity")
        }
        
        let exercise = NSManagedObject(entity: entity, insertInto: viewContext)
        exercise.setValue(name, forKey: "name")
        exercise.setValue(highestOrder + 1, forKey: "order")
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
    
    func startWorkout(from template: NSManagedObject) -> NSManagedObject {
        guard let entity = NSEntityDescription.entity(forEntityName: "Workout", in: viewContext) else {
            fatalError("Failed to find Workout entity")
        }
        
        let workout = NSManagedObject(entity: entity, insertInto: viewContext)
        workout.setValue(Date(), forKey: "date")
        workout.setValue(template, forKey: "template")
        
        // Get exercises from template
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "Exercise")
        fetchRequest.predicate = NSPredicate(format: "template == %@", template)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "order", ascending: true)]
        
        do {
            let exercises = try viewContext.fetch(fetchRequest)
            
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
                
                // Create sets
                for setIndex in 0..<setsToCreate {
                    guard let setEntity = NSEntityDescription.entity(forEntityName: "ExerciseSet", in: viewContext) else {
                        fatalError("Failed to find ExerciseSet entity")
                    }
                    
                    let exerciseSet = NSManagedObject(entity: setEntity, insertInto: viewContext)
                    exerciseSet.setValue(Int16(setIndex), forKey: "setNumber")
                    exerciseSet.setValue(workoutExercise, forKey: "workoutExercise")
                    
                    // Populate with previous data if available
                    if setIndex < previousSetsCount {
                        if let previousData = self.getLastWorkoutSetData(for: exercise, setNumber: Int16(setIndex)) {
                            exerciseSet.setValue(previousData.reps, forKey: "reps")
                            exerciseSet.setValue(previousData.weight, forKey: "weight")
                        }
                    }
                }
            }
            
            saveContext()
            return workout
        } catch {
            print("Error creating workout: \(error)")
            viewContext.delete(workout)
            saveContext()
            fatalError("Failed to create workout: \(error)")
        }
    }
    
    func createBlankWorkout(name: String = "Blank Workout") -> NSManagedObject {
        print("DEBUG: Creating blank workout with name: \(name)")
        
        guard let entity = NSEntityDescription.entity(forEntityName: "Workout", in: viewContext) else {
            fatalError("Failed to find Workout entity")
        }
        
        let workout = NSManagedObject(entity: entity, insertInto: viewContext)
        workout.setValue(Date(), forKey: "date")
        workout.setValue(name, forKey: "name")
        
        saveContext()
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
        saveContext()
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
        
        // If there are previous sets, copy the last one's values
        if let lastSet = self.getLastSet(for: workoutExercise), 
           (lastSet.value(forKey: "setNumber") as? Int16) != highestSetNumber {
            exerciseSet.setValue(lastSet.value(forKey: "reps"), forKey: "reps")
            exerciseSet.setValue(lastSet.value(forKey: "weight"), forKey: "weight")
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
    
    private func getLastWorkoutSetData(for exercise: NSManagedObject, setNumber: Int16) -> (reps: Int16, weight: Double)? {
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "WorkoutExercise")
        fetchRequest.predicate = NSPredicate(format: "exercise == %@", exercise)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "workout.date", ascending: false)]
        fetchRequest.fetchLimit = 1
        
        do {
            guard let lastWorkoutExercise = try viewContext.fetch(fetchRequest).first else {
                return nil
            }
            
            let setsFetchRequest = NSFetchRequest<NSManagedObject>(entityName: "ExerciseSet")
            setsFetchRequest.predicate = NSPredicate(format: "workoutExercise == %@ AND setNumber == %d", lastWorkoutExercise, setNumber)
            setsFetchRequest.fetchLimit = 1
            
            guard let set = try viewContext.fetch(setsFetchRequest).first else {
                return nil
            }
            
            let reps = set.value(forKey: "reps") as? Int16 ?? 0
            let weight = set.value(forKey: "weight") as? Double ?? 0.0
            
            return (reps, weight)
        } catch {
            print("Error fetching last workout data: \(error)")
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
        print("DEBUG: Fetching all templates")
        let request = NSFetchRequest<NSManagedObject>(entityName: "WorkoutTemplate")
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        
        do {
            let results = try viewContext.fetch(request)
            print("DEBUG: Fetched \(results.count) templates")
            if !results.isEmpty {
                print("DEBUG: First template name: \(results[0].value(forKey: "name") as? String ?? "Unknown")")
            }
            return results
        } catch {
            print("DEBUG: Error fetching templates: \(error)")
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
        request.predicate = NSPredicate(format: "ANY exercises.name CONTAINS[cd] %@", name)
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        
        do {
            return try viewContext.fetch(request)
        } catch {
            print("Error fetching workouts with exercise: \(error)")
            return []
        }
    }
} 