
// Toggle for grayscale effect
uniform bool _Grayscale <
    ui_category = "Effects";
    ui_label = "Grayscale";
> = false;


// Texture for drawing the downsampled image to
texture2D DownscaleTex { Width = BUFFER_WIDTH / 8; Height = BUFFER_HEIGHT / 8; Format = RGBA16F; };
sampler2D Downscale { Texture = DownscaleTex; MagFilter = POINT; MinFilter = POINT; MipFilter = POINT;};

// Ascii texture
texture2D AsciiFillTexture < source = "Ascii_fill.png"; > { Width = 80; Height = 8; };
sampler2D AsciiFill { Texture = AsciiFillTexture; AddressU = REPEAT; AddressV = REPEAT; };

// Default backbuffer
texture2D texColorBuffer : COLOR;
sampler2D samplerColor { Texture = texColorBuffer; };


[shader("vertex")]
void defaultVertexShader(uint id : SV_VertexID, out float4 position : SV_Position, out float2 texcoord : TEXCOORD0)
{
    texcoord.x = (id == 2) ? 2.0 : 0.0;
    texcoord.y = (id == 1) ? 2.0 : 0.0;
    position = float4(texcoord * float2(2, -2) + float2(-1, 1), 0, 1);

}

[shader("pixel")]
void quantizeShader(float4 position : SV_Position, float2 texcoord : TEXCOORD0, out float4 finalColor : SV_Target) 
{
	// Get original color   
	float4 color = tex2D(samplerColor, texcoord);

    // Find grayscale value
    float luminance = (color.r + color.g + color.b) / 3.0f;
    
    int numShades = 10;
    
    // Quantize the luminance
    float quantizedLuminance = floor(luminance * numShades) / numShades;
       
    finalColor = (quantizedLuminance, quantizedLuminance, quantizedLuminance);
    
    float2 UV;
    UV.x = (position.x % 8) / 8 + quantizedLuminance;
    UV.y = (position.y % 8) / 8;
    
    float3 ascii = tex2Dfetch(AsciiFill, UV).r;
    
    
        
    
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
	// Get color from texture 
	float4 color = tex2D(Downscale, texcoord);
	finalColor = color;

}



technique test < ui_label = "test shader...?"; >
{
	// Quantize the image and render to a smaller texture resulting in downsampling   
	pass {      
		RenderTarget = DownscaleTex;		

		VertexShader = defaultVertexShader;
        PixelShader = quantizeShader;
    }

    
    pass {
        VertexShader = defaultVertexShader;
        PixelShader = viewDownsamplePixelShader;
    }

    
    
}