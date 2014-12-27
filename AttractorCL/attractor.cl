kernel void attractor (
                      const __global float8 *parameters,
                      __global float3 *particles,
                      __global ulong *histogram,
                      __global float *colors
                      )
{
    const float min = -2.0;
    const float max = 2.0;
    
    int n = (int)parameters->s4;
    
    int gid = get_global_id(0);
    float3 particle = particles[gid];
    
    // Position
    particle.x = sin(parameters->s0 * particle.y) - cos(parameters->s1 * particle.x);
    particle.y = sin(parameters->s2 * particle.x) - cos(parameters->s3 * particle.y);
    
    // Color
    float newColor = clamp((float)sin(parameters->s0 * particle.x) - sin(parameters->s4 * particle.y), (float)0.0, (float)1.0);
    float oldColor = particle.z;
    particle.z = (newColor + oldColor) / 2.0;
    
    particle = clamp(particle, min, max);
    
    particles[gid] = particle;
    
    // Histogram
    float2 coordinate;
    coordinate.x = ((particle.x + 2.0)/4.0) * n;
    coordinate.y = ((particle.y + 2.0)/4.0) * n;
    
    int x = (int)coordinate.x;
    int y = (int)coordinate.y;
    int index = y * n + x;
    
    if (index >= 0 && index < n*n)
    {
        ulong d = histogram[index];
        histogram[index] = d + 1;
        
        colors[index] = particle.z;
    }
}