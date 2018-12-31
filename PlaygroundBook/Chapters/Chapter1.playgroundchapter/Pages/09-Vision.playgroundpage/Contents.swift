import UIKit
import PlaygroundSupport
import Accelerate
import Vision

var hoge: Any?

@available(iOSApplicationExtension 11.0, *)
func handleFaceFeatures(request: VNRequest, errror: Error?)  {
    guard let observations = request.results as? [VNFaceObservation] else {
        fatalError("unexpected result type!")
    }
    
    hoge = observations.first
}

func creatCGImage(pointer: UnsafeMutableRawPointer?, width: Int, height: Int, bytesPerPixel: Int) -> CGImage? {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        .union(CGBitmapInfo.byteOrder32Little)
    guard let context = CGContext(data: pointer, width: (width), height: (height), bitsPerComponent: 8, bytesPerRow: (bytesPerPixel), space: colorSpace, bitmapInfo: bitmapInfo.rawValue) else { return nil }
    return context.makeImage()
}

let page = PlaygroundPage.current
page.needsIndefiniteExecution = true

var rgb24buffer: [Float]?
var rgb32buffer: [UInt8]?
var graybuffer: [Float]?
var tempBuffer3: [Float]?
var tempBuffer4: [Float]?
var tempBuffer5: [Float]?

func process(input: UnsafePointer<UInt8>, temp: inout [UInt8], output: inout [UInt8], width: Int, height: Int, bytesPerPixel: Int) {
    
    if rgb24buffer == nil {
        rgb24buffer = [Float](repeating: 0, count: height * width * 3)
    }
    if rgb32buffer == nil {
        rgb32buffer = [UInt8](repeating: 0, count: height * width * 4)
    }
    
    for y in 0..<height {
        for x in 0..<width {
            let r = input[3 * x + y * width * 3 + 0]
            let g = input[3 * x + y * width * 3 + 1]
            let b = input[3 * x + y * width * 3 + 2]
            rgb32buffer![4 * x + y * width * 4 + 0] = 255
            rgb32buffer![4 * x + y * width * 4 + 1] = b
            rgb32buffer![4 * x + y * width * 4 + 2] = g
            rgb32buffer![4 * x + y * width * 4 + 3] = r
        }
    }
    if let cgImage = creatCGImage(pointer: &rgb32buffer!, width: width, height: height, bytesPerPixel: width * 4) {
        
        if #available(iOSApplicationExtension 11.0, *) {
            let faceLandmarksRequest = VNDetectFaceLandmarksRequest(completionHandler: handleFaceFeatures)
            let requestHandler = VNImageRequestHandler(cgImage: cgImage, orientation: .up ,options: [:])
            do {
                try requestHandler.perform([faceLandmarksRequest])
            } catch {
                print(error)
            }
        } else {
            // Fallback on earlier versions
        }
        
    }
    
    if graybuffer == nil {
        graybuffer = [Float](repeating: 0, count: height * width * 3)
    }
    let averageFilter = UnsafeMutablePointer<Float>.allocate(capacity: 3)
    defer { averageFilter.deallocate() }
    
    averageFilter[0] = 0.333333
    averageFilter[1] = 0.333333
    averageFilter[2] = 0.333333
    
    var upper: [Float] = [0]
    var lower: [Float] = [255]
    
    vDSP_vfltu8(input, 1, &rgb24buffer!, 1, UInt (height * width * 3))
    
    vDSP_conv(rgb24buffer!, 3, averageFilter, 1, &graybuffer!, 1, UInt(height * width), 3)
    
    var minX = Int.max
    var minY = Int.max
    var maxX = Int.min
    var maxY = Int.min
    
    if #available(iOSApplicationExtension 11.0, *) {
        if let face = hoge as? VNFaceObservation {
            if let points = face.landmarks?.leftEye?.pointsInImage(imageSize: CGSize(width: width, height: height)) {
                
                for point in points {
                    if minX > Int(point.x) {
                        minX = Int(point.x)
                    } else if maxX < Int(point.x) {
                        maxX = Int(point.x)
                    }
                    if minY > Int(point.y) {
                        minY = Int(point.y)
                    } else if maxY < Int(point.y) {
                        maxY = Int(point.y)
                    }
                }
            }
            if let points = face.landmarks?.rightEye?.pointsInImage(imageSize: CGSize(width: width, height: height)) {
                
                for point in points {
                    for point in points {
                        if minX > Int(point.x) {
                            minX = Int(point.x)
                        } else if maxX < Int(point.x) {
                            maxX = Int(point.x)
                        }
                        if minY > Int(point.y) {
                            minY = Int(point.y)
                        } else if maxY < Int(point.y) {
                            maxY = Int(point.y)
                        }
                    }
                }
            }
        }
    }
    
    minY -= 2
    maxY += 2
    minX -= 10
    maxX += 10
    
    for y in minY..<maxY {
        for x in minX..<maxX {
            graybuffer![x + (height - y) * width] = 0
        }
    }
    
    vDSP_vclip(graybuffer!, 1, &upper, &lower, &graybuffer!, 1, UInt(height * width))
    
    vDSP_vfixu8(graybuffer!, 1, &output, 1, UInt(width * height))
}
//#-hidden-code
class Listener: PlaygroundRemoteLiveViewProxyDelegate {
    
    var pixelBuffer24bit: [UInt8]?
    
    var temp: [UInt8]?
    
    func remoteLiveViewProxy(_ remoteLiveViewProxy: PlaygroundRemoteLiveViewProxy,
                             received message: PlaygroundValue) {
        if let (data, width, height, bytesPerPixel) = unpackPixels(message) {
            print(data)
            if pixelBuffer24bit == nil {
                pixelBuffer24bit = [UInt8](repeating: 0, count: height * width)
            }
            if temp == nil {
                temp = [UInt8](repeating: 0, count: height * width)
            }
            
            data.withUnsafeBytes { (rawPtr: UnsafePointer<UInt8>) in
                
                process(input: rawPtr, temp: &temp!, output: &pixelBuffer24bit!, width: width, height: height, bytesPerPixel: 3)
                
                let data = NSData(bytes: pixelBuffer24bit, length: MemoryLayout<UInt8>.size * width * height)
                
                guard let proxy = PlaygroundPage.current.liveView as? PlaygroundRemoteLiveViewProxy else { return }
                
                let value = PlaygroundValue.dictionary(["data": .data(data as Data), "width": .integer(width), "height": .integer(height), "bytesPerPixel": .integer(1)])
                
                proxy.send(value)
            }
            
        }
    }
    func remoteLiveViewProxyConnectionClosed(_ remoteLiveViewProxy: PlaygroundRemoteLiveViewProxy) { }
}

let listener = Listener()

if let proxy = page.liveView as? PlaygroundRemoteLiveViewProxy {
    proxy.delegate = listener
}

//#-end-hidden-code
