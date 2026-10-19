import SwiftUI
import WebKit

public struct ReservationWebView: View {
    let initialUrl: String
    var onClose: () -> Void
    
    @State private var canGoBack: Bool = false
    @State private var canGoForward: Bool = false
    @State private var isLoading: Bool = true
    @State private var webView: WKWebView?
    
    public init(
        initialUrl: String = WebTracScraper.webTracSearchURL,
        onClose: @escaping () -> Void
    ) {
        self.initialUrl = initialUrl
        self.onClose = onClose
    }
    
    public var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Helpful guidance banner
                HStack(spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(AppTheme.burlingameBlue)
                    
                    Text("Burlingame WebTrac: Select date & court time to add to cart.")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.primary)
                    
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(AppTheme.burlingameBlue.opacity(0.1))
                
                // Live WebKit View
                ZStack {
                    WebBrowserRepresentable(
                        urlString: initialUrl,
                        canGoBack: $canGoBack,
                        canGoForward: $canGoForward,
                        isLoading: $isLoading,
                        webViewRef: $webView
                    )
                    
                    if isLoading {
                        VStack(spacing: 10) {
                            ProgressView()
                                .scaleEffect(1.2)
                            Text("Connecting to Burlingame WebTrac...")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(.systemBackground).opacity(0.85))
                    }
                }
            }
            .navigationTitle("Reserve Washington Park")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        onClose()
                    }
                    .bold()
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        Button(action: { webView?.reload() }) {
                            Image(systemName: "arrow.clockwise")
                        }
                        
                        if let url = URL(string: initialUrl) {
                            Link(destination: url) {
                                Image(systemName: "safari")
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct WebBrowserRepresentable: UIViewRepresentable {
    let urlString: String
    @Binding var canGoBack: Bool
    @Binding var canGoForward: Bool
    @Binding var isLoading: Bool
    @Binding var webViewRef: WKWebView?
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let wv = WKWebView(frame: .zero, configuration: config)
        wv.navigationDelegate = context.coordinator
        wv.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1"
        
        DispatchQueue.main.async {
            self.webViewRef = wv
        }
        
        if let url = URL(string: urlString) {
            let request = URLRequest(url: url)
            wv.load(request)
        }
        return wv
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WebBrowserRepresentable
        
        init(_ parent: WebBrowserRepresentable) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = true
            }
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
                self.parent.canGoBack = webView.canGoBack
                self.parent.canGoForward = webView.canGoForward
            }
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
            }
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
            }
        }
    }
}
