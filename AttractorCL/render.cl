kernel void histogram_render(const __global uint *histogram,
                             const __global float *colors,
                             const __global uint *maxDensity,
                             unsigned int N,
                             write_only image2d_t output)
{
    size_t x = get_global_id(0);
    size_t y = get_global_id(1);
    
    uint index = (N * y) + x;
    
    float logMaxDensity = log((float)maxDensity[0]);
    
    uint density = histogram[index];
    float logDensity = log((float)density);
    float intensity = logDensity / logMaxDensity;
    
    float colorValue = colors[index];
    
    uint4 color;
    color.x = (uint)((colorValue * 0.9 + (1.0 - colorValue) * 0.6) * 255.0 * intensity);
    color.y = (uint)((colorValue * 0.2 + (1.0 - colorValue) * 0.4) * 255.0 * intensity);;
    color.z = (uint)((colorValue * 0.5 + (1.0 - colorValue) * 0.9) * 255.0 * intensity);;
    color.w = 255;
    
    write_imageui(output, (int2)(x,y), color.xyzw);
}