//
//  AttractorCL.swift
//  De Jong Attractor
//
//  Created by Thor Frølich on 24/12/14.
//  Copyright (c) 2014 Strange Loop. All rights reserved.
//

import Cocoa
import OpenCL

var numParticles: Int = 8192
var N: Int = 4096
var fN: Float = Float(N)

func randomFloat() -> Float {
    return Float(arc4random()) /  Float(UInt32.max)
}

class Attractor {
    
    struct Particle {
        var x: Float
        var y: Float
        var z: Float
    }
    
    var parameterA: Float = 0.0
    var parameterB: Float = 0.0
    var parameterC: Float = 0.0
    var parameterD: Float = 0.0
    
    var parametersPointer: COpaquePointer?
    var particlesPointer: COpaquePointer?
    var histogramBuffer: UnsafeMutablePointer<Void>?
    var histogramPointer: COpaquePointer?
    var maxDensityBuffer: UnsafeMutablePointer<Void>?
    var maxDensityPointer: COpaquePointer?
    var colorsPointer: COpaquePointer?
    var colorsBuffer: UnsafeMutablePointer<Void>?
    
    var gclDeallocHandler: () -> () = {}
    
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
            
            // Create histogram buffer and pointer
            var maxDensity = [cl_uint](count: 1, repeatedValue: cl_uint(0))
            self.maxDensityBuffer = gcl_malloc(UInt(sizeof(cl_uint)), &maxDensity, cl_malloc_flags(CL_MEM_READ_ONLY|CL_MEM_COPY_HOST_PTR))
            self.maxDensityPointer = COpaquePointer(self.maxDensityBuffer!)

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
                gcl_free(self.maxDensityBuffer!)
                self.maxDensityBuffer = nil
                gcl_free(self.colorsBuffer!)
                self.colorsBuffer = nil
                gcl_free(parametersBuffer)
            }
        }
    }
    
    func updateParticles(iterations: Int) {
        
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
            
            for i in 0..<(iterations) {
                attractor_kernel(rangePointer, self.parametersPointer!, self.particlesPointer!, UnsafeMutablePointer<cl_uint>(self.histogramPointer!), UnsafeMutablePointer<cl_uint>(self.maxDensityPointer!), UnsafeMutablePointer<cl_float>(self.colorsPointer!))
            }
        })
    }
    
    func imageFromBuffer(completionHandler: ((NSImage) -> Void)!) {
        
        var format = cl_image_format(image_channel_order: cl_uint(CL_RGBA), image_channel_data_type: cl_uint(CL_UNSIGNED_INT8))
        var output_image = gcl_create_image(&format, UInt(N), UInt(N), 0, nil)
        
        dispatch_sync(self.queue, { () -> Void in
            
            var ndRange = cl_ndrange(
                work_dim: 2,
                global_work_offset: (0, 0, 0),
                global_work_size: (UInt(N), UInt(N), 0),
                local_work_size: (0, 0, 0)
            )
            var rangePointer = withUnsafePointer(&ndRange, { (p: UnsafePointer<cl_ndrange>) -> UnsafePointer<cl_ndrange> in
                return p
            })
            
            histogram_render_kernel(
                rangePointer,
                UnsafeMutablePointer<cl_uint>(self.histogramPointer!),
                UnsafeMutablePointer<cl_float>(self.colorsPointer!),
                UnsafeMutablePointer<cl_uint>(self.maxDensityPointer!),
                cl_uint(N),
                output_image)
            
            var pixels = UnsafeMutablePointer<UInt8>.alloc(N * N * 4)
            var origin = [UInt(0), UInt(0), UInt(0)]
            var region = [UInt(N), UInt(N), UInt(1)]
            
            gcl_copy_image_to_ptr(pixels, output_image, &origin, &region)
            
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), { () -> Void in
                
                var imageRep = Attractor.createNewImageRep(&pixels)
                var image = NSImage(size: imageRep.size)
                image.addRepresentation(imageRep)
                
                dispatch_async(dispatch_get_main_queue(), { () -> Void in
                    completionHandler(image)
                })
            })
        })
    }
    
    class func createNewImageRep(planes: UnsafeMutablePointer<UnsafeMutablePointer<UInt8>>) -> NSBitmapImageRep {
        
        var rep = NSBitmapImageRep(bitmapDataPlanes: planes,
            pixelsWide: N,
            pixelsHigh: N,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: NSDeviceRGBColorSpace,
            bytesPerRow: 4 * N,
            bitsPerPixel: 32)
        
        return rep!
    }
}