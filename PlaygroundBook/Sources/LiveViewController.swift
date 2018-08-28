//
//  See LICENSE folder for this template’s licensing information.
//
//  Abstract:
//  An auxiliary source file which is part of the book-level auxiliary sources.
//  Provides the implementation of the "always-on" live view.
//

import UIKit
import PlaygroundSupport
import AVFoundation
import CoreImage

public enum CameraOrientation {
    case landscapeLeft
    case landscapeRight
    case portrait
    case portraitUpsideDown
    case unknown
}

public func unpack(_ value: PlaygroundValue) -> (Data, Int, Int)? {
    
    if case .dictionary(let dict) = value {
        guard let d_value = dict["data"] else { return nil }
        guard let w_value = dict["width"] else { return nil }
        guard let h_value = dict["height"] else { return nil }
        
        if case (.data(let data), .integer(let width), .integer(let height)) = (d_value, w_value, h_value) {
            print(data)
            print(width)
            print(height)
            return (data, width, height)
        }
    }
    
    return nil
}

@objc(Book_Sources_LiveViewController)
public class LiveViewController: UIViewController, PlaygroundLiveViewMessageHandler, PlaygroundLiveViewSafeAreaContainer, UITableViewDelegate, UITableViewDataSource, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    var device: AVCaptureDevice!
    public var session: AVCaptureSession!
    
    var pixelBuffer24bit: [CUnsignedChar]?
    var pixelBuffer32bit: [CUnsignedChar]?
    
    var outputWidth = 192
    var outputHeight = 144
    
    var data: Data?
    
    public var orientation = CameraOrientation.landscapeLeft
    
    #if LiveViewTestApp
    public var vc: LiveViewController?
    #else
    public var vc: PlaygroundRemoteLiveViewProxy?
    #endif
    
    public static var aaaa: CUnsignedChar = 10
    public var threshold: CUnsignedChar = 255
    
    @IBOutlet var label: UILabel!
    
    @IBOutlet var tableView: UITableView!
    
    var buffers: [String] = []
    
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return buffers.count
    }
    
    public func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 44
    }
    
    public func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        cell.backgroundColor = .clear
        cell.textLabel?.text = buffers[indexPath.row]
        return cell
    }
    
    fileprivate var cameraOrientation = CameraOrientation.unknown
    
    var constraintWidth: NSLayoutConstraint?
    var constraintHeight: NSLayoutConstraint?
    let imageView = UIImageView(frame: .zero)
    
    
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)!
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else { return }
        
        let pointer: UnsafeMutablePointer<UInt8> = baseAddress.assumingMemoryBound(to: UInt8.self)
        
        if pixelBuffer24bit == nil {
            let dict: [String : PlaygroundValue] = [
                "width": PlaygroundValue.integer(width),
                "height": PlaygroundValue.integer(height)
            ]
            print(dict)
            #if LiveViewTestApp
            vc?.updateAttribute(dict)
            #else
            vc?.send(.dictionary(dict))
            #endif
            pixelBuffer24bit = [CUnsignedChar](repeating: 0, count: height * width * 3)
        }
        if pixelBuffer32bit == nil {
            pixelBuffer32bit = [CUnsignedChar](repeating: 0, count: height * width * 4)
        }
        
        let convertPosition: (Int, Int, CameraOrientation) -> (Int, Int) = { (x: Int, y: Int, cameraOrientation: CameraOrientation) -> (Int, Int) in
            switch cameraOrientation {
            case .landscapeLeft:
                return (x, y)
            case .landscapeRight:
                return (x, height - 1 - y)
            case .portrait:
                return (y, x)
            case .portraitUpsideDown:
                return (y, width - 1 - x)
            default:
                return (0, 0)
            }
        }
        
        for y in 0..<height {
            for x in 0..<width {
                let (targetx, targety) = convertPosition(x, y, cameraOrientation)
                let b = pointer[4 * x + y * bytesPerRow + 0]
                let g = pointer[4 * x + y * bytesPerRow + 1]
                let r = pointer[4 * x + y * bytesPerRow + 2]
                pixelBuffer24bit![3 * targetx + targety * outputWidth * 3 + 0] = r
                pixelBuffer24bit![3 * targetx + targety * outputWidth * 3 + 1] = g
                pixelBuffer24bit![3 * targetx + targety * outputWidth * 3 + 2] = b
            }
        }
        
        updateOrientation(width: width, height: height)
        
        let data = NSData(bytes: pixelBuffer24bit, length: MemoryLayout<CUnsignedChar>.size * outputWidth * outputHeight * 3)
        
//        imageFunc(&pixelBuffer24bit!, outputWidth, outputHeight, 3 * outputWidth)
        
//        let value = PlaygroundValue.dictionary(["data": .data(data as Data), "width": .integer(outputWidth), "height": .integer(outputHeight)])
//        if let a = unpack(value) {
//            print(a)
//        }
        
#if LiveViewTestApp
        self.updateImage(data as Data)
#else
        let value = PlaygroundValue.dictionary(["data": .data(data as Data), "width": .integer(outputWidth), "height": .integer(outputHeight)])
        self.send(value)
#endif
        
        
        
        CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
        
//        let data = NSData(bytes: pixelBuffer24bit, length: MemoryLayout<CUnsignedChar>.size * outputWidth * outputHeight * 3)
        
//        #if LiveViewTestApp
//        vc?.updateImage(data as Data)
//        #else
//        vc?.send(.data(data as Data))
//        #endif
    }
    
    public func setup() {
        
        let session = AVCaptureSession()
        let discoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .front)
        guard discoverySession.devices.count > 0 else {
            assert(false, "Cannot initialize capture device.")
            return
        }
        let device = discoverySession.devices[0]
        
        session.beginConfiguration()
        
        do {
            let deviceInput = try AVCaptureDeviceInput(device: device)
            session.addInput(deviceInput)
            session.sessionPreset = .low
        } catch {
            print(error)
            assert(false, "Cannot initialize capture device.")
            return
        }
        
        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        let cameraQueue = DispatchQueue(label: "camera")
        output.setSampleBufferDelegate(self, queue: cameraQueue)
        output.alwaysDiscardsLateVideoFrames = true
        session.addOutput(output)
        
        session.commitConfiguration()
        
        do {
            try device.lockForConfiguration()
            device.activeVideoMinFrameDuration = CMTimeMake(1, 30)
            device.unlockForConfiguration()
        } catch {
            print(error)
            assert(false, "Cannot initialize capture device.")
            return
        }
        
        self.session = session
        self.device = device
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.delegate = self
        tableView.dataSource = self
        tableView.backgroundColor = .clear
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        tableView.separatorStyle = .none
        
        self.view.backgroundColor = .white
        
        self.view.addSubview(imageView)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        
        let constraintX = NSLayoutConstraint(item: self.view, attribute: .centerX, relatedBy: .equal, toItem: imageView, attribute: .centerX, multiplier: 1, constant: 0)
        let constraintY = NSLayoutConstraint(item: self.view, attribute: .centerY, relatedBy: .equal, toItem: imageView, attribute: .centerY, multiplier: 1, constant: 0)
        let constraintWidth = NSLayoutConstraint(item: imageView, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: 384)
        let constraintHeight = NSLayoutConstraint(item: imageView, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: 384)
        
        self.view.addConstraint(constraintX)
        self.view.addConstraint(constraintY)
        imageView.addConstraint(constraintWidth)
        imageView.addConstraint(constraintHeight)
        
        self.constraintWidth = constraintWidth
        self.constraintHeight = constraintHeight
        
        self.view.bringSubview(toFront: tableView)
        
        setup()
    }
    
    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.session.startRunning()
    }
    
    private func updateOrientation(width: Int, height: Int) {
        let prev = cameraOrientation
        switch self.interfaceOrientation {
        case .landscapeRight:
            if CameraOrientation.landscapeRight != cameraOrientation {
                cameraOrientation = .landscapeRight
                outputWidth = width
                outputHeight = height
            }
        case .landscapeLeft:
            if CameraOrientation.landscapeLeft != cameraOrientation {
                cameraOrientation = .landscapeLeft
                outputWidth = width
                outputHeight = height
            }
        case .portrait:
            if CameraOrientation.portrait != cameraOrientation {
                cameraOrientation = .portrait
                outputWidth = height
                outputHeight = width
            }
        case .portraitUpsideDown:
            if CameraOrientation.portraitUpsideDown != cameraOrientation {
                cameraOrientation = .portraitUpsideDown
                outputWidth = height
                outputHeight = width
            }
        default:
            do {}
        }
        if prev != cameraOrientation {
            DispatchQueue.main.async {
                let A = self.view.frame.size.width / self.view.frame.size.height
                let a = CGFloat(self.outputWidth) / CGFloat(self.outputHeight)
                if A > a {
                    self.constraintHeight?.constant = self.view.frame.size.height
                    self.constraintWidth?.constant = self.view.frame.size.height * a
                } else {
                    self.constraintWidth?.constant = self.view.frame.size.width
                    self.constraintHeight?.constant = self.view.frame.size.width / a
                }
            }
        }
    }
    
    public func liveViewMessageConnectionOpened() {
        // Implement this method to be notified when the live view message connection is opened.
        // The connection will be opened when the process running Contents.swift starts running and listening for messages.
    }

    public func liveViewMessageConnectionClosed() {
        // Implement this method to be notified when the live view message connection is closed.
        // The connection will be closed when the process running Contents.swift exits and is no longer listening for messages.
        // This happens when the user's code naturally finishes running, if the user presses Stop, or if there is a crash.
    }
    
    private func creatCGImage(pointer: UnsafeMutableRawPointer?, width: Int, height: Int, bytesPerPixel: Int) -> CGImage? {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
            .union(CGBitmapInfo.byteOrder32Little)
        guard let context = CGContext(data: pointer, width: (width), height: (height), bitsPerComponent: 8, bytesPerRow: (bytesPerPixel), space: colorSpace, bitmapInfo: bitmapInfo.rawValue) else { return nil }
        return context.makeImage()
    }
    
    public func updateImage(_ data: Data) {
        
        guard outputHeight > 0 && outputWidth > 0 else { return }
        
        data.withUnsafeBytes { (u8Ptr: UnsafePointer<CUnsignedChar>) in
            let rawPtr = UnsafePointer(u8Ptr)
            for y in 0..<outputHeight {
                for x in 0..<outputWidth {
                    let r = rawPtr[3 * x + y * outputWidth * 3 + 0]
                    let g = rawPtr[3 * x + y * outputWidth * 3 + 1]
                    let b = rawPtr[3 * x + y * outputWidth * 3 + 2]
                    pixelBuffer32bit![4 * x + y * outputWidth * 4 + 0] = 255
                    pixelBuffer32bit![4 * x + y * outputWidth * 4 + 1] = b
                    pixelBuffer32bit![4 * x + y * outputWidth * 4 + 2] = g
                    pixelBuffer32bit![4 * x + y * outputWidth * 4 + 3] = r
                }
            }
            
            guard let cgImage = creatCGImage(pointer: &pixelBuffer32bit!, width: outputWidth, height: outputHeight, bytesPerPixel: outputWidth * 4) else { return }
            
            let uiImage = UIImage(cgImage: cgImage)
            
            DispatchQueue.main.async {
                self.imageView.image = uiImage
            }
        }
    }
    
    public func updateAttribute(_ dict: [String : PlaygroundValue]) {
        
        guard let value_w = dict["width"] else { return }
        guard let value_h = dict["height"] else { return }
        
        switch (value_w, value_h) {
        case (.integer(let w), .integer(let h)):
            print(w)
            print(h)
            updateOrientation(width: w, height: h)
            if pixelBuffer32bit == nil {
                pixelBuffer32bit = [CUnsignedChar](repeating: 0, count: w * h * 4)
            }
        default:
            do {}
        }
    }
    
    public override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        self.view.bringSubview(toFront: label)
        buffers.append("viewWillTransition")
        tableView.reloadData()
        
    }
    
    public func receive(_ message: PlaygroundValue) {
        switch message {
        case .dictionary(let dict):
            updateAttribute(dict)
        case .data(let data):
            self.updateImage(data)
        default:
            do {}
        }
    }
}
