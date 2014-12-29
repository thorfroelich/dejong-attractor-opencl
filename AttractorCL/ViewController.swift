//
//  ViewController.swift
//  AttractorCL
//
//  Created by Thor Frølich on 25/12/14.
//  Copyright (c) 2014 Strange Loop. All rights reserved.
//

import Cocoa

class ViewController: NSViewController {

    @IBOutlet weak var imageView: NSImageView!
    @IBOutlet weak var parameterSliderA: NSSlider!
    @IBOutlet weak var parameterSliderB: NSSlider!
    @IBOutlet weak var parameterSliderC: NSSlider!
    @IBOutlet weak var parameterSliderD: NSSlider!
    
    var attractor: Attractor = {
        var a = Attractor()
        return a
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.updateAttractorSettingsFromSliders()
    }

    override var representedObject: AnyObject? {
        didSet {
        // Update the view, if already loaded.
        }
    }
    
    func updateAttractorSettingsFromSliders() {
        
        self.attractor.parameterA = self.parameterSliderA.floatValue
        self.attractor.parameterB = self.parameterSliderB.floatValue
        self.attractor.parameterC = self.parameterSliderC.floatValue
        self.attractor.parameterD = self.parameterSliderD.floatValue
        
        self.attractor.initializeCL()
        self.updateAttractorAndRender()
    }
    
    func updateAttractorAndRender() {
        
        self.attractor.updateParticles(5000)
        
        self.attractor.imageFromBuffer { (image: NSImage) -> Void in
            println("Setting image")
            self.imageView.image = image
        }
    }

    @IBAction func updateButtonPressed(sender: AnyObject) {
        self.updateAttractorSettingsFromSliders()
    }

    @IBAction func repeatButtonPressed(sender: AnyObject) {
        self.updateAttractorAndRender()
    }
}

