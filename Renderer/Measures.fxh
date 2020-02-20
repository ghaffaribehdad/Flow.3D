//included in Line.fx

static const float PI = 3.14159265f;

// Helper

float4 convertIntToRgb(uint i)
{
	float4 color;
	color.x = (i & 0xff) / 256.0;
	color.y = ((i >> 8) & 0xff) / 256.0f;
	color.z = ((i >> 16) & 0xff) / 256.0f;
	//color.w = ((i > 24) & 0xff) / 256.0f;
	color.w = 1;
	return color;
}

float3 getVorticity(float3x3 jacobian)
{
	return float3(jacobian[2][1] - jacobian[1][2], jacobian[0][2] - jacobian[2][0], jacobian[1][0] - jacobian[0][1]);
}

float3 getCosines(float arg)
{
	float acs = acos(arg);
	return float3(cos(acs / 3.0f), cos(acs / 3.0f + 2.0f / 3.0f * PI), cos(acs / 3.0f + 4.0f / 3.0f * PI));
}

float3x3 getStrainRateTensor(float3x3 J)
{
	// S_ij = 1/2 (J_ij + J_ji)
	float3x3 S;

	S[0] = float3((J[0].x + J[0].x) / 2.0f, (J[0].y + J[1].x) / 2.0f, (J[0].z + J[2].x) / 2.0f);
	S[1] = float3((J[1].x + J[0].y) / 2.0f, (J[1].y + J[1].y) / 2.0f, (J[1].z + J[2].y) / 2.0f);
	S[2] = float3((J[2].x + J[0].z) / 2.0f, (J[2].y + J[1].z) / 2.0f, (J[2].z + J[2].z) / 2.0f);

	return S;
}

float3x3 getSpinTensor(float3x3 J)
{
	// O_ij = 1/2 (J_ij - J_ji)
	float3x3 O;

	O[0] = float3((J[0].x - J[0].x) / 2.0f, (J[0].y - J[1].x) / 2.0f, (J[0].z - J[2].x) / 2.0f);
	O[1] = float3((J[1].x - J[0].y) / 2.0f, (J[1].y - J[1].y) / 2.0f, (J[1].z - J[2].y) / 2.0f);
	O[2] = float3((J[2].x - J[0].z) / 2.0f, (J[2].y - J[1].z) / 2.0f, (J[2].z - J[2].z) / 2.0f);

	return O;
}

float Trace3x3(float3x3 A)
{
	return float(A[0].x + A[1].y + A[2].z);
}



float TraceAAT(float3x3 A)
{
	return float(A[0].x * A[0].x + A[0].y * A[0].y + A[0].z * A[0].z +
		A[1].x * A[1].x + A[1].y * A[1].y + A[1].z * A[1].z +
		A[2].x * A[2].x + A[2].y * A[2].y + A[2].z * A[2].z);
}



float FrobeniusNorm3x3(float3x3 A)
{
	return sqrt(TraceAAT(A));
}

float3 getHeatCurrent(float3 vel, float4 heat)
{
	float3 j;

	float ra = 7e5;
	float pr = 0.7;
	float kappa = 1 / sqrt(ra * pr);

	j.x = vel.x * heat.w - kappa * heat.x;
	j.y = vel.y * heat.w - kappa * heat.y;
	j.z = vel.z * heat.w - kappa * heat.z;

	return j;
}

// Measures

float getLambda2(float3x3 J)
{
	float s01 = 0.5 * ((J[0].x + J[1].y) * (J[0].y + J[1].x) + J[0].z * J[2].y + J[1].z * J[2].x);
	float s02 = 0.5 * ((J[0].x + J[2].z) * (J[0].z + J[2].x) + J[0].y * J[1].z + J[2].y * J[1].x);
	float s12 = 0.5 * ((J[1].y + J[2].z) * (J[1].z + J[2].y) + J[1].x * J[0].z + J[2].x * J[0].y);

	float s00 = J[0].x * J[0].x + J[0].y * J[1].x + J[0].z * J[2].x;
	float s11 = J[1].x * J[0].y + J[1].y * J[1].y + J[1].z * J[2].y;
	float s22 = J[2].x * J[0].z + J[2].y * J[1].z + J[2].z * J[2].z;

	float b = +s00 + s11 + s22;
	float c = -s00 * (s11 + s22) - s11 * s22 + s12 * s12 + s01 * s01 + s02 * s02;
	float d = s00 * (s11 * s22 - s12 * s12) + 2.0 * s01 * s12 * s02 - s02 * s02 * s11 - s01 * s01 * s22;

	const float onethird = 1.0f / 3.0f;
	float xN = b * onethird;
	float yN = d + xN * (c + xN * (b - xN));
	float deltasqr = xN * xN + c * onethird;
	float delta = -sign(yN) * sqrt(deltasqr);
	float hsqr = 4.0f * deltasqr * deltasqr * deltasqr;
	float h = -2.0f * delta * deltasqr;
	float yNsqr = yN * yN;
	float lambda2;

	if (yNsqr > hsqr)
	{
		float D = sqrt(yNsqr - hsqr);
		lambda2 = xN + sign(yN - D) * pow(0.5f * abs(yN - D), onethird)
			+ sign(yN + D) * pow(0.5f * abs(yN + D), onethird);
	}
	else if (yNsqr < hsqr)
	{
		float3 L = xN + 2.0 * delta * getCosines(-yN / h);
		lambda2 = min(max(min(L.x, L.y), L.z), max(L.x, L.y));
	}
	else
	{
		if (h == 0.0f) lambda2 = xN;
		else		 lambda2 = xN + delta;
	}

	return lambda2;
}

float getQHunt(float3x3 jacobian)
{
	float3x3 S = getStrainRateTensor(jacobian);
	float3x3 O = getSpinTensor(jacobian);
	float fS = FrobeniusNorm3x3(S);
	float fO = FrobeniusNorm3x3(O);
	return (0.5 * (fO * fO - fS * fS));
}


float getDeltaChong(float3x3 J)
{
	float3x3 S = getStrainRateTensor(J);
	float3x3 O = getSpinTensor(J);
	float3x3 SS = mul(S, S);
	float3x3 OO = mul(O, O);
	float3x3 SSpOO = SS + OO;

	float Q = -0.5f * Trace3x3(SSpOO);
	//float Q = getQHunt(J);
	float R = determinant(J);

	Q /= 3.0f;
	R /= 2.0f;

	return (Q * Q * Q + R * R);
}


float getSquareRotation(float3x3 J)
{
	float3x3 O = getSpinTensor(J);
	float3x3 Osq = mul(O, O);

	return float(-0.5 * Trace3x3(Osq));
}


float getTurbulentViscosity(const float3x3 J, float3 v)
{
	float3x3 S = getStrainRateTensor(J);

	// kinetic dissipation rate
	float kdr = 2.0f * sqrt(0.001f / 100000.0f) *
		(
			S[0].x * S[0].x + S[0].y * S[0].y + S[0].z * S[0].z +
			S[1].x * S[1].x + S[1].y * S[1].y + S[0].z * S[1].z +
			S[1].x * S[1].x + S[1].y * S[1].y + S[1].z * S[1].z
			);
	// Kinetic Turbulent Energy
	float kte = 0.5f * dot(v, v);

	return ((kte * kte) / kdr);
}



float getEnstrophyProduction(float3x3 J)
{
	float3x3 S = getStrainRateTensor(J);
	float3 w = getVorticity(J);

	float e = S[0].x * w.x * w.x +
		S[0].y * w.x * w.y +
		S[0].z * w.x * w.z +
		S[1].x * w.y * w.x +
		S[1].y * w.y * w.y +
		S[1].z * w.y * w.z +
		S[2].x * w.z * w.x +
		S[2].y * w.z * w.y +
		S[2].z * w.z * w.z;

	return e;
}


float getStrainProduction(float3x3 J)
{
	float3x3 S = getStrainRateTensor(J);

	float e = S[0].x * S[0].x * S[0].x + S[0].x * S[0].y * S[1].x + S[0].x * S[0].z * S[2].x +
		S[0].y * S[1].x * S[0].x + S[0].y * S[1].y * S[1].x + S[0].y * S[1].z * S[2].x +
		S[0].z * S[2].x * S[0].x + S[0].z * S[2].y * S[1].x + S[0].z * S[2].z * S[2].x +
		S[1].x * S[0].x * S[0].y + S[1].x * S[0].y * S[1].y + S[1].x * S[0].z * S[2].y +
		S[1].y * S[1].x * S[0].y + S[1].y * S[1].y * S[1].y + S[1].y * S[1].z * S[2].y +
		S[1].z * S[2].x * S[0].y + S[1].z * S[2].y * S[1].y + S[1].z * S[2].z * S[2].y +
		S[2].x * S[0].x * S[0].z + S[2].x * S[0].y * S[1].z + S[2].x * S[0].z * S[2].z +
		S[2].y * S[1].x * S[0].z + S[2].y * S[1].y * S[1].z + S[2].y * S[1].z * S[2].z +
		S[2].z * S[2].x * S[0].z + S[2].z * S[2].y * S[1].z + S[2].z * S[2].z * S[2].z;

	return e;
}

float getSquareRateOfStrain(float3x3 J)
{
	float3x3 S = getStrainRateTensor(J);
	float3x3 Ssq = mul(S, S);
	return Trace3x3(Ssq);
}

// Switch for the measure

float getMeasureFloat(int measure, LineVertex input)
{
	//TODO
	switch (measure)
	{
	case 0: //MEASURE_VELOCITY
		return length(input.vel.xyz);
	case 1: //MEASURE_VELOCITY_Z
		return input.vel.z;
	case 2: //MEASURE_TEMPERATURE
		return input.heat;
	case 3: //MEASURE_VORTICITY
		return length(getVorticity(input.jac));
	case 4: //MEASURE_LAMBDA2
		return getLambda2(input.jac);
	case 5: //MEASURE_QHUNT
		return getQHunt(input.jac);
	case 6: //MEASURE_DELTACHONG
		return getDeltaChong(input.jac);
	case 7: //MEASURE_ENSTROPHY_PRODUCTION
		return getEnstrophyProduction(input.jac);
	case 8: //MEASURE_STRAIN_PRODUCTION
		return getStrainProduction(input.jac);
	case 9: //MEASURE_SQUARE_ROTATION
		return getSquareRotation(input.jac);
	case 10: //MEASURE_SQUARE_RATE_OF_STRAIN
		return getSquareRateOfStrain(input.jac);
	case 11: //MEASURE_TRACE_JJT
		return TraceAAT(input.jac);
	case 12: //MEASURE_PVA
		//not implemented yet
		break;
	case 13: //MEASURE_HEAT_CURRENT
		return length(getHeatCurrent(input.vel, float4(input.heatCurrent, input.heat)));
	case 14: //MEASURE_HEAT_CURRENT_X
		return getHeatCurrent(input.vel, float4(input.heatCurrent, input.heat)).x;
	case 15: //MEASURE_HEAT_CURRENT_Y
		return getHeatCurrent(input.vel, float4(input.heatCurrent, input.heat)).y;
	case 16: //MEASURE_HEAT_CURRENT_Z
		return getHeatCurrent(input.vel, float4(input.heatCurrent, input.heat)).z;
	case 19: //MEASURE_TIME_IN_CURRENT_CELL
		return input.timeInCell[0];
	case 20: // MEASURE_TURBULENT_VISCOSITY
		return getTurbulentViscosity(input.jac, input.vel.xyz);
	}
	return 0.0;
}

float4 getMeasure(LineVertex input)
{
	switch (g_iMeasureMode) {
	case 17: //MEASURE_CURRENT_CELL
		return convertIntToRgb(input.recordedCellIndices[0]);
	case 18: //MEASURE_LONGEST_CELL
		return convertIntToRgb(input.recordedCellIndices[2]);
	}

	float value = getMeasureFloat(g_iMeasureMode, input) * g_fMeasureScale;
	value = (value - g_vTfRange.x) / (g_vTfRange.y - g_vTfRange.x);
	float4 color = g_transferFunction.SampleLevel(SamplerLinear, value, 0);
	return color;
}