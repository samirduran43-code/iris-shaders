/*
    ============================================================================
    Channel Separator Showcase Shader (Standalone Single-File Version)
    Compatible with ReShade 3.x, 4.x, 5.x, and 6.x
    ============================================================================
*/

#include "ReShade.fxh"

// =============================================================================
// COLOR CHANNEL SEPARATOR FUNCTIONS
// =============================================================================

// Isolate a single RGB channel (Red, Green, or Blue)
float3 SeparateRGBChannel(float3 color, int channelIndex, bool asGrayscale)
{
    float val = color[clamp(channelIndex, 0, 2)];
    return asGrayscale ? float3(val, val, val) : float3(channelIndex == 0 ? val : 0.0,
                                                       channelIndex == 1 ? val : 0.0,
                                                       channelIndex == 2 ? val : 0.0);
}

// Extract individual RGB channels into a struct
struct RGBChannels
{
    float3 Red;
    float3 Green;
    float3 Blue;
};

RGBChannels GetRGBChannels(float3 color, bool asGrayscale)
{
    RGBChannels channels;
    channels.Red   = SeparateRGBChannel(color, 0, asGrayscale);
    channels.Green = SeparateRGBChannel(color, 1, asGrayscale);
    channels.Blue  = SeparateRGBChannel(color, 2, asGrayscale);
    return channels;
}

struct CMYKChannels
{
    float Cyan;
    float Magenta;
    float Yellow;
    float KeyBlack;
};

// Convert RGB (0.0 - 1.0) to CMYK (0.0 - 1.0)
CMYKChannels SeparateCMYK(float3 color)
{
    CMYKChannels cmyk;
    cmyk.KeyBlack = 1.0 - max(max(color.r, color.g), color.b);
    
    if (cmyk.KeyBlack >= 1.0)
    {
        cmyk.Cyan    = 0.0;
        cmyk.Magenta = 0.0;
        cmyk.Yellow  = 0.0;
    }
    else
    {
        float invK = 1.0 - cmyk.KeyBlack;
        cmyk.Cyan    = (1.0 - color.r - cmyk.KeyBlack) / invK;
        cmyk.Magenta = (1.0 - color.g - cmyk.KeyBlack) / invK;
        cmyk.Yellow  = (1.0 - color.b - cmyk.KeyBlack) / invK;
    }
    
    return cmyk;
}

// Reconstruct RGB from CMYK channels
float3 CMYKToRGB(CMYKChannels cmyk)
{
    float invK = 1.0 - cmyk.KeyBlack;
    return float3(
        (1.0 - cmyk.Cyan) * invK,
        (1.0 - cmyk.Magenta) * invK,
        (1.0 - cmyk.Yellow) * invK
    );
}

// Returns Hue (0-1), Saturation (0-1), Value (0-1)
float3 SeparateHSV(float3 color)
{
    float4 K = float4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    float4 p = lerp(float4(color.bg, K.wz), float4(color.gb, K.xy), step(color.b, color.g));
    float4 q = lerp(float4(p.xyw, color.r), float4(color.r, p.yzx), step(p.x, color.r));

    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10;
    return float3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

// Returns Hue (0-1), Saturation (0-1), Lightness (0-1)
float3 SeparateHSL(float3 color)
{
    float maxVal = max(max(color.r, color.g), color.b);
    float minVal = min(min(color.r, color.g), color.b);
    float lightness = (maxVal + minVal) * 0.5;
    
    if (maxVal == minVal)
    {
        return float3(0.0, 0.0, lightness);
    }

    float delta = maxVal - minVal;
    float saturation = lightness > 0.5 ? delta / (2.0 - maxVal - minVal) : delta / (maxVal + minVal);
    
    float hue;
    if (maxVal == color.r)
        hue = (color.g - color.b) / delta + (color.g < color.b ? 6.0 : 0.0);
    else if (maxVal == color.g)
        hue = (color.b - color.r) / delta + 2.0;
    else
        hue = (color.r - color.g) / delta + 4.0;

    hue /= 6.0;
    return float3(hue, saturation, lightness);
}

// Samples color texture with spatial offset per channel
float3 SampleSeparatedChannels(sampler2D texSampler, float2 texcoord, float2 offset)
{
    float red   = tex2D(texSampler, texcoord + offset).r;
    float green = tex2D(texSampler, texcoord).g;
    float blue  = tex2D(texSampler, texcoord - offset).b;
    return float3(red, green, blue);
}

// =============================================================================
// UI CONTROLS
// =============================================================================

uniform int Mode <
    ui_type = "combo";
    ui_label = "Effect Mode";
    ui_items = "1. Channel Isolator\0"
               "2. RGB Chromatic Aberration\0"
               "3. CMYK Halftone Print Effect\0"
               "4. HSV Quantize & Boost\0"
               "5. Channel Swap / Re-mapping\0";
    ui_category = "Mode Selection";
> = 0;

uniform int SelectedChannel <
    ui_type = "combo";
    ui_label = "Isolate Channel";
    ui_items = "RGB - Red\0RGB - Green\0RGB - Blue\0"
               "CMYK - Cyan\0CMYK - Magenta\0CMYK - Yellow\0CMYK - Key (Black)\0"
               "HSV - Hue\0HSV - Saturation\0HSV - Value\0"
               "HSL - Lightness\0";
    ui_category = "Mode 1: Channel Isolator";
> = 0;

uniform bool AsGrayscale <
    ui_label = "View RGB as Grayscale";
    ui_category = "Mode 1: Channel Isolator";
> = true;

uniform float2 OffsetAmount <
    ui_type = "drag";
    ui_label = "RGB Shift Offset";
    ui_min = -0.05; ui_max = 0.05;
    ui_step = 0.001;
    ui_category = "Mode 2: RGB Chromatic Aberration";
> = float2(0.005, 0.002);

uniform float DotScale <
    ui_type = "drag";
    ui_label = "Halftone Screen Scale";
    ui_min = 10.0; ui_max = 500.0;
    ui_step = 1.0;
    ui_category = "Mode 3: CMYK Halftone Print";
> = 150.0;

uniform float HalftoneStrength <
    ui_type = "drag";
    ui_label = "Halftone Intensity";
    ui_min = 0.0; ui_max = 1.0;
    ui_category = "Mode 3: CMYK Halftone Print";
> = 0.8;

uniform int HueSteps <
    ui_type = "slider";
    ui_label = "Hue Quantization Levels";
    ui_min = 2; ui_max = 32;
    ui_category = "Mode 4: HSV Quantize & Boost";
> = 8;

uniform float SaturationBoost <
    ui_type = "drag";
    ui_label = "Saturation Multiplier";
    ui_min = 0.0; ui_max = 3.0;
    ui_category = "Mode 4: HSV Quantize & Boost";
> = 1.2;

uniform int RedOutputMap <
    ui_type = "combo";
    ui_label = "Output Red From";
    ui_items = "Red\0Green\0Blue\0";
    ui_category = "Mode 5: Channel Swap";
> = 1;

uniform int GreenOutputMap <
    ui_type = "combo";
    ui_label = "Output Green From";
    ui_items = "Red\0Green\0Blue\0";
    ui_category = "Mode 5: Channel Swap";
> = 0;

uniform int BlueOutputMap <
    ui_type = "combo";
    ui_label = "Output Blue From";
    ui_items = "Red\0Green\0Blue\0";
    ui_category = "Mode 5: Channel Swap";
> = 2;

// =============================================================================
// HELPER FUNCTIONS & PIXEL SHADER
// =============================================================================

float RotateAndDot(float2 uv, float angle, float scale)
{
    float rad = angle * 0.0174532925;
    float2 s = float2(sin(rad), cos(rad));
    uv = float2(uv.x * s.y - uv.y * s.x, uv.x * s.x + uv.y * s.y);
    float2 p = frac(uv * scale) - 0.5;
    return length(p);
}

float3 HSVToRGB(float3 hsv)
{
    float4 K = float4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    float3 p = abs(frac(hsv.xxx + K.xyz) * 6.0 - K.www);
    return hsv.z * lerp(K.xxx, clamp(p - K.xxx, 0.0, 1.0), hsv.y);
}

float4 PS_ChannelSeparatorDemo(float4 pos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
    float3 originalColor = tex2D(ReShade::BackBuffer, texcoord).rgb;
    float3 finalColor = originalColor;

    if (Mode == 0)
    {
        if (SelectedChannel <= 2)
        {
            finalColor = SeparateRGBChannel(originalColor, SelectedChannel, AsGrayscale);
        }
        else if (SelectedChannel <= 6)
        {
            CMYKChannels cmyk = SeparateCMYK(originalColor);
            float cmykVal = 0.0;
            if (SelectedChannel == 3) cmykVal = cmyk.Cyan;
            if (SelectedChannel == 4) cmykVal = cmyk.Magenta;
            if (SelectedChannel == 5) cmykVal = cmyk.Yellow;
            if (SelectedChannel == 6) cmykVal = cmyk.KeyBlack;
            finalColor = float3(cmykVal, cmykVal, cmykVal);
        }
        else if (SelectedChannel <= 9)
        {
            float3 hsv = SeparateHSV(originalColor);
            float hsvVal = hsv[SelectedChannel - 7];
            finalColor = float3(hsvVal, hsvVal, hsvVal);
        }
        else if (SelectedChannel == 10)
        {
            float3 hsl = SeparateHSL(originalColor);
            finalColor = float3(hsl.z, hsl.z, hsl.z);
        }
    }
    else if (Mode == 1)
    {
        finalColor = SampleSeparatedChannels(ReShade::BackBuffer, texcoord, OffsetAmount);
    }
    else if (Mode == 2)
    {
        CMYKChannels cmyk = SeparateCMYK(originalColor);
        float aspect = BUFFER_WIDTH / BUFFER_HEIGHT;
        float2 st = float2(texcoord.x * aspect, texcoord.y);

        float dotC = step(RotateAndDot(st, 15.0, DotScale), cmyk.Cyan);
        float dotM = step(RotateAndDot(st, 75.0, DotScale), cmyk.Magenta);
        float dotY = step(RotateAndDot(st,  0.0, DotScale), cmyk.Yellow);
        float dotK = step(RotateAndDot(st, 45.0, DotScale), cmyk.KeyBlack);

        CMYKChannels halftoneCMYK;
        halftoneCMYK.Cyan     = dotC;
        halftoneCMYK.Magenta  = dotM;
        halftoneCMYK.Yellow   = dotY;
        halftoneCMYK.KeyBlack = dotK;

        float3 halftoneRGB = CMYKToRGB(halftoneCMYK);
        finalColor = lerp(originalColor, halftoneRGB, HalftoneStrength);
    }
    else if (Mode == 3)
    {
        float3 hsv = SeparateHSV(originalColor);
        hsv.x = floor(hsv.x * HueSteps) / HueSteps;
        hsv.y = clamp(hsv.y * SaturationBoost, 0.0, 1.0);
        finalColor = HSVToRGB(hsv);
    }
    else if (Mode == 4)
    {
        RGBChannels channels = GetRGBChannels(originalColor, true);

        float r = channels.Red.r;
        if (RedOutputMap == 1) r = channels.Green.g;
        if (RedOutputMap == 2) r = channels.Blue.b;

        float g = channels.Green.g;
        if (GreenOutputMap == 0) g = channels.Red.r;
        if (GreenOutputMap == 2) g = channels.Blue.b;

        float b = channels.Blue.b;
        if (BlueOutputMap == 0) b = channels.Red.r;
        if (BlueOutputMap == 1) b = channels.Green.g;

        finalColor = float3(r, g, b);
    }

    return float4(finalColor, 1.0);
}

technique ChannelSeparatorShowcase
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader  = PS_ChannelSeparatorDemo;
    }
}