//
//  AttractorCL.swift
//  De Jong Attractor
//
//  Created by Thor Frølich on 24/12/14.
//  Copyright (c) 2014 Strange Loop. All rights reserved.
//

import Cocoa
import OpenCL

var numParticles: Int = (1024 * 1024 * 4)
var N: Int = 2048
var fN: Float = Float(N)

func randomFloat() -> Float {
    return Float(arc4random()) /  Float(UInt32.max)
}

func SLNormalize(value: Float, minimum: Float, maximum: Float) -> Float
{
    return (value - minimum) / (maximum - minimum);
}

// Takes a value from 0 to 1 and a range and returns the interpolated value in that range.
func SLInterpolate(normValue: Float, from: Float, to: Float) -> Float
{
    return from + (to - from) * normValue;
}

//map(value, min1, max1, min2, max2) takes a value in a given range (min1, max1) and finds the corresonding value in the next range(min2, max2).
func SLMap(value: Float, min1: Float, max1: Float, min2: Float, max2: Float) -> Float
{
    return SLInterpolate(SLNormalize(value, min1, max1), min2, max2);
}

func SLClamp(value: Float, min: Float, max: Float) -> Float {
    return value < min ? min : (value > max ? max : value)
}

class Attractor {
    
    struct Particle {
        var x: Float
        var y: Float
        var z: Float
    }
    
    struct RGBColor {
        var r: Int = 0
        var g: Int = 0
        var b: Int = 0
    }
    
    struct HSVColor {
        var h: Int = 0
        var s: Int = 0
        var v: Int = 0
    }
    
//    lazy var currentBitmapRep: NSBitmapImageRep = {
//        var rep = self.createNewImageRep()
//        return rep
//        }()
    
    var parameterA: Float = 0.0
    var parameterB: Float = 0.0
    var parameterC: Float = 0.0
    var parameterD: Float = 0.0
    
    var parametersPointer: COpaquePointer?
    var particlesPointer: COpaquePointer?
    var histogramBuffer: UnsafeMutablePointer<Void>?
    var histogramPointer: COpaquePointer?
    var colorsPointer: COpaquePointer?
    var colorsBuffer: UnsafeMutablePointer<Void>?
    
    lazy var queue: dispatch_queue_t = {
        var q = gcl_create_dispatch_queue(cl_queue_flags(CL_DEVICE_TYPE_GPU), nil)
        
        if (q == nil) {
            q = gcl_create_dispatch_queue(cl_queue_flags(CL_DEVICE_TYPE_CPU), nil)
        }
        return q
        }()
    
    init(){}
    
    func initializeCL() {
        
        let cgl_context = CGLGetCurrentContext()
        
        dispatch_sync(self.queue) {
            
            var particles = [Particle]()
            for i in 0..<numParticles {
                let p = Particle(x: (randomFloat() * fN), y: (randomFloat() * fN), z: (randomFloat() * fN))
                particles.append(p)
            }
            
            // Create and upload particles
            var particlesBuffer = gcl_malloc(UInt(sizeof(Particle) * numParticles), &particles, cl_malloc_flags(CL_MEM_READ_WRITE|CL_MEM_COPY_HOST_PTR))
            self.particlesPointer = COpaquePointer(particlesBuffer)
            gcl_memcpy(particlesBuffer, particles, UInt(sizeof(cl_float) * 3 * numParticles))
            
            // Create histogram buffer and pointer
            var histogram = [cl_ulong](count: (N * N), repeatedValue: 0)
            self.histogramBuffer = gcl_malloc(UInt(sizeof(cl_ulong) * N * N), &histogram, cl_malloc_flags(CL_MEM_READ_WRITE|CL_MEM_COPY_HOST_PTR))
            self.histogramPointer = COpaquePointer(self.histogramBuffer!)

            // Create color buffer and pointer
            var colors = [cl_float](count: (N * N), repeatedValue: 0.0)
            self.colorsBuffer = gcl_malloc(UInt(sizeof(cl_float) * N * N), &colors, cl_malloc_flags(CL_MEM_READ_WRITE|CL_MEM_COPY_HOST_PTR))
            self.colorsPointer = COpaquePointer(self.colorsBuffer!)
            
            // Create and upload current parameters
            var parameters = [cl_float](count: 8, repeatedValue: 0.0)
            parameters[0] = self.parameterA
            parameters[1] = self.parameterB
            parameters[2] = self.parameterC
            parameters[3] = self.parameterD
            parameters[4] = fN
            var parametersBuffer = gcl_malloc(UInt(sizeof(cl_float) * 8), &parameters, cl_malloc_flags(CL_MEM_READ_WRITE|CL_MEM_COPY_HOST_PTR))
            self.parametersPointer = COpaquePointer(parametersBuffer)
            gcl_memcpy(parametersBuffer, parameters, UInt(sizeof(cl_float) * 8))
        }
    }
    
    func updateParticles() {
        
        dispatch_sync(self.queue, { () -> Void in
            
            var ndRange = cl_ndrange(
                work_dim: 1,
                global_work_offset: (0, 0, 0),
                global_work_size: (UInt(numParticles), 0, 0),
                local_work_size: (0, 0, 0)
            )
            
            var rangePointer = withUnsafePointer(&ndRange, { (p: UnsafePointer<cl_ndrange>) -> UnsafePointer<cl_ndrange> in
                return p
            })
            
            attractor_kernel(rangePointer, self.parametersPointer!, self.particlesPointer!, UnsafeMutablePointer<cl_ulong>(self.histogramPointer!), UnsafeMutablePointer<cl_float>(self.colorsPointer!))
            
        })
    }
    
    func imageFromBuffer(completionHandler: ((NSImage) -> Void)!) {
        
        dispatch_async(self.queue, { () -> Void in
            
            var histogramResult = [cl_ulong](count: (N * N), repeatedValue: 0)
            var colorResult = [cl_float](count: (N * N), repeatedValue: 0)
            
            gcl_memcpy(&histogramResult, self.histogramBuffer!, UInt(sizeof(cl_ulong) * N * N))
            gcl_memcpy(&colorResult, self.colorsBuffer!, UInt(sizeof(cl_float) * N * N))
            
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), { () -> Void in
                
                let maxDensity = maxElement(histogramResult)
                println("Max density: \(maxDensity)")
                let logMaxDensity = logf(Float(maxDensity))
                
                var imageRep = self.createNewImageRep()
                NSGraphicsContext.saveGraphicsState()
                NSGraphicsContext.setCurrentContext(NSGraphicsContext(bitmapImageRep: imageRep))
                
                for index in 0..<(N * N) {
                    let density = Int(histogramResult[index])
                    let color = Float(colorResult[index])
                    
                    let x = index % N
                    let y = index / N
                    
                    let logDensity = logf(Float(density))
                    if logDensity <= 0 {
                        continue
                    }
                    
                    let hue = SLMap(color, 0.0, fN, 0.5, 1.0)
                    let saturation = SLMap(logDensity / logMaxDensity, 0.0, 1.0, 0.5, 0.0)
                    let brightness = SLClamp(logDensity / logMaxDensity, 0.0, 1.0)
                    
                    var hsv = HSVColor(h: Int(hue * 255.0), s: Int(saturation * 255.0), v: Int(brightness * 255.0))
                    var rgb = Attractor.HSBToRGB(hsv)

                    var pixel = [Int](count: 4, repeatedValue: Int(0))
                    pixel[0] = rgb.r
                    pixel[1] = rgb.g
                    pixel[2] = rgb.b
                    pixel[3] = 255

                    imageRep.setPixel(&pixel, atX: x, y: y)
                }
                
                let image = NSImage(size: NSSize(width: N, height: N))
                image.addRepresentation(imageRep)
                
                NSGraphicsContext.restoreGraphicsState()
                
//                self.currentBitmapRep = imageRep
                
                dispatch_async(dispatch_get_main_queue(), { () -> Void in
                    completionHandler(image)
                })
            })
        })
    }
    
    func createNewImageRep() -> NSBitmapImageRep {
        
        var rep = NSBitmapImageRep(bitmapDataPlanes: nil,
            pixelsWide: N,
            pixelsHigh: N,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: NSCalibratedRGBColorSpace,
            bytesPerRow: 4 * N,
            bitsPerPixel: 32)
        
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.setCurrentContext(NSGraphicsContext(bitmapImageRep: rep!))
        
        NSColor.blackColor().setFill()
        NSRectFill(NSRect(x: 0, y: 0, width: N, height: N))
        
        NSGraphicsContext.restoreGraphicsState()
        
        return rep!
    }
    
    class func HSBToRGB(hsv: HSVColor) -> RGBColor
    {
        var rgb = RGBColor(r: 0, g: 0, b: 0)
        var region: Int
        var remainder: Int
        var p: Int
        var q: Int
        var t: Int
        
        if (hsv.s == 0)
        {
            rgb.r = hsv.v
            rgb.g = hsv.v
            rgb.b = hsv.v
            return rgb
        }
        
        region = hsv.h / 43
        remainder = (hsv.h - (region * 43)) * 6
        
        p = (hsv.v * (255 - hsv.s)) >> 8
        q = (hsv.v * (255 - ((hsv.s * remainder) >> 8))) >> 8
        t = (hsv.v * (255 - ((hsv.s * (255 - remainder)) >> 8))) >> 8
        
        switch (region)
        {
        case 0:
            rgb.r = hsv.v
            rgb.g = t
            rgb.b = p;
            break;
        case 1:
            rgb.r = q
            rgb.g = hsv.v
            rgb.b = p
            break;
        case 2:
            rgb.r = p
            rgb.g = hsv.v
            rgb.b = t
            break;
        case 3:
            rgb.r = p
            rgb.g = q
            rgb.b = hsv.v
            break;
        case 4:
            rgb.r = t
            rgb.g = p
            rgb.b = hsv.v
            break;
        default:
            rgb.r = hsv.v
            rgb.g = p
            rgb.b = q
            break;
        }
        
        return rgb
    }
}