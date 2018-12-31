//#-hidden-code
import UIKit
import PlaygroundSupport

let page = PlaygroundPage.current
page.needsIndefiniteExecution = true

//#-end-hidden-code
func process(input: UnsafePointer<CUnsignedChar>, temp: inout [CUnsignedChar], output: inout [CUnsignedChar], width: Int, height: Int, bytesPerPixel: Int) {
    //#-editable-code
    for y in 0..<height {
        for x in 0..<width {
            let red = input[3 * x + y * width * bytesPerPixel + 0]
            let green = input[3 * x + y * width * bytesPerPixel + 1]
            let blue = input[3 * x + y * width * bytesPerPixel + 2]
            
            let simpleGray = (UInt(red) + UInt(green) + UInt(blue)) / 3
            
            temp[x + y * width] = simpleGray > 255 ? 255 : CUnsignedChar(simpleGray)
        }
    }
    
    for y in 1..<height - 1 {
        for x in 1..<width - 1 {
            
//            let weight: [Int] = [
//                1, 0, -1,
//                2, 0, -2,
//                1, 0, -1
//            ]
            
            let weight: [Int] = [
                 1,  2,  1,
                 0,  0,  0,
                -1, -2, -1
            ]
            
            let v = weight[0] * Int(temp[(x - 1) + (y - 1) * width]) + weight[1] * Int(temp[(x) + (y - 1) * width]) + weight[2] * Int(temp[(x + 1) + (y - 1) * width]) + weight[3] * Int(temp[(x - 1) + (y) * width]) + weight[4] * Int(temp[(x) + (y) * width]) + weight[5] *  Int(temp[(x + 1) + (y) * width]) + weight[6] * Int(temp[(x - 1) + (y + 1) * width]) + weight[7] * Int(temp[(x) + (y + 1) * width]) + weight[8] * Int(temp[(x + 1) + (y + 1) * width])
            
            let i = (v + 1024) / 8
            
            if i > 0 {
                output[x + y * width] = UInt8(i)
            } else {
                output[x + y * width] = 0
            }
        }
    }
    //#-end-editable-code
}

//#-hidden-code
class Listener: PlaygroundRemoteLiveViewProxyDelegate {
    
    var pixelBuffer24bit: [CUnsignedChar]?
    
    var temp: [CUnsignedChar]?
    
    func remoteLiveViewProxy(_ remoteLiveViewProxy: PlaygroundRemoteLiveViewProxy,
                             received message: PlaygroundValue) {
        if let (data, width, height, bytesPerPixel) = unpackPixels(message) {
            print(data)
            if pixelBuffer24bit == nil {
                pixelBuffer24bit = [CUnsignedChar](repeating: 0, count: height * width)
            }
            if temp == nil {
                temp = [CUnsignedChar](repeating: 0, count: height * width)
            }
            
            data.withUnsafeBytes { (rawPtr: UnsafePointer<CUnsignedChar>) in
                
                process(input: rawPtr, temp: &temp!, output: &pixelBuffer24bit!, width: width, height: height, bytesPerPixel: 3)
                
                let data = NSData(bytes: pixelBuffer24bit, length: MemoryLayout<CUnsignedChar>.size * width * height)
                
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
