import SwiftUI

struct ReplayConnectionView: View {
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var alertTitle = "Transfer"
    @State private var isTransferring = false
    @State private var showHackScreen = false
    @State private var logs: [String] = []
    
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
                        Text(isTransferring ? "BYPASSING..." : "BYPASS")
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
            
            // Hack Screen Overlay
            if showHackScreen {
                HackTransferScreen(logs: $logs, isVisible: $showHackScreen)
                    .transition(.opacity)
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
        logs = []
        
        withAnimation {
            showHackScreen = true
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            let result = executeTransfer()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                isTransferring = false
                
                withAnimation {
                    showHackScreen = false
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    if result["success"] as? Bool == true {
                        showSuccess(result["message"] as? String ?? "Transfer completed!")
                    } else {
                        showError(result["message"] as? String ?? "Transfer failed")
                    }
                }
            }
        }
    }
    
    private func addLog(_ message: String) {
        DispatchQueue.main.async {
            logs.append(message)
        }
    }
    
    private func executeTransfer() -> [String: Any] {
        addLog("[SYSTEM] Initializing bypass system...")
        Thread.sleep(forTimeInterval: 0.3)
        
        addLog("[DETECT] Scanning for Free Fire MAX...")
        Thread.sleep(forTimeInterval: 0.2)
        
        var maxError: NSString?
        guard let ffMaxPath = MCMActivateContainerPath(2, "com.dts.freefiremax", false, &maxError) else {
            addLog("[ERROR] FF MAX not found!")
            return ["success": false, "message": "Free Fire MAX não encontrado"]
        }
        addLog("[SUCCESS] FF MAX detected: \(ffMaxPath)")
        Thread.sleep(forTimeInterval: 0.2)
        
        addLog("[DETECT] Scanning for Free Fire Normal...")
        Thread.sleep(forTimeInterval: 0.2)
        
        var normalError: NSString?
        guard let ffNormalPath = MCMActivateContainerPath(2, "com.dts.freefireth", false, &normalError) else {
            addLog("[ERROR] FF Normal not found!")
            return ["success": false, "message": "Free Fire Normal não encontrado"]
        }
        addLog("[SUCCESS] FF Normal detected: \(ffNormalPath)")
        Thread.sleep(forTimeInterval: 0.2)
        
        let sourcePath = URL(fileURLWithPath: ffMaxPath).appendingPathComponent("Documents/MReplays")
        let destPath = URL(fileURLWithPath: ffNormalPath).appendingPathComponent("Documents/MReplays")
        
        let fileManager = FileManager.default
        
        addLog("[ACCESS] Accessing replay directory...")
        Thread.sleep(forTimeInterval: 0.2)
        
        guard fileManager.fileExists(atPath: sourcePath.path) else {
            addLog("[ERROR] Replay folder not found!")
            return ["success": false, "message": "Pasta de replays do FF MAX não existe"]
        }
        
        do {
            try fileManager.createDirectory(at: destPath, withIntermediateDirectories: true)
            addLog("[CREATE] Destination folder ready")
            Thread.sleep(forTimeInterval: 0.2)
        } catch {
            addLog("[ERROR] Cannot create destination!")
            return ["success": false, "message": "Erro ao criar pasta destino"]
        }
        
        // Get reference Version from FF Normal
        var referenceVersion: String = "1.123.1"
        addLog("[ANALYZE] Reading target version...")
        Thread.sleep(forTimeInterval: 0.2)
        
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
                    addLog("[VERSION] Target: \(version)")
                }
            }
        } catch {}
        Thread.sleep(forTimeInterval: 0.2)
        
        // Process replays
        addLog("[BYPASS] Starting transfer process...")
        Thread.sleep(forTimeInterval: 0.3)
        
        do {
            let files = try fileManager.contentsOfDirectory(at: sourcePath, includingPropertiesForKeys: nil)
            let jsonFiles = files.filter { $0.pathExtension == "json" }
            
            guard !jsonFiles.isEmpty else {
                addLog("[ERROR] No replays found!")
                return ["success": false, "message": "Nenhum replay encontrado"]
            }
            
            addLog("[FOUND] \(jsonFiles.count) replays detected")
            Thread.sleep(forTimeInterval: 0.2)
            
            var transferred = 0
            
            for jsonFile in jsonFiles {
                let baseName = jsonFile.deletingPathExtension().lastPathComponent
                let binFile = sourcePath.appendingPathComponent("\(baseName).bin")
                
                guard fileManager.fileExists(atPath: binFile.path) else { continue }
                
                guard let jsonData = try? Data(contentsOf: jsonFile),
                      var jsonObject = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
                    continue
                }
                
                addLog("[TRANSFER] \(baseName)...")
                Thread.sleep(forTimeInterval: 0.15)
                
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
                
                addLog("[OK] \(baseName) transferred")
                transferred += 1
            }
            
            Thread.sleep(forTimeInterval: 0.3)
            addLog("[COMPLETE] \(transferred) replays bypassed!")
            Thread.sleep(forTimeInterval: 0.5)
            
            return ["success": true, "message": "✓ Transferidos \(transferred) replays!", "count": transferred]
        } catch {
            addLog("[ERROR] Transfer failed: \(error.localizedDescription)")
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

// Hack Transfer Screen
struct HackTransferScreen: View {
    @Binding var logs: [String]
    @Binding var isVisible: Bool
    
    var body: some View {
        ZStack {
            // Dark overlay
            Color.black.opacity(0.95)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("BYPASS SYSTEM")
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(.red)
                    Spacer()
                    Text("URIEL XITER")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(.green)
                }
                .padding()
                .background(Color(white: 0.05))
                .overlay(
                    Rectangle()
                        .stroke(Color.red, lineWidth: 1)
                )
                
                // Log console
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(Array(logs.enumerated()), id: \.offset) { index, log in
                                HStack(alignment: .top, spacing: 8) {
                                    Text("►")
                                        .font(.system(size: 12, design: .monospaced))
                                        .foregroundColor(.red)
                                    
                                    Text(log)
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundColor(getLogColor(log))
                                }
                                .id(index)
                            }
                        }
                        .padding()
                    }
                    .onChange(of: logs.count) { _ in
                        if let last = logs.indices.last {
                            withAnimation {
                                proxy.scrollTo(last, anchor: .bottom)
                            }
                        }
                    }
                }
                .background(Color.black)
                .overlay(
                    Rectangle()
                        .stroke(Color.red, lineWidth: 1)
                )
                
                // Footer
                HStack {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                        .shadow(color: .green, radius: 4)
                    
                    Text("PROCESSING...")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundColor(.green)
                    
                    Spacer()
                    
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .red))
                        .scaleEffect(0.7)
                }
                .padding()
                .background(Color(white: 0.05))
                .overlay(
                    Rectangle()
                        .stroke(Color.red, lineWidth: 1)
                )
            }
            .padding(20)
        }
    }
    
    private func getLogColor(_ log: String) -> Color {
        if log.contains("[ERROR]") {
            return .red
        } else if log.contains("[SUCCESS]") || log.contains("[OK]") || log.contains("[COMPLETE]") {
            return .green
        } else if log.contains("[TRANSFER]") || log.contains("[BYPASS]") {
            return .yellow
        } else {
            return .gray
        }
    }
}
