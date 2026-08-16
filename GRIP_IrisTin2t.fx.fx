/*
    GRIP Combat Racing - Iris Tint / Contrast
    Yellow-Green cinematic racing look
    Full default preset included
*/

#include "ReShade.fxh"

// ============================================================
// SETTINGS
// ============================================================

uniform float TintStrength <
    ui_type = "slider";
    ui_label = "Yellow-Green Tint";
    ui_min = 0.0;
    ui_max = 1.0;
    ui_step = 0.01;
> = 0.18;

uniform float Contrast <
    ui_type = "slider";
    ui_label = "Contrast";
    ui_min = 0.50;
    ui_max = 2.00;
    ui_step = 0.01;
> = 1.14;

uniform float Saturation <
    ui_type = "slider";
    ui_label = "Saturation";
    ui_min = 0.50;
    ui_max = 1.50;
    ui_step = 0.01;
> = 1.08;

uniform float GreenBias <
    ui_type = "slider";
    ui_label = "Green Bias";
    ui_min = -0.20;
    ui_max = 0.30;
    ui_step = 0.01;
> = 0.05;

uniform float LineStrength <
    ui_type = "slider";
    ui_label = "Fine Line Effect";
    ui_min = 0.0;
    ui_max = 0.15;
    ui_step = 0.005;
> = 0.025;

uniform float LineScale <
    ui_type = "slider";
    ui_label = "Line Density";
    ui_min = 100.0;
    ui_max = 1200.0;
    ui_step = 10.0;
> = 600.0;


// ============================================================
// CONTRAST
// ============================================================

float3 ApplyContrast(float3 color, float contrast)
{
    return saturate(
        (color - 0.5) * contrast + 0.5
    );
}


// ============================================================
// MAIN SHADER
// ============================================================

float4 PS_IrisTint(
    float4 position : SV_Position,
    float2 uv : TEXCOORD
) : SV_Target
{
    float4 source = tex2D(
        ReShade::BackBuffer,
        uv
    );

    float3 color = source.rgb;


    // --------------------------------------------------------
    // LUMINANCE
    // --------------------------------------------------------

    float luminance = dot(
        color,
        float3(
            0.2126,
            0.7152,
            0.0722
        )
    );


    // --------------------------------------------------------
    // YELLOW-GREEN IRIS COLOR
    // --------------------------------------------------------

    float3 irisColor = float3(
        0.72,
        0.90,
        0.20
    );

    // Keep the effect away from deep blacks.
    float tintMask = smoothstep(
        0.15,
        0.85,
        luminance
    );

    color = lerp(
        color,
        color * irisColor * 1.35,
        TintStrength * tintMask
    );


    // --------------------------------------------------------
    // GREEN BIAS
    // --------------------------------------------------------

    color.g += GreenBias * tintMask;


    // --------------------------------------------------------
    // SATURATION
    // --------------------------------------------------------

    float gray = dot(
        color,
        float3(
            0.2126,
            0.7152,
            0.0722
        )
    );

    color = lerp(
        float3(gray, gray, gray),
        color,
        Saturation
    );


    // --------------------------------------------------------
    // CONTRAST
    // --------------------------------------------------------

    color = ApplyContrast(
        color,
        Contrast
    );


    // --------------------------------------------------------
    // FINE HORIZONTAL LINE STRUCTURE
    // --------------------------------------------------------

    float lines = sin(
        uv.y *
        LineScale *
        6.2831853
    );

    float lineEffect =
        lines * LineStrength;

    color -= lineEffect;


    // --------------------------------------------------------
    // OUTPUT
    // --------------------------------------------------------

    return float4(
        saturate(color),
        source.a
    );
}


// ============================================================
// TECHNIQUE
// ============================================================

technique GRIP_IrisTint
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = PS_IrisTint;
    }
}
