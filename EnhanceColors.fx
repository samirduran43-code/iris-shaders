/*
    ============================================================
    GRIP: Combat Racing - VIBRANT COLORS
    ReShade 3.8.x
    ============================================================

    Focus:
      - Stronger colors
      - More vibrant neon
      - Richer reds / blues / greens
      - Better color separation
      - Optional color controls
      - No bloom
      - No vignette
      - No sharpening

    Recommended starting point:
      Saturation       1.20
      Vibrance         0.35
      Color Boost      0.12
      Highlight Color  0.08
      Shadow Color     0.04

    ============================================================
*/

#include "ReShade.fxh"


// ============================================================
// MAIN COLOR CONTROLS
// ============================================================

uniform float Saturation
<
    ui_type = "slider";
    ui_label = "Saturation";
    ui_category = "COLOR";
    ui_min = 0.50;
    ui_max = 2.50;
    ui_step = 0.01;
>
= 1.20;


uniform float Vibrance
<
    ui_type = "slider";
    ui_label = "Vibrance";
    ui_category = "COLOR";
    ui_min = 0.00;
    ui_max = 2.00;
    ui_step = 0.01;
>
= 0.35;


uniform float ColorBoost
<
    ui_type = "slider";
    ui_label = "Color Boost";
    ui_category = "COLOR";
    ui_min = 0.00;
    ui_max = 1.00;
    ui_step = 0.01;
>
= 0.12;


// ============================================================
// COLOR CONTRAST
// ============================================================

uniform float ColorContrast
<
    ui_type = "slider";
    ui_label = "Color Contrast";
    ui_category = "COLOR CONTRAST";
    ui_min = 0.50;
    ui_max = 2.00;
    ui_step = 0.01;
>
= 1.05;


uniform float ColorDepth
<
    ui_type = "slider";
    ui_label = "Color Depth";
    ui_category = "COLOR CONTRAST";
    ui_min = 0.00;
    ui_max = 1.00;
    ui_step = 0.01;
>
= 0.15;


// ============================================================
// HIGHLIGHT / SHADOW COLOR
// ============================================================

uniform float HighlightColor
<
    ui_type = "slider";
    ui_label = "Highlight Color";
    ui_category = "COLOR TONE";
    ui_min = 0.00;
    ui_max = 1.00;
    ui_step = 0.01;
>
= 0.08;


uniform float ShadowColor
<
    ui_type = "slider";
    ui_label = "Shadow Color";
    ui_category = "COLOR TONE";
    ui_min = 0.00;
    ui_max = 1.00;
    ui_step = 0.01;
>
= 0.04;


// ============================================================
// RGB COLOR CONTROL
// ============================================================

uniform float RedBoost
<
    ui_type = "slider";
    ui_label = "Red Boost";
    ui_category = "RGB";
    ui_min = -0.30;
    ui_max = 0.50;
    ui_step = 0.01;
>
= 0.00;


uniform float GreenBoost
<
    ui_type = "slider";
    ui_label = "Green Boost";
    ui_category = "RGB";
    ui_min = -0.30;
    ui_max = 0.50;
    ui_step = 0.01;
>
= 0.00;


uniform float BlueBoost
<
    ui_type = "slider";
    ui_label = "Blue Boost";
    ui_category = "RGB";
    ui_min = -0.30;
    ui_max = 0.50;
    ui_step = 0.01;
>
= 0.00;


// ============================================================
// NEON / STRONG COLOR CONTROL
// ============================================================

uniform float NeonBoost
<
    ui_type = "slider";
    ui_label = "Neon / Strong Color Boost";
    ui_category = "VIBRANCE";
    ui_min = 0.00;
    ui_max = 2.00;
    ui_step = 0.01;
>
= 0.25;


uniform float NeonProtection
<
    ui_type = "slider";
    ui_label = "Neon Highlight Protection";
    ui_category = "VIBRANCE";
    ui_min = 0.00;
    ui_max = 1.00;
    ui_step = 0.01;
>
= 0.35;


// ============================================================
// OPTIONAL BRIGHTNESS / CONTRAST
// ============================================================

uniform float Exposure
<
    ui_type = "slider";
    ui_label = "Exposure";
    ui_category = "IMAGE";
    ui_min = -1.00;
    ui_max = 1.00;
    ui_step = 0.01;
>
= 0.00;


uniform float Contrast
<
    ui_type = "slider";
    ui_label = "Contrast";
    ui_category = "IMAGE";
    ui_min = 0.50;
    ui_max = 1.50;
    ui_step = 0.01;
>
= 1.00;


// ============================================================
// SOURCE
// ============================================================

texture2D BackBufferTex : COLOR;

sampler2D BackBuffer
{
    Texture = BackBufferTex;
};


// ============================================================
// FUNCTIONS
// ============================================================

float GetLuma(float3 color)
{
    return dot(
        color,
        float3(
            0.2126,
            0.7152,
            0.0722
        )
    );
}


// ------------------------------------------------------------
// SATURATION
// ------------------------------------------------------------

float3 ApplySaturation(
    float3 color,
    float amount
)
{
    float luma = GetLuma(color);

    return lerp(
        float3(luma, luma, luma),
        color,
        amount
    );
}


// ------------------------------------------------------------
// VIBRANCE
// ------------------------------------------------------------

float3 ApplyVibrance(
    float3 color,
    float amount
)
{
    float luma = GetLuma(color);

    float maxColor =
        max(
            color.r,
            max(color.g, color.b)
        );

    float minColor =
        min(
            color.r,
            min(color.g, color.b)
        );

    float colorRange =
        maxColor - minColor;

    /*
        Already saturated colors receive less boost.
        This gives a much nicer result than simply
        increasing saturation.
    */

    float boost =
        (1.0 - colorRange) * amount;

    return lerp(
        float3(luma, luma, luma),
        color,
        1.0 + boost
    );
}


// ------------------------------------------------------------
// COLOR BOOST
// ------------------------------------------------------------

float3 ApplyColorBoost(
    float3 color,
    float amount
)
{
    float luma = GetLuma(color);

    float3 chroma =
        color - luma;

    /*
        Increase the distance from neutral gray.
    */

    color += chroma * amount;

    return color;
}


// ------------------------------------------------------------
// COLOR CONTRAST
// ------------------------------------------------------------

float3 ApplyColorContrast(
    float3 color,
    float amount
)
{
    float luma = GetLuma(color);

    float3 neutral =
        float3(
            luma,
            luma,
            luma
        );

    return neutral +
           (color - neutral) * amount;
}


// ------------------------------------------------------------
// COLOR DEPTH
// ------------------------------------------------------------

float3 ApplyColorDepth(
    float3 color,
    float amount
)
{
    float luma = GetLuma(color);

    /*
        Push dark colors slightly darker while
        preserving the color information.
    */

    float shadowMask =
        1.0 - smoothstep(
            0.05,
            0.60,
            luma
        );

    color -=
        color *
        shadowMask *
        amount *
        0.15;

    return color;
}


// ------------------------------------------------------------
// HIGHLIGHT COLOR
// ------------------------------------------------------------

float3 ApplyHighlightColor(
    float3 color,
    float amount
)
{
    float luma = GetLuma(color);

    float mask =
        smoothstep(
            0.45,
            1.0,
            luma
        );

    /*
        Slight warm highlight bias.
        Mostly affects bright colors.
    */

    color.r +=
        amount * mask;

    color.g +=
        amount * mask * 0.30;

    return color;
}


// ------------------------------------------------------------
// SHADOW COLOR
// ------------------------------------------------------------

float3 ApplyShadowColor(
    float3 color,
    float amount
)
{
    float luma = GetLuma(color);

    float mask =
        1.0 -
        smoothstep(
            0.05,
            0.55,
            luma
        );

    /*
        Very subtle cyan/blue shadow coloration.
    */

    color.b +=
        amount * mask;

    color.g +=
        amount * mask * 0.35;

    return color;
}


// ------------------------------------------------------------
// NEON BOOST
// ------------------------------------------------------------

float3 ApplyNeonBoost(
    float3 color,
    float amount,
    float protection
)
{
    float luma = GetLuma(color);

    float maxColor =
        max(
            color.r,
            max(color.g, color.b)
        );

    float minColor =
        min(
            color.r,
            min(color.g, color.b)
        );

    float chroma =
        maxColor - minColor;


    /*
        Detect strongly colored pixels.
    */

    float colorMask =
        smoothstep(
            0.12,
            0.45,
            chroma
        );


    /*
        Prevent extremely bright pixels from
        becoming completely blown out.
    */

    float highlightMask =
        smoothstep(
            0.55,
            1.0,
            luma
        );

    float protectionMask =
        1.0 -
        highlightMask * protection;


    float boost =
        1.0 +
        colorMask *
        amount *
        protectionMask;


    float3 neutral =
        float3(
            luma,
            luma,
            luma
        );

    return lerp(
        neutral,
        color,
        boost
    );
}


// ------------------------------------------------------------
// RGB BOOST
// ------------------------------------------------------------

float3 ApplyRGB(
    float3 color
)
{
    color.r +=
        RedBoost *
        color.r;

    color.g +=
        GreenBoost *
        color.g;

    color.b +=
        BlueBoost *
        color.b;

    return color;
}


// ============================================================
// MAIN
// ============================================================

float4 PS_GRIP_Vibrant(
    float4 position : SV_Position,
    float2 texcoord : TEXCOORD
) : SV_Target
{
    float3 color =
        tex2D(
            BackBuffer,
            texcoord
        ).rgb;


    // --------------------------------------------------------
    // Exposure
    // --------------------------------------------------------

    color *=
        pow(
            2.0,
            Exposure
        );


    // --------------------------------------------------------
    // Normal contrast
    // --------------------------------------------------------

    color =
        (color - 0.5) *
        Contrast +
        0.5;


    // --------------------------------------------------------
    // Main saturation
    // --------------------------------------------------------

    color =
        ApplySaturation(
            color,
            Saturation
        );


    // --------------------------------------------------------
    // Vibrance
    // --------------------------------------------------------

    color =
        ApplyVibrance(
            color,
            Vibrance
        );


    // --------------------------------------------------------
    // Color boost
    // --------------------------------------------------------

    color =
        ApplyColorBoost(
            color,
            ColorBoost
        );


    // --------------------------------------------------------
    // Color contrast
    // --------------------------------------------------------

    color =
        ApplyColorContrast(
            color,
            ColorContrast
        );


    // --------------------------------------------------------
    // Color depth
    // --------------------------------------------------------

    color =
        ApplyColorDepth(
            color,
            ColorDepth
        );


    // --------------------------------------------------------
    // Highlight color
    // --------------------------------------------------------

    color =
        ApplyHighlightColor(
            color,
            HighlightColor
        );


    // --------------------------------------------------------
    // Shadow color
    // --------------------------------------------------------

    color =
        ApplyShadowColor(
            color,
            ShadowColor
        );


    // --------------------------------------------------------
    // Neon colors
    // --------------------------------------------------------

    color =
        ApplyNeonBoost(
            color,
            NeonBoost,
            NeonProtection
        );


    // --------------------------------------------------------
    // RGB controls
    // --------------------------------------------------------

    color =
        ApplyRGB(
            color
        );


    // --------------------------------------------------------
    // Final clamp
    // --------------------------------------------------------

    color =
        saturate(color);


    return float4(
        color,
        1.0
    );
}


// ============================================================
// TECHNIQUE
// ============================================================

technique GRIP_VibrantColors
<
    ui_label = "GRIP - Vibrant Colors";
>
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = PS_GRIP_Vibrant;
    }
}
