import Foundation
import CoreData

extension WorkoutTemplate {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<WorkoutTemplate> {
        return NSFetchRequest<WorkoutTemplate>(entityName: "WorkoutTemplate")
    }

    @NSManaged public var createdAt: Date?
    @NSManaged public var name: String?
    @NSManaged public var exercises: NSSet?
    @NSManaged public var workouts: NSSet?
    
    // Custom properties as defined in ModelExtensions
    var templateName: String {
        name ?? "Unknown Template"
    }
    
    var exerciseArray: [Exercise] {
        let set = exercises as? Set<Exercise> ?? []
        return set.sorted {
            $0.order < $1.order
        }
    }
    
    var formattedCreationDate: String {
        guard let date = createdAt else { return "Unknown date" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    var lastWorkout: Workout? {
        let workoutSet = workouts as? Set<Workout> ?? []
        return workoutSet.sorted {
            $0.date! > $1.date!
        }.first
    }
} 