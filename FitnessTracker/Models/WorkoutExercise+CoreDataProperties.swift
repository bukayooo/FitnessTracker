import Foundation
import CoreData

extension WorkoutExercise {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<WorkoutExercise> {
        return NSFetchRequest<WorkoutExercise>(entityName: "WorkoutExercise")
    }

    @NSManaged public var name: String?
    @NSManaged public var order: Int16
    @NSManaged public var exercise: Exercise?
    @NSManaged public var sets: NSSet?
    @NSManaged public var workout: Workout?
    
    // Custom properties
    var exerciseName: String {
        name ?? exercise?.name ?? "Unknown Exercise"
    }
    
    var setArray: [ExerciseSet] {
        let setSet = sets as? Set<ExerciseSet> ?? []
        return setSet.sorted {
            $0.setNumber < $1.setNumber
        }
    }
} 