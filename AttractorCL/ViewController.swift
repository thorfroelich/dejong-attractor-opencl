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
    @IBOutlet weak var sensitivitySlider: NSSlider!
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

        self.updateAttractorFromSliders()
    }

    override var representedObject: AnyObject? {
        didSet {
        // Update the view, if already loaded.
        }
    }
    
    func updateAttractorFromSliders() {
        
        let sensitivity = self.sensitivitySlider.floatValue
        self.attractor.parameterA = (self.parameterSliderA.floatValue * sensitivity)
        self.attractor.parameterB = (self.parameterSliderB.floatValue * sensitivity)
        self.attractor.parameterC = (self.parameterSliderC.floatValue * sensitivity)
        self.attractor.parameterD = (self.parameterSliderD.floatValue * sensitivity)
        
        self.attractor.initializeCL()
        
        for i in 0...100 {
            self.attractor.updateParticles()
        }
        
        self.attractor.imageFromBuffer { (image: NSImage) -> Void in
            println("Setting image")
            self.imageView.image = image
        }
    }

    @IBAction func updateButtonPressed(sender: AnyObject) {
        self.updateAttractorFromSliders()
    }

}

