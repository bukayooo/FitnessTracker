//
//  FitnessTrackerApp.swift
//  FitnessTracker
//
//  Created by Bukayo Odedele on 2/25/25.
//

import SwiftUI
import CoreData

// Create a notification name for scene phase changes
extension Notification.Name {
    static let appScenePhaseChanged = Notification.Name("AppScenePhaseChanged")
}

@main
struct FitnessTrackerApp: App {
    let persistenceController = PersistenceController.shared
    
    @Environment(\.scenePhase) var scenePhase
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .tint(.fitnessPrimary)
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            // Broadcast app state change so any active TimerManager instances can respond
            NotificationCenter.default.post(
                name: .appScenePhaseChanged,
                object: nil,
                userInfo: ["phase": newPhase]
            )
            
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
        } else {
            // Configure store to ensure it's included in backups
            guard let storeDescription = container.persistentStoreDescriptions.first else {
                fatalError("No persistent store description found")
            }
            
            // Get the app's document directory which is backed up by default
            let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let storeName = "FitnessTracker.sqlite"
            let storeURL = documentsDirectory.appendingPathComponent(storeName)
            
            print("DEBUG: Setting Core Data store location to \(storeURL.path)")
            storeDescription.url = storeURL
            
            // Set options to ensure data is included in backups
            storeDescription.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        }
        
        container.loadPersistentStores { description, error in
            if let error = error {
                fatalError("Error loading Core Data stores: \(error.localizedDescription)")
            }
            
            print("DEBUG: Core Data store loaded successfully from \(description.url?.absoluteString ?? "unknown location")")
            
            // Verify backup status of the store file
            if let storeURL = description.url {
                self.verifyBackupAttributes(for: storeURL)
            }
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
    
    // Verify that the database file is set to be included in backups
    private func verifyBackupAttributes(for url: URL) {
        do {
            var resourceValues = URLResourceValues()
            resourceValues.isExcludedFromBackup = false
            
            var fileURL = url
            try fileURL.setResourceValues(resourceValues)
            
            // Also ensure the parent directory is included in backups
            var directoryURL = url.deletingLastPathComponent()
            try directoryURL.setResourceValues(resourceValues)
            
            // Check if the file is actually marked for backup
            let retrievedValues = try url.resourceValues(forKeys: [.isExcludedFromBackupKey])
            let isExcluded = retrievedValues.isExcludedFromBackup ?? true
            
            print("DEBUG: Core Data store backup status - excluded from backup: \(isExcluded)")
            if isExcluded {
                print("DEBUG: Warning - Core Data store is still excluded from backups despite attempt to include it")
            } else {
                print("DEBUG: Core Data store is properly configured for backup")
            }
        } catch {
            print("DEBUG: Error setting backup attributes: \(error.localizedDescription)")
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
                    
                    // Verify backup status after reload
                    if let storeURL = description.url {
                        self.verifyBackupAttributes(for: storeURL)
                    }
                }
            }
        } catch {
            print("DEBUG: Error resetting Core Data: \(error)")
        }
    }
}
