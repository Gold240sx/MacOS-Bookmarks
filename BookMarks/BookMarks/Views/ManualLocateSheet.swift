//
//  ManualLocateSheet.swift
//  BookMarks
//
//  Created by Michael Martell on 12/18/25.
//

import SwiftUI
import AppKit

struct ManualLocateSheet: View {
    let folderName: String
    let onLocate: (URL?) -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Locate Folder")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Please locate the folder '\(folderName)' on your hard drive.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            
            HStack {
                Button("Cancel", role: .cancel) {
                    onCancel()
                }
                
                Button("Select Folder") {
                    let panel = NSOpenPanel()
                    panel.title = "Locate '\(folderName)'"
                    panel.allowsMultipleSelection = false
                    panel.canChooseDirectories = true
                    panel.canChooseFiles = false
                    panel.canCreateDirectories = false
                    
                    let response = panel.runModal()
                    if response == .OK {
                        onLocate(panel.url)
                    } else {
                        onCancel()
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 400)
    }
}

