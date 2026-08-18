/*------------------------------------------------------------------------------
    LCD Hologram Effect Shader for ReShade 3.8+
    Combines LCD subpixel grid, chromatic aberration, moving scanlines, & tint.
------------------------------------------------------------------------------*/

#include "ReShade.fxh"

namespace LCDHolo
{
    // --- UI Controls ---
    uniform float GridStrength <
        ui_type = "slider";
        ui_min = 0.0; ui_max = 1.0;
        ui_label = "LCD Grid Strength";
        ui_tooltip = "Intensity of the pixel grid overlay.";
    > = 0.40;

    uniform float PixelScale <
        ui_type = "slider";
        ui_min = 1.0; ui_max = 8.0;
        ui_label = "LCD Pixel Size";
        ui_step = 0.5;
        ui_tooltip = "Scale of the LCD pixel grid matrix.";
    > = 2.0;

    uniform float ChromaticOffset <
        ui_type = "slider";
        ui_min = 0.0; ui_max = 10.0;
        ui_label = "Chromatic Aberration";
        ui_tooltip = "Color edge separation in pixels.";
    > = 2.5;

    uniform float3 HoloColor <
        ui_type = "color";
        ui_label = "Hologram Tint Color";
    > = float3(0.15, 0.85, 1.0);

    uniform float TintAmount <
        ui_type = "slider";
        ui_min = 0.0; ui_max = 1.0;
        ui_label = "Holo Tint Intensity";
    > = 0.35;

    uniform float ScanlineSpeed <
        ui_type = "slider";
        ui_min = 0.0; ui_max = 5.0;
        ui_label = "Scanline Speed";
    > = 1.0;

    uniform float ScanlineIntensity <
        ui_type = "slider";
        ui_min = 0.0; ui_max = 0.5;
        ui_label = "Scanline Opacity";
    > = 0.12;

    uniform float Timer < source = "timer"; >;

    // --- Main Shader Pass ---
    float4 PS_LCDHolo(float4 pos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
    {
        // 1. Chromatic Aberration
        float2 shift = BUFFER_PIXEL_SIZE * ChromaticOffset;
        float r = tex2D(ReShade::BackBuffer, texcoord + float2(-shift.x, 0.0)).r;
        float g = tex2D(ReShade::BackBuffer, texcoord).g;
        float b = tex2D(ReShade::BackBuffer, texcoord + float2(shift.x, 0.0)).b;
        float3 color = float3(r, g, b);

        // 2. LCD Subpixel Grid
        float2 pixelPos = texcoord * BUFFER_SCREEN_SIZE / PixelScale;
        float2 grid = abs(frac(pixelPos - 0.5) - 0.5);
        float gridMask = smoothstep(0.0, 0.35, min(grid.x, grid.y));
        color *= lerp(1.0, gridMask, GridStrength);

        // 3. Hologram Color Tinting
        float luminance = dot(color, float3(0.299, 0.587, 0.114));
        float3 tintedColor = lerp(color, luminance * HoloColor * 1.5, TintAmount);

        // 4. Moving Hologram Scanlines
        float scanline = sin((texcoord.y * BUFFER_SCREEN_SIZE.y * 0.25) - (Timer * 0.003 * ScanlineSpeed));
        scanline = smoothstep(-0.2, 0.2, scanline);
        tintedColor -= scanline * ScanlineIntensity * luminance;

        return float4(saturate(tintedColor), 1.0);
    }

    // --- Technique Definition ---
    technique LCDHolo
    {
        pass Pass0
        {
            VertexShader = PostProcessVS;
            PixelShader = PS_LCDHolo;
        }
    }
}