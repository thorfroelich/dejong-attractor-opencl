//
//  AttractorCL.swift
//  De Jong Attractor
//
//  Created by Thor Frølich on 24/12/14.
//  Copyright (c) 2014 Strange Loop. All rights reserved.
//

import Foundation
import OpenCL

func randomFloat() -> Float {
    return Float(arc4random()) /  Float(UInt32.max)
}

var numParticles: Int = (1024 * 1024 * 4)
var sensitivity: Float = 1.4
var N: Int = (4096 * 2)
var fN: Float = Float(N)

class Attractor {
    
    struct Particle {
        var x: Float
        var y: Float
        var z: Float
    }
    
    var parameterA: Float = 2.4 * sensitivity
    var parameterB: Float = -2.3 * sensitivity
    var parameterC: Float = 2.1 * sensitivity
    var parameterD: Float = -2.1 * sensitivity
    
    //    var histogram = [cl_int](count: (N * N), repeatedValue: 0)
    //    var colors = [cl_float](count: (N * N), repeatedValue: 0.0)
    //
    //    var parametersPointer: COpaquePointer?
    //    var particlesPointer: COpaquePointer?
    //    var histogramBuffer: UnsafeMutablePointer<Void>?
    //    var histogramPointer: COpaquePointer?
    //    var colorsPointer: COpaquePointer?
    //    var colorsBuffer: UnsafeMutablePointer<Void>?
    
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
        //        let sharegroup = CGLGetShareGroup(cgl_context)
        //        gcl_gl_set_sharegroup(unsafeBitCast(sharegroup, UnsafeMutablePointer<Void>.self))
        
        dispatch_sync(self.queue) {
            
            var particles = [Particle]()
            for i in 0...numParticles {
                let p = Particle(x: (randomFloat() * fN), y: (randomFloat() * fN), z: (randomFloat() * fN))
                particles.append(p)
            }
            
            var particlesBuffer = gcl_malloc(UInt(sizeof(Particle) * numParticles), &particles, cl_malloc_flags(CL_MEM_READ_WRITE|CL_MEM_COPY_HOST_PTR))
            var particlesPointer = COpaquePointer(particlesBuffer)
            gcl_memcpy(particlesBuffer, particles, UInt(sizeof(cl_float) * 3 * numParticles))
            
            var histogram = [cl_int](count: (N * N), repeatedValue: 0)
            var histogramBuffer = gcl_malloc(UInt(sizeof(cl_int) * N * N), &histogram, cl_malloc_flags(CL_MEM_READ_WRITE|CL_MEM_COPY_HOST_PTR))
            var histogramPointer = COpaquePointer(histogramBuffer)
            gcl_memcpy(histogramBuffer, histogram, UInt(sizeof(cl_int) * N * N))
            
            var colors = [cl_float](count: (N * N), repeatedValue: 0.0)
            var colorsBuffer = gcl_malloc(UInt(sizeof(cl_float) * N * N), &colors, cl_malloc_flags(CL_MEM_READ_WRITE|CL_MEM_COPY_HOST_PTR))
            var colorsPointer = COpaquePointer(colorsBuffer)
            gcl_memcpy(colorsBuffer, colors, UInt(sizeof(cl_float) * N * N))
            
            
            var parameters = [cl_float](count: 8, repeatedValue: 0.0)
            parameters[0] = self.parameterA * sensitivity
            parameters[1] = self.parameterB * sensitivity
            parameters[2] = self.parameterC * sensitivity
            parameters[3] = self.parameterD * sensitivity
            parameters[4] = fN
            var parametersBuffer = gcl_malloc(UInt(sizeof(cl_float) * 8), &parameters, cl_malloc_flags(CL_MEM_READ_WRITE|CL_MEM_COPY_HOST_PTR))
            var parametersPointer = COpaquePointer(parametersBuffer)
            gcl_memcpy(parametersBuffer, parameters, UInt(sizeof(cl_float) * 8))
            
            var ndRange = cl_ndrange(
                work_dim: 1,
                global_work_offset: (0, 0, 0),
                global_work_size: (UInt(numParticles), 0, 0),
                local_work_size: (0, 0, 0)
            )
            
            var rangePointer = withUnsafePointer(&ndRange, { (p: UnsafePointer<cl_ndrange>) -> UnsafePointer<cl_ndrange> in
                return p
            })
            
            for i in 0...10 {
                attractor_kernel(rangePointer, parametersPointer, particlesPointer, UnsafeMutablePointer<cl_int>(histogramPointer), UnsafeMutablePointer<cl_float>(colorsPointer))
            }
            
            var histogramResult = [cl_int](count: (N * N), repeatedValue: 0)
            var colorResult = [cl_float](count: (N * N), repeatedValue: 0)
            
            gcl_memcpy(&histogramResult, histogramBuffer, UInt(sizeof(cl_int) * N * N))
            gcl_memcpy(&colorResult, colorsBuffer, UInt(sizeof(cl_float) * N * N))
            
            var maxDensity = 0
            for i in 0...((N * N) - 1) {
                let density = Int(histogramResult[i])
                if density > maxDensity {
                    maxDensity = density
                }
            }
            println("Max density: \(maxDensity)")
        }
    }
    
}