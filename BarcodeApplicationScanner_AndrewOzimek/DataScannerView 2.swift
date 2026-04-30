//this is old file
//need to get rid of


import SwiftUI
import AVFoundation

#if os(iOS)
import UIKit
#endif

#if os(iOS)
import VisionKit
#endif

struct DataScannerView: View {
    @Binding var scannedCode: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        #if os(iOS)
        if #available(iOS 16.0, *), DataScannerEnvironment.isScannerAvailable {
            ScannerRepresentable(scannedCode: $scannedCode)
                .ignoresSafeArea()
        } else {
            UnsupportedView(dismiss: dismiss)
        }
        #else
        UnsupportedView(dismiss: dismiss)
        #endif
    }
}

private struct UnsupportedView: View {
    let dismiss: DismissAction
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "barcode.viewfinder")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Scanner not available on this device")
                .font(.headline)
                .multilineTextAlignment(.center)
            Text("Try running on a supported iPhone with iOS 16 or later.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Close") { dismiss() }
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

#if os(iOS)
@available(iOS 16.0, *)
private enum DataScannerEnvironment {
    static var isScannerAvailable: Bool {
        // Guard VisionKit availability without referencing symbols on older SDKs
        if #available(iOS 16.0, *), (NSClassFromString("DataScannerViewController") as? NSObject.Type) != nil {
            // Use direct API since we're on iOS and SDK has VisionKit
            return DataScannerViewController.isSupported && DataScannerViewController.isAvailable
        }
        return false
    }
}
#endif

#if os(iOS)
@available(iOS 16.0, *)
private struct ScannerRepresentable: UIViewControllerRepresentable {
    @Binding var scannedCode: String

    func makeCoordinator() -> Coordinator { Coordinator(scannedCode: $scannedCode) }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let controller = DataScannerViewController(
            recognizedDataTypes: [.barcode()],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: true,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )
        controller.delegate = context.coordinator
        
        // Start scanning immediately after creation
        Task { @MainActor in
            let status = AVCaptureDevice.authorizationStatus(for: .video)
            switch status {
            case .authorized:
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second delay
                try? controller.startScanning()
                print("📸 Scanner started (authorized)")
            case .notDetermined:
                print("📸 Requesting camera permission...")
                let granted = await AVCaptureDevice.requestAccess(for: .video)
                if granted {
                    try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second delay
                    try? controller.startScanning()
                    print("📸 Scanner started (permission granted)")
                } else {
                    print("❌ Camera permission denied")
                }
            case .denied, .restricted:
                print("❌ Camera access denied or restricted")
            @unknown default:
                break
            }
        }
        
        return controller
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {
        // Do nothing - scanner already started in makeUIViewController
    }

    static func dismantleUIViewController(_ uiViewController: DataScannerViewController, coordinator: Coordinator) {
        uiViewController.stopScanning()
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        private var scannedCode: Binding<String>
        init(scannedCode: Binding<String>) { self.scannedCode = scannedCode }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            handle(items: addedItems, in: dataScanner)
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didUpdate updatedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            handle(items: updatedItems, in: dataScanner)
        }

        private func handle(items: [RecognizedItem], in scanner: DataScannerViewController) {
            for item in items {
                if case let .barcode(barcode) = item, let payload = barcode.payloadStringValue, !payload.isEmpty {
                    scannedCode.wrappedValue = payload
                    scanner.stopScanning()
                    scanner.dismiss(animated: true)
                    break
                }
            }
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) { }
        func dataScanner(_ dataScanner: DataScannerViewController, becameUnavailableWithError error: Error) { }
    }
}
#endif
