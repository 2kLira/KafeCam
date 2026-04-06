//
//  CameraPreview.swift
//  KafeCam_CoreML
//
//  Created by Humberto Figueroa on 10/09/25.
//

import SwiftUI
import AVFoundation

struct CameraPreview: UIViewControllerRepresentable {

    @Binding var takePhotoTrigger: Bool
    var onPhotoCaptured: (UIImage) -> Void

    class CameraViewController: UIViewController {
        private var captureSession: AVCaptureSession?
        private var previewLayer: AVCaptureVideoPreviewLayer?
        private var photoOutput = AVCapturePhotoOutput()
        var onPhotoCaptured: ((UIImage) -> Void)?

        override func viewDidLoad() {
            super.viewDidLoad()
            requestCameraAccess()
        }


        private func requestCameraAccess() {
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted {
                    DispatchQueue.main.async {
                        self.setupCamera()
                    }
                } else {
                    print("❌ Acceso a la cámara denegado")
                }
            }
        }


        private func setupCamera() {
            let session = AVCaptureSession()
            session.sessionPreset = .photo

            guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                  let input = try? AVCaptureDeviceInput(device: camera),
                  session.canAddInput(input) else { return }

            session.addInput(input)

            if session.canAddOutput(photoOutput) {
                session.addOutput(photoOutput)
            }

            let preview = AVCaptureVideoPreviewLayer(session: session)
            preview.videoGravity = .resizeAspectFill
            preview.frame = view.bounds
            view.layer.addSublayer(preview)

            self.captureSession = session
            self.previewLayer = preview

            DispatchQueue.global(qos: .userInitiated).async {
                session.startRunning()
                print("✅ Cámara iniciada")
            }
        }


        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            previewLayer?.frame = view.bounds
        }


        func capturePhoto() {
            let settings = AVCapturePhotoSettings()
            photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    func makeUIViewController(context: Context) -> CameraViewController {
        let vc = CameraViewController()
        vc.onPhotoCaptured = onPhotoCaptured
        return vc
    }

    func updateUIViewController(_ uiViewController: CameraViewController, context: Context) {
        if takePhotoTrigger {
            uiViewController.capturePhoto()
            DispatchQueue.main.async {
                takePhotoTrigger = false 
            }
        }
    }
}

extension CameraPreview.CameraViewController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        if let data = photo.fileDataRepresentation(),
           let image = UIImage(data: data) {
            onPhotoCaptured?(image)
        }
    }
}

