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
var N: Int = 1024
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
    
    var gclDeallocHandler: () -> () = {}
    
    lazy var queue: dispatch_queue_t = {
        var q = gcl_create_dispatch_queue(cl_queue_flags(CL_DEVICE_TYPE_GPU), nil)
        
        if (q == nil) {
            q = gcl_create_dispatch_queue(cl_queue_flags(CL_DEVICE_TYPE_CPU), nil)
        }
        
//        var name = [CChar](count: 128, repeatedValue: 0)
//        name.reserveCapacity(128)
//        
//        var nameSize : UInt = 0
//        let gpu = gcl_get_device_id_with_dispatch_queue(q)
//        if clGetDeviceInfo(gpu, cl_device_info(CL_DEVICE_NAME), UInt(128), &name, &nameSize) == CL_SUCCESS {
//            let deviceName = String(
//            let deviceName = withUnsafePointer(&name) {
//                String.fromCString(UnsafePointer($0))!
//            }
//            println(deviceName)
//        }
        
        return q
        }()
    
    init(){}
    
    func initializeCL() {
        
        let cgl_context = CGLGetCurrentContext()
        
        dispatch_sync(self.queue) {
            
            self.gclDeallocHandler()
            
            var particles = [Particle]()
            for i in 0..<numParticles {
                let p = Particle(x: (randomFloat() * fN), y: (randomFloat() * fN), z: (randomFloat() * fN))
                particles.append(p)
            }
            
            // Create and upload particles
            var particlesBuffer = gcl_malloc(UInt(sizeof(Particle) * numParticles), &particles, cl_malloc_flags(CL_MEM_WRITE_ONLY|CL_MEM_COPY_HOST_PTR))
            self.particlesPointer = COpaquePointer(particlesBuffer)
            gcl_memcpy(particlesBuffer, particles, UInt(sizeof(cl_float) * 3 * numParticles))
            
            // Create histogram buffer and pointer
            var histogram = [cl_uint](count: (N * N), repeatedValue: cl_uint(0))
            self.histogramBuffer = gcl_malloc(UInt(sizeof(cl_uint) * N * N), &histogram, cl_malloc_flags(CL_MEM_READ_ONLY|CL_MEM_COPY_HOST_PTR))
            self.histogramPointer = COpaquePointer(self.histogramBuffer!)

            // Create color buffer and pointer
            var colors = [cl_float](count: (N * N), repeatedValue: cl_float(0.0))
            self.colorsBuffer = gcl_malloc(UInt(sizeof(cl_float) * N * N), &colors, cl_malloc_flags(CL_MEM_READ_ONLY|CL_MEM_COPY_HOST_PTR))
            self.colorsPointer = COpaquePointer(self.colorsBuffer!)
            
            // Create and upload current parameters
            var parameters = [cl_float](count: 8, repeatedValue: 0.0)
            parameters[0] = self.parameterA
            parameters[1] = self.parameterB
            parameters[2] = self.parameterC
            parameters[3] = self.parameterD
            parameters[4] = fN
            var parametersBuffer = gcl_malloc(UInt(sizeof(cl_float) * 8), &parameters, cl_malloc_flags(CL_MEM_WRITE_ONLY|CL_MEM_COPY_HOST_PTR))
            self.parametersPointer = COpaquePointer(parametersBuffer)
            gcl_memcpy(parametersBuffer, parameters, UInt(sizeof(cl_float) * 8))
            
            self.gclDeallocHandler = {
                gcl_free(particlesBuffer)
                gcl_free(self.histogramBuffer!)
                self.histogramBuffer = nil
                gcl_free(self.colorsBuffer!)
                self.colorsBuffer = nil
                gcl_free(parametersBuffer)
            }
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
            
            attractor_kernel(rangePointer, self.parametersPointer!, self.particlesPointer!, UnsafeMutablePointer<cl_uint>(self.histogramPointer!), UnsafeMutablePointer<cl_float>(self.colorsPointer!))
        })
    }
    
    func imageFromBuffer(completionHandler: ((NSImage) -> Void)!) {
        
        dispatch_async(self.queue, { () -> Void in
            
            var histogramResult = [cl_uint](count: (N * N), repeatedValue: cl_uint(0))
            var colorResult = [cl_float](count: (N * N), repeatedValue: cl_float(0.0))
            
            gcl_memcpy(&histogramResult, self.histogramBuffer!, UInt(sizeof(cl_uint) * N * N))
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
                    if density <= 0 {
                        continue
                    }
                    
                    let color = Float(colorResult[index])
                    if color.isNaN {
                        continue
                    }
                    
                    let x = index % N
                    let y = index / N
                    
                    let logDensity = logf(Float(density))
                    let intensity = logDensity / logMaxDensity
                    
                    let r = Int((color * 0.9 + (1.0 - color) * 0.6) * 255.0 * intensity)
                    let g = Int((color * 0.2 + (1.0 - color) * 0.4) * 255.0 * intensity)
                    let b = Int((color * 0.5 + (1.0 - color) * 0.9) * 255.0 * intensity)
                    let a = 255
                    var pixel: [Int] = [r, g, b, a]
                    
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
            colorSpaceName: NSDeviceRGBColorSpace,
            bytesPerRow: 4 * N,
            bitsPerPixel: 32)
        
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.setCurrentContext(NSGraphicsContext(bitmapImageRep: rep!))
        
        NSColor.blackColor().setFill()
        NSRectFill(NSRect(x: 0, y: 0, width: N, height: N))
        
        NSGraphicsContext.restoreGraphicsState()
        
        return rep!
    }
}