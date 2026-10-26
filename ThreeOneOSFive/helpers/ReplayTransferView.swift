import SwiftUI
import WebKit

struct ReplayTransferView: View {
    @State private var showInstructions = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                WebView(url: URL(string: "http://localhost:8080")!)
                    .edgesIgnoringSafeArea(.bottom)
            }
            .navigationTitle("Replay Transfer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showInstructions = true
                    } label: {
                        Image(systemName: "info.circle")
                    }
                }
            }
            .sheet(isPresented: $showInstructions) {
                InstructionsView()
            }
        }
    }
}

struct WebView: UIViewRepresentable {
    let url: URL
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.load(URLRequest(url: url))
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        // No update needed
    }
}

struct InstructionsView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("How to Use")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        InstructionStep(number: 1, text: "Open the 3105 app on your iPhone")
                        InstructionStep(number: 2, text: "The HTTP server will start automatically")
                        InstructionStep(number: 3, text: "Use Safari to access http://localhost:8080")
                        InstructionStep(number: 4, text: "Login with your credentials")
                        InstructionStep(number: 5, text: "Click 'Transfer Replays' to copy replays from FF MAX to FF Normal")
                    }
                    
                    Divider()
                    
                    Text("Requirements")
                        .font(.title3)
                        .fontWeight(.semibold)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        RequirementRow(text: "Both Free Fire MAX and Free Fire Normal must be installed")
                        RequirementRow(text: "Valid login credentials from urielxiter.shop")
                        RequirementRow(text: "iOS 16.0 or later")
                    }
                    
                    Divider()
                    
                    Text("Notes")
                        .font(.title3)
                        .fontWeight(.semibold)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        NoteRow(text: "The Free Fire Normal app remains 100% clean")
                        NoteRow(text: "Replays are copied, not moved")
                        NoteRow(text: "Server runs on localhost:8080")
                    }
                }
                .padding()
            }
            .navigationTitle("Instructions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct InstructionStep: View {
    let number: Int
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 30, height: 30)
                .background(Color.blue)
                .clipShape(Circle())
            
            Text(text)
                .font(.body)
        }
    }
}

struct RequirementRow: View {
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            Text(text)
                .font(.subheadline)
        }
    }
}

struct NoteRow: View {
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundColor(.orange)
            Text(text)
                .font(.subheadline)
        }
    }
}
