kernel void attractor (
                      const __global float8 *parameters,
                      __global float3 *particles,
                      __global uint *histogram,
                       __global uint *maxDensity,
                      __global float *colors
                      )
{
    float fN = parameters->s4;
    int N = (int)fN;
    
    int gid = get_global_id(0);
    float3 particle = particles[gid];
    float previousX = particle.x;
    
    // Position
    float x = particle.x;
    float y = particle.y;
    float z = particle.z;
    
    particle.x = sin(parameters->s0 * y) - cos(parameters->s1 * x);
    particle.y = sin(parameters->s2 * x) - cos(parameters->s3 * y);
    particle.z = sin(0.7 * x) - cos(-1.1 * z);
    
    particles[gid] = particle;
    
    // Histogram
    float2 coordinate;
    coordinate.x = particle.x;
    coordinate.y = particle.y;
    
    const float scaleFactor = 0.2;
    int iX = (int)((coordinate.x * fN * scaleFactor) + fN/2.0);
    int iY = (int)((coordinate.y * fN * scaleFactor) + fN/2.0);
    int index = iY * N + iX;
    
    if (index >= 0 && index < N*N)
    {
        uint d = histogram[index];
        d = d + 1;
        histogram[index] = d;
        
        if (d > maxDensity[0])
        {
            maxDensity[0] = d;
        }
        
        colors[index] = particle.z;
    }
}