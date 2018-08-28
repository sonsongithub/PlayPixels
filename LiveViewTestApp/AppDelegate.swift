//
//  See LICENSE folder for this template’s licensing information.
//
//  Abstract:
//  Implements the application delegate for LiveViewTestApp with appropriate configuration points.
//

import UIKit
import LiveViewHost
import PlaygroundSupport
import Book_Sources


// Handle messages from the live view.
class Listener: PlaygroundRemoteLiveViewProxyDelegate {
    func remoteLiveViewProxy(_ remoteLiveViewProxy: PlaygroundRemoteLiveViewProxy,
                             received message: PlaygroundValue) {
//
//        guard let liveViewMessage = PlaygroundMessageFromLiveView(playgroundValue: message) else { return }
//
//        switch liveViewMessage {
//        case .planeFound(let plane):
//            planes.append(plane)
//            detectedPlane(plane: plane)
//
//            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 2, execute: {
//                if placedObjectsCount == 0 {
//                    page.assessmentStatus = assessmentPoint(planes: planes)
//                }
//            })
//        case .objectPlacedOnPlane(let object, let plane, let position):
//            if let index = planes.index(of: plane) {
//                object.position = position
//                planes[index].placedObjects.append(object)
//
//                proxy?.send(
//                    PlaygroundMessageToLiveView.announceObjectPlacement(objects: planes[index].placedObjects).playgroundValue
//                )
//            }
//
//            page.assessmentStatus = assessmentPoint(planes: planes)
//        default:
//            break
//        }
    }
    func remoteLiveViewProxyConnectionClosed(_ remoteLiveViewProxy: PlaygroundRemoteLiveViewProxy) { }
}

@UIApplicationMain
class AppDelegate: LiveViewHost.AppDelegate {
    
//    let camera = CameraCapture()
    
    override func setUpLiveView() -> PlaygroundLiveViewable {
        // This method should return a fully-configured live view. This method must be implemented.
        //
        // The view or view controller returned from this method will be automatically be shown on screen,
        // as if it were a live view in Swift Playgrounds. You can control how the live view is shown by
        // changing the implementation of the `liveViewConfiguration` property below.
        let a = Book_Sources.sharedLiveViewController

//        camera.setup()
//        
//        camera.vc = a
//        
//        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 2, execute: {
//            self.camera.session.startRunning()
//        })
//        
        return a
    }

    override var liveViewConfiguration: LiveViewConfiguration {
        // Make this property return the configuration of the live view which you desire to test.
        //
        // Valid values are `.fullScreen`, which simulates when the user has expanded the live
        // view to fill the full screen in Swift Playgrounds, and `.sideBySide`, which simulates when
        // the live view is shown next to or above the source code editor in Swift Playgrounds.
        return .sideBySide
    }
}
