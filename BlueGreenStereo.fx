/*
================================================================================
    Custom Anaglyph 3D Shader for ReShade 3.8
================================================================================
*/

uniform float Separation <
    ui_type = "slider";
    ui_min = -0.05; ui_max = 0.05;
    ui_tooltip = "Horizontal offset (parallax) between left and right eye views.";
    ui_default = 0.005;
> = 0.005;

texture BackBufferTex : COLOR;

sampler BackBuffer 
{ 
    Texture = BackBufferTex; 
    AddressU = Clamp;
    AddressV = Clamp;
    MagFilter = Linear;
    MinFilter = Linear;
};

void PostProcessVS(in uint id : SV_VertexID, out float4 position : SV_Position, out float2 texcoord : TEXCOORD)
{
    texcoord.x = (id == 2) ? 2.0 : 0.0;
    texcoord.y = (id == 1) ? 2.0 : 0.0;
    position = float4(texcoord * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
}

void PS_BlueGreen3D(float4 vpos : SV_POSITION, float2 texcoord : TEXCOORD, out float4 res : SV_Target0)
{
    float2 uvLeft = float2(texcoord.x - Separation, texcoord.y);
    float2 uvRight = float2(texcoord.x + Separation, texcoord.y);

    float3 colLeft = tex2D(BackBuffer, uvLeft).rgb;
    float3 colRight = tex2D(BackBuffer, uvRight).rgb;

    float grayLeft = dot(colLeft, float3(0.299, 0.587, 0.114));
    float grayRight = dot(colRight, float3(0.299, 0.587, 0.114));

    // Assigning Green to Left eye channel, Blue to Right eye channel
    float3 finalColor = float3(0.0, grayLeft, grayRight);

    res = float4(finalColor, 1.0);
}

technique BlueGreen3D_Technique
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = PS_BlueGreen3D;
    }
}