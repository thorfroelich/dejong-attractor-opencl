//
//  AttractorCL.swift
//  De Jong Attractor
//
//  Created by Thor Frølich on 24/12/14.
//  Copyright (c) 2014 Strange Loop. All rights reserved.
//

import Foundation
import OpenCL
//import GLKit

var numParticles: Int = (1024 * 1024 * 4)

class AttractorCL {

    struct Particle {
        var x: Float
        var y: Float
        var z: Float
    }
    
    struct Parameter {
        var s0: Float
        var s1: Float
        var s2: Float
        var s3: Float
        var s4: Float
    }
    
//    var programID: GLuint
//    var projectionMatrix: GLint
//    var modelMatrix: GLint
    
    var isComputingHistogram: Bool = false
    var shouldResetParticles: Bool = false
    
    var parameterA: Float = 2.4 * sensitivity
    var parameterB: Float = -2.3 * sensitivity
    var parameterC: Float = 2.1 * sensitivity
    var parameterD: Float = -2.1 * sensitivity
    
    var histogram = [Int](count: (N * N), repeatedValue: 0)
    var colors = [Float](count: (N * N), repeatedValue: 0.0)
    
    var parametersPointer: COpaquePointer?
    var particlesPointer: COpaquePointer?
    var histogramBuffer: UnsafeMutablePointer<Void>?
    var histogramPointer: COpaquePointer?
    var colorsPointer: COpaquePointer?
    var colorsBuffer: UnsafeMutablePointer<Void>?
    
    lazy var queue: dispatch_queue_t = {
        
//        self.cl_gl_semaphore = dispatch_semaphore_create(0);
        var q = gcl_create_dispatch_queue(cl_queue_flags(CL_DEVICE_TYPE_GPU), nil)
        
        if (q == nil) {
            q = gcl_create_dispatch_queue(cl_queue_flags(CL_DEVICE_TYPE_CPU), nil)
        }
        return q
    }()
    
//    var cl_gl_semaphore: dispatch_semaphore_t?
    
//    var program: cl_program
//    var kernel: cl_kernel
    
    func initCL() {
        
        let cgl_context = CGLGetCurrentContext()
        let sharegroup = CGLGetShareGroup(cgl_context)
        gcl_gl_set_sharegroup(unsafeBitCast(sharegroup, UnsafeMutablePointer<Void>.self))
        
        // Only create and upload particles to GPU if needed
        if (self.shouldResetParticles == true) {
            
            self.shouldResetParticles = false
            
            var particles: [Particle] = [Particle]()
            for index in 0...numParticles {
                var p = Particle(
                    x: (Float)(arc4random_uniform(200) - 100) / 100.0,
                    y: (Float)(arc4random_uniform(200) - 100) / 100.0,
                    z: (Float)(arc4random_uniform(200) - 100) / 100.0)
                particles.append(p)
            }
            var particlesBuffer = gcl_malloc(UInt(sizeof(Particle) * numParticles), &particles, cl_malloc_flags(CL_MEM_READ_WRITE|CL_MEM_COPY_HOST_PTR))
            self.particlesPointer = COpaquePointer(particlesBuffer)
            
            self.histogram = [Int](count: (N * N), repeatedValue: 0)
            self.histogramBuffer = gcl_malloc(UInt(sizeof(cl_int) * N * N), &histogram, cl_malloc_flags(CL_MEM_READ_WRITE|CL_MEM_COPY_HOST_PTR))
            self.histogramPointer = COpaquePointer(self.histogramBuffer!)
            
            self.colors = [Float](count: (N * N), repeatedValue: 0.0)
            self.colorsBuffer = gcl_malloc(UInt(sizeof(cl_int) * N * N), &colors, cl_malloc_flags(CL_MEM_READ_WRITE|CL_MEM_COPY_HOST_PTR))
            self.colorsPointer = COpaquePointer(self.colorsBuffer!)
            
            var parameters = Parameter(
                s0: self.parameterA * sensitivity,
                s1: self.parameterB * sensitivity,
                s2: self.parameterC * sensitivity,
                s3: self.parameterD * sensitivity,
                s4: fN)
            var parametersBuffer = gcl_malloc(UInt(sizeof(Parameter)), &parameters, cl_malloc_flags(CL_MEM_READ_WRITE|CL_MEM_COPY_HOST_PTR))
            self.parametersPointer = COpaquePointer(parametersBuffer)
        }
        
        var ndRange = cl_ndrange(
            work_dim: 1,
            global_work_offset: (0, 0, 0),
            global_work_size: (UInt(numParticles), 0, 0),
            local_work_size: (0, 0, 0)
        )
        
        withUnsafePointer(&ndRange, { (ptr: UnsafePointer<cl_ndrange>) -> Void in
            attractor_kernel(ptr, self.parametersPointer, self.particlesPointer, self.histogramPointer, self.colorsPointer)
            return
        })
        
        withUnsafePointer(&ndRange) { ndRangePointer in
            attractor_kernel(ndRangePointer, self.parametersPointer, self.particlesPointer, self.histogramPointer, self.colorsPointer)
        }
        
        gcl_memcpy(&self.histogramBuffer!, self.histogramPointer, UInt(sizeof(Int) * N * N))
        gcl_memcpy(&self.colorsBuffer!, self.colorsPointer, UInt(sizeof(Float) * N * N))
    }
    
}