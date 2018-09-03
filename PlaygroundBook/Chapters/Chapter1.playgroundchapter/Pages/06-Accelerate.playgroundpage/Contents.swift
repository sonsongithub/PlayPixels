import UIKit
import PlaygroundSupport
import Accelerate

let page = PlaygroundPage.current
page.needsIndefiniteExecution = true

var tempBuffer1: [Float]?
var tempBuffer2: [Float]?
var tempBuffer3: [Float]?

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
    
    vDSP_vfltu8(input, 1, &tempBuffer1!, 1, UInt (height * width * 3))
    
    let averageFilter = UnsafeMutablePointer<Float>.allocate(capacity: 3)
    defer { averageFilter.deallocate() }
    
    averageFilter[0] = 0.3333
    averageFilter[1] = 0.3333
    averageFilter[2] = 0.3333
    
    vDSP_conv(&tempBuffer1!, 3, averageFilter, 1, &tempBuffer2!, 1, UInt(height * width), 3)
    
    for y in 1..<height - 1 {
        for x in 1..<width - 1 {
            
            let weight: [Int] = [
                1,  2,  1,
                0,  0,  0,
                -1, -2, -1
            ]
            
            
            let v = weight[0] * Int(tempBuffer2![(x - 1) + (y - 1) * width]) + weight[1] * Int(tempBuffer2![(x) + (y - 1) * width]) + weight[2] * Int(tempBuffer2![(x + 1) + (y - 1) * width]) + weight[3] * Int(tempBuffer2![(x - 1) + (y) * width]) + weight[4] * Int(tempBuffer2![(x) + (y) * width]) + weight[5] *  Int(tempBuffer2![(x + 1) + (y) * width]) + weight[6] * Int(tempBuffer2![(x - 1) + (y + 1) * width]) + weight[7] * Int(tempBuffer2![(x) + (y + 1) * width]) + weight[8] * Int(tempBuffer2![(x + 1) + (y + 1) * width])
            
            let i = v / 4
            
            tempBuffer3![x + y * width] = Float(abs(i))
        }
    }
    
    
    vDSP_vfixu8(tempBuffer3!, 1, &output, 1, UInt(width * height))
}

//#-hidden-code
class Listener: PlaygroundRemoteLiveViewProxyDelegate {
    
    var pixelBuffer24bit: [UInt8]?
    
    var temp: [UInt8]?
    
    func remoteLiveViewProxy(_ remoteLiveViewProxy: PlaygroundRemoteLiveViewProxy,
                             received message: PlaygroundValue) {
        if let (data, width, height, bytesPerPixel) = unpack(message) {
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
