//The Secondary Scanner. slightly different camera logic, used as an alternative scanning method.


import SwiftUI
import AVFoundation

#if os(iOS)
import UIKit
import VisionKit
#endif

struct LegacyDataScannerView: View {
    @Binding var scannedCode: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        #if os(iOS)
        if #available(iOS 16.0, *) {
            LegacyScannerRepresentable(scannedCode: $scannedCode)
                .ignoresSafeArea()
        } else {
            unsupported
        }
        #else
        unsupported
        #endif
    }

    private var unsupported: some View {
        VStack(spacing: 16) {
            Image(systemName: "barcode.viewfinder")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Scanner not available on this device")
                .font(.headline)
                .multilineTextAlignment(.center)
            Button("Close") { dismiss() }
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}
#if os(iOS)
@available(iOS 16.0, *)
private struct LegacyScannerRepresentable: UIViewControllerRepresentable {
    @Binding var scannedCode: String

    func makeCoordinator() -> Coordinator { Coordinator(scannedCode: $scannedCode) }

    func makeUIViewController(context: Context) -> UIViewController {
        guard DataScannerViewController.isSupported, DataScannerViewController.isAvailable else {
            return UIViewController()
        }
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
        return controller
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        guard let controller = uiViewController as? DataScannerViewController else { return }
        Task { @MainActor in
            let status = AVCaptureDevice.authorizationStatus(for: .video)
            switch status {
            case .authorized:
                try? controller.startScanning()
            case .notDetermined:
                let granted = await AVCaptureDevice.requestAccess(for: .video)
                if granted { try? controller.startScanning() }
            default:
                break
            }
        }
    }

    static func dismantleUIViewController(_ uiViewController: UIViewController, coordinator: Coordinator) {
        (uiViewController as? DataScannerViewController)?.stopScanning()
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

