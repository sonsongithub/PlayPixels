import UIKit
import PlaygroundSupport
import Accelerate

let page = PlaygroundPage.current
page.needsIndefiniteExecution = true

var tempBuffer1: [Float]?
var tempBuffer2: [Float]?
var tempBuffer3: [Float]?
var tempBuffer4: [Float]?
var tempBuffer5: [Float]?

func process(input: UnsafePointer<UInt8>, temp: inout [UInt8], output: inout [UInt8], width: Int, height: Int, bytesPerPixel: Int) {
    
    if tempBuffer1 == nil {
        tempBuffer1 = [Float](repeating: 0, count: height * width * 3)
    }
    if tempBuffer2 == nil {
        tempBuffer2 = [Float](repeating: 0, count: height * width)
    }
    if tempBuffer3 == nil {
        tempBuffer3 = [Float](repeating: 0, count: height * width)
    }
    if tempBuffer4 == nil {
        tempBuffer4 = [Float](repeating: 0, count: height * width)
    }
    if tempBuffer5 == nil {
        tempBuffer5 = [Float](repeating: 0, count: height * width)
    }
    
    vDSP_vfltu8(input, 1, &tempBuffer1!, 1, UInt (height * width * 3))
    
    let averageFilter = UnsafeMutablePointer<Float>.allocate(capacity: 3)
    defer { averageFilter.deallocate() }
    
    let convFilter = UnsafeMutablePointer<Float>.allocate(capacity: 9)
    defer { convFilter.deallocate() }
    
    averageFilter[0] = 0.333333
    averageFilter[1] = 0.333333
    averageFilter[2] = 0.333333
    
    vDSP_conv(tempBuffer1!, 3, averageFilter, 1, &tempBuffer2!, 1, UInt(height * width), 3)
    
    convFilter[0] = -1/4
    convFilter[1] = 0
    convFilter[2] = 1/4
    
    convFilter[3] = -2/4
    convFilter[4] = 0
    convFilter[5] = 2/4
    
    convFilter[6] = -1/4
    convFilter[7] = 0
    convFilter[8] = 1/4
    
    vDSP_f3x3(tempBuffer2!, UInt(height), UInt(width), convFilter, &tempBuffer3!)
    
    vDSP_vabs(tempBuffer3!, 1, &tempBuffer3!, 1, UInt(width * height))
    
    convFilter[0] = -1/4
    convFilter[3] = 0
    convFilter[6] = 1/4
    
    convFilter[1] = -2/4
    convFilter[4] = 0
    convFilter[7] = 2/4
    
    convFilter[2] = -1/4
    convFilter[5] = 0
    convFilter[8] = 1/4
    
    vDSP_f3x3(tempBuffer2!, UInt(height), UInt(width), convFilter, &tempBuffer4!)
    
    vDSP_vabs(tempBuffer4!, 1, &tempBuffer4!, 1, UInt(width * height))
    
    var upper: [Float] = [0]
    var lower: [Float] = [255]
    
    vDSP_vadd(tempBuffer3!, 1, tempBuffer4!, 1, &tempBuffer5!, 1, UInt(width * height))
    
    vDSP_vclip(tempBuffer5!, 1, &upper, &lower, &tempBuffer5!, 1, UInt(height * width))
    
    vDSP_vfixu8(tempBuffer5!, 1, &output, 1, UInt(width * height))
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
