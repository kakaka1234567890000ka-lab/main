import SwiftUI

struct ReplayConnectionView: View {
    @StateObject private var connectionManager = ReplayConnectionManager()
    @State private var serverIP: String = ""
    @State private var serverPort: String = "8080"
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        ZStack {
            // Dark background
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 30) {
                Spacer()
                
                // Title
                VStack(spacing: 8) {
                    Text("URIEL XITER")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundColor(.red)
                        .shadow(color: .red.opacity(0.5), radius: 10)
                    
                    Text("REPLAY TRANSFER")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(.gray)
                        .tracking(3)
                }
                .padding(.bottom, 20)
                
                // Connection Form
                VStack(spacing: 20) {
                    // IP Field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("SERVER IP")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(.red)
                            .tracking(2)
                        
                        TextField("192.168.1.100", text: $serverIP)
                            .font(.system(size: 16, weight: .medium, design: .monospaced))
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.white.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 0)
                                    .stroke(Color.red.opacity(0.3), lineWidth: 1)
                            )
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .keyboardType(.decimalPad)
                    }
                    
                    // Port Field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("PORT")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(.red)
                            .tracking(2)
                        
                        TextField("8080", text: $serverPort)
                            .font(.system(size: 16, weight: .medium, design: .monospaced))
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.white.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 0)
                                    .stroke(Color.red.opacity(0.3), lineWidth: 1)
                            )
                            .keyboardType(.numberPad)
                    }
                    
                    // Status
                    HStack {
                        Circle()
                            .fill(connectionManager.isConnected ? Color.green : Color.red)
                            .frame(width: 8, height: 8)
                        
                        Text(connectionManager.isConnected ? "CONNECTED" : "DISCONNECTED")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(connectionManager.isConnected ? .green : .red)
                            .tracking(1)
                    }
                    .padding(.top, 10)
                    
                    // Connect Button
                    Button(action: connectToServer) {
                        HStack {
                            if connectionManager.isConnecting {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            }
                            Text(connectionManager.isConnecting ? "CONNECTING..." : "CONNECT")
                                .font(.system(size: 16, weight: .bold, design: .monospaced))
                                .tracking(2)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(
                                colors: [Color(red: 0.55, green: 0, blue: 0), Color.red],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 0)
                                .stroke(Color.red, lineWidth: 1)
                        )
                        .shadow(color: .red.opacity(0.4), radius: 10)
                    }
                    .disabled(connectionManager.isConnecting || serverIP.isEmpty)
                    .opacity(serverIP.isEmpty ? 0.5 : 1.0)
                    .padding(.top, 10)
                }
                .padding(.horizontal, 30)
                
                Spacer()
                
                // Footer
                VStack(spacing: 4) {
                    Text("Keep app open for remote control")
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .foregroundColor(.gray)
                    
                    if let localIP = getLocalIPAddress() {
                        Text("Device IP: \(localIP)")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(.red.opacity(0.6))
                    }
                }
                .padding(.bottom, 30)
            }
        }
        .alert("Connection", isPresented: $showAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
        .onAppear {
            connectionManager.startLocalServer()
        }
    }
    
    private func connectToServer() {
        guard !serverIP.isEmpty else { return }
        
        let port = Int(serverPort) ?? 8080
        connectionManager.connectToServer(ip: serverIP, port: port) { success, message in
            alertMessage = message
            showAlert = true
        }
    }
    
    private func getLocalIPAddress() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        
        if getifaddrs(&ifaddr) == 0 {
            var ptr = ifaddr
            while ptr != nil {
                defer { ptr = ptr?.pointee.ifa_next }
                
                let interface = ptr?.pointee
                let addrFamily = interface?.ifa_addr.pointee.sa_family
                
                if addrFamily == UInt8(AF_INET) {
                    let name = String(cString: (interface?.ifa_name)!)
                    if name == "en0" {
                        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                        getnameinfo(interface?.ifa_addr, socklen_t((interface?.ifa_addr.pointee.sa_len)!),
                                    &hostname, socklen_t(hostname.count),
                                    nil, socklen_t(0), NI_NUMERICHOST)
                        address = String(cString: hostname)
                    }
                }
            }
            freeifaddrs(ifaddr)
        }
        
        return address
    }
}
