
// Toggle for grayscale effect
uniform bool _Grayscale <
    ui_category = "Effects";
    ui_label = "Grayscale";
> = false;


// Texture for drawing the downsampled image to
texture2D DownscaleTex { Width = BUFFER_WIDTH / 8; Height = BUFFER_HEIGHT / 8; Format = RGBA16F; };
sampler2D Downscale { Texture = DownscaleTex; MagFilter = POINT; MinFilter = POINT; MipFilter = POINT;};

// Default backbuffer
texture2D texColorBuffer : COLOR;
sampler2D samplerColor
{
    Texture = texColorBuffer;

    AddressU = CLAMP;
    AddressV = CLAMP;
    AddressW = CLAMP;
};


[shader("vertex")]
void defaultVertexShader(uint id : SV_VertexID, out float4 position : SV_Position, out float2 texcoord : TEXCOORD0)
{
    texcoord.x = (id == 2) ? 2.0 : 0.0;
    texcoord.y = (id == 1) ? 2.0 : 0.0;
    position = float4(texcoord * float2(2, -2) + float2(-1, 1), 0, 1);

}

[shader("pixel")]
void testPixelShader(float4 position : SV_Position, float2 texcoord : TEXCOORD0, out float4 finalColor : SV_Target) 
{
	// Get original color   
	float4 color = tex2D(samplerColor, texcoord);

    if (_Grayscale) {
        // Calculate average
        float grayscaleAverage = (color.r + color.g + color.b)/3.0f;
        
        finalColor = (grayscaleAverage, grayscaleAverage, grayscaleAverage);
        }
    else {
        finalColor = color;
        }
}

[shader("pixel")]
void defaultPixelShader(float4 position : SV_Position, float2 texcoord : TEXCOORD0, out float4 finalColor : SV_Target) 
{
	// Get original color   
	float4 color = tex2D(samplerColor, texcoord);

}

[shader("pixel")]
void viewDownsamplePixelShader(float4 position : SV_Position, float2 texcoord : TEXCOORD0, out float4 finalColor : SV_Target) 
{
	// Get original color   
	float4 color = tex2D(Downscale, texcoord);
	finalColor = color;

}



technique test < ui_label = "test shader...?"; >
{
    pass {      
		RenderTarget = DownscaleTex;		

		VertexShader = defaultVertexShader;
        PixelShader = testPixelShader;
    }

    
    pass {
        VertexShader = defaultVertexShader;
        PixelShader = viewDownsamplePixelShader;
    }

    
    
}