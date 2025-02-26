import Foundation
import CoreData

extension Exercise {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Exercise> {
        return NSFetchRequest<Exercise>(entityName: "Exercise")
    }

    @NSManaged public var name: String?
    @NSManaged public var order: Int16
    @NSManaged public var sets: Int16
    @NSManaged public var template: WorkoutTemplate?
    @NSManaged public var workoutExercises: NSSet?
    
    // Custom properties
    var exerciseName: String {
        name ?? "Unknown Exercise"
    }
    
    var lastWorkoutExercise: WorkoutExercise? {
        let exercises = workoutExercises as? Set<WorkoutExercise> ?? []
        return exercises.sorted {
            $0.workout?.date ?? Date.distantPast > $1.workout?.date ?? Date.distantPast
        }.first
    }
} 