#include "MeasuresGPU.h"
#include "cudaUtil.h"
#include "../Renderer/Measures.cuh"
#include "../Renderer/Coords.cuh"
#include "../Renderer/Measures.cuh"

/**
 * Reference: Based on kernel 4 from https://developer.download.nvidia.com/assets/cuda/files/reduction.pdf
 * @param input The array of input values (of size 'sizeOfInput').
 * @param output The output array (of size iceil(numberOfBlocksI, blockSize1D*2)).
 * @param sizeOfInput The number of input values.
 */
 __global__ void calculateMinimum(float* input, float* output, int sizeOfInput, int blockSize1D) {
    extern __shared__ float sdata[];

    unsigned int threadID = threadIdx.x;
    unsigned int i = blockIdx.x * blockDim.x * 2 + threadIdx.x;

    // Copy the data to the shared memory and do the first reduction step.
    if (i + blockDim.x < sizeOfInput){
        sdata[threadID] = fminf(input[i], input[i + blockDim.x]);
    } else if (i < sizeOfInput){
        sdata[threadID] = input[i];
    } else{
        sdata[threadID] = FLT_MAX;
    }
    __syncthreads();

    // Do the reduction in the shared memory.
    for (unsigned int stride = blockDim.x / 2; stride > 0; stride >>= 1) {
        if (threadID < stride) {
            sdata[threadID] = fminf(sdata[threadID], sdata[threadID + stride]);
        }
        __syncthreads();
    }

    // Write the result for this block to global memory.
    if (threadID == 0) {
        output[blockIdx.x] = sdata[0];
    }
}

/**
 * Reference: Based on kernel 4 from https://developer.download.nvidia.com/assets/cuda/files/reduction.pdf
 * @param input The array of input values (of size 'sizeOfInput').
 * @param output The output array (of size iceil(numberOfBlocksI, blockSize1D*2)).
 * @param sizeOfInput The number of input values.
 */
 __global__ void calculateMaximum(float* input, float* output, int sizeOfInput, int blockSize1D) {
    extern __shared__ float sdata[];

    unsigned int threadID = threadIdx.x;
    unsigned int i = blockIdx.x * blockDim.x * 2 + threadIdx.x;

    // Copy the data to the shared memory and do the first reduction step.
    if (i + blockDim.x < sizeOfInput){
        sdata[threadID] = fmaxf(input[i], input[i + blockDim.x]);
    } else if (i < sizeOfInput){
        sdata[threadID] = input[i];
    } else{
        sdata[threadID] = -FLT_MAX;
    }
    __syncthreads();

    // Do the reduction in the shared memory.
    for (unsigned int stride = blockDim.x / 2; stride > 0; stride >>= 1) {
        if (threadID < stride) {
            sdata[threadID] = fmaxf(sdata[threadID], sdata[threadID + stride]);
        }
        __syncthreads();
    }

    // Write the result for this block to global memory.
    if (threadID == 0) {
        output[blockIdx.x] = sdata[0];
    }
}

inline int iceil(int x, int y)
{
    return 1 + ((x - 1) / y);
}

texture<float4, cudaTextureType3D, cudaReadModeElementType> texVolume;

/*template<eMeasureSource source>
__device__ inline float getMeasureFromVolume_Preprocessor(eMeasure measure, const float3& pos, const float3& h);

template<>
__device__ inline float getMeasureFromVolume_Preprocessor<MEASURE_SOURCE_RAW>(eMeasure measure, const float3& pos, const float3& h) {
	float4 vel4 = make_floatn<float4, float4>(tex3D(texVolume, pos.x, pos.y, pos.z));
	return getMeasureFromRaw(measure, vel4);
}

__device__ inline float3 sampleScalarGradient_Preprocessor(float3 coord, const float3& h)
{
	// default implementation: just get derivatives in x, y, z
	float3 grad;

	// derivative in x direction
	float4 dx = sampleVolumeDerivativeX<F, float4, float4>(tex, coord, h);
	grad.x = dx.w;

	// derivative in y direction
	float4 dy = sampleVolumeDerivativeY<F, float4, float4>(tex, coord, h);
	grad.y = dy.w;

	// derivative in z direction
	float4 dz = sampleVolumeDerivativeZ<F, float4, float4>(tex, coord, h);
	grad.z = dz.w;


template<>
__device__ inline float getMeasureFromVolume_Preprocessor<MEASURE_SOURCE_HEAT_CURRENT>(eMeasure measure, const float3& pos, const float3& h) {
	float3 heatCurrent;
	return getMeasureFromHeatCurrent(measure, heatCurrent);
}

template<>
__device__ inline float getMeasureFromVolume_Preprocessor<MEASURE_SOURCE_JACOBIAN>(eMeasure measure, const float3& pos, const float3& h) {
	float4 vel4 = make_floatn<float4, float4>(tex3D(texVolume, pos.x, pos.y, pos.z));
	float3x3 jacobian;
	return getMeasureFromJac(measure, jacobian);
}

/*template <eTextureFilterMode F>
struct getMeasureFromVolume_Impl2<MEASURE_SOURCE_RAW, F, MEASURE_COMPUTE_ONTHEFLY>
{
	__device__ static inline float exec(eMeasure measure, texture<float4, cudaTextureType3D, cudaReadModeElementType> tex, float3 pos, float3 h)
	{
		float4 vel4 = make_floatn<float4, float4>(tex3D(texVolume, x, y, z));
		return getMeasureFromRaw(measure, vel4);
	}
};

template <eTextureFilterMode F>
struct getMeasureFromVolume_Impl2<MEASURE_SOURCE_HEAT_CURRENT, F, MEASURE_COMPUTE_ONTHEFLY>
{
	__device__ static inline float exec(eMeasure measure, texture<float4, cudaTextureType3D, cudaReadModeElementType> tex, float3 pos, float3 h)
	{
		float3 heatCurrent = getHeatCurrent<F>(tex, pos, h);
		return getMeasureFromHeatCurrent(measure, heatCurrent);
	}
};

template <eTextureFilterMode F>
struct getMeasureFromVolume_Impl2<MEASURE_SOURCE_JACOBIAN, F, MEASURE_COMPUTE_ONTHEFLY>
{
	__device__ static inline float exec(eMeasure measure, texture<float4, cudaTextureType3D, cudaReadModeElementType> tex, float3 pos, float3 h)
	{
		float3x3 jacobian = getJacobian<F>(tex, pos, h);
		return getMeasureFromJac(measure, jacobian);
	}
};*/

template <eMeasureSource measureSource>
__global__ void computeMeasuresKernel(
        int sizeX, int sizeY, int sizeZ, int brickOverlap,
        const float3& h, eMeasure measure,
        float* minValueReductionArray, float* maxValueReductionArray)
{
	int i = blockIdx.x * blockDim.x + threadIdx.x;
	int j = blockIdx.y * blockDim.y + threadIdx.y;
	int k = blockIdx.z * blockDim.z + threadIdx.z;
	int x = i + brickOverlap;
    int y = j + brickOverlap;
    int z = k + brickOverlap;

    if (x < sizeX - brickOverlap && y < sizeY - brickOverlap && z < sizeZ - brickOverlap) {
        // Sample at the voxel centers
		//float3 pos{ (x + 0.5f) / float(sizeX), (y + 0.5f) / float(sizeY), (z + 0.5f) / float(sizeZ) };
		//float3 pos{ x + 0.5f, y + 0.5f, z + 0.5f };
		float3 pos{ 0.0f, 0.0f, 0.0f };
		//float value = getMeasure<measureSource, TEXTURE_FILTER_LINEAR, MEASURE_COMPUTE_ONTHEFLY>(
		//	measure, texVolume, pos, h, 1.0f);
		float4 vel4 = sampleVolume<TEXTURE_FILTER_LINEAR, float4, float4>(texVolume, pos);
		float value = getMeasureFromRaw(measure, vel4);
		//float value = getMeasureFromVolume_Impl2<measureSource, TEXTURE_FILTER_LINEAR, MEASURE_COMPUTE_ONTHEFLY>::exec(measure, texVolume, pos, h);

		int reductionWriteIndex = i + (j + k * (sizeY - 2 * brickOverlap)) * (sizeX - 2 * brickOverlap);
		minValueReductionArray[reductionWriteIndex] = value;
        maxValueReductionArray[reductionWriteIndex] = value;
    }
}

#include <cmath>
#include <algorithm>

void reduceMeasureArray(
        float& minValue, float& maxValue,
        float* reductionArrayMin0, float* reductionArrayMin1,
        float* reductionArrayMax0, float* reductionArrayMax1,
        int sizeX, int sizeY, int sizeZ, int brickOverlap)
{
    const int BLOCK_SIZE = 256;
    int numBlocks = (sizeX-2*brickOverlap)*(sizeY-2*brickOverlap)*(sizeZ-2*brickOverlap);
    int inputSize;

    if (numBlocks == 0) {
        return;
    }

	float* cpuValues = new float[numBlocks];
	cudaMemcpy(cpuValues, reductionArrayMin0, sizeof(float) * numBlocks, cudaMemcpyDeviceToHost);
	float cpuMin = 10000.0f;
	float cpuMax = -10000.0f;
	for (int i = 0; i < numBlocks; i++) {
		cpuMin = std::min(cpuValues[i], cpuMin);
		cpuMax = std::max(cpuValues[i], cpuMax);
	}
	delete[] cpuValues;


    float* minReductionInput;
    float* maxReductionInput;
    float* minReductionOutput;
    float* maxReductionOutput;

    int iteration = 0;
    while (numBlocks > 1) {
        inputSize = numBlocks;
        numBlocks = iceil(numBlocks, BLOCK_SIZE*2);

        if (iteration % 2 == 0) {
            minReductionInput = reductionArrayMin0;
            maxReductionInput = reductionArrayMax0;
            minReductionOutput = reductionArrayMin1;
            maxReductionOutput = reductionArrayMax1;
        } else {
            minReductionInput = reductionArrayMin1;
            maxReductionInput = reductionArrayMax1;
            minReductionOutput = reductionArrayMin0;
            maxReductionOutput = reductionArrayMax0;
        }

        int sharedMemorySize = BLOCK_SIZE * sizeof(float);
		calculateMinimum<<<numBlocks, BLOCK_SIZE, sharedMemorySize>>>(
			minReductionInput, minReductionOutput, inputSize, BLOCK_SIZE);
		calculateMaximum<<<numBlocks, BLOCK_SIZE, sharedMemorySize>>>(
			maxReductionInput, maxReductionOutput, inputSize, BLOCK_SIZE);

        iteration++;
    }

    cudaMemcpy(&minValue, minReductionOutput, sizeof(float), cudaMemcpyDeviceToHost);
    cudaMemcpy(&maxValue, maxReductionOutput, sizeof(float), cudaMemcpyDeviceToHost);
}

MinMaxMeasureGPUHelperData::MinMaxMeasureGPUHelperData(size_t sizeX, size_t sizeY, size_t sizeZ, size_t brickOverlap)
{
	cudaChannelFormatDesc channelDesc;
	channelDesc = cudaCreateChannelDesc<float4>();
    int reductionArraySize = (sizeX - 2*brickOverlap)*(sizeY - 2*brickOverlap)*(sizeZ - 2*brickOverlap);
    cudaSafeCall(cudaMalloc(&reductionArrayMin0, reductionArraySize*sizeof(float)));
    cudaSafeCall(cudaMalloc(&reductionArrayMin1, reductionArraySize*sizeof(float)));
    cudaSafeCall(cudaMalloc(&reductionArrayMax0, reductionArraySize*sizeof(float)));
    cudaSafeCall(cudaMalloc(&reductionArrayMax1, reductionArraySize*sizeof(float)));
    cudaSafeCall(cudaMalloc3DArray(&textureArray, &channelDesc, make_cudaExtent(sizeX, sizeY, sizeZ), cudaArraySurfaceLoadStore));
    cpuData = new float[sizeX*sizeY*sizeZ*4]; // 4 channels
}

MinMaxMeasureGPUHelperData::~MinMaxMeasureGPUHelperData()
{
    cudaSafeCall(cudaFreeArray(textureArray));
    cudaSafeCall(cudaFree(reductionArrayMin0));
    cudaSafeCall(cudaFree(reductionArrayMin1));
    cudaSafeCall(cudaFree(reductionArrayMax0));
    cudaSafeCall(cudaFree(reductionArrayMax1));
    delete[] cpuData;
}

void computeMeasureMinMaxGPU(
        VolumeTextureCPU& texCPU, const vec3& h,
        eMeasureSource measureSource, eMeasure measure,
        MinMaxMeasureGPUHelperData* helperData,
        float& minVal, float& maxVal)
{
    texVolume.addressMode[0] = cudaAddressModeClamp;
    texVolume.addressMode[1] = cudaAddressModeClamp;
    texVolume.addressMode[2] = cudaAddressModeClamp;
    texVolume.normalized = false;
    texVolume.filterMode = cudaFilterModeLinear;    


    cudaArray* textureArray = helperData->textureArray;
    int sizeX = texCPU.getSizeX();
    int sizeY = texCPU.getSizeY();
    int sizeZ = texCPU.getSizeZ();
    int brickOverlap = texCPU.getBrickOverlap();

    float* cpuData = helperData->cpuData;
    const std::vector<std::vector<float>>& channelData = texCPU.getChannelData();
    size_t n = channelData.at(0).size();
    for (int i = 0; i < n; i++) {
        for (int c = 0; c < 4; c++) {
            cpuData[i*4 + c] = channelData.at(c).at(i);
        }
    }

    // Upload the channel data to the GPU
	cudaMemcpy3DParms memcpyParams = { 0 };
	memcpyParams.srcPtr   = make_cudaPitchedPtr(cpuData, sizeX * 4 * sizeof(float), sizeX, sizeY);
	memcpyParams.dstArray = textureArray;
	memcpyParams.extent   = make_cudaExtent(sizeX, sizeY, sizeZ);
	memcpyParams.kind     = cudaMemcpyHostToDevice;

    cudaSafeCall(cudaMemcpy3D(&memcpyParams));
	cudaSafeCall(cudaBindTextureToArray(texVolume, textureArray));

    dim3 dimBlock(32, 4, 1);
    dim3 dimGrid(
        iceil(sizeX-2*brickOverlap, dimBlock.x),
        iceil(sizeY-2*brickOverlap, dimBlock.y),
        iceil(sizeZ-2*brickOverlap, dimBlock.z));
	//cuCtxSynchronize();

    float3 h_cu{h.x, h.y, h.z};
	switch (measureSource) {
	case MEASURE_SOURCE_RAW:
		computeMeasuresKernel<MEASURE_SOURCE_RAW><<<dimGrid, dimBlock>>>(
			sizeX, sizeY, sizeZ, brickOverlap, h_cu, measure,
			helperData->reductionArrayMin0, helperData->reductionArrayMax0);
		break;
	case MEASURE_SOURCE_HEAT_CURRENT:
		computeMeasuresKernel<MEASURE_SOURCE_HEAT_CURRENT><<<dimGrid, dimBlock>>>(
			sizeX, sizeY, sizeZ, brickOverlap, h_cu, measure,
			helperData->reductionArrayMin0, helperData->reductionArrayMax0);
		break;
	case MEASURE_SOURCE_JACOBIAN:
		computeMeasuresKernel<MEASURE_SOURCE_JACOBIAN><<<dimGrid, dimBlock>>>(
			sizeX, sizeY, sizeZ, brickOverlap, h_cu, measure,
			helperData->reductionArrayMin0, helperData->reductionArrayMax0);
		break;
	}

	//cuCtxSynchronize();
	cudaDeviceSynchronize();

    reduceMeasureArray(
        minVal, maxVal,
		helperData->reductionArrayMin0, helperData->reductionArrayMin1,
		helperData->reductionArrayMax0, helperData->reductionArrayMax1,
        sizeX, sizeY, sizeZ, brickOverlap);

	cudaDeviceSynchronize();

    // Clean-up
    cudaSafeCall(cudaUnbindTexture(texVolume));
}