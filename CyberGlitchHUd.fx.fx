/*------------------------------------------------------------------------------
    CyberGlitchHUD.fx - Advanced Cyberpunk HUD & Channel Processing
    Designed for un-shaded gameplay to create a sci-fi optical overlay.
------------------------------------------------------------------------------*/

#include "ReShade.fxh"

// =============================================================================
// UI PARAMETERS
// =============================================================================

// --- 1. Channel Separation & Fringing ---
uniform float2 RedOffset <
    ui_category = "1. RGB Channel Offsets";
    ui_label = "Red Channel Shift";
    ui_type = "slider"; ui_min = -0.05; ui_max = 0.05; ui_step = 0.001;
> = float2(0.004, 0.002);

uniform float2 GreenOffset <
    ui_category = "1. RGB Channel Offsets";
    ui_label = "Green Channel Shift";
    ui_type = "slider"; ui_min = -0.05; ui_max = 0.05; ui_step = 0.001;
> = float2(0.0, 0.0);

uniform float2 BlueOffset <
    ui_category = "1. RGB Channel Offsets";
    ui_label = "Blue Channel Shift";
    ui_type = "slider"; ui_min = -0.05; ui_max = 0.05; ui_step = 0.001;
> = float2(-0.004, -0.002);

// --- 2. Smart Blue Color Magic ---
uniform bool EnableBlueIsolation <
    ui_category = "2. Smart Color Magic";
    ui_label = "Isolate Vehicle Yellow / Convert Shadows to Cyan-Blue";
> = true;

uniform float BlueBoost <
    ui_category = "2. Smart Color Magic";
    ui_label = "Cyan/Blue Tint Strength";
    ui_type = "slider"; ui_min = 0.0; ui_max = 2.0; ui_step = 0.05;
> = 1.25;

uniform float3 ShadowBlueTint <
    ui_category = "2. Smart Color Magic";
    ui_label = "Shadow Blue Tone";
    ui_type = "color";
> = float3(0.0, 0.4, 0.9);

uniform float3 HighlightGreenTint <
    ui_category = "2. Smart Color Magic";
    ui_label = "Highlight Tone";
    ui_type = "color";
> = float3(0.8, 1.0, 0.2);

// --- 3. Lens & Edge Effects ---
uniform float LensDistortion <
    ui_category = "3. HUD Optics & Scanlines";
    ui_label = "Spherize / Lens Curve";
    ui_type = "slider"; ui_min = -0.3; ui_max = 0.3; ui_step = 0.01;
> = 0.12;

uniform float VignetteStrength <
    ui_category = "3. HUD Optics & Scanlines";
    ui_label = "Vignette Darkness";
    ui_type = "slider"; ui_min = 0.0; ui_max = 1.0; ui_step = 0.05;
> = 0.6;

uniform float ScanlineIntensity <
    ui_category = "3. HUD Optics & Scanlines";
    ui_label = "Scanline Density/Strength";
    ui_type = "slider"; ui_min = 0.0; ui_max = 1.0; ui_step = 0.05;
> = 0.35;

uniform float EdgeEnhance <
    ui_category = "3. HUD Optics & Scanlines";
    ui_label = "HUD Edge Glow";
    ui_type = "slider"; ui_min = 0.0; ui_max = 3.0; ui_step = 0.1;
> = 1.5;

// =============================================================================
// HELPER FUNCTIONS
// =============================================================================

// Radial Lens Distortion (Fisheye HUD curvature)
float2 DistortUV(float2 uv, float dist)
{
    float2 cc = uv - 0.5;
    float r2 = dot(cc, cc);
    return uv + cc * (r2 * dist);
}

// Luminance extraction
float GetLuma(float3 color)
{
    return dot(color, float3(0.2126, 0.7152, 0.0722));
}

// =============================================================================
// PIXEL SHADER
// =============================================================================

float4 PS_CyberGlitchHUD(float4 pos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
    // 1. Apply Curved Optics to UVs
    float2 uv = DistortUV(texcoord, LensDistortion);

    // Out-of-bounds check for curved lens
    if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0)
        return float4(0.0, 0.0, 0.0, 1.0);

    // 2. Separate RGB Channels spatially
    float r = tex2D(ReShade::BackBuffer, uv + RedOffset).r;
    float g = tex2D(ReShade::BackBuffer, uv + GreenOffset).g;
    float b = tex2D(ReShade::BackBuffer, uv + BlueOffset).b;

    float3 color = float3(r, g, b);

    // 3. Smart Color Functions (Split Toning & Blue Shadow Remapping)
    if (EnableBlueIsolation)
    {
        float luma = GetLuma(color);

        // Calculate how "yellow" a pixel is (High Red + High Green, Low Blue)
        float yellowMask = saturate((r * g) - b);

        // Inject vibrant cyan/blue into midtones and shadows
        float3 blueMapped = lerp(ShadowBlueTint * BlueBoost, HighlightGreenTint, luma);

        // Blend: Keep original bright yellow areas intact, remap the rest to blue/cyan HUD tones
        color = lerp(blueMapped, color, yellowMask * 0.85);
    }

    // 4. Procedural Edge Outline Glow (Sobel-like high-pass filter)
    float2 texel = BUFFER_PIXEL_SIZE;
    float3 center = color;
    float3 left   = tex2D(ReShade::BackBuffer, uv - float2(texel.x, 0.0)).rgb;
    float3 right  = tex2D(ReShade::BackBuffer, uv + float2(texel.x, 0.0)).rgb;
    float3 top    = tex2D(ReShade::BackBuffer, uv - float2(0.0, texel.y)).rgb;
    float3 bottom = tex2D(ReShade::BackBuffer, uv + float2(0.0, texel.y)).rgb;

    float3 edge = abs(center - left) + abs(center - right) + abs(center - top) + abs(center - bottom);
    float edgeLuma = GetLuma(edge);

    // Add high-tech cyan edge highlights
    color += edgeLuma * EdgeEnhance * float3(0.0, 0.8, 1.0);

    // 5. CRT Scanline Overlay
    float scanline = sin(uv.y * BUFFER_HEIGHT * 1.5) * 0.5 + 0.5;
    color *= 1.0 - (scanline * ScanlineIntensity * 0.5);

    // 6. Radial Vignette
    float2 vignetteUV = uv * (1.0 - uv.yx);
    float vig = vignetteUV.x * vignetteUV.y * 15.0;
    vig = saturate(pow(vig, VignetteStrength));
    color *= vig;

    return float4(saturate(color), 1.0);
}

// =============================================================================
// TECHNIQUE DEFINITION
// =============================================================================

technique CyberGlitchHUD
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader  = PS_CyberGlitchHUD;
    }
}