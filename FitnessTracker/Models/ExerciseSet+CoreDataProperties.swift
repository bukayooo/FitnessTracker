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
    
    // Mark: This property will be added to the Core Data model
    // @NSManaged public var isComplete: Bool
    
    // Since the Core Data model needs to be updated in Xcode directly,
    // we provide a computed property that safely handles the case where
    // the property isn't yet in the model
    var isComplete: Bool {
        get {
            if let value = primitiveValue(forKey: "isComplete") as? Bool {
                return value
            }
            return false
        }
        set {
            if entity.propertiesByName["isComplete"] != nil {
                setPrimitiveValue(newValue, forKey: "isComplete")
            }
        }
    }
    
    // Custom property for formatted weight
    var formattedWeight: String {
        String(format: "%.1f", weight)
    }
} 