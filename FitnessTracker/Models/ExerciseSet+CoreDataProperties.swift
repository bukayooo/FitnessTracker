import Foundation
import CoreData

extension ExerciseSet {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<ExerciseSet> {
        return NSFetchRequest<ExerciseSet>(entityName: "ExerciseSet")
    }

    @NSManaged public var reps: Int16
    @NSManaged public var setNumber: Int16
    @NSManaged public var weight: Double
    @NSManaged public var workoutExercise: WorkoutExercise?
    
    // Custom property for formatted weight
    var formattedWeight: String {
        String(format: "%.1f", weight)
    }
} 