#ifndef __TUM3D__PARTICLERENDERPARAMS_H__
#define __TUM3D__PARTICLERENDERPARAMS_H__


#include <global.h>

#include <ConfigFile.h>
#include <Vec.h>
#include <D3D11.h>

#include "LineRenderMode.h"
#include "ParticleRenderMode.h"
#include "LineColorMode.h"
#include "Measure.h"

struct ParticleRenderParams
{
	ParticleRenderParams();

	void Reset();

	void ApplyConfig(const ConfigFile& config);
	void WriteConfig(ConfigFile& config) const;

	bool m_linesEnabled;

	eLineRenderMode m_lineRenderMode;
	float m_ribbonWidth;
	float m_tubeRadius;

	float m_particleSize;
	float m_particleTransparency;
	eParticleRenderMode m_particleRenderMode;

	bool  m_tubeRadiusFromVelocity;
	float m_referenceVelocity;

	eLineColorMode m_lineColorMode;

	tum3D::Vec4f m_color0;
	tum3D::Vec4f m_color1;
	ID3D11ShaderResourceView* m_pColorTexture;
	eMeasure m_measure;
	float m_measureScale;
	ID3D11ShaderResourceView* m_pTransferFunction;

	bool  m_timeStripes;
	float m_timeStripeLength;

	ID3D11ShaderResourceView* m_pSliceTexture;
	bool m_showSlice;
	float m_slicePosition;
	float m_sliceAlpha;

	bool operator==(const ParticleRenderParams& rhs) const;
	bool operator!=(const ParticleRenderParams& rhs) const;
};


#endif
