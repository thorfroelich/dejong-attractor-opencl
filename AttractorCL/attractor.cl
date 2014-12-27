kernel void attractor (
                      const __global float8 *parameters,
                      __global float3 *particles,
                      __global ulong *histogram,
                      __global float *colors
                      )
{
    float fN = parameters->s4;
    int N = (int)fN;
    
    int gid = get_global_id(0);
    float3 particle = particles[gid];
    
    // Position
    const float scaleFactor = 0.2;
    particle.x = ((sin(parameters->s0 * particle.y) - cos(parameters->s1 * particle.x)) * fN * scaleFactor) + fN/2.0;
    particle.y = ((sin(parameters->s2 * particle.x) - cos(parameters->s3 * particle.y)) * fN * scaleFactor) + fN/2.0;
    
    // Color
    float newColor = clamp((float)sin(parameters->s0 * particle.x) - sin(parameters->s4 * particle.y), (float)0.0, (float)1.0);
    float oldColor = particle.z;
    particle.z = (newColor + oldColor) / 2.0;
    
    particles[gid] = particle;
    
    // Histogram
    float2 coordinate;
    coordinate.x = particle.x;
    coordinate.y = particle.y;
    
    int x = (int)coordinate.x;
    int y = (int)coordinate.y;
    int index = y * N + x;
    
    if (index >= 0 && index < N*N)
    {
        ulong d = histogram[index];
        histogram[index] = d + 1;
        
        colors[index] = particle.z;
    }
}