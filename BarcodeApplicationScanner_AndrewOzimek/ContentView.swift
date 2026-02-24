//This is the User Interface. It displays the "Scan Item" button and handles the logic for showing the scanner sheet.


import SwiftUI
struct ContentView: View {
    @State private var resultText = "Scan a product to begin"
    @State private var showingScanner = false
    
    var body: some View {
        VStack(spacing: 30) {
            Text(resultText)
                .font(.title2)
                .padding()
            
            Button(action: { showingScanner = true }) {
                Label("Scan Item", systemImage: "barcode.viewfinder")
                    .font(.headline)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding(.horizontal)
        }
        .sheet(isPresented: $showingScanner) {
            
            
#if os(iOS)
    if #available(iOS 16.0, *) {
        #if targetEnvironment(simulator)
        //dont use vision kit if its a simulator
        DataScannerView(scannedCode: $resultText)
        #else
        // Use the real scanner on device
        LegacyDataScannerView(scannedCode: $resultText)
        #endif
    } else {
        // Fallback UI for older iOS versions
        DataScannerView(scannedCode: $resultText)
    }
#else
    // Non-iOS platforms
    DataScannerView(scannedCode: $resultText)
#endif
        }
    }
}
