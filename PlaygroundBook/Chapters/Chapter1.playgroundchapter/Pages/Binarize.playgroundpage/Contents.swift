//#-hidden-code
import UIKit
import PlaygroundSupport

let page = PlaygroundPage.current
page.needsIndefiniteExecution = true

//#-end-hidden-code
func process(input: UnsafePointer<CUnsignedChar>, output: inout [CUnsignedChar], width: Int, height: Int, bytesPerPixel: Int) {
    //#-editable-code
    for y in 0..<height {
        for x in 0..<width {
            let red = input[3 * x + y * width * bytesPerPixel + 0]
            let green = input[3 * x + y * width * bytesPerPixel + 1]
            let blue = input[3 * x + y * width * bytesPerPixel + 2]
            
            let simpleGray = (UInt(red) + UInt(green) + UInt(blue)) / 3
            
            output[x + y * width] = simpleGray > 255 ? 255 : CUnsignedChar(simpleGray)
        }
    }
    //#-end-editable-code
}

//#-hidden-code
class Listener: PlaygroundRemoteLiveViewProxyDelegate {
    
    var pixelBuffer24bit: [CUnsignedChar]?
    
    func remoteLiveViewProxy(_ remoteLiveViewProxy: PlaygroundRemoteLiveViewProxy,
                             received message: PlaygroundValue) {
        if let (data, width, height, bytesPerPixel) = unpack(message) {
            print(data)
            if pixelBuffer24bit == nil {
                pixelBuffer24bit = [CUnsignedChar](repeating: 0, count: height * width)
            }
            
            data.withUnsafeBytes { (rawPtr: UnsafePointer<CUnsignedChar>) in
                
                process(input: rawPtr, output: &pixelBuffer24bit!, width: width, height: height, bytesPerPixel: 3)
                
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
