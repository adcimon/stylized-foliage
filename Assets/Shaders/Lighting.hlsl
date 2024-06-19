#ifndef LIGHTING_HLSL
#define LIGHTING_HLSL

void Diffuse_float( float3 Normal, float3 LightDirection, out float Diffuse, out float Brightness )
{
    Normal = normalize(Normal);
    LightDirection = normalize(LightDirection);

    float NdotL = dot(Normal, LightDirection);

    Diffuse = saturate(NdotL);
    Brightness = NdotL;
}

void Specular_float( float3 Normal, float3 LightDirection, float3 ViewDirection, float Smoothness, out float Specular )
{
    Normal = normalize(Normal);
    LightDirection = normalize(LightDirection);
    ViewDirection = normalize(ViewDirection);

    float3 H = normalize(float3(LightDirection)+float3(ViewDirection));
    float NdotH = dot(Normal, H);
    Specular = pow(saturate(NdotH), Smoothness);
}

void MainLight_float( float3 WorldPosition, out float3 Direction, out float3 Color, out float DistanceAttenuation, out float ShadowAttenuation )
{
	#if SHADERGRAPH_PREVIEW
		Direction = float3(0.5, 0.5, 0);
		Color = 1;
		DistanceAttenuation = 1;
		ShadowAttenuation = 1;
	#else
		#if SHADOWS_SCREEN
			float4 clipPos = TransformWorldToHClip(WorldPosition);
			float4 shadowCoord = ComputeScreenPos(clipPos);
		#else
			float4 shadowCoord = TransformWorldToShadowCoord(WorldPosition);
		#endif

			Light mainLight = GetMainLight(shadowCoord);
			Direction = mainLight.direction;
			Color = mainLight.color;
			DistanceAttenuation = mainLight.distanceAttenuation;

		#if !defined(_MAIN_LIGHT_SHADOWS) || defined(_RECEIVE_SHADOWS_OFF)
			ShadowAttenuation = 1.0;
		#endif

		#if SHADOWS_SCREEN
			ShadowAttenuation = SampleScreenSpaceShadowmap(shadowCoord);
		#else
			ShadowSamplingData shadowSamplingData = GetMainLightShadowSamplingData();
			float shadowStrength = GetMainLightShadowStrength();
			ShadowAttenuation = SampleShadowmap(shadowCoord, TEXTURE2D_ARGS(_MainLightShadowmapTexture, sampler_MainLightShadowmapTexture), shadowSamplingData, shadowStrength, false);
		#endif
	#endif
}

void AdditionalLight_float( int i, float3 WorldPosition, out float3 Direction, out float3 Color, out float DistanceAttenuation, out float ShadowAttenuation )
{
	float3 direction = 0;
	float3 color = 0;
	float distanceAttenuation = 0;
	float shadowAttenuation = 0;

	#ifndef SHADERGRAPH_PREVIEW
		int count = GetAdditionalLightsCount();
		if( i < 0 || i >= count )
		{
			Direction = 0;
			Color = 0;
			DistanceAttenuation = 0;
			ShadowAttenuation = 0;
			return;
		}

		Light light = GetAdditionalLight(i, WorldPosition);

		direction = light.direction;
		color = light.color;
		distanceAttenuation = light.distanceAttenuation;
		shadowAttenuation = light.shadowAttenuation;
	#endif

	Direction = direction;
	Color = color;
	DistanceAttenuation = distanceAttenuation;
	ShadowAttenuation = shadowAttenuation;
}

void AdditionalLightsModel_float( float3 WorldPosition, float3 Normal, float3 ViewDirection, float Smoothness, out float3 Diffuse, out float3 Specular )
{
	float3 diffuseFinal = 0;
	float3 specularFinal = 0;

	Normal = normalize(Normal);
	ViewDirection = normalize(ViewDirection);

	#ifndef SHADERGRAPH_PREVIEW
		int count = GetAdditionalLightsCount();
		for( int i = 0; i < count; i++ )
		{
			Light light = GetAdditionalLight(i, WorldPosition);

			float3 attenuatedLightColor = light.color * (light.distanceAttenuation * light.shadowAttenuation);

			float diffuse = 0;
			float brightness = 0;
			Diffuse_float(Normal, light.direction, diffuse, brightness);
			diffuseFinal += float3(brightness, brightness, brightness) * attenuatedLightColor;

			float specular = 0;
			Specular_float(Normal, light.direction, ViewDirection, Smoothness, specular);
			specularFinal += float3(specular, specular, specular) * attenuatedLightColor;
		}
	#endif

	Diffuse = diffuseFinal;
	Specular = specularFinal;
}

#endif