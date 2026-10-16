//
//  QRScanViewController.swift
//  ShopliveOnboardingDemo — demo harness (not a copy target)
//
//  Scans a credentials QR code (the format the native test apps use) and hands back a
//  QrCredentials. A QR it cannot use keeps the camera open and says why.
//  Same screen and behavior as the Android and Flutter demos: a viewfinder, a hint card at the
//  bottom that turns into the rejection message, and an inline message when the camera is
//  unavailable.
//
//  QR input is a tester convenience, not part of the SDK integration, so it is not in
//  ShopliveIntegration/.
//

import AVFoundation
import UIKit

final class QRScanViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {

    private let onResult: (QrCredentials) -> Void
    private let session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private let hintLabel = UILabel.demo(L("qr.hint"), size: 12.5)
    private var lastRaw: String?
    private var done = false

    init(onResult: @escaping (QrCredentials) -> Void) {
        self.onResult = onResult
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        buildChrome()
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            startCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async { granted ? self?.startCamera() : self?.showCameraError("permissionDenied") }
            }
        default:
            showCameraError("permissionDenied")
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        let session = session
        DispatchQueue.global(qos: .userInitiated).async { if session.isRunning { session.stopRunning() } }
    }

    // MARK: - Camera

    private func startCamera() {
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            showCameraError("noCamera")
            return
        }
        session.addInput(input)
        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else {
            showCameraError("noCamera")
            return
        }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.qr]

        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.frame = view.bounds
        view.layer.insertSublayer(layer, at: 0)
        previewLayer = layer

        let session = session
        DispatchQueue.global(qos: .userInitiated).async { session.startRunning() }
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput metadataObjects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        guard !done,
              let raw = (metadataObjects.first as? AVMetadataMachineReadableCodeObject)?.stringValue,
              raw != lastRaw else { return } // the same code is reported every frame
        lastRaw = raw
        guard let parsed = QrCredentials.parse(raw) else {
            hintLabel.text = L("qr.rejected")
            return
        }
        done = true
        navigationController?.popViewController(animated: true)
        onResult(parsed)
    }

    // MARK: - Layout

    private func showCameraError(_ code: String) {
        let tip = DemoTipView(.warn, L("qr.cameraError", code))
        view.addSubview(tip)
        tip.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tip.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            tip.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            tip.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
        ])
    }

    private func buildChrome() {
        // Top bar: back + title (the root navigation bar is hidden app-wide).
        let bar = UIView()
        bar.backgroundColor = .white
        let back = UIButton(type: .system)
        back.setImage(UIImage(systemName: "chevron.left"), for: .normal)
        back.tintColor = DemoTheme.text
        back.accessibilityLabel = L("common.back")
        back.addTarget(self, action: #selector(close), for: .touchUpInside)
        let title = UILabel.demo(L("qr.title"), size: 16, weight: .semibold)

        // Viewfinder — a visual target only; the whole preview is scanned.
        let finder = UIView()
        finder.layer.borderColor = UIColor.white.cgColor
        finder.layer.borderWidth = 3
        finder.layer.cornerRadius = 16

        let card = UIView()
        card.backgroundColor = .white
        card.layer.cornerRadius = 12
        hintLabel.numberOfLines = 0
        card.addSubview(hintLabel)

        [bar, finder, card].forEach { view.addSubview($0) }
        [back, title].forEach { bar.addSubview($0) }
        [bar, back, title, finder, card, hintLabel].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }
        let safe = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            bar.topAnchor.constraint(equalTo: view.topAnchor),
            bar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bar.bottomAnchor.constraint(equalTo: safe.topAnchor, constant: 52),
            back.leadingAnchor.constraint(equalTo: bar.leadingAnchor, constant: 8),
            back.bottomAnchor.constraint(equalTo: bar.bottomAnchor, constant: -6),
            back.widthAnchor.constraint(equalToConstant: 40),
            back.heightAnchor.constraint(equalToConstant: 40),
            title.leadingAnchor.constraint(equalTo: back.trailingAnchor, constant: 4),
            title.centerYAnchor.constraint(equalTo: back.centerYAnchor),

            finder.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            finder.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            finder.widthAnchor.constraint(equalToConstant: 240),
            finder.heightAnchor.constraint(equalToConstant: 240),

            card.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            card.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            card.bottomAnchor.constraint(equalTo: safe.bottomAnchor, constant: -32),
            hintLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 12),
            hintLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
            hintLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
            hintLabel.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -12),
        ])
    }

    @objc private func close() {
        navigationController?.popViewController(animated: true)
    }
}
