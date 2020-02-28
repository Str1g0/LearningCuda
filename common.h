#pragma once

#include <string>
#include <vector>
#include <cmath>

#include <Windows.h>

typedef unsigned char byte;

template<typename T>
struct vec2 {
    T x, y;
};

struct color {
    byte r, g, b;
};