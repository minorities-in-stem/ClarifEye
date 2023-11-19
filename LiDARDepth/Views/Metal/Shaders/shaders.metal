/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Metal shaders that render the app's camera views.
*/

#include <metal_stdlib>

using namespace metal;


typedef struct
{
    float2 position [[attribute(0)]];
    float2 texCoord [[attribute(1)]];
} Vertex;

typedef struct
{
    float4 position [[position]];
    float2 texCoord;
} ColorInOut;



// Display a 2D texture.
vertex ColorInOut planeVertexShader(Vertex in [[stage_in]])
{
    ColorInOut out;
    out.position = float4(in.position, 0.0f, 1.0f);
    out.texCoord = in.texCoord;
    return out;
}

// Shade a 2D plane by passing through the texture inputs.
fragment float4 planeFragmentShader(ColorInOut in [[stage_in]], texture2d<float, access::sample> textureIn [[ texture(0) ]])
{
    constexpr sampler colorSampler(address::clamp_to_edge, filter::linear);
    float4 sample = textureIn.sample(colorSampler, in.texCoord);
    return sample;
}

// Convert a color value to RGB using a Jet color scheme.
static half4 getJetColorsFromNormalizedVal(half val) {
    half4 res ;
    if(val <= 0.01h)
        return half4();
    res.r = 1.5h - fabs(4.0h * val - 3.0h);
    res.g = 1.5h - fabs(4.0h * val - 2.0h);
    res.b = 1.5h - fabs(4.0h * val - 1.0h);
    res.a = 1.0h;
    res = clamp(res,0.0h,1.0h);
    return res;
}

// Shade a texture with depth values using a Jet color scheme.
//- Tag: planeFragmentShaderDepth
fragment half4 planeFragmentShaderDepth(
                                        ColorInOut in [[stage_in]],
                                        texture2d<float, access::sample> textureDepth [[ texture(0) ]],
                                        constant float &minDepth [[buffer(0)]],
                                        constant float &maxDepth [[buffer(1)]])
{
    constexpr sampler colorSampler(address::clamp_to_edge, filter::nearest);
    float val = (textureDepth.sample(colorSampler, in.texCoord).r/* - minDepth*/)/(maxDepth-minDepth);
    half4 rgbaResult = getJetColorsFromNormalizedVal(half(val));
    
    if(val < minDepth || val > maxDepth)
    {
        rgbaResult = 0 ;
    }
    return rgbaResult;
}

fragment half4 planeFragmentShaderColor(ColorInOut in [[stage_in]],
                                        texture2d<half> colorYtexture [[ texture(0) ]],
                                        texture2d<half> colorCbCrtexture [[ texture(1) ]])
{
    constexpr sampler textureSampler (mag_filter::linear,
                                      min_filter::linear);
    half y = colorYtexture.sample(textureSampler, in.texCoord).r;
    half2 uv = colorCbCrtexture.sample(textureSampler, in.texCoord).rg - half2(0.5h, 0.5h);
    // Convert YUV to RGB inline.
    half4 rgbaResult = half4(y + 1.402h * uv.y, y - 0.7141h * uv.y - 0.3441h * uv.x, y + 1.772h * uv.x, 1.0h);
    
    
    return rgbaResult;
}


fragment half4 planeFragmentShaderColorThresholdDepth(ColorInOut in [[stage_in]],
                                                      texture2d<half> colorYTexture [[ texture(0) ]],
                                                      texture2d<half> colorCbCrTexture [[ texture(1) ]],
                                                      texture2d<float> depthTexture [[ texture(2) ]],
                                                      constant float &minDepth [[buffer(0)]],
                                                      constant float &maxDepth [[buffer(1)]]
                                                      )
{
    constexpr sampler textureSampler (mag_filter::linear,
                                      min_filter::linear);
    half y = colorYTexture.sample(textureSampler, in.texCoord).r;
    half2 uv = colorCbCrTexture.sample(textureSampler, in.texCoord).rg - half2(0.5h, 0.5h);
    // Convert YUV to RGB inline.
    half4 rgbaResult = half4(y + 1.402h * uv.y, y - 0.7141h * uv.y - 0.3441h * uv.x, y + 1.772h * uv.x, 1.0h);
    float depth = depthTexture.sample(textureSampler, in.texCoord).r;
    if(depth < minDepth || depth > maxDepth)
    {
        rgbaResult = 0 ;
    }
    return rgbaResult;
}


// Shade a texture with confidence levels low, medium, and high to red, green,
// and blue, respectively.
fragment half4 planeFragmentShaderConfidence(ColorInOut in [[stage_in]], texture2d<float, access::sample> textureIn [[ texture(0) ]])
{
    constexpr sampler colorSampler(address::clamp_to_edge, filter::nearest);
    float4 s = textureIn.sample(colorSampler, in.texCoord);
    float res = round( 255.0f*(s.r) ) ;
    int resI = int(res);
    half4 color = half4(0.0h, 0.0h, 0.0h, 0.0h);
    if (resI == 0)
        color = half4(1.0h, 0.0h, 0.0h, 1.0h);
    else if (resI == 1)
        color = half4(0.0h, 1.0h, 0.0h, 1.0h);
    else if (resI == 2)
        color = half4(0.0h, 0.0h, 1.0h, 1.0h);
    return color;
}


// Convert the Y and CbCr textures into a single RGBA texture.
kernel void convertYCbCrToRGBA(texture2d<float, access::read> colorYtexture [[texture(0)]],
                               texture2d<float, access::read> colorCbCrtexture [[texture(1)]],
                               texture2d<float, access::write> colorRGBTexture [[texture(2)]],
                               uint2 gid [[thread_position_in_grid]])
{
    float y = colorYtexture.read(gid).r;
    float2 uv = colorCbCrtexture.read(gid / 2).rg;
    
    const float4x4 ycbcrToRGBTransform = float4x4(
                                                  float4(+1.0000f, +1.0000f, +1.0000f, +0.0000f),
                                                  float4(+0.0000f, -0.3441f, +1.7720f, +0.0000f),
                                                  float4(+1.4020f, -0.7141f, +0.0000f, +0.0000f),
                                                  float4(-0.7010f, +0.5291f, -0.8860f, +1.0000f)
                                                  );
    
    // Sample Y and CbCr textures to get the YCbCr color at the given texture
    // coordinate.
    float4 ycbcr = float4(y, uv.x, uv.y, 1.0f);
    
    // Return the converted RGB color.
    float4 colorSample = ycbcrToRGBTransform * ycbcr;
    colorRGBTexture.write(colorSample, uint2(gid.xy));
}
