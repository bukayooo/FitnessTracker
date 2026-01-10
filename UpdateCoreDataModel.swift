#!/usr/bin/env swift

import Foundation

// Path to the Core Data model file
let modelPath = "FitnessTracker/FitnessTracker/FitnessTracker.xcdatamodeld/FitnessTracker.xcdatamodel/contents"

// Read the model file
guard let modelXML = try? String(contentsOfFile: modelPath) else {
    print("Error: Could not read Core Data model file")
    exit(1)
}

// First check if the file already has manual codegen and change it to none
if modelXML.contains("codeGenerationType=\"manual\"") {
    // Replace codeGenerationType="manual" with codeGenerationType="none"
    let updatedXML = modelXML.replacingOccurrences(
        of: "codeGenerationType=\"manual\"", 
        with: "codeGenerationType=\"none\""
    )
    
    // Write the updated model back to disk
    do {
        try updatedXML.write(toFile: modelPath, atomically: true, encoding: .utf8)
        print("Successfully updated Core Data model to use 'none' code generation!")
    } catch {
        print("Error: Failed to write updated model: \(error)")
        exit(1)
    }
} 
// Then check if it has class codegen and change it to none
else if modelXML.contains("codeGenerationType=\"class\"") {
    // Replace codeGenerationType="class" with codeGenerationType="none"
    let updatedXML = modelXML.replacingOccurrences(
        of: "codeGenerationType=\"class\"", 
        with: "codeGenerationType=\"none\""
    )
    
    // Write the updated model back to disk
    do {
        try updatedXML.write(toFile: modelPath, atomically: true, encoding: .utf8)
        print("Successfully updated Core Data model to use 'none' code generation!")
    } catch {
        print("Error: Failed to write updated model: \(error)")
        exit(1)
    }
} else {
    print("Core Data model is already set to the correct code generation type or uses the default.")
} 