import Foundation
import Network

@MainActor
final class ReplayHTTPServer: ObservableObject {
    private var listener: NWListener?
    @Published var isRunning = false
    @Published var port: UInt16 = 8080
    
    func start() {
        guard listener == nil else { return }
        
        do {
            let parameters = NWParameters.tcp
            parameters.allowLocalEndpointReuse = true
            
            listener = try NWListener(using: parameters, on: NWEndpoint.Port(integerLiteral: port))
            
            listener?.stateUpdateHandler = { [weak self] state in
                Task { @MainActor in
                    switch state {
                    case .ready:
                        self?.isRunning = true
                        print("✓ HTTP Server rodando em http://localhost:\(self?.port ?? 8080)")
                    case .failed(let error):
                        print("✗ Erro no servidor: \(error)")
                        self?.isRunning = false
                    default:
                        break
                    }
                }
            }
            
            listener?.newConnectionHandler = { [weak self] connection in
                self?.handleConnection(connection)
            }
            
            listener?.start(queue: .main)
            
        } catch {
            print("✗ Erro ao iniciar servidor: \(error)")
        }
    }
    
    func stop() {
        listener?.cancel()
        listener = nil
        isRunning = false
    }
    
    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: .main)
        
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let data = data,
                  let request = String(data: data, encoding: .utf8) else {
                connection.cancel()
                return
            }
            
            self?.processRequest(request, connection: connection)
        }
    }
    
    private func processRequest(_ request: String, connection: NWConnection) {
        let lines = request.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else {
            sendResponse(connection: connection, status: 400, body: "Bad Request")
            return
        }
        
        let parts = requestLine.components(separatedBy: " ")
        guard parts.count >= 2 else {
            sendResponse(connection: connection, status: 400, body: "Bad Request")
            return
        }
        
        let method = parts[0]
        let path = parts[1]
        
        // Rotas
        switch (method, path) {
        case ("GET", "/"):
            serveHTML(connection: connection)
            
        case ("POST", "/api/login"):
            handleLogin(request: request, connection: connection)
            
        case ("POST", "/api/transfer"):
            handleTransfer(request: request, connection: connection)
            
        case ("GET", let p) where p.hasPrefix("/api/status"):
            handleStatus(connection: connection)
            
        default:
            sendResponse(connection: connection, status: 404, body: "Not Found")
        }
    }
    
    private func serveHTML(connection: NWConnection) {
        let html = """
<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
    <meta name="apple-mobile-web-app-capable" content="yes">
    <meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">
    <title>URIEL XITER - Replay Transfer</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        
        body {
            font-family: -apple-system, BlinkMacSystemFont, "SF Pro Display", sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            color: #fff;
            overflow-x: hidden;
        }
        
        .container {
            max-width: 520px;
            margin: 0 auto;
            padding: 52px 24px 42px;
        }
        
        .logo {
            width: 72px;
            height: 72px;
            margin: 0 auto 24px;
            background: rgba(255,255,255,0.15);
            border-radius: 20px;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 36px;
            backdrop-filter: blur(10px);
        }
        
        h1 {
            font-size: 34px;
            font-weight: 700;
            text-align: center;
            margin-bottom: 8px;
        }
        
        .subtitle {
            text-align: center;
            opacity: 0.8;
            font-size: 16px;
            margin-bottom: 28px;
        }
        
        .card {
            background: rgba(255,255,255,0.95);
            border-radius: 20px;
            padding: 30px;
            color: #333;
            box-shadow: 0 20px 60px rgba(0,0,0,0.3);
        }
        
        .form-group {
            margin-bottom: 20px;
        }
        
        .form-label {
            font-size: 12px;
            font-weight: 600;
            color: #666;
            text-transform: uppercase;
            letter-spacing: 0.5px;
            margin-bottom: 9px;
            display: block;
        }
        
        .input-wrapper {
            display: flex;
            align-items: center;
            gap: 10px;
            padding: 14px;
            background: #f5f5f7;
            border: 1px solid rgba(0,0,0,0.1);
            border-radius: 14px;
            transition: all 0.2s;
        }
        
        .input-wrapper:focus-within {
            border-color: #667eea;
            box-shadow: 0 0 0 4px rgba(102,126,234,0.1);
        }
        
        .input-icon {
            font-size: 20px;
            color: #667eea;
        }
        
        input {
            flex: 1;
            border: none;
            background: transparent;
            font-size: 16px;
            outline: none;
            color: #333;
        }
        
        input::placeholder {
            color: #999;
        }
        
        .btn {
            width: 100%;
            padding: 18px;
            border: none;
            border-radius: 14px;
            font-size: 16px;
            font-weight: 600;
            cursor: pointer;
            transition: all 0.3s;
            margin-top: 24px;
        }
        
        .btn-primary {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
        }
        
        .btn-primary:disabled {
            opacity: 0.4;
            cursor: not-allowed;
        }
        
        .btn-primary:not(:disabled):active {
            transform: scale(0.98);
        }
        
        .error {
            display: flex;
            align-items: center;
            gap: 8px;
            color: #dc3545;
            font-size: 14px;
            margin-top: 16px;
            padding: 12px;
            background: #ffe5e5;
            border-radius: 10px;
        }
        
        .success {
            display: flex;
            align-items: center;
            gap: 8px;
            color: #28a745;
            font-size: 14px;
            margin-top: 16px;
            padding: 12px;
            background: #d4edda;
            border-radius: 10px;
        }
        
        .info {
            font-size: 13px;
            color: #666;
            text-align: center;
            margin-top: 18px;
            opacity: 0.7;
        }
        
        .hidden { display: none; }
        
        /* Dashboard */
        .dashboard {
            animation: fadeIn 0.3s ease-in;
        }
        
        @keyframes fadeIn {
            from { opacity: 0; transform: translateY(10px); }
            to { opacity: 1; transform: translateY(0); }
        }
        
        .welcome {
            font-size: 20px;
            font-weight: 600;
            margin-bottom: 8px;
        }
        
        .device-info {
            font-size: 14px;
            color: #666;
            margin-bottom: 28px;
        }
        
        .feature-card {
            background: #f8f9fa;
            border-radius: 16px;
            padding: 20px;
            margin-bottom: 16px;
        }
        
        .feature-icon {
            font-size: 32px;
            margin-bottom: 12px;
        }
        
        .feature-title {
            font-size: 18px;
            font-weight: 600;
            margin-bottom: 8px;
        }
        
        .feature-desc {
            font-size: 14px;
            color: #666;
            margin-bottom: 16px;
        }
        
        .btn-logout {
            background: #f5f5f7;
            color: #dc3545;
            margin-top: 8px;
        }
        
        .spinner {
            border: 3px solid rgba(255,255,255,0.3);
            border-top: 3px solid white;
            border-radius: 50%;
            width: 20px;
            height: 20px;
            animation: spin 1s linear infinite;
            display: inline-block;
            margin: 0 auto;
        }
        
        @keyframes spin {
            0% { transform: rotate(0deg); }
            100% { transform: rotate(360deg); }
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="logo">🔥</div>
        <h1>URIEL XITER</h1>
        <p class="subtitle" id="pageSubtitle">Digite sua Key para continuar</p>
        
        <!-- Login Screen -->
        <div class="card" id="loginCard">
            <div class="form-group">
                <label class="form-label">KEY</label>
                <div class="input-wrapper">
                    <span class="input-icon">🔑</span>
                    <input type="text" id="keyInput" placeholder="Cole sua Key aqui" autocomplete="off" autocapitalize="characters">
                </div>
            </div>
            
            <div id="errorMessage" class="error hidden">
                <span>⚠️</span>
                <span id="errorText"></span>
            </div>
            
            <button class="btn btn-primary" id="loginBtn" onclick="login()">
                Validar Key
            </button>
            
            <p class="info">A Key será vinculada a este dispositivo.</p>
        </div>
        
        <!-- Dashboard -->
        <div class="card dashboard hidden" id="dashboardCard">
            <p class="welcome">Bem-vindo! 👋</p>
            <p class="device-info" id="deviceInfo">Dispositivo autenticado</p>
            
            <div class="feature-card">
                <div class="feature-icon">🔄</div>
                <h3 class="feature-title">Replay Transfer</h3>
                <p class="feature-desc">Transfira replays do FF MAX para o FF Normal automaticamente</p>
                
                <div id="transferStatus" class="hidden"></div>
                
                <button class="btn btn-primary" id="transferBtn" onclick="transferReplays()">
                    Transfer Replays
                </button>
            </div>
            
            <button class="btn btn-logout" onclick="logout()">
                Sair
            </button>
        </div>
    </div>
    
    <script>
        const API_URL = window.location.origin;
        let authKey = localStorage.getItem('authKey');
        let deviceUID = localStorage.getItem('deviceUID');
        
        // Generate device UID
        if (!deviceUID) {
            deviceUID = 'iOS-' + Math.random().toString(36).substr(2, 9) + '-' + Date.now();
            localStorage.setItem('deviceUID', deviceUID);
        }
        
        // Check if already logged in
        window.onload = async () => {
            if (authKey) {
                const isValid = await validateSession();
                if (isValid) {
                    showDashboard();
                } else {
                    localStorage.removeItem('authKey');
                }
            }
        };
        
        async function validateSession() {
            try {
                const response = await fetch(`${API_URL}/api/status`);
                return response.ok;
            } catch {
                return false;
            }
        }
        
        async function login() {
            const keyInput = document.getElementById('keyInput');
            const key = keyInput.value.trim().toUpperCase();
            
            if (!key) {
                showError('Digite seu usuário.');
                return;
            }
            
            hideError();
            setLoading(true);
            
            try {
                const response = await fetch(`${API_URL}/api/login`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ user: key, uid: deviceUID })
                });
                
                const data = await response.json();
                
                if (response.ok && data.success) {
                    authKey = key;
                    localStorage.setItem('authKey', key);
                    showDashboard();
                } else {
                    showError(data.error || 'Erro ao validar key.');
                }
            } catch (error) {
                showError('Não foi possível conectar ao servidor.');
            } finally {
                setLoading(false);
            }
        }
        
        async function transferReplays() {
            const btn = document.getElementById('transferBtn');
            const status = document.getElementById('transferStatus');
            
            btn.disabled = true;
            btn.innerHTML = '<div class="spinner"></div>';
            status.className = 'hidden';
            
            try {
                const response = await fetch(`${API_URL}/api/transfer`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ key: authKey })
                });
                
                const data = await response.json();
                
                if (response.ok && data.success) {
                    status.className = 'success';
                    status.innerHTML = `<span>✓</span><span>${data.message || 'Replays transferidos com sucesso!'}</span>`;
                } else {
                    status.className = 'error';
                    status.innerHTML = `<span>✗</span><span>${data.error || 'Erro ao transferir replays.'}</span>`;
                }
            } catch (error) {
                status.className = 'error';
                status.innerHTML = '<span>✗</span><span>Erro de conexão.</span>';
            } finally {
                btn.disabled = false;
                btn.textContent = 'Transfer Replays';
            }
        }
        
        function logout() {
            localStorage.removeItem('authKey');
            authKey = null;
            showLogin();
        }
        
        function showDashboard() {
            document.getElementById('loginCard').classList.add('hidden');
            document.getElementById('dashboardCard').classList.remove('hidden');
            document.getElementById('pageSubtitle').textContent = 'Painel de Controle';
            document.getElementById('deviceInfo').textContent = `Dispositivo: ${deviceUID.substr(0, 20)}...`;
        }
        
        function showLogin() {
            document.getElementById('dashboardCard').classList.add('hidden');
            document.getElementById('loginCard').classList.remove('hidden');
            document.getElementById('pageSubtitle').textContent = 'Digite sua Key para continuar';
            document.getElementById('keyInput').value = '';
        }
        
        function showError(message) {
            document.getElementById('errorText').textContent = message;
            document.getElementById('errorMessage').classList.remove('hidden');
        }
        
        function hideError() {
            document.getElementById('errorMessage').classList.add('hidden');
        }
        
        function setLoading(loading) {
            const btn = document.getElementById('loginBtn');
            btn.disabled = loading;
            btn.innerHTML = loading ? '<div class="spinner"></div>' : 'Validar Key';
        }
        
        // Enter key to login
        document.getElementById('keyInput')?.addEventListener('keypress', (e) => {
            if (e.key === 'Enter') login();
        });
    </script>
</body>
</html>
"""
        
        let response = """
HTTP/1.1 200 OK\r
Content-Type: text/html; charset=utf-8\r
Content-Length: \(html.utf8.count)\r
Connection: close\r
\r
\(html)
"""
        
        sendData(connection: connection, data: response.data(using: .utf8)!)
    }
    
    private func handleLogin(request: String, connection: NWConnection) {
        // Extrai o body JSON
        guard let bodyData = extractBody(from: request),
              let json = try? JSONSerialization.jsonObject(with: bodyData) as? [String: String],
              let user = json["user"],
              let uid = json["uid"] else {
            sendJSON(connection: connection, status: 400, data: ["error": "Parâmetros inválidos"])
            return
        }
        
        // Valida no servidor
        Task {
            let result = await validateKey(user: user, uid: uid)
            await MainActor.run {
                sendJSON(connection: connection, status: result.success ? 200 : 401, data: result.data)
            }
        }
    }
    
    private func handleTransfer(request: String, connection: NWConnection) {
        // Transfere replays
        Task {
            let result = await performReplayTransfer()
            await MainActor.run {
                sendJSON(connection: connection, status: result.success ? 200 : 500, data: result.data)
            }
        }
    }
    
    private func handleStatus(connection: NWConnection) {
        sendJSON(connection: connection, status: 200, data: ["status": "ok"])
    }
    
    // MARK: - Validation
    
    private func validateKey(user: String, uid: String) async -> (success: Bool, data: [String: Any]) {
        guard var components = URLComponents(string: "https://urielxiter.shop/mod/CheckLogin.php") else {
            return (false, ["error": "Erro interno"])
        }
        
        components.queryItems = [
            URLQueryItem(name: "user", value: user),
            URLQueryItem(name: "uid", value: uid)
        ]
        
        guard let url = components.url else {
            return (false, ["error": "Erro interno"])
        }
        
        do {
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.timeoutInterval = 15
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return (false, ["error": "Servidor indisponível"])
            }
            
            let body = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            
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
            
            let isError = errorPrefixes.contains(where: { body.lowercased().hasPrefix($0.lowercased()) }) || body.isEmpty
            
            if isError {
                let message = body == "ﾠ" || body.isEmpty ? "Usuário não encontrado" : body
                return (false, ["error": message])
            }
            
            return (true, ["success": true, "uid": body])
            
        } catch {
            return (false, ["error": "Não foi possível conectar ao servidor"])
        }
    }
    
    // MARK: - Replay Transfer
    
    private func performReplayTransfer() async -> (success: Bool, data: [String: Any]) {
        do {
            let containers = ContainerManagerService.shared.resolveAllContainers()
            
            guard let ffMax = containers.first(where: { $0.bundleID == "com.dts.freefiremax" }),
                  let ffNormal = containers.first(where: { $0.bundleID == "com.dts.freefireth" }) else {
                return (false, ["error": "Apps não encontrados. Instale FF MAX e FF Normal."])
            }
            
            let sourcePath = "\(ffMax.containerPath)/Documents/MReplays"
            let destPath = "\(ffNormal.containerPath)/Documents/MReplays"
            
            let fileManager = FileManager.default
            
            // Cria pasta destino se não existir
            try? fileManager.createDirectory(atPath: destPath, withIntermediateDirectories: true)
            
            // Copia replays
            let files = try fileManager.contentsOfDirectory(atPath: sourcePath)
            let replayFiles = files.filter { $0.hasSuffix(".json") || $0.hasSuffix(".bin") }
            
            guard !replayFiles.isEmpty else {
                return (false, ["error": "Nenhum replay encontrado no FF MAX."])
            }
            
            var copiedCount = 0
            for file in replayFiles {
                let source = "\(sourcePath)/\(file)"
                let dest = "\(destPath)/\(file)"
                
                // Remove arquivo antigo se existir
                try? fileManager.removeItem(atPath: dest)
                
                // Copia
                try fileManager.copyItem(atPath: source, toPath: dest)
                copiedCount += 1
            }
            
            return (true, [
                "success": true,
                "message": "\(copiedCount) replays transferidos com sucesso!",
                "count": copiedCount
            ])
            
        } catch {
            return (false, ["error": "Erro ao transferir: \(error.localizedDescription)"])
        }
    }
    
    // MARK: - Helpers
    
    private func extractBody(from request: String) -> Data? {
        guard let bodyStart = request.range(of: "\r\n\r\n") else { return nil }
        let body = String(request[bodyStart.upperBound...])
        return body.data(using: .utf8)
    }
    
    private func sendJSON(connection: NWConnection, status: Int, data: [String: Any]) {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: data),
              let json = String(data: jsonData, encoding: .utf8) else {
            sendResponse(connection: connection, status: 500, body: "{\"error\":\"Internal error\"}")
            return
        }
        
        let response = """
HTTP/1.1 \(status) OK\r
Content-Type: application/json; charset=utf-8\r
Content-Length: \(json.utf8.count)\r
Connection: close\r
\r
\(json)
"""
        
        sendData(connection: connection, data: response.data(using: .utf8)!)
    }
    
    private func sendResponse(connection: NWConnection, status: Int, body: String) {
        let response = """
HTTP/1.1 \(status) OK\r
Content-Type: text/plain; charset=utf-8\r
Content-Length: \(body.utf8.count)\r
Connection: close\r
\r
\(body)
"""
        
        sendData(connection: connection, data: response.data(using: .utf8)!)
    }
    
    private func sendData(connection: NWConnection, data: Data) {
        connection.send(content: data, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
}
