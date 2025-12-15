
// Toggle for grayscale effect
uniform bool _Grayscale <
    ui_category = "Colors";
    ui_label = "Grayscale";
> = false;

// Toggle for color palette 1
uniform bool _Palette1 <
    ui_category = "Colors";
    ui_label = "Color Palette 1";
> = false;

// Toggle for color palette 2
uniform bool _Palette2 <
    ui_category = "Colors";
    ui_label = "Color Palette 2";
> = false;

// Toggle for color palette 3
uniform bool _Palette3 <
    ui_category = "Colors";
    ui_label = "Color Palette 3";
> = false;

// Adjust Brightness
uniform float _Brightness <
	ui_category = "Parameters";
	ui_label = "Brightness";
	ui_min = 0.0f;
	ui_max = 10.0f;
	ui_type = "drag";
> = 1.0f;

// Adjust the scaling for edge detection
uniform float _EdgeScaling <
	ui_category = "Parameters";
	ui_label = "Edge Scaling";
	ui_min = 0.0f;
	ui_max = 5.0f;
	ui_type = "drag";
> = 1.6f;

// Toggle for showing downscaled image
uniform bool _ShowDownscale <
    ui_category = "Shader Progress";
    ui_label = "Show Downscale";
> = false;

// Toggle for showing the difference of gaussians
uniform bool _ShowDoG <
    ui_category = "Shader Progress";
    ui_label = "Show DoG";
> = false;

// Toggle for showing the image with the sobel filter applied
uniform bool _ShowSobel <
    ui_category = "Shader Progress";
    ui_label = "Show Sobel";
> = false;

// Toggle for showing a split view of the image before and after the shader
uniform bool _ShowSplitView <
    ui_category = "Shader Progress";
    ui_label = "Show Split View";
> = false;

// Adjust split view center point
uniform float _SplitViewAmount <
	ui_category = "Shader Progress";
	ui_label = "Split View Amount";
	ui_min = 0.0f;
	ui_max = 1.0f;
	ui_type = "drag";
> = 0.5f;

// Store original image
texture2D OriginalTex { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; Format = RGBA16F; };
sampler2D Original { Texture = OriginalTex; MagFilter = POINT; MinFilter = POINT; MipFilter = POINT;};

// Texture for drawing the downsampled image to
texture2D DownscaleTex { Width = BUFFER_WIDTH / 8; Height = BUFFER_HEIGHT / 8; Format = RGBA16F; };
sampler2D Downscale { Texture = DownscaleTex; MagFilter = POINT; MinFilter = POINT; MipFilter = POINT;};

// Ascii fill texture import
texture2D AsciiFillTexture < source = "Ascii_fill.png"; > { Width = 80; Height = 8; };
sampler2D AsciiFill { Texture = AsciiFillTexture; AddressU = REPEAT; AddressV = REPEAT; };

// Ascii edge texture import
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

// Store final result
texture2D ResultTex { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; Format = RGBA16F; };
sampler2D Result { Texture = ResultTex; MagFilter = POINT; MinFilter = POINT; MipFilter = POINT;};

// Default backbuffer
texture2D texColorBuffer : COLOR;
sampler2D samplerColor { Texture = texColorBuffer; };


// Function applying a Gaussian filter
float gaussianFilter(float sigma, float x) {
	return (1.0 / (sigma * sqrt(2.0*3.14)) * exp(-(x*x)/(2.0*sigma*sigma)));
}

// Default vertex shader (used for all passes)
[shader("vertex")]
void defaultVertexShader(uint id : SV_VertexID, out float4 position : SV_Position, out float2 texcoord : TEXCOORD0)
{
    texcoord.x = (id == 2) ? 2.0 : 0.0;
    texcoord.y = (id == 1) ? 2.0 : 0.0;
    position = float4(texcoord * float2(2, -2) + float2(-1, 1), 0, 1);

}

// Default pixel shader (doesn't affect the image)
[shader("pixel")]
void defaultPixelShader(float4 position : SV_Position, float2 texcoord : TEXCOORD0, out float4 finalColor : SV_Target) 
{
	// Get color from backbuffer
	finalColor = tex2D(samplerColor, texcoord);	
}

// Color Quantization
[shader("pixel")]
void quantizeShader(float4 position : SV_Position, float2 texcoord : TEXCOORD0, out float4 finalColor : SV_Target) 
{
	// Get original color   
	float4 color = tex2D(samplerColor, texcoord);
	
	// Adjust brightness of image from the menu slider
	color *= _Brightness;
	
	// Number of colors per channel
	float3 colorResolution = (8.0, 8.0, 8.0);
    
    // Quantize colors
	float3 quantizedColor = floor(color.rgb * colorResolution) / (colorResolution - 1);
       
    finalColor = quantizedColor;  
}

// Horizontal Gaussian filter
float4 horizontalGaussianShader(float4 position : SV_Position, float2 texcoord : TEXCOORD) : SV_Target {
	// Define texel size (BUFFER_RCP_WIDTH = 1 / BUFFER_WIDTH)
	float2 texelSize = float2(BUFFER_RCP_WIDTH, BUFFER_RCP_HEIGHT);
	
	float2 blur = 0;
	float2 kernelSum = 0;
	
	int kernelSize = 2;
	float sigma = 2.0;
	
	for(int x = -kernelSize; x <= kernelSize; x++){
		// Get pixel color from downscaled image
		float2 color = tex2D(Downscale, texcoord + float2(x,0) * texelSize).r;
		float2 gauss = float2(gaussianFilter(sigma,x),gaussianFilter(sigma*_EdgeScaling,x));
		blur += color * gauss;
		kernelSum += gauss;
	}
	
	blur /= kernelSum;
	
	return float4(blur, 0, 0);
}

// Vertical gaussian and Difference of Gaussians
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
	
	// Difference of Gaussians
	float diff = blur.x - blur.y;
	float threshold = 0.005;
	
	// Thresholding
	if (diff >= threshold) {diff = 1.0;}
	else {diff = 0.0;}
	
	return diff;
}

// Sobel filter
float2 sobelShader(float4 position : SV_Position, float2 texcoord : TEXCOORD0) : SV_Target {
	
	float2 delta = float2(0.001, 0.001);

	float Gx;
	float Gy;

	// Applying Gx matrix
	Gx += tex2D(DiffGauss, (texcoord + float2(-1.0, -1.0) * delta)).r * -1.0;
	Gx += tex2D(DiffGauss, (texcoord + float2(0.0, -1.0) * delta)).r * 0.0;
	Gx += tex2D(DiffGauss, (texcoord + float2(1.0, -1.0) * delta)).r * 1.0;
	Gx += tex2D(DiffGauss, (texcoord + float2(-1.0, 0.0) * delta)).r * -2.0;
	Gx += tex2D(DiffGauss, (texcoord + float2(0.0, 0.0) * delta)).r * 0.0;
	Gx += tex2D(DiffGauss, (texcoord + float2(0.0, 1.0) * delta)).r * 2.0;
	Gx += tex2D(DiffGauss, (texcoord + float2(-1.0, 1.0) * delta)).r * -1.0;
	Gx += tex2D(DiffGauss, (texcoord + float2(0.0, 1.0) * delta)).r * 0.0;
	Gx += tex2D(DiffGauss, (texcoord + float2(1.0, 1.0) * delta)).r * 1.0;
	
	// Applying Gy matrix
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
	
	// Get angle
	float theta = atan2(G.y, G.x);
	
	return float2(theta, 1 - theta);
}

// Stores edges for 8x8 tile
groupshared int edges[64];

// Convert to ascii
void convertAscii(uint3 tid : SV_DISPATCHTHREADID, uint3 gid : SV_GROUPTHREADID)
{
	// Get sobel filtered image
	float2 sobel = tex2Dfetch(Sobel, tid.xy).rg;

	// Get angle
    float theta = sobel.r;
    float absTheta = abs(theta) / 3.14;

    int direction = -1;

	// Assign direction index based on angle
    if (any(sobel.r)) {
  	  if (0.4f <= absTheta && absTheta <= 0.6f) {direction = 0;} // Underscore      
		else if (0.0f <= absTheta && absTheta < 0.25f || 0.75f < absTheta && absTheta <= 1.0f) {direction = 1;} // Vertical line
        else if (0.25f < absTheta && absTheta < 0.4f) { // Diagonal
			if (sign(theta) > 0) {direction = 3;}
			else {direction = 2;}
		} 
        else if (0.6f < absTheta && absTheta < 0.75f) { // Diagonal
			if (sign(theta) > 0) {direction = 2;}
			else {direction = 3;}
		} 
    }	
    
    // Store directions for every pixel in the tile
    edges[gid.x + gid.y * 8] = direction;

    barrier();

	// Find most common edge direction in the tile
    int edgeIndex = -1;
    if ((gid.x == 0) && (gid.y == 0)) { // Only perform once per tile
  	  // Store amount of each edge direction present in the tile      
		uint tileEdges[4] = {0, 0, 0, 0};

        // Count all edges in the tile
        for (int i = 0; i < 64; i++) {
            tileEdges[edges[i]] += 1;
        }

        uint maxEdge = 0;

        // Find the most common type of edge in the tile
        for (int i = 0; i < 4; i++) {
            if (tileEdges[i] > maxEdge) {
                edgeIndex = i;
                maxEdge = tileEdges[i];
            }
        }
		
		int edgeThreshold = 8;
		
        // Only count as an edge if there are enough edges present in the tile
        if (maxEdge < edgeThreshold) edgeIndex = -1;

        edges[0] = edgeIndex;
    }

    barrier();
    
    // Quantize edge (in order to find right place in edge texture)
    float4 quantizedEdge = (edges[0] + 1) * 8;

	float3 ascii = 0;
	
	// Get color from downscaled image
	uint2 downscaleID = tid.xy / 8;
	float4 downscaleColor = tex2Dfetch(Downscale, downscaleID);
	
	// Get luminance
	float luminance = saturate(downscaleColor.w);
	// Quantize luminance to 10 shades
	luminance = max(0, (floor(luminance * 10) - 1)) / 10.0f;
	
	float2 localUV;
	
	if (saturate(edges[0] + 1)) { // If the tile contains an edge
		// Edges
		localUV.x = (tid.x % 8) + quantizedEdge.x;
		localUV.y = 8 - (tid.y % 8);
	
		ascii = tex2Dfetch(AsciiEdge, localUV).r;
	}
	else {
		// Fill
    	localUV.x = (tid.x % 8) + luminance * 80;
    	localUV.y = tid.y % 8;

    	ascii = tex2Dfetch(AsciiFill, localUV).r;
	}
    
    // Store result in texture
    tex2Dstore(AsciiStore, tid.xy, float4(ascii, 1.0));
}

// Display the ascii texture
float4 printAscii(float4 position : SV_POSITION, float2 uv : TEXCOORD) : SV_TARGET { 
	return tex2D(ASCII, uv);
}

// Applies color palettes
float4 colorShader(float4 position : SV_POSITION, float2 texcoord : TEXCOORD0)  : SV_TARGET { 	

	float4 ascii = tex2D(ASCII, texcoord);
	float4 color = tex2D(Downscale, texcoord);
	
	int numShades = 10;
	
    float luminance = (color.r + color.g + color.b) / 3.0f;
    float quantizedLuminance = floor(luminance * numShades) / numShades;
	
	// Color palettes consist of black + 9 colors
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

// Shows the different textures generated throughout the process
[shader("pixel")]
void viewProgress(float4 position : SV_Position, float2 texcoord : TEXCOORD0, out float4 finalColor : SV_Target) 
{
	if (_ShowDownscale) {finalColor = tex2D(Downscale, texcoord);}
	else if (_ShowDoG) {finalColor = tex2D(DiffGauss, texcoord);}
	else if (_ShowSobel) {finalColor = tex2D(Sobel, texcoord);}
	else if (_ShowSplitView) {
		float4 res = tex2D(Result, texcoord);
		float4 org = tex2D(Original, texcoord);
		if (texcoord.x <= _SplitViewAmount) {finalColor = res;}
		else {finalColor = org;}
	}
	else {finalColor = tex2D(Result, texcoord);}
}


technique test < ui_label = "ASCII Shader :3"; >
{
	// Save unmodified image
	pass {
		RenderTarget = OriginalTex;
		
		VertexShader = defaultVertexShader;
        PixelShader = defaultPixelShader;
	}	

	// Quantize the image and render to a smaller texture resulting in downsampling   
	pass {      
		RenderTarget = DownscaleTex;		

		VertexShader = defaultVertexShader;
        PixelShader = quantizeShader;
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
    
    pass {
        ComputeShader = convertAscii<8, 8>;
        DispatchSizeX = BUFFER_WIDTH / 8;
        DispatchSizeY = BUFFER_HEIGHT / 8;
    }
    
    pass {
    	VertexShader = defaultVertexShader;
    	PixelShader = printAscii;
    }
    
    // Store result from ascii shader
    pass {
		RenderTarget = ResultTex;    	

		VertexShader = defaultVertexShader;
    	PixelShader = colorShader;
    }
    
    pass {
		VertexShader = defaultVertexShader;
		PixelShader = viewProgress;
	}
    
    
}