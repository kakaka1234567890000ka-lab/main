import SwiftUI
import Foundation

struct ReplayTransferView: View {
    @Environment(\.appLanguage) private var language
    @State private var isTransferring = false
    @State private var statusMessage = ""
    @State private var transferLog: [String] = []
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    // Bundle IDs
    private let ffMaxBundleID = "com.dts.freefiremax"
    private let ffNormalBundleID = "com.dts.freefireth"
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("FF Replay Transfer")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Transfer replays from FF MAX to FF Normal")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)
                
                // Info Card
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.blue)
                        Text("How it works")
                            .font(.headline)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        bulletPoint("Copies .json and .bin files from FF MAX")
                        bulletPoint("Updates Version and AccountID automatically")
                        bulletPoint("Preserves replay compatibility")
                        bulletPoint("100% safe - FF Normal stays clean")
                    }
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal)
                
                // Status
                if !statusMessage.isEmpty {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text(statusMessage)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                    .padding(.horizontal)
                }
                
                // Transfer Button
                Button(action: { transferReplays() }) {
                    HStack {
                        Image(systemName: isTransferring ? "hourglass" : "paperplane.fill")
                        Text(isTransferring ? "Transferring..." : "Transfer Replays")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isTransferring ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(isTransferring)
                .padding(.horizontal)
                
                // Log
                if !transferLog.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "doc.text.fill")
                            Text("Transfer Log")
                                .font(.headline)
                            Spacer()
                            Button("Clear") {
                                transferLog.removeAll()
                            }
                            .font(.caption)
                            .foregroundColor(.blue)
                        }
                        
                        ScrollView {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(Array(transferLog.enumerated()), id: \.offset) { _, entry in
                                    Text(entry)
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundColor(.primary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                        }
                        .frame(height: 200)
                        .background(Color.black.opacity(0.05))
                        .cornerRadius(8)
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
            }
        }
        .navigationTitle("Replay Transfer")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Transfer Result", isPresented: $showAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func bulletPoint(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
            Text(text)
                .font(.subheadline)
        }
    }
    
    private func addLog(_ message: String) {
        let timestamp = Date().formatted(date: .omitted, time: .standard)
        transferLog.append("[\(timestamp)] \(message)")
    }
    
    private func transferReplays() {
        guard !isTransferring else { return }
        
        isTransferring = true
        statusMessage = "Starting transfer..."
        addLog("=== Transfer Started ===")
        
        Task {
            do {
                // Get container paths
                guard let maxContainer = try await getContainerPath(bundleID: ffMaxBundleID) else {
                    throw TransferError.containerNotFound(ffMaxBundleID)
                }
                
                guard let normalContainer = try await getContainerPath(bundleID: ffNormalBundleID) else {
                    throw TransferError.containerNotFound(ffNormalBundleID)
                }
                
                addLog("✓ FF MAX container found")
                addLog("✓ FF Normal container found")
                
                let maxReplaysPath = maxContainer.appendingPathComponent("Documents/MReplays")
                let normalReplaysPath = normalContainer.appendingPathComponent("Documents/MReplays")
                
                // Create destination if needed
                try FileManager.default.createDirectory(at: normalReplaysPath, withIntermediateDirectories: true)
                addLog("✓ Destination folder ready")
                
                // Get reference replay (for Version/AccountID)
                statusMessage = "Reading reference replay..."
                let referenceData = try getReferenceReplayData(from: normalReplaysPath)
                addLog("✓ Reference data extracted")
                
                // Transfer replays
                statusMessage = "Copying replay files..."
                let transferred = try await transferReplayFiles(
                    from: maxReplaysPath,
                    to: normalReplaysPath,
                    referenceData: referenceData
                )
                
                await MainActor.run {
                    isTransferring = false
                    statusMessage = ""
                    alertMessage = "✓ Success!\n\n\(transferred) replays transferred"
                    showAlert = true
                    addLog("=== Transfer Complete: \(transferred) files ===")
                }
                
            } catch {
                await MainActor.run {
                    isTransferring = false
                    statusMessage = ""
                    alertMessage = "✗ Error:\n\n\(error.localizedDescription)"
                    showAlert = true
                    addLog("✗ ERROR: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func getContainerPath(bundleID: String) async throws -> URL? {
        // Use 3105's MobileHouseArrest exploit to get container path
        let containers = try await ContainerManagerService.shared.resolveAllContainers()
        return containers.first(where: { $0.bundleID == bundleID })?.url
    }
    
    private func getReferenceReplayData(from path: URL) throws -> ReplayReferenceData {
        let fileManager = FileManager.default
        let jsonFiles = try fileManager.contentsOfDirectory(at: path, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
            .sorted { $0.lastModified() > $1.lastModified() }
        
        guard let latest = jsonFiles.first else {
            return ReplayReferenceData(version: "1.123.1", accountID: nil)
        }
        
        let data = try Data(contentsOf: latest)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        let version = json?["Version"] as? String ?? "1.123.1"
        let accountID = json?["AccountID"] as? String
        
        return ReplayReferenceData(version: version, accountID: accountID)
    }
    
    private func transferReplayFiles(from source: URL, to destination: URL, referenceData: ReplayReferenceData) async throws -> Int {
        let fileManager = FileManager.default
        let jsonFiles = try fileManager.contentsOfDirectory(at: source, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
        
        var count = 0
        
        for jsonFile in jsonFiles {
            let binFile = jsonFile.deletingPathExtension().appendingPathExtension("bin")
            
            // Copy JSON
            let destJSON = destination.appendingPathComponent(jsonFile.lastPathComponent)
            try? fileManager.removeItem(at: destJSON)
            try fileManager.copyItem(at: jsonFile, to: destJSON)
            
            // Copy BIN if exists
            if fileManager.fileExists(atPath: binFile.path) {
                let destBIN = destination.appendingPathComponent(binFile.lastPathComponent)
                try? fileManager.removeItem(at: destBIN)
                try fileManager.copyItem(at: binFile, to: destBIN)
            }
            
            // Modify JSON
            try modifyReplayJSON(at: destJSON, referenceData: referenceData)
            
            count += 1
            addLog("✓ Copied: \(jsonFile.lastPathComponent)")
        }
        
        return count
    }
    
    private func modifyReplayJSON(at url: URL, referenceData: ReplayReferenceData) throws {
        var data = try Data(contentsOf: url)
        var json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        
        // Update Version
        json["Version"] = referenceData.version
        
        // Update AccountID if available
        if let accountID = referenceData.accountID {
            json["AccountID"] = accountID
        }
        
        data = try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted])
        try data.write(to: url)
    }
}

struct ReplayReferenceData {
    let version: String
    let accountID: String?
}

enum TransferError: LocalizedError {
    case containerNotFound(String)
    
    var errorDescription: String? {
        switch self {
        case .containerNotFound(let bundleID):
            return "Container not found for \(bundleID). Make sure both FF MAX and FF Normal are installed."
        }
    }
}

extension URL {
    func lastModified() -> Date {
        (try? resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
    }
}
