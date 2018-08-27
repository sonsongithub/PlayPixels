//
//  See LICENSE folder for this template’s licensing information.
//
//  Abstract:
//  Provides supporting functions for setting up a live view.
//

import UIKit
import PlaygroundSupport

public var intrinsicSharedLiveViewController: LiveViewController!

private func instantiate() {
    if intrinsicSharedLiveViewController == nil {
        
        let storyboard = UIStoryboard(name: "LiveView", bundle: nil)
        
        guard let viewController = storyboard.instantiateInitialViewController() else {
            fatalError("LiveView.storyboard does not have an initial scene; please set one or update this function")
        }
        
        guard let liveViewController = viewController as? LiveViewController else {
            fatalError("LiveView.storyboard's initial scene is not a LiveViewController; please either update the storyboard or this function")
        }
        intrinsicSharedLiveViewController = liveViewController
    }
}

public var sharedLiveViewController: LiveViewController {
    get {
        instantiate()
        return intrinsicSharedLiveViewController
    }
}
