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
var sensitivity: Float = 0.003
var N: Int = 1000
var fN: Float = Float(N)

class Attractor {
    
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
            
            // Only create and upload particles to GPU if needed
            if (self.shouldResetParticles == true) {
                
                self.shouldResetParticles = false
                
                var particles = [Particle]()
                while (particles.count < numParticles) {
                    particles += Particle(
                        x: (Float)(arc4random_uniform(200) - 100) / 100.0,
                        y: (Float)(arc4random_uniform(200) - 100) / 100.0,
                        z: (Float)(arc4random_uniform(200) - 100) / 100.0)
                }
                
                var particlesBuffer = gcl_malloc(UInt(sizeof(Particle) * numParticles), &particles, cl_malloc_flags(CL_MEM_READ_WRITE|CL_MEM_COPY_HOST_PTR))
                self.particlesPointer = COpaquePointer(particlesBuffer)
                
                self.histogram = [Int](count: (N * N), repeatedValue: 0)
                self.histogramBuffer = gcl_malloc(UInt(sizeof(cl_int) * N * N), &self.histogram, cl_malloc_flags(CL_MEM_READ_WRITE|CL_MEM_COPY_HOST_PTR))
                self.histogramPointer = COpaquePointer(self.histogramBuffer!)
                
                self.colors = [Float](count: (N * N), repeatedValue: 0.0)
                self.colorsBuffer = gcl_malloc(UInt(sizeof(cl_int) * N * N), &self.colors, cl_malloc_flags(CL_MEM_READ_WRITE|CL_MEM_COPY_HOST_PTR))
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
            
            var rangePointer = withUnsafePointer(&ndRange, { (p: UnsafePointer<cl_ndrange>) -> UnsafePointer<cl_ndrange> in
                return p
            })
            
            attractor_kernel(rangePointer, self.parametersPointer!, self.particlesPointer!, UnsafeMutablePointer<cl_int>(self.histogramPointer!), UnsafeMutablePointer<cl_float>(self.colorsPointer!))
            
            gcl_memcpy(&self.histogramBuffer, UnsafePointer(self.histogramPointer!), UInt(sizeof(Int) * N * N))
            gcl_memcpy(&self.colorsBuffer, UnsafePointer(self.colorsPointer!), UInt(sizeof(Float) * N * N))
            
            println("LOL!")
        }
    }
    
}