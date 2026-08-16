/*
    IrisFidelity_38.fx
    ReShade 3.8 compatible

    Designed for:
      Minecraft Java + Iris
      ReShade 3.8.x

    Effects:
      - Filmic tonemapping
      - Contrast
      - Local contrast
      - Subtle bloom
      - Sharpening
      - Saturation
      - Highlight rolloff
*/

#include "ReShade.fxh"


// ============================================================
// SETTINGS
// ============================================================

uniform float Exposure <
    ui_type = "slider";
    ui_label = "Exposure";
    ui_min = -1.0;
    ui_max = 1.0;
    ui_step = 0.01;
> = 0.0;


uniform float TonemapStrength <
    ui_type = "slider";
    ui_label = "Filmic Tonemap";
    ui_min = 0.0;
    ui_max = 1.0;
    ui_step = 0.01;
> = 0.85;


uniform float Contrast <
    ui_type = "slider";
    ui_label = "Contrast";
    ui_min = 0.0;
    ui_max = 1.0;
    ui_step = 0.01;
> = 0.20;


uniform float LocalContrast <
    ui_type = "slider";
    ui_label = "Local Contrast";
    ui_min = 0.0;
    ui_max = 1.0;
    ui_step = 0.01;
> = 0.30;


uniform float Sharpen <
    ui_type = "slider";
    ui_label = "Sharpen";
    ui_min = 0.0;
    ui_max = 1.0;
    ui_step = 0.01;
> = 0.18;


uniform float BloomStrength <
    ui_type = "slider";
    ui_label = "Bloom";
    ui_min = 0.0;
    ui_max = 0.30;
    ui_step = 0.01;
> = 0.06;


uniform float Saturation <
    ui_type = "slider";
    ui_label = "Saturation";
    ui_min = 0.0;
    ui_max = 2.0;
    ui_step = 0.01;
> = 1.04;


// ============================================================
// SOURCE
// ============================================================

texture BackBufferTex : COLOR;

sampler BackBufferSampler
{
    Texture = BackBufferTex;
};


// ============================================================
// SAMPLING
// ============================================================

float3 GetColor(float2 uv)
{
    return tex2D(BackBufferSampler, uv).rgb;
}


// ============================================================
// FILMIC TONEMAP
// ============================================================

float3 Filmic(float3 x)
{
    float3 a = 2.51;
    float3 b = 0.03;
    float3 c = 2.43;
    float3 d = 0.59;
    float3 e = 0.14;

    return saturate(
        (x * (a * x + b)) /
        (x * (c * x + d) + e)
    );
}


// ============================================================
// BLOOM
// ============================================================

float3 GetBloom(float2 uv)
{
    float2 px = ReShade::PixelSize;

    float3 result = 0.0;

    result += GetColor(uv + px * float2(-2.0, -2.0)) * 0.05;
    result += GetColor(uv + px * float2( 0.0, -2.0)) * 0.08;
    result += GetColor(uv + px * float2( 2.0, -2.0)) * 0.05;

    result += GetColor(uv + px * float2(-2.0,  0.0)) * 0.08;
    result += GetColor(uv)                           * 0.48;
    result += GetColor(uv + px * float2( 2.0,  0.0)) * 0.08;

    result += GetColor(uv + px * float2(-2.0,  2.0)) * 0.05;
    result += GetColor(uv + px * float2( 0.0,  2.0)) * 0.08;
    result += GetColor(uv + px * float2( 2.0,  2.0)) * 0.05;

    return result;
}


// ============================================================
// MAIN PIXEL SHADER
// ============================================================

float4 IrisFidelityPS(
    float4 position : SV_Position,
    float2 uv : TEXCOORD
) : SV_Target
{
    float3 color = GetColor(uv);


    // --------------------------------------------------------
    // EXPOSURE
    // --------------------------------------------------------

    color *= pow(2.0, Exposure);


    // --------------------------------------------------------
    // FILMIC TONEMAPPING
    // --------------------------------------------------------

    float3 filmic = Filmic(color);

    color = lerp(
        color,
        filmic,
        TonemapStrength
    );


    // --------------------------------------------------------
    // CONTRAST
    // --------------------------------------------------------

    color = lerp(
        0.5,
        color,
        1.0 + Contrast
    );


    // --------------------------------------------------------
    // LOCAL CONTRAST
    // --------------------------------------------------------

    float2 px = ReShade::PixelSize;

    float3 surrounding =
        GetColor(uv + px * float2(-1.0,  0.0)) +
        GetColor(uv + px * float2( 1.0,  0.0)) +
        GetColor(uv + px * float2( 0.0, -1.0)) +
        GetColor(uv + px * float2( 0.0,  1.0));

    surrounding *= 0.25;

    float3 detail = color - surrounding;

    color += detail * LocalContrast;


    // --------------------------------------------------------
    // BLOOM
    // --------------------------------------------------------

    float3 bloom = GetBloom(uv);

    float bloomLuma =
        dot(
            bloom,
            float3(0.2126, 0.7152, 0.0722)
        );

    float bloomMask =
        smoothstep(
            0.60,
            1.0,
            bloomLuma
        );

    color +=
        bloom *
        bloomMask *
        BloomStrength;


    // --------------------------------------------------------
    // SHARPEN
    // --------------------------------------------------------

    float3 neighbors =
        GetColor(uv + px * float2(-1.0,  0.0)) +
        GetColor(uv + px * float2( 1.0,  0.0)) +
        GetColor(uv + px * float2( 0.0, -1.0)) +
        GetColor(uv + px * float2( 0.0,  1.0));

    float3 sharp =
        color * 2.0 -
        neighbors * 0.25;

    color = lerp(
        color,
        sharp,
        Sharpen
    );


    // --------------------------------------------------------
    // SATURATION
    // --------------------------------------------------------

    float luminance =
        dot(
            color,
            float3(0.2126, 0.7152, 0.0722)
        );

    color = lerp(
        luminance.xxx,
        color,
        Saturation
    );


    // --------------------------------------------------------
    // OUTPUT
    // --------------------------------------------------------

    return float4(
        saturate(color),
        1.0
    );
}


// ============================================================
// TECHNIQUE
// ============================================================

technique IrisFidelity
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = IrisFidelityPS;
    }
}
