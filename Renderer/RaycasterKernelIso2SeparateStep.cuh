
template <eMeasureSource measureSource1, eMeasureSource measureSource2, eTextureFilterMode F, eMeasureComputeMode C, eColorMode CM> 
__device__ inline void iso2separateStep(
	float4& sum,
	bool& bWasInsideCoarse,
	bool& bWasInsideFine,
	const float3& world2texOffset,
	float3 world2texScale,
	const float3& rayPosTx,
	const float3& pos,
	const float3& step,
	const float3& rayDir)
{
	float fDist = 1e10;
	float4 vColors[2] = {make_float4(0,0,0,0), make_float4(0,0,0,0)};

	bool bInsideCoarse = (c_raycastParams.isoValues.x < getMeasure<measureSource1,F,C>(c_raycastParams.measure1, g_texVolume1, w2t(pos), c_raycastParams.gridSpacing, c_raycastParams.measureScale1));
	if (bInsideCoarse != bWasInsideCoarse) 
	{
		float factor = (bInsideCoarse ? 1.0f : 0.0f);
		float3 pp = binarySearch<measureSource1,F,C>(c_raycastParams.measure1, g_texVolume1, w2t(pos - factor * step), w2t(pos - (1.0f-factor) * step), c_raycastParams.gridSpacing, c_raycastParams.isoValues.x, c_raycastParams.measureScale1);

		float3 grad = getGradient<measureSource1,F,C>(c_raycastParams.measure1, g_texVolume1, pp, c_raycastParams.gridSpacing) * (bInsideCoarse ? 1.0f : -1.0f);
		vColors[0] = shadeScaleInvariant(rayDir, grad, c_raycastParams.isoColor1);

		fDist = lengthSq(pp-rayPosTx);
	}
	bWasInsideCoarse = bInsideCoarse;

	bool bInsideFine = (c_raycastParams.isoValues.y < getMeasure<measureSource2,F,C>(c_raycastParams.measure2, g_texVolume2, w2t(pos), c_raycastParams.gridSpacing, c_raycastParams.measureScale2));
	if (bInsideFine != bWasInsideFine)
	{
		float factor = (bInsideFine ? 1.0f : 0.0f);
		float3 pp = binarySearch<measureSource2,F,C>(c_raycastParams.measure2, g_texVolume2, w2t(pos - factor * step), w2t(pos - (1.0f-factor) * step), c_raycastParams.gridSpacing, c_raycastParams.isoValues.y, c_raycastParams.measureScale2);

		float3 grad = getGradient<measureSource2,F,C>(c_raycastParams.measure2, g_texVolume2, pp, c_raycastParams.gridSpacing) * (bInsideFine ? 1.0f : -1.0f);
		float4 surfColor = getIsoColor<F,C,CM>(g_texVolume2, g_texVolume2, pp, c_raycastParams.isoColor2);
		float4 c2 = shadeScaleInvariant(rayDir, grad, surfColor);

		vColors[1] = vColors[0];
		int index = (lengthSq(pp-rayPosTx) <= fDist) ? 0 : 1;
		vColors[index] = c2;
	}
	bWasInsideFine = bInsideFine;

	sum += (1.0f - sum.w) * vColors[0];
	sum += (1.0f - sum.w) * vColors[1];
}
