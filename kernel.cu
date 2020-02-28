
#include "cuda_runtime.h"
#include "device_launch_parameters.h"

#include <stdio.h>
#include "tga.h"
#include "Stopwatch.h"
#include <limits>

constexpr float PI = 3.1415962f;
constexpr float E  = 2.718281828f;

constexpr size_t        ITERS           = 256;
constexpr float         THRESHOLD       = 6.f;
constexpr float         CTHRESHOLD      = 2.f;
constexpr float         ZOOM            = 2.3f;
constexpr float2        OFFSET          = { 1.7f, 1.2f };

struct mat4x4 {
    float data[16];
    __host__ __device__ 
        float& at(uint8_t x, uint8_t y);
};

__host__ __device__
float& mat4x4::at(uint8_t x, uint8_t y) {
    return data[x * 4 + y];
}

struct mat3x3 {
    float data[9];
    __host__ __device__
        float& at(uint8_t x, uint8_t y);
};

__host__ __device__
float& mat3x3::at(uint8_t x, uint8_t y) {
    return data[x * 3 + y];
}

__host__ __device__ 
byte operator""_b(unsigned long long val)
{
    return static_cast<byte>(val);
}

template<typename T>
__host__ __device__ 
 inline T square(T x) {
    return x * x;
}

template<typename T>
__host__ __device__
inline T inverse(T x) {
    return static_cast<T>(1) / x;
}

__host__ __device__ 
float2 squareComplex(float2 complex) {
    return { square(complex.x) - square(complex.y), 2.f * complex.x * complex.y };
}

__host__ __device__ 
float nextComplexAbs(float2 complex) {
    return square(complex.x) + square(complex.y);
}

#pragma warning(disable : 4838)
void fractalHost(int2 dimensions, color* output)
{
    #pragma omp parallel
    for (size_t i = 0; i < dimensions.x * dimensions.y; ++i)
    {
        size_t x = i / dimensions.y;
        size_t y = i % dimensions.y;

        output[y * dimensions.x + x] = color{ 0_b,  0_b,  0_b };

        float aspectRatio = (float)dimensions.y / (float)dimensions.x;
        float2 point {  (float)x / (float)dimensions.x, 
                        (float)y / (float)dimensions.y};

        point.x *= aspectRatio * ZOOM;
        point.y *= ZOOM;

        point.x -= OFFSET.x;
        point.y -= OFFSET.y;

        float2 z {0.f, 0.f};
        size_t iter = 0;

        for (; iter < ITERS; ++iter)
        {
            z = squareComplex(z);
            z.x += point.x;
            z.y += point.y;

            if (nextComplexAbs(z) > THRESHOLD)
                break;
        }

        if (nextComplexAbs(z) > CTHRESHOLD)
            output[y * dimensions.x + x] = color{ (byte)iter,  0_b,  0_b };
    }
}
#pragma warning(default : 4838)



__global__ void fractalKernel(int2 dimensions, color* output)
{
    int x = (blockIdx.x * blockDim.x) + threadIdx.x;
    int y = (blockIdx.y * blockDim.y) + threadIdx.y;

    output[y * dimensions.x + x] = color{ 0_b,  0_b,  0_b };

    float aspectRatio = (float)dimensions.y / (float)dimensions.x;
    float2 point{ (float)x / (float)dimensions.x, (float)y / (float)dimensions.y };

    point.x *= aspectRatio * ZOOM;
    point.y *= ZOOM;

    point.x -= OFFSET.x;
    point.y -= OFFSET.y;

    float2 z{ 0.f, 0.f };
    size_t iter = 0;

    for (; iter < ITERS; ++iter)
    {
        z = squareComplex(z);
        z.x += point.x;
        z.y += point.y;

        if (nextComplexAbs(z) > THRESHOLD)
            break;
    }

    if (nextComplexAbs(z) > CTHRESHOLD)
        output[y * dimensions.x + x] = color{ (byte)iter,  0_b,  0_b };
}

mat3x3 createGaussianKernel(float theta)
{
    mat3x3 kernel;
    for(int i = 0; i < 3; ++i)
        for (int j = 0; j < 3; ++j)
        {
            kernel.at(i, j) = inverse(2.f * PI * square(theta)) * 
                std::pow(E, (square(i) + square(j)) / (2.f * square(theta)));
        }

    return kernel;
}

__host__ __device__ bool isOutside(int2 point, int2 dimensions) {

    if (point.x > dimensions.x - 1 || point.x < 0)
        return true;

    if (point.y > dimensions.y - 1 || point.y < 0)
        return true;

    return false;
}

__global__ void convoluteKernel(mat3x3 kernel, int2 dimensions, color* input, color* output)
{
    int x = (blockIdx.x * blockDim.x) + threadIdx.x;
    int y = (blockIdx.y * blockDim.y) + threadIdx.y;

    color current {0.f,0.f,0.f};

    for(int i = -1; i < 2; ++i)
        for (int j = -1; j < 2; ++j)
        {
            int2 point{ x,y };
            point.x += i;
            point.y += j;

            if (!isOutside(point, dimensions))
            {
                current.r += input[point.x * dimensions.y + y].r * kernel.at(i + 1, j + 1);
                current.g += input[point.x * dimensions.y + y].g * kernel.at(i + 1, j + 1);
                current.b += input[point.x * dimensions.y + y].b * kernel.at(i + 1, j + 1);
            }
        }

    output[x * dimensions.y + y] = current;
}

int main()
{
    constexpr uint32_t x = 512, 
                       y = 512;

    int2 canvas{ x, y };
    color* data     = nullptr;
    color* blurred  = nullptr; 

    cudaMallocManaged(&data, x * y * sizeof(color));
    cudaMallocManaged(&blurred, x * y * sizeof(color));

    dim3 noThreads = { 16, 16 };
    dim3 noBlocks  = { x / noThreads.x, y / noThreads.y };

    fractalKernel<<<noBlocks, noThreads>>>(canvas, data);
    cudaDeviceSynchronize();

    constexpr float THETA = 1.6f;

    convoluteKernel<<<noBlocks, noThreads>>>(createGaussianKernel(THETA), canvas, data, blurred);
    cudaDeviceSynchronize();

    color* host_data = new color[x * y];

    cudaError_t rc = cudaMemcpy(host_data, blurred, x*y*sizeof(color), cudaMemcpyKind::cudaMemcpyDeviceToHost);
    cudaDeviceSynchronize();

    if (rc > 0)
    {
        fprintf(stderr, "Failed to copy memory from device!\n");
    }

    cudaFree(data);

    //sw.start();
    //fractalHost(canvas, host_data);
    //sw.stop();

    //fprintf(stdout, "CPU time %I64u ms\n", sw.get_time<std::chrono::milliseconds>().count());

    tga fractal(host_data, {x,y});
    fractal.write("test.tga");

    delete[] host_data;
    return 0;
}