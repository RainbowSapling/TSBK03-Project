
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
uniform float2 AsciiFill_TexelSize = (8,8);

texture2D RenderTexture { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; Format = RGBA16F; };
sampler2D ASCII { Texture = RenderTexture; MagFilter = POINT; MinFilter = POINT; MipFilter = POINT; };
storage2D AsciiStore { Texture = RenderTexture; };

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

// Quantization
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
   
}

// Convert to ascii
void asciiShader(uint3 tid : SV_DISPATCHTHREADID, uint3 gid : SV_GROUPTHREADID)
{

	float3 ascii = 0;
	
	uint2 downscaleID = tid.xy / 8;
	float4 downscaleInfo = tex2Dfetch(Downscale, downscaleID);
	
	float luminance = saturate(downscaleInfo.w);
	luminance = max(0, (floor(luminance * 10) - 1)) / 10.0f;
	
	float2 localUV;
    localUV.x = (((tid.x % 8)) + (luminance) * 80);
    localUV.y = (tid.y % 8);

    ascii = tex2Dfetch(AsciiFill, localUV).r;
    
    tex2Dstore(AsciiStore, tid.xy, float4(ascii, 1.0));

}

float4 PS_EndPass(float4 position : SV_POSITION, float2 uv : TEXCOORD) : SV_TARGET { return tex2D(ASCII, uv).rgba; }

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
    
    pass {
        ComputeShader = asciiShader<8, 8>;
        DispatchSizeX = BUFFER_WIDTH / 8;
        DispatchSizeY = BUFFER_HEIGHT / 8;
    }
    
    pass {
    	VertexShader = defaultVertexShader;
    	PixelShader = PS_EndPass;
    }
    
    
}