/*
    ColorHelper.fx for ReShade 3.0+
    Quantizes color channels across an expanded bit depth range (0.1 to 16.0 bits).
*/

#include "ReShade.fxh"

namespace ColorHelper
{
    // ==========================================
    // UI Controls
    // ==========================================

    uniform float BitDepth <
        ui_type = "slider";
        ui_min = 0.1; ui_max = 16.0;
        ui_step = 0.1;
        ui_label = "Bit Depth Per Channel";
        ui_tooltip = "0.1–0.9 = Extreme binary thresholding\n1.0 = 8 total colors\n2.0 = 64 total colors\n8.0 = Standard 24-bit RGB (16.7M colors)\n16.0 = Ultra-high precision";
    > = 4.0;

    uniform bool EnableDither <
        ui_type = "bool";
        ui_label = "Enable Dithering";
        ui_tooltip = "Applies 4x4 Bayer dithering to blend transitions between quantized color steps.";
    > = false;

    uniform float DitherAmount <
        ui_type = "slider";
        ui_min = 0.0; ui_max = 1.0;
        ui_step = 0.01;
        ui_label = "Dither Intensity";
    > = 0.5;

    // ==========================================
    // Helper Functions
    // ==========================================

    float GetBayerDither(float2 pos)
    {
        const float bayerMatrix[16] = {
             0.0 / 16.0,  8.0 / 16.0,  2.0 / 16.0, 10.0 / 16.0,
            12.0 / 16.0,  4.0 / 16.0, 14.0 / 16.0,  6.0 / 16.0,
             3.0 / 16.0, 11.0 / 16.0,  1.0 / 16.0,  9.0 / 16.0,
            15.0 / 16.0,  7.0 / 16.0, 13.0 / 16.0,  5.0 / 16.0
        };

        int x = int(pos.x) % 4;
        int y = int(pos.y) % 4;
        
        return bayerMatrix[y * 4 + x] - 0.5;
    }

    // ==========================================
    // Pixel Shader
    // ==========================================

    float4 PS_ColorQuantize(float4 pos : SV_POSITION, float2 texcoord : TEXCOORD) : SV_TARGET
    {
        float4 color = tex2D(ReShade::BackBuffer, texcoord);

        // Calculate discrete color levels per channel
        float levels = max(1.0, pow(2.0, BitDepth) - 1.0);

        if (EnableDither)
        {
            float dither = GetBayerDither(pos.xy) * (DitherAmount / levels);
            color.rgb += dither;
        }

        color.rgb = saturate(color.rgb);
        color.rgb = round(color.rgb * levels) / levels;

        return color;
    }

    // ==========================================
    // Technique Definition
    // ==========================================

    technique ColorHelper
    {
        pass QuantizePass
        {
            VertexShader = PostProcessVS;
            PixelShader = PS_ColorQuantize;
        }
    }
}