//
//  AppDelegate.swift
//  AttractorCL
//
//  Created by Thor Frølich on 25/12/14.
//  Copyright (c) 2014 Strange Loop. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(aNotification: NSNotification) {
        // Insert code here to initialize your application
        
        var attractor = Attractor()
        attractor.shouldResetParticles = true
        attractor.initializeCL()
    }

    func applicationWillTerminate(aNotification: NSNotification) {
        // Insert code here to tear down your application
    }


}

