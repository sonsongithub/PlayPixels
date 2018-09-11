import UIKit
import PlaygroundSupport
import AVFoundation
import CoreImage
import Accelerate

func createCGImage(pointer: UnsafeMutableRawPointer?, width: Int, height: Int, bytesPerPixel: Int) -> CGImage? {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        .union(CGBitmapInfo.byteOrder32Little)
    guard let context = CGContext(data: pointer, width: (width), height: (height), bitsPerComponent: 8, bytesPerRow: (bytesPerPixel), space: colorSpace, bitmapInfo: bitmapInfo.rawValue) else { return nil }
    return context.makeImage()
}

public func unpackLog(_ value: PlaygroundValue) -> String? {
    
    if case .dictionary(let dict) = value {
        guard let log = dict["log"] else { return nil }
        if case .string(let string) = log {
            return string
        }
    }
    
    return nil
}

public func unpackPixels(_ value: PlaygroundValue) -> (Data, Int, Int, Int)? {
    
    if case .dictionary(let dict) = value {
        guard let d_value = dict["data"] else { return nil }
        guard let w_value = dict["width"] else { return nil }
        guard let h_value = dict["height"] else { return nil }
        guard let p_value = dict["bytesPerPixel"] else { return nil }
        
        if case (.data(let data), .integer(let width), .integer(let height), .integer(let bytesPerPixel)) = (d_value, w_value, h_value, p_value) {
            print(data)
            print(width)
            print(height)
            return (data, width, height, bytesPerPixel)
        }
    }
    
    return nil
}

struct FrameBuffer {
    var pixel: [CUnsignedChar]?
    var width: Int
    var height: Int
}

public func createImage(data: Data, buffer: inout [CUnsignedChar], width: Int, height: Int, bytesPerPixel: Int) -> UIImage? {

    if bytesPerPixel == 3 {
        
        guard height > 0 && width > 0 else {
            return nil
        }
        
        data.withUnsafeBytes { (p: UnsafePointer<UInt8>) -> Void in
            let rawPtr = UnsafePointer(p)
            for y in 0..<height {
                for x in 0..<width {
                    let r = rawPtr[3 * x + y * width * 3 + 0]
                    let g = rawPtr[3 * x + y * width * 3 + 1]
                    let b = rawPtr[3 * x + y * width * 3 + 2]
                    buffer[4 * x + y * width * 4 + 0] = 255
                    buffer[4 * x + y * width * 4 + 1] = b
                    buffer[4 * x + y * width * 4 + 2] = g
                    buffer[4 * x + y * width * 4 + 3] = r
                }
            }
        }
        
        
        guard let cgImage = createCGImage(pointer: &buffer, width: width, height: height, bytesPerPixel: width * 4) else {
            return nil
        }
        
        return UIImage(cgImage: cgImage)
        
    } else if bytesPerPixel == 1 {
        
        guard height > 0 && width > 0 else {
            return nil
        }
        
        data.withUnsafeBytes { (p: UnsafePointer<UInt8>) -> Void in
            let rawPtr = UnsafePointer(p)
            for y in 0..<height {
                for x in 0..<width {
                    let gray = rawPtr[x + y * width]
                    buffer[4 * x + y * width * 4 + 0] = 255
                    buffer[4 * x + y * width * 4 + 1] = gray
                    buffer[4 * x + y * width * 4 + 2] = gray
                    buffer[4 * x + y * width * 4 + 3] = gray
                }
            }
        }
        guard let cgImage = createCGImage(pointer: &buffer, width: width, height: height, bytesPerPixel: width * 4) else { return nil}
        return UIImage(cgImage: cgImage)
    }
    return nil
}

public func log(_ string: String) {
    guard let proxy = PlaygroundPage.current.liveView as? PlaygroundRemoteLiveViewProxy else { return }
    let dict: [String: PlaygroundValue] = ["log": .string(string)]
    proxy.send(.dictionary(dict))
}
