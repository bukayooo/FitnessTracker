//
//  CoreDataModels.swift
//  FitnessTracker
//
//  Created by Bukayo Odedele on 2/25/25.
//

import Foundation
import CoreData

// This file acts as a unified import for all Core Data models to resolve any circular dependencies
// and make it easier to import all models at once.

// Make sure all Core Data entity types are properly defined and accessible
@_exported import class Foundation.NSObject
@_exported import class CoreData.NSManagedObject
@_exported import class CoreData.NSManagedObjectContext

// Note: The Core Data entity classes are defined in their respective files
// and should be imported directly where needed 

// Warmup Entity
class Warmup: NSManagedObject {
    @NSManaged public var name: String?
    @NSManaged public var order: Int16
    @NSManaged public var template: WorkoutTemplate?
    
    var warmupName: String {
        name ?? "Unknown Warmup"
    }
} 