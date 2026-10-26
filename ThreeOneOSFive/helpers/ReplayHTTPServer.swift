import Foundation
import Network

class ReplayHTTPServer: ObservableObject {
    private var listener: NWListener?
    @Published var isRunning = false
    private let port: UInt16 = 8080
    
    func start() {
        guard listener == nil else { return }
        
        log("HTTP Server: Attempting to start on port \(port)")
        
        do {
            let parameters = NWParameters.tcp
            parameters.allowLocalEndpointReuse = true
            
            listener = try NWListener(using: parameters, on: NWEndpoint.Port(integerLiteral: port))
            
            listener?.newConnectionHandler = { [weak self] connection in
                log("HTTP Server: New connection received")
                self?.handleConnection(connection)
            }
            
            listener?.stateUpdateHandler = { [weak self] state in
                DispatchQueue.main.async {
                    switch state {
                    case .ready:
                        self?.isRunning = true
                        log("HTTP Server: ✅ Started successfully on port \(self?.port ?? 0)")
                    case .failed(let error):
                        log("HTTP Server: ❌ Failed - \(error)")
                        self?.isRunning = false
                    case .cancelled:
                        log("HTTP Server: Cancelled")
                        self?.isRunning = false
                    default:
                        log("HTTP Server: State changed to \(state)")
                        break
                    }
                }
            }
            
            listener?.start(queue: .global(qos: .userInitiated))
            log("HTTP Server: Listener started, waiting for ready state...")
        } catch {
            log("HTTP Server: ❌ Failed to start - \(error)")
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
        
        guard let key = params["key"] else {
            sendJSONResponse(connection: connection, json: ["success": false, "message": "Missing key"])
            return
        }
        
        // Get device UID (same as app)
        let deviceUID = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        
        // Validate with urielxiter.shop
        validateLogin(username: key, deviceUID: deviceUID) { success in
            if success {
                self.sendJSONResponse(connection: connection, json: ["success": true, "message": "Login successful"])
            } else {
                self.sendJSONResponse(connection: connection, json: ["success": false, "message": "Key inválida"])
            }
        }
    }
    
    private func validateLogin(username: String, deviceUID: String, completion: @escaping (Bool) -> Void) {
        var components = URLComponents(string: "https://urielxiter.shop/mod/CheckLogin.php")
        components?.queryItems = [
            URLQueryItem(name: "user", value: username),
            URLQueryItem(name: "uid", value: deviceUID)
        ]
        
        guard let url = components?.url else {
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 15
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data,
                  let responseText = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) else {
                completion(false)
                return
            }
            
            // Same validation as KeyAuthService
            let errorPrefixes = [
                "Em manutenção",
                "Usuário inválido",
                "Dispositivo não permitido",
                "Usuário banido",
                "Usuário pausado",
                "Key expirada",
                "Configuração de dispositivo inválida",
                "ﾠ"
            ]
            
            let isError = errorPrefixes.contains(where: { responseText.lowercased().hasPrefix($0.lowercased()) })
                || responseText.isEmpty
            
            completion(!isError)
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
        <html lang="pt-BR">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>URIEL XITER - 3105</title>
            <style>
                * { margin: 0; padding: 0; box-sizing: border-box; }
                body { 
                    font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Display', 'Segoe UI', Roboto, sans-serif;
                    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                    min-height: 100vh;
                    display: flex;
                    align-items: center;
                    justify-content: center;
                    padding: 20px;
                }
                .container {
                    background: white;
                    border-radius: 24px;
                    box-shadow: 0 20px 60px rgba(0,0,0,0.3);
                    max-width: 440px;
                    width: 100%;
                    padding: 48px 32px;
                    text-align: center;
                }
                .logo { 
                    font-size: 64px; 
                    margin-bottom: 20px;
                }
                h1 { 
                    color: #1a1a1a;
                    font-size: 32px;
                    font-weight: 700;
                    margin-bottom: 8px;
                    letter-spacing: -0.5px;
                }
                .subtitle { 
                    color: #8e8e93;
                    font-size: 15px;
                    margin-bottom: 32px;
                }
                .input-group { 
                    text-align: left;
                    margin-bottom: 24px;
                }
                label { 
                    display: block;
                    color: #8e8e93;
                    font-size: 12px;
                    font-weight: 600;
                    margin-bottom: 8px;
                    text-transform: uppercase;
                    letter-spacing: 0.5px;
                }
                .input-wrapper {
                    display: flex;
                    align-items: center;
                    background: #f2f2f7;
                    border: 1px solid rgba(0,0,0,0.06);
                    border-radius: 14px;
                    padding: 14px 16px;
                    transition: all 0.2s;
                }
                .input-wrapper:focus-within {
                    background: white;
                    border-color: #667eea;
                    box-shadow: 0 0 0 3px rgba(102, 126, 234, 0.1);
                }
                .icon {
                    color: #667eea;
                    font-size: 18px;
                    margin-right: 12px;
                }
                input { 
                    flex: 1;
                    border: none;
                    background: transparent;
                    font-size: 16px;
                    color: #1a1a1a;
                    outline: none;
                }
                input::placeholder {
                    color: #c7c7cc;
                }
                button { 
                    width: 100%;
                    padding: 16px;
                    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                    color: white;
                    border: none;
                    border-radius: 14px;
                    font-size: 17px;
                    font-weight: 600;
                    cursor: pointer;
                    transition: all 0.3s;
                    box-shadow: 0 8px 16px rgba(102, 126, 234, 0.3);
                }
                button:hover:not(:disabled) { 
                    transform: translateY(-2px);
                    box-shadow: 0 12px 24px rgba(102, 126, 234, 0.4);
                }
                button:active:not(:disabled) { 
                    transform: translateY(0);
                }
                button:disabled { 
                    opacity: 0.4;
                    cursor: not-allowed;
                }
                .footer-note {
                    color: #aeaeb2;
                    font-size: 13px;
                    margin-top: 20px;
                    line-height: 1.4;
                }
                .message { 
                    padding: 14px 16px;
                    border-radius: 12px;
                    margin-top: 16px;
                    font-size: 14px;
                    text-align: left;
                    display: flex;
                    align-items: center;
                    gap: 10px;
                }
                .message.success { 
                    background: #d1f4e0;
                    color: #0f5132;
                }
                .message.error { 
                    background: #f8d7da;
                    color: #842029;
                }
                .loading { 
                    display: inline-block;
                    width: 18px;
                    height: 18px;
                    border: 3px solid rgba(255,255,255,0.3);
                    border-top-color: white;
                    border-radius: 50%;
                    animation: spin 0.8s linear infinite;
                }
                @keyframes spin { 
                    to { transform: rotate(360deg); }
                }
                .dashboard { 
                    display: none;
                }
                .dashboard.active { 
                    display: block;
                }
                .login-form.hidden { 
                    display: none;
                }
                .welcome { 
                    color: #667eea;
                    font-size: 20px;
                    font-weight: 600;
                    margin-bottom: 24px;
                }
                .transfer-btn {
                    margin-top: 0;
                }
            </style>
        </head>
        <body>
            <div class="container">
                <div class="login-form" id="loginForm">
                    <div class="logo">🎮</div>
                    <h1>URIEL XITER</h1>
                    <p class="subtitle">Digite sua Key para continuar</p>
                    
                    <div class="input-group">
                        <label for="key">KEY</label>
                        <div class="input-wrapper">
                            <span class="icon">🔑</span>
                            <input type="text" id="key" placeholder="Cole sua Key aqui" autocapitalize="characters" autocorrect="off">
                        </div>
                    </div>
                    
                    <button onclick="login()" id="loginBtn">Validar Key</button>
                    
                    <p class="footer-note">A Key será vinculada a este dispositivo.</p>
                    
                    <div id="loginMessage"></div>
                </div>
                
                <div class="dashboard" id="dashboard">
                    <div class="logo">🎮</div>
                    <div class="welcome" id="welcomeMsg">Bem-vindo!</div>
                    
                    <button class="transfer-btn" onclick="transferReplays()" id="transferBtn">
                        Transferir Replays<br><small style="font-size:13px;opacity:0.8;font-weight:400;">FF MAX → FF Normal</small>
                    </button>
                    
                    <div id="transferMessage"></div>
                </div>
            </div>
            
            <script>
                async function login() {
                    const key = document.getElementById('key').value.trim();
                    const btn = document.getElementById('loginBtn');
                    const msgDiv = document.getElementById('loginMessage');
                    
                    if (!key) {
                        showMessage(msgDiv, '⚠️ Por favor, cole sua Key', 'error');
                        return;
                    }
                    
                    btn.disabled = true;
                    btn.innerHTML = '<span class="loading"></span>';
                    
                    try {
                        const response = await fetch('/api/login', {
                            method: 'POST',
                            headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
                            body: `key=${encodeURIComponent(key)}`
                        });
                        
                        const data = await response.json();
                        
                        if (data.success) {
                            document.getElementById('loginForm').classList.add('hidden');
                            document.getElementById('dashboard').classList.add('active');
                            document.getElementById('welcomeMsg').textContent = 'Bem-vindo!';
                        } else {
                            showMessage(msgDiv, '❌ ' + (data.message || 'Key inválida'), 'error');
                            btn.disabled = false;
                            btn.innerHTML = 'Validar Key';
                        }
                    } catch (error) {
                        showMessage(msgDiv, '❌ Erro de conexão', 'error');
                        btn.disabled = false;
                        btn.innerHTML = 'Validar Key';
                    }
                }
                
                async function transferReplays() {
                    const btn = document.getElementById('transferBtn');
                    const msgDiv = document.getElementById('transferMessage');
                    
                    btn.disabled = true;
                    btn.innerHTML = '<span class="loading"></span>';
                    
                    try {
                        const response = await fetch('/api/transfer', { method: 'POST' });
                        const data = await response.json();
                        
                        if (data.success) {
                            showMessage(msgDiv, '✅ ' + data.message, 'success');
                        } else {
                            showMessage(msgDiv, '❌ ' + data.message, 'error');
                        }
                    } catch (error) {
                        showMessage(msgDiv, '❌ Falha na transferência', 'error');
                    } finally {
                        btn.disabled = false;
                        btn.innerHTML = 'Transferir Replays<br><small style="font-size:13px;opacity:0.8;font-weight:400;">FF MAX → FF Normal</small>';
                    }
                }
                
                function showMessage(div, text, type) {
                    div.className = `message ${type}`;
                    div.textContent = text;
                    div.style.display = 'flex';
                }
                
                // Auto-focus no campo KEY
                document.getElementById('key').focus();
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
