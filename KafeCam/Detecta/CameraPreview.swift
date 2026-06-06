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
    var onError: ((String) -> Void)? = nil

    class CameraViewController: UIViewController {
        private var captureSession: AVCaptureSession?
        private var previewLayer: AVCaptureVideoPreviewLayer?
        private var photoOutput = AVCapturePhotoOutput()
        var onPhotoCaptured: ((UIImage) -> Void)?
        var onError: ((String) -> Void)?

        override func viewDidLoad() {
            super.viewDidLoad()
            requestCameraAccess()
        }

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            stopSession()
        }

        deinit { stopSession() }

        private func stopSession() {
            guard let session = captureSession, session.isRunning else { return }
            // Stop off the main thread (startRunning/stopRunning block).
            DispatchQueue.global(qos: .userInitiated).async { session.stopRunning() }
        }


        private func requestCameraAccess() {
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted {
                    DispatchQueue.main.async {
                        self.setupCamera()
                    }
                } else {
                    debugLog("❌ Acceso a la cámara denegado")
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
                debugLog("✅ Cámara iniciada")
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
        vc.onError = onError
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
        if let error = error {
            debugLog("❌ Error al capturar foto: \(error)")
            DispatchQueue.main.async { self.onError?("No se pudo tomar la foto. Intenta de nuevo.") }
            return
        }
        guard let data = photo.fileDataRepresentation(), let image = UIImage(data: data) else {
            debugLog("❌ Foto vacía o no decodificable")
            DispatchQueue.main.async { self.onError?("No se pudo procesar la foto. Intenta de nuevo.") }
            return
        }
        DispatchQueue.main.async { self.onPhotoCaptured?(image) }
    }
}

