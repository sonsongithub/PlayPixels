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
import Accelerate

public enum CameraOrientation {
    case landscapeLeft
    case landscapeRight
    case portrait
    case portraitUpsideDown
    case unknown
}

@objc(Book_Sources_LiveViewController)
public class LiveViewController: UIViewController, PlaygroundLiveViewMessageHandler, PlaygroundLiveViewSafeAreaContainer, UITableViewDelegate, UITableViewDataSource, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    var device: AVCaptureDevice!
    public var session: AVCaptureSession!
    
    var pixelBuffer24bit: [CUnsignedChar]?
    var pixelBuffer32bit: [CUnsignedChar]?
    var grayBuffer: [CUnsignedChar]?
    var floatBuffer: [Float]?
    
    var outputWidth = 192
    var outputHeight = 144
    
    var data: Data?
    
    private var cameraPosition = AVCaptureDevice.Position.front
    
    public var orientation = CameraOrientation.landscapeLeft
    
    #if LiveViewTestApp
    public var vc: LiveViewController?
    #else
    public var vc: PlaygroundRemoteLiveViewProxy?
    #endif
    
    public static var aaaa: CUnsignedChar = 10
    public var threshold: CUnsignedChar = 255
    
    @IBOutlet var tableView: UITableView!
    @IBOutlet var cameraToggle: UIButton!
    @IBOutlet var logSwitch: UIButton!
    @IBOutlet var trashButton: UIButton!
    
    var buffers: [String] = []
    
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
//            vc?.updateAttribute(dict)
            #else
//            vc?.send(.dictionary(dict))
            #endif
            pixelBuffer24bit = [CUnsignedChar](repeating: 0, count: height * width * 3)
            grayBuffer = [CUnsignedChar](repeating: 0, count: height * width)
            floatBuffer = [Float](repeating: 0, count: height * width)
        }
        if pixelBuffer32bit == nil {
            pixelBuffer32bit = [CUnsignedChar](repeating: 0, count: height * width * 4)
        }
        
        let convertPosition: (Int, Int, CameraOrientation, AVCaptureDevice.Position) -> (Int, Int) = { (x: Int, y: Int, cameraOrientation: CameraOrientation, position: AVCaptureDevice.Position) -> (Int, Int) in
            switch (cameraOrientation, position) {
            case (.landscapeLeft, .front):
                return (x, y)
            case (.landscapeRight, .front):
                return (x, height - 1 - y)
            case (.portrait, .front):
                return (y, x)
            case (.portraitUpsideDown, .front):
                return (y, width - 1 - x)
            case (.landscapeLeft, .back):
                return (x, height - 1 - y)
            case (.landscapeRight, .back):
                return (x, y)
            case (.portrait, .back):
                return (y, x)
            case (.portraitUpsideDown, .back):
                return (y, width - 1 - x)
            default:
                return (x, y)
            }
        }
        
        for y in 0..<height {
            for x in 0..<width {
                let (targetx, targety) = convertPosition(x, y, cameraOrientation, cameraPosition)
                let b = pointer[4 * x + y * bytesPerRow + 0]
                let g = pointer[4 * x + y * bytesPerRow + 1]
                let r = pointer[4 * x + y * bytesPerRow + 2]
                pixelBuffer24bit![3 * targetx + targety * outputWidth * 3 + 0] = r
                pixelBuffer24bit![3 * targetx + targety * outputWidth * 3 + 1] = g
                pixelBuffer24bit![3 * targetx + targety * outputWidth * 3 + 2] = b
            }
        }
        
        updateOrientation(width: width, height: height)
        
        for y in 0..<height {
            for x in 0..<width {
                let red = pixelBuffer24bit![3 * x + y * outputWidth * 3 + 0]
                let green = pixelBuffer24bit![3 * x + y * outputWidth * 3 + 1]
                let blue = pixelBuffer24bit![3 * x + y * outputWidth * 3 + 2]
                
                let simpleGray = (UInt(red) + UInt(green) + UInt(blue)) / 3
                
                grayBuffer![x + y * width] = simpleGray > 255 ? 255 : CUnsignedChar(simpleGray)
            }
        }

#if LiveViewTestApp
        let data = NSData(bytes: grayBuffer, length: MemoryLayout<CUnsignedChar>.size * outputWidth * outputHeight * 1)
        let (message) = PlaygroundValue.dictionary(["data": .data(data as Data), "width": .integer(outputWidth), "height": .integer(outputHeight), "bytesPerPixel": .integer(1)])
        if let (data, width, height, bytesPerPixel) = unpackPixels(message) {
            updateImage(data: data, width: width, height: height, bytesPerPixel: bytesPerPixel)
        }
#else
        let data = NSData(bytes: pixelBuffer24bit, length: MemoryLayout<CUnsignedChar>.size * outputWidth * outputHeight * 3)
        let value = PlaygroundValue.dictionary(["data": .data(data as Data), "width": .integer(outputWidth), "height": .integer(outputHeight), "bytesPerPixel": .integer(3)])
        self.send(value)
#endif
        CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
    }
    
    public func setup(position: AVCaptureDevice.Position) {
        
        if self.session != nil {
            self.session.stopRunning()
            self.session = nil
            self.device = nil
        }
        
        let session = AVCaptureSession()
        let discoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: position)
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
        self.session.startRunning()
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
        self.view.bringSubview(toFront: cameraToggle)
        self.view.bringSubview(toFront: trashButton)
        self.view.bringSubview(toFront: logSwitch)
        
        [(trashButton, "trash"), (cameraToggle, "camera"), (logSwitch, "no_monitor")].forEach({
            if let image = UIImage(named: $0.1) {
                let temp = image.withRenderingMode(.alwaysTemplate)
                $0.0.setImage(temp, for: .normal)
            }
        })
        trashButton.isHidden = true
        tableView.isHidden = true
    }
    
    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        cameraPosition = .front
        setup(position: .front)
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
    
    public override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        buffers.append("viewWillTransition")
        tableView.reloadData()
    }
    
    // MARK: - IBAction
    
    @IBAction func pushToggle(sender: Any) {
        if cameraPosition == .front {
            cameraPosition = .back
            setup(position: .back)
        } else {
            cameraPosition = .front
            setup(position: .front)
        }
        updateLog(string: "toggle")
    }
    
    @IBAction func didChangedSwitch(sender: Any) {
        tableView.isHidden = !tableView.isHidden
        trashButton.isHidden = tableView.isHidden
        
        if tableView.isHidden {
            if let image = UIImage(named: "no_monitor") {
                let temp = image.withRenderingMode(.alwaysTemplate)
                logSwitch.setImage(temp, for: .normal)
            }
        } else {
            if let image = UIImage(named: "monitor") {
                let temp = image.withRenderingMode(.alwaysTemplate)
                logSwitch.setImage(temp, for: .normal)
            }
        }
    }
    
    @IBAction func didPushTrashButton(sender: Any) {
        buffers.removeAll()
        tableView.reloadData()
    }
    
    // MARK: - Message dispatch
    
    public func updateImage(data: Data, width: Int, height: Int, bytesPerPixel: Int) {
        if let image = createImage(data: data, buffer: &pixelBuffer32bit!, width: width, height: height, bytesPerPixel: bytesPerPixel) {
            DispatchQueue.main.async {
                self.imageView.image = image
            }
        }
    }
    
    public func updateLog(string: String) {
        tableView.beginUpdates()
        buffers.append(string)
        tableView.insertRows(at: [IndexPath(row: self.buffers.count - 1, section: 0)], with: .left)
        tableView.endUpdates()
        tableView.scrollToRow(at: IndexPath(row: self.buffers.count - 1, section: 0), at: .bottom, animated: true)
    }
    
    // MARK: - Log
    
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        trashButton.isEnabled = (buffers.count > 0)
        return buffers.count
    }
    
    public func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 44
    }
    
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
    }
    
    public func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        cell.backgroundColor = .clear
        cell.textLabel?.text = buffers[indexPath.row]
        cell.selectionStyle = .none
        return cell
    }
    
    // MARK: - PlaygroundSupport
    
    public func liveViewMessageConnectionOpened() {
        // Implement this method to be notified when the live view message connection is opened.
        // The connection will be opened when the process running Contents.swift starts running and listening for messages.
    }
    
    public func liveViewMessageConnectionClosed() {
        // Implement this method to be notified when the live view message connection is closed.
        // The connection will be closed when the process running Contents.swift exits and is no longer listening for messages.
        // This happens when the user's code naturally finishes running, if the user presses Stop, or if there is a crash.
    }
    
    public func receive(_ message: PlaygroundValue) {
        if let (data, width, height, bytesPerPixel) = unpackPixels(message) {
            updateImage(data: data, width: width, height: height, bytesPerPixel: bytesPerPixel)
        } else if let string = unpackLog(message) {
            updateLog(string: string)
        }
    }
}
