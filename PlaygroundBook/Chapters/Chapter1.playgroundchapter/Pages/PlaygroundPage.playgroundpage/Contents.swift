import UIKit
import PlaygroundSupport

let camera = CameraCapture()

camera.setup()

let proc:(inout [CUnsignedChar], Int, Int, Int) -> Void = { pixel, width, height, bytesPerRow in
    for y in 0..<height {
        for x in 0..<width/2 {
            pixel[3 * x + y * bytesPerRow + 2] = 255
        }
    }
}

//camera.imageFunc = proc

let page = PlaygroundPage.current
PlaygroundPage.current.needsIndefiniteExecution = true
if let proxy = page.liveView as? PlaygroundRemoteLiveViewProxy {
    camera.vc = proxy
    let a = 10
    proxy.send(.integer(a))
}

DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 2, execute: {
    camera.session.startRunning()
})

