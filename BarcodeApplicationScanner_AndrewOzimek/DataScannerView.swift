//the primary scanner. A SwiftUI view that checks if the device is a supported iPhone and launches the camera


#if canImport(UIKit)
import SwiftUI
import UIKit

#if canImport(VisionKit)
import VisionKit
#endif

//scanner that uses vision kit
struct ScannerView: View {
    @Binding var scannedCode: String

    var body: some View {
        #if os(iOS)
        if #available(iOS 16.0, *) {
            ScannerRepresentable(scannedCode: $scannedCode)
        } else {
            FallbackScanner(scannedCode: $scannedCode)
        }
        #else
        FallbackScanner(scannedCode: $scannedCode)
        #endif
    }
}

//this is the fallback if it doesnt work
private struct FallbackScanner: View {
    @Binding var scannedCode: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "barcode.viewfinder")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("Scanner not available on this device.")
                .font(.headline)
            Text("Use a real iOS device running iOS 16+ to scan with VisionKit.")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Button("Close") { dismiss() }
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}



// VisionKit-backed implementation
#if os(iOS)
@available(iOS 16.0, *)
private struct ScannerRepresentable: UIViewControllerRepresentable {
    @Binding var scannedCode: String

    func makeUIViewController(context: Context) -> UIViewController {
        #if canImport(VisionKit)
        if DataScannerViewController.isSupported, DataScannerViewController.isAvailable {
            let scanner = DataScannerViewController(
                recognizedDataTypes: [.barcode()],
                qualityLevel: .balanced,
                isHighlightingEnabled: true
            )
            scanner.delegate = context.coordinator
            return scanner
        } else {
            return UIViewController()
        }
        #else
        return UIViewController()
        #endif
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        #if canImport(VisionKit)
        if let scanner = uiViewController as? DataScannerViewController {
            try? scanner.startScanning()
        }
        #endif
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject {
        var parent: ScannerRepresentable
        init(_ parent: ScannerRepresentable) {
            self.parent = parent
        }
    }
}


//helper method
#if canImport(VisionKit)
@available(iOS 16.0, *)
extension ScannerRepresentable.Coordinator: DataScannerViewControllerDelegate {
    func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) {
        switch item {
        case .barcode(let barcode):
            parent.scannedCode = barcode.payloadStringValue ?? "Unknown"
        default:
            break
        }
    }
}
#endif
#endif
#endif

