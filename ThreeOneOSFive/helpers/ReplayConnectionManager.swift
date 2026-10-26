import Foundation
import Network

class ReplayConnectionManager: ObservableObject {
    @Published var isConnected = false
    @Published var isConnecting = false
    
    private var listener: NWListener?
    private var serverIP: String = ""
    private var serverPort: Int = 8080
    private let localPort: UInt16 = 9090 // Local server port for receiving commands
    
    // Start local HTTP server to receive commands from Python
    func startLocalServer() {
        guard listener == nil else { return }
        
        log("ReplayConnection: Starting local server on port \(localPort)")
        
        do {
            let parameters = NWParameters.tcp
            parameters.allowLocalEndpointReuse = true
            
            listener = try NWListener(using: parameters, on: NWEndpoint.Port(integerLiteral: localPort))
            
            listener?.newConnectionHandler = { [weak self] connection in
                log("ReplayConnection: Received command from Python")
                self?.handleCommand(connection)
            }
            
            listener?.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    log("ReplayConnection: Local server ready on port \(self.localPort)")
                case .failed(let error):
                    log("ReplayConnection: Local server failed - \(error)")
                default:
                    break
                }
            }
            
            listener?.start(queue: .global(qos: .userInitiated))
        } catch {
            log("ReplayConnection: Failed to start local server - \(error)")
        }
    }
    
    // Connect to Python server
    func connectToServer(ip: String, port: Int, completion: @escaping (Bool, String) -> Void) {
        serverIP = ip
        serverPort = port
        
        DispatchQueue.main.async {
            self.isConnecting = true
        }
        
        // Register device with server
        guard let url = URL(string: "http://\(ip):\(port)?action=device_register") else {
            DispatchQueue.main.async {
                self.isConnecting = false
                completion(false, "Invalid server URL")
            }
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let deviceData: [String: Any] = [
            "device_id": UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString,
            "device_name": UIDevice.current.name,
            "local_port": localPort,
            "ios_version": UIDevice.current.systemVersion
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: deviceData) else {
            DispatchQueue.main.async {
                self.isConnecting = false
                completion(false, "Failed to create request")
            }
            return
        }
        
        request.httpBody = jsonData
        request.timeoutInterval = 10
        
        log("ReplayConnection: Registering with server at \(ip):\(port)")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isConnecting = false
                
                if let error = error {
                    log("ReplayConnection: Registration failed - \(error)")
                    self?.isConnected = false
                    completion(false, "Connection failed: \(error.localizedDescription)")
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    log("ReplayConnection: Successfully registered with server")
                    self?.isConnected = true
                    completion(true, "Connected to server!")
                    
                    // Start heartbeat
                    self?.startHeartbeat()
                } else {
                    log("ReplayConnection: Registration rejected by server")
                    self?.isConnected = false
                    completion(false, "Server rejected connection")
                }
            }
        }.resume()
    }
    
    // Handle commands from Python server
    private func handleCommand(_ connection: NWConnection) {
        connection.start(queue: .global(qos: .userInitiated))
        
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let data = data, !data.isEmpty,
                  let request = String(data: data, encoding: .utf8) else {
                connection.cancel()
                return
            }
            
            log("ReplayConnection: Received request: \(request.prefix(100))")
            
            // Parse HTTP request
            let lines = request.components(separatedBy: "\r\n")
            guard let requestLine = lines.first else {
                self?.sendResponse(connection: connection, statusCode: 400, body: "{\"error\":\"Bad Request\"}")
                return
            }
            
            let parts = requestLine.components(separatedBy: " ")
            guard parts.count >= 2 else {
                self?.sendResponse(connection: connection, statusCode: 400, body: "{\"error\":\"Bad Request\"}")
                return
            }
            
            let method = parts[0]
            let path = parts[1]
            
            if method == "POST" && path == "/transfer" {
                log("ReplayConnection: Executing replay transfer...")
                let result = self?.executeTransfer() ?? ["success": false, "message": "Transfer failed"]
                
                if let jsonData = try? JSONSerialization.data(withJSONObject: result),
                   let jsonString = String(data: jsonData, encoding: .utf8) {
                    self?.sendResponse(connection: connection, statusCode: 200, body: jsonString)
                } else {
                    self?.sendResponse(connection: connection, statusCode: 500, body: "{\"error\":\"Internal error\"}")
                }
            } else if method == "GET" && path == "/status" {
                let status = ["status": "online", "connected": self?.isConnected ?? false] as [String : Any]
                if let jsonData = try? JSONSerialization.data(withJSONObject: status),
                   let jsonString = String(data: jsonData, encoding: .utf8) {
                    self?.sendResponse(connection: connection, statusCode: 200, body: jsonString)
                }
            } else {
                self?.sendResponse(connection: connection, statusCode: 404, body: "{\"error\":\"Not Found\"}")
            }
            
            if isComplete {
                connection.cancel()
            }
        }
    }
    
    // Execute replay transfer (same logic as before)
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
    
    // Send HTTP response
    private func sendResponse(connection: NWConnection, statusCode: Int, body: String) {
        let response = """
        HTTP/1.1 \(statusCode) OK\r
        Content-Type: application/json\r
        Content-Length: \(body.utf8.count)\r
        Connection: close\r
        \r
        \(body)
        """
        
        let data = response.data(using: .utf8)!
        connection.send(content: data, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
    
    // Heartbeat to keep connection alive
    private func startHeartbeat() {
        Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            guard let self = self, self.isConnected else { return }
            
            guard let url = URL(string: "http://\(self.serverIP):\(self.serverPort)?action=device_heartbeat") else { return }
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let deviceData: [String: Any] = [
                "device_id": UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
            ]
            
            guard let jsonData = try? JSONSerialization.data(withJSONObject: deviceData) else { return }
            request.httpBody = jsonData
            request.timeoutInterval = 5
            
            URLSession.shared.dataTask(with: request) { _, response, error in
                if error != nil || (response as? HTTPURLResponse)?.statusCode != 200 {
                    DispatchQueue.main.async {
                        self.isConnected = false
                    }
                }
            }.resume()
        }
    }
    
    deinit {
        listener?.cancel()
    }
}
