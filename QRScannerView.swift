import SwiftUI
import AVFoundation

/// A full-screen camera view that decodes QR codes using AVFoundation.
///
/// Present in a `.sheet`. On the first successful scan, `onScan` is called with the
/// decoded string (an Ethereum address, an `ethereum:` URI, or an ENS name),
/// and the sheet is automatically dismissed.
struct QRScannerView: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    var onScan: (String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onScan: onScan, dismiss: dismiss) }

    func makeUIViewController(context: Context) -> ScannerViewController {
        ScannerViewController(coordinator: context.coordinator)
    }

    func updateUIViewController(_ uiViewController: ScannerViewController, context: Context) {}

    // MARK: - Coordinator (AVCaptureMetadataOutputObjectsDelegate)

    final class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        let onScan: (String) -> Void
        let dismiss: DismissAction
        private var hasScanned = false

        init(onScan: @escaping (String) -> Void, dismiss: DismissAction) {
            self.onScan = onScan; self.dismiss = dismiss
        }

        func metadataOutput(_ output: AVCaptureMetadataOutput,
                            didOutput metadataObjects: [AVMetadataObject],
                            from connection: AVCaptureConnection) {
            guard !hasScanned,
                  let obj = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
                  let value = obj.stringValue else { return }
            hasScanned = true
            onScan(value)
            let d = dismiss
            Task { @MainActor in d() }
        }
    }
}

// MARK: - UIViewController

final class ScannerViewController: UIViewController {
    private let coordinator: QRScannerView.Coordinator
    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?

    private var isTorchOn = false

    init(coordinator: QRScannerView.Coordinator) {
        self.coordinator = coordinator
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("not used") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        checkPermissionAndSetup()
        addReticle()
        addHintLabel()
        addControls()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        DispatchQueue.global(qos: .userInitiated).async { self.captureSession?.startRunning() }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        DispatchQueue.global(qos: .userInitiated).async { self.captureSession?.stopRunning() }
        if isTorchOn, let device = AVCaptureDevice.default(for: .video), device.hasTorch {
            try? device.lockForConfiguration()
            device.torchMode = .off
            device.unlockForConfiguration()
            isTorchOn = false
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    // MARK: Private

    private func checkPermissionAndSetup() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:       startCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async { granted ? self?.startCamera() : self?.showDenied() }
            }
        default: showDenied()
        }
    }

    private func startCamera() {
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else {
            showDenied(); return
        }
        let session = AVCaptureSession()
        session.beginConfiguration()
        session.addInput(input)
        let output = AVCaptureMetadataOutput()
        session.addOutput(output)
        output.setMetadataObjectsDelegate(coordinator, queue: .main)
        output.metadataObjectTypes = [.qr]
        session.commitConfiguration()

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.frame = view.bounds
        preview.videoGravity = .resizeAspectFill
        view.layer.insertSublayer(preview, at: 0)
        previewLayer = preview
        captureSession = session
        DispatchQueue.global(qos: .userInitiated).async { session.startRunning() }
    }

    private func addHintLabel() {
        let label = UILabel()
        label.text = "Point the camera at a QR code"
        label.textColor = .white
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -32)
        ])
    }

    private func addReticle() {
        let reticle = UIView()
        reticle.layer.borderColor = UIColor.white.withAlphaComponent(0.6).cgColor
        reticle.layer.borderWidth = 2
        reticle.layer.cornerRadius = 16
        reticle.translatesAutoresizingMaskIntoConstraints = false
        reticle.isUserInteractionEnabled = false
        view.addSubview(reticle)
        NSLayoutConstraint.activate([
            reticle.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            reticle.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            reticle.widthAnchor.constraint(equalToConstant: 240),
            reticle.heightAnchor.constraint(equalToConstant: 240)
        ])
    }

    private func addControls() {
        let closeButton = UIButton(type: .system)
        let closeImage = UIImage(systemName: "xmark.circle.fill",
                                 withConfiguration: UIImage.SymbolConfiguration(pointSize: 28, weight: .semibold))
        closeButton.setImage(closeImage, for: .normal)
        closeButton.tintColor = .white
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.addAction(UIAction { [weak self] _ in
            let d = self?.coordinator.dismiss
            Task { @MainActor in d?() }
        }, for: .touchUpInside)
        view.addSubview(closeButton)

        if let device = AVCaptureDevice.default(for: .video), device.hasTorch {
            let torchButton = UIButton(type: .system)
            let torchImage = UIImage(systemName: "bolt.circle.fill",
                                     withConfiguration: UIImage.SymbolConfiguration(pointSize: 28, weight: .semibold))
            torchButton.setImage(torchImage, for: .normal)
            torchButton.tintColor = .white
            torchButton.translatesAutoresizingMaskIntoConstraints = false
            torchButton.addAction(UIAction { [weak self, weak torchButton] _ in
                guard let self = self else { return }
                self.toggleTorch(button: torchButton)
            }, for: .touchUpInside)
            view.addSubview(torchButton)

            NSLayoutConstraint.activate([
                torchButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
                torchButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16)
            ])
        }

        NSLayoutConstraint.activate([
            closeButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16)
        ])
    }

    private func toggleTorch(button: UIButton?) {
        guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else { return }
        do {
            try device.lockForConfiguration()
            isTorchOn.toggle()
            device.torchMode = isTorchOn ? .on : .off
            device.unlockForConfiguration()
            button?.tintColor = isTorchOn ? .yellow : .white
        } catch {}
    }

    private func showDenied() {
        let label = UILabel()
        label.text = "Camera access is required to scan QR codes.\n\nGo to Settings → VaultETH → Camera to enable it."
        label.textColor = UIColor.secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            label.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32)
        ])
    }
}
