import Foundation
import CoreData

extension Workout {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Workout> {
        return NSFetchRequest<Workout>(entityName: "Workout")
    }

    @NSManaged public var date: Date?
    @NSManaged public var duration: Int32
    @NSManaged public var exercises: NSSet?
    @NSManaged public var template: WorkoutTemplate?
    
    // Custom properties
    var formattedDate: String {
        guard let date = date else { return "Unknown date" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    var formattedDuration: String {
        let totalSeconds = Int(duration)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    var exerciseArray: [WorkoutExercise] {
        let set = exercises as? Set<WorkoutExercise> ?? []
        return set.sorted {
            $0.order < $1.order
        }
    }
    
    var templateName: String {
        template?.name ?? "Custom Workout"
    }
} 