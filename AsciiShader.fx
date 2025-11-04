
texture2D texColorBuffer : COLOR;

sampler2D samplerColor
{
    Texture = texColorBuffer;

    AddressU = CLAMP;
    AddressV = CLAMP;
    AddressW = CLAMP;
};


[shader("vertex")]
void testVertexShader(uint id : SV_VertexID, out float4 position : SV_Position, out float2 texcoord : TEXCOORD0)
{
    texcoord.x = (id == 2) ? 2.0 : 0.0;
    texcoord.y = (id == 1) ? 2.0 : 0.0;
    position = float4(texcoord * float2(2, -2) + float2(-1, 1), 0, 1);

}

[shader("pixel")]
void testPixelShader(float4 position : SV_Position, float2 texcoord : TEXCOORD0, out float4 color : SV_Target)
{
    color = tex2D(samplerColor, texcoord);

    // Only use red channel
    color.g = 0.0;
    color.b = 0.0;
}


technique test < ui_label = "test shader...?"; >
{
    pass {
        VertexShader = testVertexShader;
        PixelShader = testPixelShader;
    }
    
}