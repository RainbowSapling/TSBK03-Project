
// Toggle for grayscale effect
uniform bool _Grayscale <
    ui_category = "Effects";
    ui_label = "Grayscale";
> = false;

// Toggle for color palette 1
uniform bool _Palette1 <
    ui_category = "Effects";
    ui_label = "Color Palette 1";
> = false;

// Toggle for color palette 2
uniform bool _Palette2 <
    ui_category = "Effects";
    ui_label = "Color Palette 2";
> = false;

// Toggle for color palette 3
uniform bool _Palette3 <
    ui_category = "Effects";
    ui_label = "Color Palette 3";
> = false;


uniform float _Brightness <
	ui_label = "Brightness";
	ui_min = 0.0f;
	ui_max = 10.0f;
	ui_type = "drag";
> = 1.0f;

uniform float _EdgeScaling <
	ui_label = "Edge Scaling";
	ui_min = 0.0f;
	ui_max = 5.0f;
	ui_type = "drag";
> = 1.6f;


// Texture for drawing the downsampled image to
texture2D DownscaleTex { Width = BUFFER_WIDTH / 8; Height = BUFFER_HEIGHT / 8; Format = RGBA16F; };
sampler2D Downscale { Texture = DownscaleTex; MagFilter = POINT; MinFilter = POINT; MipFilter = POINT;};

// Ascii fill texture
texture2D AsciiFillTexture < source = "Ascii_fill.png"; > { Width = 80; Height = 8; };
sampler2D AsciiFill { Texture = AsciiFillTexture; AddressU = REPEAT; AddressV = REPEAT; };

// Ascii edge texture
texture2D AsciiEdgeTexture < source = "Ascii_edge.png"; > { Width = 40; Height = 8; };
sampler2D AsciiEdge { Texture = AsciiEdgeTexture; AddressU = REPEAT; AddressV = REPEAT; };

// Ascii rendering
texture2D RenderTexture { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; Format = RGBA16F; };
sampler2D ASCII { Texture = RenderTexture; MagFilter = POINT; MinFilter = POINT; MipFilter = POINT; };
storage2D AsciiStore { Texture = RenderTexture; };

// Sobel filter
texture2D SobelTex { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; Format = RGBA16F; };
sampler2D Sobel { Texture = SobelTex; MagFilter = POINT; MinFilter = POINT; MipFilter = POINT;};


// Gauss horizontal
texture2D GaussHorizontalTex { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; Format = RGBA16F; };
sampler2D GaussHorizontal { Texture = GaussHorizontalTex; MagFilter = POINT; MinFilter = POINT; MipFilter = POINT;};

// Gauss vertical + difference of gaussians
texture2D DiffGaussTex { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; Format = RGBA16F; };
sampler2D DiffGauss { Texture = DiffGaussTex; MagFilter = POINT; MinFilter = POINT; MipFilter = POINT;};

// Default backbuffer
texture2D texColorBuffer : COLOR;
sampler2D samplerColor { Texture = texColorBuffer; };


float gaussianFilter(float sigma, float x) {
	return (1.0 / (sigma * sqrt(2.0*3.14)) * exp(-(x*x)/(2.0*sigma*sigma)));
}


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
	
	color *= _Brightness;
	
	// Number of colors per channel
	float3 colorResolution = (8.0, 8.0, 8.0);
    
    // Quantize colors
	float3 quantizedColor = floor(color.rgb * colorResolution) / (colorResolution - 1);
       
    finalColor = quantizedColor;  
}

float4 horizontalGaussianShader(float4 position : SV_Position, float2 texcoord : TEXCOORD) : SV_Target {
	float2 texelSize = float2(BUFFER_RCP_WIDTH, BUFFER_RCP_HEIGHT);
	
	float2 blur = 0;
	float2 kernelSum = 0;
	
	int kernelSize = 2;
	float sigma = 2.0;
	
	for(int x = -kernelSize; x <= kernelSize; x++){
		float2 color = tex2D(Downscale, texcoord + float2(x,0) * texelSize).r;
		float2 gauss = float2(gaussianFilter(sigma,x),gaussianFilter(sigma*_EdgeScaling,x));
		blur += color * gauss;
		kernelSum += gauss;
	}
	
	blur /= kernelSum;
	
	return float4(blur, 0, 0);
}

float differenceGaussianShader(float4 position : SV_Position, float2 texcoord : TEXCOORD) : SV_Target {
	float2 texelSize = float2(BUFFER_RCP_WIDTH, BUFFER_RCP_HEIGHT);
	
	float2 blur = 0;
	float2 kernelSum = 0;
	
	int kernelSize = 2;
	float sigma = 2.0;
	
	for(int y = -kernelSize; y <= kernelSize; y++){
		float2 color = tex2D(GaussHorizontal, texcoord + float2(0,y) * texelSize).rg;
		float2 gauss = float2(gaussianFilter(sigma,y),gaussianFilter(sigma*_EdgeScaling,y));
		blur += color * gauss;
		kernelSum += gauss;
	}
	
	blur /= kernelSum;
	
	float diff = blur.x - blur.y;
	float threshold = 0.005;
	
	if (diff >= threshold) {diff = 1.0;}
	else {diff = 0.0;}
	
	return diff;
}


float2 sobelShader(float4 position : SV_Position, float2 texcoord : TEXCOORD0) : SV_Target {
	
	float2 delta = float2(0.001, 0.001);

	float Gx;
	float Gy;

	Gx += tex2D(DiffGauss, (texcoord + float2(-1.0, -1.0) * delta)).r * -1.0;
	Gx += tex2D(DiffGauss, (texcoord + float2(0.0, -1.0) * delta)).r * 0.0;
	Gx += tex2D(DiffGauss, (texcoord + float2(1.0, -1.0) * delta)).r * 1.0;
	Gx += tex2D(DiffGauss, (texcoord + float2(-1.0, 0.0) * delta)).r * -2.0;
	Gx += tex2D(DiffGauss, (texcoord + float2(0.0, 0.0) * delta)).r * 0.0;
	Gx += tex2D(DiffGauss, (texcoord + float2(0.0, 1.0) * delta)).r * 2.0;
	Gx += tex2D(DiffGauss, (texcoord + float2(-1.0, 1.0) * delta)).r * -1.0;
	Gx += tex2D(DiffGauss, (texcoord + float2(0.0, 1.0) * delta)).r * 0.0;
	Gx += tex2D(DiffGauss, (texcoord + float2(1.0, 1.0) * delta)).r * 1.0;
	
	Gy += tex2D(DiffGauss, (texcoord + float2(-1.0, -1.0) * delta)).r * -1.0;
	Gy += tex2D(DiffGauss, (texcoord + float2(0.0, -1.0) * delta)).r * -2.0;
	Gy += tex2D(DiffGauss, (texcoord + float2(1.0, -1.0) * delta)).r * -1.0;
	Gy += tex2D(DiffGauss, (texcoord + float2(-1.0, 0.0) * delta)).r * 0.0;
	Gy += tex2D(DiffGauss, (texcoord + float2(0.0, 0.0) * delta)).r * 0.0;
	Gy += tex2D(DiffGauss, (texcoord + float2(0.0, 1.0) * delta)).r * 0.0;
	Gy += tex2D(DiffGauss, (texcoord + float2(-1.0, 1.0) * delta)).r * 1.0;
	Gy += tex2D(DiffGauss, (texcoord + float2(0.0, 1.0) * delta)).r * 2.0;
	Gy += tex2D(DiffGauss, (texcoord + float2(1.0, 1.0) * delta)).r * 1.0;
	
	
	float2 G = float2(Gx, Gy);
	G = normalize(G);
	
	float theta = atan2(G.y, G.x);
	
	return float2(theta, 1 - isnan(theta));
}

groupshared int edgeCount[64];
// Convert to ascii
void convertAscii(uint3 tid : SV_DISPATCHTHREADID, uint3 gid : SV_GROUPTHREADID)
{

	float2 sobel = tex2Dfetch(Sobel, tid.xy).rg;

    float theta = sobel.r;
    float absTheta = abs(theta) / 3.14;

    int direction = -1;

    if (any(sobel.r)) {
        if ((0.0f <= absTheta) && (absTheta < 0.05f)) direction = 0; // VERTICAL
        else if ((0.9f < absTheta) && (absTheta <= 1.0f)) direction = 0;
        else if ((0.45f < absTheta) && (absTheta < 0.55f)) direction = 1; // HORIZONTAL
        else if (0.05f < absTheta && absTheta < 0.45f) direction = sign(theta) > 0 ? 3 : 2; // DIAGONAL 1
        else if (0.55f < absTheta && absTheta < 0.9f) direction = sign(theta) > 0 ? 2 : 3; // DIAGONAL 2
    }	
    
    
    // Set group thread bucket to direction
    edgeCount[gid.x + gid.y * 8] = direction;

    barrier();

    int commonEdgeIndex = -1;
    if ((gid.x == 0) && (gid.y == 0)) {
        uint buckets[4] = {0, 0, 0, 0};

        // Count up directions in tile
        for (int i = 0; i < 64; ++i) {
            buckets[edgeCount[i]] += 1;
        }

        uint maxValue = 0;

        // Scan for most common edge direction (max)
        for (int j = 0; j < 4; ++j) {
            if (buckets[j] > maxValue) {
                commonEdgeIndex = j;
                maxValue = buckets[j];
            }
        }
		
		int edgeThreshold = 8;
		
        // Discard edge info if not enough edge pixels in tile
        if (maxValue < edgeThreshold) commonEdgeIndex = -1;

        edgeCount[0] = commonEdgeIndex;
    }

    barrier();
    
    
    
    float4 quantizedEdge = (edgeCount[0] + 1) * 8;

	float3 ascii = 0;
	
	uint2 downscaleID = tid.xy / 8;
	float4 downscaleInfo = tex2Dfetch(Downscale, downscaleID);
	
	float luminance = saturate(downscaleInfo.w);
	luminance = max(0, (floor(luminance * 10) - 1)) / 10.0f;
	
	float2 localUV;
	
	if (saturate(edgeCount[0] + 1)) {
		// Edges
		localUV.x = ((tid.x % 8)) + quantizedEdge.x;
		localUV.y = 8 - (tid.y % 8);
	
		ascii = tex2Dfetch(AsciiEdge, localUV).r;
	}
	else {
		// Fill
    	localUV.x = (((tid.x % 8)) + (luminance) * 80);
    	localUV.y = (tid.y % 8);

    	ascii = tex2Dfetch(AsciiFill, localUV).r;
	}
    
    
    tex2Dstore(AsciiStore, tid.xy, float4(ascii, 1.0));
}

float4 printAscii(float4 position : SV_POSITION, float2 uv : TEXCOORD) : SV_TARGET { 

	return tex2D(ASCII, uv).rgba;
}

float4 colorShader(float4 position : SV_POSITION, float2 texcoord : TEXCOORD0)  : SV_TARGET { 	

	float4 ascii = tex2D(ASCII, texcoord).rgba;
	float4 color = tex2D(Downscale, texcoord); // Quantized colors
	
	int numShades = 10;
	
    float luminance = (color.r + color.g + color.b) / 3.0f;
    float quantizedLuminance = floor(luminance * numShades) / numShades;
	
	float4 color1;
	float4 color2;
	float4 color3;
	float4 color4;
	float4 color5;
	float4 color6;
	float4 color7;
	float4 color8;
	float4 color9;
	
	// Grayscale effect
	if (_Grayscale) { return ascii * quantizedLuminance;}
	
	// Color palette 1
	else if (_Palette1) {
		color1 = float4(0.718, 0.035, 0.298, 1.0);
		color2 = float4(0.627, 0.102, 0.345, 1.0);
		color3 = float4(0.537, 0.169, 0.392, 1.0);
		color4 = float4(0.447, 0.235, 0.439, 1.0);
		color5 = float4(0.361, 0.302, 0.49, 1.0);
		color6 = float4(0.271, 0.369, 0.537, 1.0);
		color7 = float4(0.18, 0.435, 0.584, 1.0);
		color8 = float4(0.09, 0.502, 0.631, 1.0);
		color9 = float4(1.0, 1.0, 1.0, 1.0);
	}
	
	// Color palette 2
	else if (_Palette2) {
		color1 = float4(0.976, 0.573, 0.678, 1.0);
		color2 = float4(0.984, 0.737, 0.933, 1.0);
		color3 = float4(0.98, 0.706, 0.784, 1.0);
		color4 = float4(0.969, 0.557, 0.812, 1.0);
		color5 = float4(0.812, 0.725, 0.969, 1.0);
		color6 = float4(0.878, 0.808, 0.992, 1.0);
		color7 = float4(0.643, 0.502, 0.949, 1.0);
		color8 = float4(0.831, 0.69, 0.976, 1.0);
		color9 = float4(1.0, 1.0, 1.0, 1.0);
	}
	
	// Color palette 3
	else if (_Palette3) {
		color1 = float4(0, 0.188, 0.286, 1.0);
		color2 = float4(0.42, 0.173, 0.224, 1.0);
		color3 = float4(0.839, 0.157, 0.157, 1.0);
		color4 = float4(0.906, 0.329, 0.078, 1.0);
		color5 = float4(0.969, 0.498, 0, 1.0);
		color6 = float4(0.98, 0.624, 0.145, 1.0);
		color7 = float4(0.988, 0.749, 0.286, 1.0);
		color8 = float4(0.953, 0.82, 0.502, 1.0);
		color9 = float4(0.918, 0.886, 0.718, 1.0);	
	}
	
	// If a color palette was chosen -> Apply it
	if (_Palette1 || _Palette2 || _Palette3) {
		float4 outColor;

		if (quantizedLuminance < 0.2) {outColor = color1;}
		else if (quantizedLuminance < 0.3) {outColor = color2;}
		else if (quantizedLuminance < 0.4) {outColor = color3;}
		else if (quantizedLuminance < 0.5) {outColor = color4;}
		else if (quantizedLuminance < 0.6) {outColor = color5;}
		else if (quantizedLuminance < 0.7) {outColor = color6;}
		else if (quantizedLuminance < 0.8) {outColor = color7;}
		else if (quantizedLuminance < 0.9) {outColor = color8;}
		else {outColor = color9;}
		
		return ascii * outColor;
	}
	
	// If none of the color effects are toggled -> use quantized colors
	return ascii * color;	
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

[shader("pixel")]
void viewSobel(float4 position : SV_Position, float2 texcoord : TEXCOORD0, out float4 finalColor : SV_Target) 
{
	finalColor = tex2D(Sobel, texcoord);
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
		RenderTarget = GaussHorizontalTex;
		
		VertexShader = defaultVertexShader;
		PixelShader = horizontalGaussianShader;
	}
	
	pass {
		RenderTarget = DiffGaussTex;
		
		VertexShader = defaultVertexShader;
		PixelShader = differenceGaussianShader;
	}
	
	pass {
		RenderTarget = SobelTex;
		
		VertexShader = defaultVertexShader;
		PixelShader = sobelShader;
	}
	
	/*pass {
		VertexShader = defaultVertexShader;
		PixelShader = viewSobel;
	}*/
    
    pass {
        ComputeShader = convertAscii<8, 8>;
        DispatchSizeX = BUFFER_WIDTH / 8;
        DispatchSizeY = BUFFER_HEIGHT / 8;
    }
    
    pass {
    	VertexShader = defaultVertexShader;
    	PixelShader = printAscii;
    }
    
    pass {
    	VertexShader = defaultVertexShader;
    	PixelShader = colorShader;
    }
    
    
}