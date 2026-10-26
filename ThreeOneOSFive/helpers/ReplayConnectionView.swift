import SwiftUI

struct ReplayConnectionView: View {
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var alertTitle = "Transfer"
    @State private var isTransferring = false
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 30) {
                // Header
                VStack(spacing: 8) {
                    Text("URIEL XITER")
                        .font(.system(size: 42, weight: .bold))
                        .foregroundColor(.red)
                        .shadow(color: .red.opacity(0.5), radius: 10)
                    
                    Text("REPLAY TRANSFER")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.gray)
                        .tracking(2)
                }
                .padding(.top, 80)
                
                Spacer()
                
                // Transfer Button
                Button(action: transferReplays) {
                    HStack {
                        if isTransferring {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        }
                        Text(isTransferring ? "TRANSFERRING..." : "URIEL XITER")
                            .font(.system(size: 18, weight: .bold))
                            .tracking(3)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .background(
                        LinearGradient(
                            colors: [Color(red: 0.55, green: 0, blue: 0), .red],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundColor(.white)
                    .cornerRadius(0)
                    .overlay(
                        Rectangle()
                            .stroke(Color.red, lineWidth: 2)
                    )
                    .shadow(color: .red.opacity(0.5), radius: 20)
                }
                .disabled(isTransferring)
                .padding(.horizontal, 30)
                
                Spacer()
                
                // Info
                VStack(spacing: 8) {
                    Text("Tap to transfer replays")
                        .font(.system(size: 12))
                        .foregroundColor(.gray.opacity(0.6))
                    
                    Text("FF MAX → FF Normal")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.red.opacity(0.8))
                }
                .padding(.bottom, 60)
            }
        }
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text(alertTitle),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    private func transferReplays() {
        isTransferring = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            let result = executeTransfer()
            
            DispatchQueue.main.async {
                isTransferring = false
                
                if result["success"] as? Bool == true {
                    showSuccess(result["message"] as? String ?? "Transfer completed!")
                } else {
                    showError(result["message"] as? String ?? "Transfer failed")
                }
            }
        }
    }
    
    private func executeTransfer() -> [String: Any] {
        log("Transfer: Starting replay transfer")
        
        var maxError: NSString?
        guard let ffMaxPath = MCMActivateContainerPath(2, "com.dts.freefiremax", false, &maxError) else {
            log("Transfer: FF MAX not found")
            return ["success": false, "message": "Free Fire MAX não encontrado"]
        }
        
        var normalError: NSString?
        guard let ffNormalPath = MCMActivateContainerPath(2, "com.dts.freefireth", false, &normalError) else {
            log("Transfer: FF Normal not found")
            return ["success": false, "message": "Free Fire Normal não encontrado"]
        }
        
        let sourcePath = URL(fileURLWithPath: ffMaxPath).appendingPathComponent("Documents/MReplays")
        let destPath = URL(fileURLWithPath: ffNormalPath).appendingPathComponent("Documents/MReplays")
        
        let fileManager = FileManager.default
        
        guard fileManager.fileExists(atPath: sourcePath.path) else {
            return ["success": false, "message": "Pasta de replays do FF MAX não existe"]
        }
        
        do {
            try fileManager.createDirectory(at: destPath, withIntermediateDirectories: true)
        } catch {
            return ["success": false, "message": "Erro ao criar pasta destino"]
        }
        
        // Get reference Version from FF Normal
        var referenceVersion: String = "1.123.1"
        do {
            let destFiles = try fileManager.contentsOfDirectory(at: destPath, includingPropertiesForKeys: [.creationDateKey])
            let jsonFiles = destFiles.filter { $0.pathExtension == "json" }
            
            if let mostRecent = jsonFiles.sorted(by: {
                let date1 = try? $0.resourceValues(forKeys: [.creationDateKey]).creationDate ?? Date.distantPast
                let date2 = try? $1.resourceValues(forKeys: [.creationDateKey]).creationDate ?? Date.distantPast
                return (date1 ?? Date.distantPast) > (date2 ?? Date.distantPast)
            }).first {
                if let jsonData = try? Data(contentsOf: mostRecent),
                   let jsonObject = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                   let version = jsonObject["Version"] as? String {
                    referenceVersion = version
                    log("Transfer: Reference Version = \(version)")
                }
            }
        } catch {}
        
        // Process replays
        do {
            let files = try fileManager.contentsOfDirectory(at: sourcePath, includingPropertiesForKeys: nil)
            let jsonFiles = files.filter { $0.pathExtension == "json" }
            
            guard !jsonFiles.isEmpty else {
                return ["success": false, "message": "Nenhum replay encontrado"]
            }
            
            var transferred = 0
            
            for jsonFile in jsonFiles {
                let baseName = jsonFile.deletingPathExtension().lastPathComponent
                let binFile = sourcePath.appendingPathComponent("\(baseName).bin")
                
                guard fileManager.fileExists(atPath: binFile.path) else { continue }
                
                guard let jsonData = try? Data(contentsOf: jsonFile),
                      var jsonObject = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
                    continue
                }
                
                // Swap Version only
                jsonObject["Version"] = referenceVersion
                
                let destJsonFile = destPath.appendingPathComponent(jsonFile.lastPathComponent)
                let modifiedJsonData = try JSONSerialization.data(withJSONObject: jsonObject, options: [.prettyPrinted])
                
                if fileManager.fileExists(atPath: destJsonFile.path) {
                    try? fileManager.removeItem(at: destJsonFile)
                }
                try modifiedJsonData.write(to: destJsonFile, options: [.atomic])
                
                // Force sync
                if let fileHandle = FileHandle(forWritingAtPath: destJsonFile.path) {
                    fileHandle.synchronizeFile()
                    fileHandle.closeFile()
                }
                
                // Copy bin
                let destBinFile = destPath.appendingPathComponent(binFile.lastPathComponent)
                if fileManager.fileExists(atPath: destBinFile.path) {
                    try? fileManager.removeItem(at: destBinFile)
                }
                try fileManager.copyItem(at: binFile, to: destBinFile)
                
                if let fileHandle = FileHandle(forWritingAtPath: destBinFile.path) {
                    fileHandle.synchronizeFile()
                    fileHandle.closeFile()
                }
                
                transferred += 1
            }
            
            log("Transfer: Completed - \(transferred) replays")
            return ["success": true, "message": "Transferidos \(transferred) replays!", "count": transferred]
        } catch {
            log("Transfer: Error - \(error)")
            return ["success": false, "message": "Erro: \(error.localizedDescription)"]
        }
    }
    
    private func showSuccess(_ message: String) {
        alertTitle = "Success"
        alertMessage = message
        showAlert = true
    }
    
    private func showError(_ message: String) {
        alertTitle = "Error"
        alertMessage = message
        showAlert = true
    }
}
