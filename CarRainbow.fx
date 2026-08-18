/*
    ==================================================================
    GameEnhancer.fx - Rainbow Dynamic Car Shader for ReShade 3.8+
    Target: Isolates the blue vehicle body and radiates dynamic 
            high-speed hue cycling (rainbow animation).
    ==================================================================
*/

#include "ReShade.fxh"

// --- UI Controls ---
uniform bool EnableRainbowCar <
    ui_label = "Enable Rainbow Car Effect";
    ui_tooltip = "Isolates the vehicle's blue color channels and cycles colors dynamically.";
> = true;

uniform float CycleSpeed <
    ui_type = "slider"; ui_min = 0.5; ui_max = 20.0;
    ui_label = "Color Radiation Speed";
    ui_tooltip = "Speed of the hue shift. Higher values radiate/flicker rapidly every few milliseconds.";
> = 12.0;

uniform float TargetHue <
    ui_type = "slider"; ui_min = 0.0; ui_max = 1.0;
    ui_label = "Target Car Color Hue";
    ui_tooltip = "Base hue of the car to isolate (0.6 = Blue / Vehicle default).";
> = 0.61;

uniform float HueTolerance <
    ui_type = "slider"; ui_min = 0.01; ui_max = 0.3;
    ui_label = "Car Color Range / Mask Width";
    ui_tooltip = "Controls how strictly only the car body receives the radiating effect.";
> = 0.12;

uniform float RadiationGlow <
    ui_type = "slider"; ui_min = 0.5; ui_max = 3.0;
    ui_label = "Rainbow Saturation & Glow";
    ui_tooltip = "Intensity of the radiating vibrant colors on the vehicle.";
> = 1.8;

// --- Built-in Uniforms ---
uniform float Timer < source = "timer"; >;

// --- Color Space Helper Functions ---

// Convert RGB to HSV for keying vehicle color
float3 RGBtoHSV(float3 c)
{
    float4 K = float4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    float4 p = lerp(float4(c.bg, K.wz), float4(c.gb, K.xy), step(c.b, c.g));
    float4 q = lerp(float4(p.xyw, c.r), float4(c.r, p.yzx), step(p.x, c.r));

    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10;
    return float3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

// Convert HSV back to RGB
float3 HSVtoRGB(float3 c)
{
    float4 K = float4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    float3 p = abs(frac(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * lerp(K.xxx, saturate(p - K.xxx), c.y);
}

// --- Main Pixel Shader ---
float4 PS_RainbowCar(float4 pos : SV_Position, float2 texcoord : TexCoord) : SV_Target
{
    // 1. Sample original frame
    float3 originalColor = tex2D(ReShade::BackBuffer, texcoord).rgb;

    if (!EnableRainbowCar)
        return float4(originalColor, 1.0);

    // 2. Convert pixel to HSV space
    float3 hsv = RGBtoHSV(originalColor);

    // 3. Calculate distance from car target hue (wrapping 0.0-1.0 hue circle)
    float hueDiff = abs(hsv.x - TargetHue);
    if (hueDiff > 0.5) hueDiff = 1.0 - hueDiff;

    // 4. Create smooth mask based on vehicle hue match & saturation threshold
    float carMask = smoothstep(HueTolerance, 0.0, hueDiff) * smoothstep(0.15, 0.4, hsv.y);

    // 5. Compute rapid animated hue shift (ms radiation cycle)
    // Adding positional UV coords creates moving rainbow streaks across the vehicle chassis
    float animTime = (Timer * 0.001 * CycleSpeed) + (texcoord.x * 2.0) + (texcoord.y * 1.5);
    float newHue = frac(animTime);

    // 6. Generate vibrant radiating color
    float3 radiatedHSV = float3(newHue, saturate(hsv.y * RadiationGlow + 0.3), hsv.z * 1.1);
    float3 radiatedRGB = HSVtoRGB(radiatedHSV);

    // 7. Blend rainbow effect onto the car body only
    float3 finalColor = lerp(originalColor, radiatedRGB, carMask);

    return float4(saturate(finalColor), 1.0);
}

// --- Technique Definition ---
technique GameEnhancer
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader  = PS_RainbowCar;
    }
}