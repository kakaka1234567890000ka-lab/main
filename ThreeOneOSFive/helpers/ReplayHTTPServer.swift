import Foundation
import Network

class ReplayHTTPServer: ObservableObject {
    private var listener: NWListener?
    @Published var isRunning = false
    private let port: UInt16 = 8080
    
    func start() {
        guard listener == nil else { return }
        
        do {
            let parameters = NWParameters.tcp
            parameters.allowLocalEndpointReuse = true
            
            listener = try NWListener(using: parameters, on: NWEndpoint.Port(integerLiteral: port))
            
            listener?.newConnectionHandler = { [weak self] connection in
                self?.handleConnection(connection)
            }
            
            listener?.stateUpdateHandler = { [weak self] state in
                DispatchQueue.main.async {
                    switch state {
                    case .ready:
                        self?.isRunning = true
                        log("HTTP Server: Started on port \(self?.port ?? 0)")
                    case .failed(let error):
                        log("HTTP Server: Failed - \(error)")
                        self?.isRunning = false
                    case .cancelled:
                        self?.isRunning = false
                    default:
                        break
                    }
                }
            }
            
            listener?.start(queue: .global(qos: .userInitiated))
        } catch {
            log("HTTP Server: Failed to start - \(error)")
        }
    }
    
    func stop() {
        listener?.cancel()
        listener = nil
        isRunning = false
    }
    
    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: .global(qos: .userInitiated))
        
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let data = data, !data.isEmpty else {
                connection.cancel()
                return
            }
            
            if let request = String(data: data, encoding: .utf8) {
                self?.processRequest(request, connection: connection)
            }
            
            if isComplete {
                connection.cancel()
            }
        }
    }
    
    private func processRequest(_ request: String, connection: NWConnection) {
        let lines = request.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else {
            sendResponse(connection: connection, statusCode: 400, body: "Bad Request")
            return
        }
        
        let parts = requestLine.components(separatedBy: " ")
        guard parts.count >= 2 else {
            sendResponse(connection: connection, statusCode: 400, body: "Bad Request")
            return
        }
        
        let method = parts[0]
        let path = parts[1]
        
        if method == "GET" && path == "/" {
            sendHTMLInterface(connection: connection)
        } else if method == "POST" && path == "/api/login" {
            handleLogin(request: request, connection: connection)
        } else if method == "POST" && path == "/api/transfer" {
            handleTransfer(connection: connection)
        } else {
            sendResponse(connection: connection, statusCode: 404, body: "Not Found")
        }
    }
    
    private func handleLogin(request: String, connection: NWConnection) {
        // Extract POST body
        guard let bodyStart = request.range(of: "\r\n\r\n")?.upperBound else {
            sendJSONResponse(connection: connection, json: ["success": false, "message": "Invalid request"])
            return
        }
        
        let body = String(request[bodyStart...])
        let params = parseFormData(body)
        
        guard let username = params["username"], let deviceUID = params["deviceUID"] else {
            sendJSONResponse(connection: connection, json: ["success": false, "message": "Missing credentials"])
            return
        }
        
        // Validate with urielxiter.shop
        validateLogin(username: username, deviceUID: deviceUID) { success in
            if success {
                self.sendJSONResponse(connection: connection, json: ["success": true, "message": "Login successful"])
            } else {
                self.sendJSONResponse(connection: connection, json: ["success": false, "message": "Invalid credentials"])
            }
        }
    }
    
    private func validateLogin(username: String, deviceUID: String, completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: "https://urielxiter.shop/mod/CheckLogin.php") else {
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = "user=\(username)&deviceUID=\(deviceUID)".data(using: .utf8)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data,
                  let responseText = String(data: data, encoding: .utf8) else {
                completion(false)
                return
            }
            
            completion(responseText.contains("success") || responseText.contains("valid"))
        }.resume()
    }
    
    private func handleTransfer(connection: NWConnection) {
        DispatchQueue.global(qos: .userInitiated).async {
            let result = self.transferReplays()
            self.sendJSONResponse(connection: connection, json: result)
        }
    }
    
    private func transferReplays() -> [String: Any] {
        // Get FF MAX container
        var maxError: NSString?
        guard let ffMaxPath = MCMActivateContainerPath(2, "com.dts.freefiremax", false, &maxError) else {
            return ["success": false, "message": "Free Fire MAX not found"]
        }
        
        // Get FF Normal container
        var normalError: NSString?
        guard let ffNormalPath = MCMActivateContainerPath(2, "com.dts.freefireth", false, &normalError) else {
            return ["success": false, "message": "Free Fire Normal not found"]
        }
        
        let sourcePath = URL(fileURLWithPath: ffMaxPath).appendingPathComponent("Documents/MReplays")
        let destPath = URL(fileURLWithPath: ffNormalPath).appendingPathComponent("Documents/MReplays")
        
        let fileManager = FileManager.default
        
        // Create destination directory if it doesn't exist
        try? fileManager.createDirectory(at: destPath, withIntermediateDirectories: true)
        
        do {
            let files = try fileManager.contentsOfDirectory(at: sourcePath, includingPropertiesForKeys: nil)
            var transferred = 0
            
            for file in files where file.pathExtension == "replay" {
                let destFile = destPath.appendingPathComponent(file.lastPathComponent)
                try? fileManager.removeItem(at: destFile) // Remove if exists
                try fileManager.copyItem(at: file, to: destFile)
                transferred += 1
            }
            
            return ["success": true, "message": "Transferred \(transferred) replays", "count": transferred]
        } catch {
            return ["success": false, "message": "Error: \(error.localizedDescription)"]
        }
    }
    
    private func parseFormData(_ data: String) -> [String: String] {
        var result: [String: String] = [:]
        let pairs = data.components(separatedBy: "&")
        for pair in pairs {
            let kv = pair.components(separatedBy: "=")
            if kv.count == 2 {
                let key = kv[0].removingPercentEncoding ?? kv[0]
                let value = kv[1].removingPercentEncoding ?? kv[1]
                result[key] = value
            }
        }
        return result
    }
    
    private func sendHTMLInterface(connection: NWConnection) {
        let html = """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>3105 Replay Transfer</title>
            <style>
                * { margin: 0; padding: 0; box-sizing: border-box; }
                body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); min-height: 100vh; display: flex; align-items: center; justify-content: center; padding: 20px; }
                .container { background: white; border-radius: 20px; box-shadow: 0 20px 60px rgba(0,0,0,0.3); max-width: 400px; width: 100%; padding: 40px 30px; }
                h1 { color: #333; margin-bottom: 10px; font-size: 28px; text-align: center; }
                .subtitle { color: #666; font-size: 14px; text-align: center; margin-bottom: 30px; }
                .form-group { margin-bottom: 20px; }
                label { display: block; color: #555; margin-bottom: 8px; font-weight: 500; font-size: 14px; }
                input { width: 100%; padding: 12px 15px; border: 2px solid #e0e0e0; border-radius: 10px; font-size: 16px; transition: border-color 0.3s; }
                input:focus { outline: none; border-color: #667eea; }
                button { width: 100%; padding: 14px; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; border: none; border-radius: 10px; font-size: 16px; font-weight: 600; cursor: pointer; transition: transform 0.2s, box-shadow 0.2s; }
                button:hover { transform: translateY(-2px); box-shadow: 0 10px 20px rgba(102, 126, 234, 0.4); }
                button:active { transform: translateY(0); }
                button:disabled { opacity: 0.6; cursor: not-allowed; }
                .dashboard { display: none; }
                .dashboard.active { display: block; }
                .login-form.hidden { display: none; }
                .welcome { color: #667eea; font-size: 18px; margin-bottom: 20px; text-align: center; font-weight: 600; }
                .transfer-btn { margin-top: 20px; }
                .message { padding: 12px; border-radius: 8px; margin-top: 15px; font-size: 14px; text-align: center; }
                .message.success { background: #d4edda; color: #155724; }
                .message.error { background: #f8d7da; color: #721c24; }
                .loading { display: inline-block; width: 20px; height: 20px; border: 3px solid rgba(255,255,255,0.3); border-top-color: white; border-radius: 50%; animation: spin 0.8s linear infinite; margin-left: 10px; }
                @keyframes spin { to { transform: rotate(360deg); } }
            </style>
        </head>
        <body>
            <div class="container">
                <h1>🎮 3105</h1>
                <p class="subtitle">Replay Transfer System</p>
                
                <div class="login-form" id="loginForm">
                    <div class="form-group">
                        <label for="username">Username</label>
                        <input type="text" id="username" placeholder="Enter your username" required>
                    </div>
                    <div class="form-group">
                        <label for="deviceUID">Device UID</label>
                        <input type="text" id="deviceUID" placeholder="Enter your device UID" required>
                    </div>
                    <button onclick="login()" id="loginBtn">Login</button>
                    <div id="loginMessage"></div>
                </div>
                
                <div class="dashboard" id="dashboard">
                    <div class="welcome" id="welcomeMsg">Welcome!</div>
                    <button class="transfer-btn" onclick="transferReplays()" id="transferBtn">
                        Transfer Replays (FF MAX → FF Normal)
                    </button>
                    <div id="transferMessage"></div>
                </div>
            </div>
            
            <script>
                async function login() {
                    const username = document.getElementById('username').value;
                    const deviceUID = document.getElementById('deviceUID').value;
                    const btn = document.getElementById('loginBtn');
                    const msgDiv = document.getElementById('loginMessage');
                    
                    if (!username || !deviceUID) {
                        showMessage(msgDiv, 'Please fill all fields', 'error');
                        return;
                    }
                    
                    btn.disabled = true;
                    btn.innerHTML = 'Logging in...<span class="loading"></span>';
                    
                    try {
                        const response = await fetch('/api/login', {
                            method: 'POST',
                            headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
                            body: `username=${encodeURIComponent(username)}&deviceUID=${encodeURIComponent(deviceUID)}`
                        });
                        
                        const data = await response.json();
                        
                        if (data.success) {
                            document.getElementById('loginForm').classList.add('hidden');
                            document.getElementById('dashboard').classList.add('active');
                            document.getElementById('welcomeMsg').textContent = `Welcome, ${username}!`;
                        } else {
                            showMessage(msgDiv, data.message || 'Login failed', 'error');
                            btn.disabled = false;
                            btn.innerHTML = 'Login';
                        }
                    } catch (error) {
                        showMessage(msgDiv, 'Connection error', 'error');
                        btn.disabled = false;
                        btn.innerHTML = 'Login';
                    }
                }
                
                async function transferReplays() {
                    const btn = document.getElementById('transferBtn');
                    const msgDiv = document.getElementById('transferMessage');
                    
                    btn.disabled = true;
                    btn.innerHTML = 'Transferring...<span class="loading"></span>';
                    
                    try {
                        const response = await fetch('/api/transfer', { method: 'POST' });
                        const data = await response.json();
                        
                        if (data.success) {
                            showMessage(msgDiv, data.message, 'success');
                        } else {
                            showMessage(msgDiv, data.message, 'error');
                        }
                    } catch (error) {
                        showMessage(msgDiv, 'Transfer failed', 'error');
                    } finally {
                        btn.disabled = false;
                        btn.innerHTML = 'Transfer Replays (FF MAX → FF Normal)';
                    }
                }
                
                function showMessage(div, text, type) {
                    div.className = `message ${type}`;
                    div.textContent = text;
                    div.style.display = 'block';
                }
            </script>
        </body>
        </html>
        """
        
        sendResponse(connection: connection, statusCode: 200, body: html, contentType: "text/html; charset=utf-8")
    }
    
    private func sendJSONResponse(connection: NWConnection, json: [String: Any]) {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: json),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            sendResponse(connection: connection, statusCode: 500, body: "{\"error\":\"Internal error\"}")
            return
        }
        
        sendResponse(connection: connection, statusCode: 200, body: jsonString, contentType: "application/json")
    }
    
    private func sendResponse(connection: NWConnection, statusCode: Int, body: String, contentType: String = "text/plain") {
        let response = """
        HTTP/1.1 \(statusCode) OK\r
        Content-Type: \(contentType)\r
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
    
    deinit {
        stop()
    }
}
