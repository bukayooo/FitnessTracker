//
//  FitnessTrackerApp.swift
//  FitnessTracker
//
//  Created by Bukayo Odedele on 2/25/25.
//

import SwiftUI
import CoreData

@main
struct FitnessTrackerApp: App {
    let persistenceController = PersistenceController.shared
    
    @Environment(\.scenePhase) var scenePhase
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            switch newPhase {
            case .active:
                print("DEBUG: App became active")
                ensureCoreDataIsLoaded()
            case .background:
                print("DEBUG: App went to background")
                // Save any unsaved changes
                if persistenceController.container.viewContext.hasChanges {
                    do {
                        try persistenceController.container.viewContext.save()
                        print("DEBUG: Saved context during app transition to background")
                    } catch {
                        print("DEBUG: Error saving context during app transition: \(error)")
                    }
                }
            case .inactive:
                print("DEBUG: App became inactive")
            @unknown default:
                print("DEBUG: Unknown scene phase")
            }
        }
    }
    
    // Helper function to ensure Core Data is properly loaded
    private func ensureCoreDataIsLoaded() {
        // Perform a simple fetch to ensure the persistent store is accessible
        let request = NSFetchRequest<NSManagedObject>(entityName: "WorkoutTemplate")
        do {
            let count = try persistenceController.container.viewContext.count(for: request)
            print("DEBUG: Verified Core Data store, template count: \(count)")
        } catch {
            print("DEBUG: Error verifying Core Data: \(error)")
            
            // If we encounter an error, attempt to reload the store
            persistenceController.resetAndReloadStore()
        }
    }
}

// Core Data persistence controller
class PersistenceController {
    static let shared = PersistenceController()
    
    static var preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        // Create sample data for previews if needed
        return controller
    }()
    
    let container: NSPersistentContainer
    
    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "FitnessTracker")
        
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }
        
        container.loadPersistentStores { description, error in
            if let error = error {
                fatalError("Error loading Core Data stores: \(error.localizedDescription)")
            }
            
            print("DEBUG: Core Data store loaded successfully from \(description.url?.absoluteString ?? "unknown location")")
        }
        
        // Enhanced configuration for better reliability
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.automaticallyMergesChangesFromParent = true
        
        // Enable constraint validation
        container.viewContext.shouldDeleteInaccessibleFaults = true
        
        // Configure to refresh objects automatically
        NotificationCenter.default.addObserver(
            forName: .NSManagedObjectContextDidSave,
            object: nil,
            queue: .main) { [weak self] notification in
                guard let context = notification.object as? NSManagedObjectContext,
                      context != self?.container.viewContext else {
                    return
                }
                
                self?.container.viewContext.perform {
                    self?.container.viewContext.mergeChanges(fromContextDidSave: notification)
                    print("DEBUG: Merged changes from background context")
                }
            }
        
        // Perform an initial fetch to ensure the persistent store is properly loaded
        do {
            let request = NSFetchRequest<NSManagedObject>(entityName: "WorkoutTemplate")
            let count = try container.viewContext.count(for: request)
            print("DEBUG: Initial template count: \(count)")
        } catch {
            print("DEBUG: Initial fetch error: \(error)")
        }
    }
    
    // Helper method to reset and reload the store if needed
    func resetAndReloadStore() {
        do {
            // Reset the view context
            container.viewContext.reset()
            
            // Reset other contexts if needed
            for persistentStore in container.persistentStoreCoordinator.persistentStores {
                try container.persistentStoreCoordinator.remove(persistentStore)
            }
            
            // Reload persistent stores
            container.loadPersistentStores { description, error in
                if let error = error {
                    print("DEBUG: Error reloading Core Data stores: \(error)")
                } else {
                    print("DEBUG: Successfully reloaded Core Data stores")
                }
            }
        } catch {
            print("DEBUG: Error resetting Core Data: \(error)")
        }
    }
}
