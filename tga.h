#pragma once

#include "common.h"
#include <fstream>
#include <cinttypes>

class tga
{
    static constexpr byte NO_COMP = 3;

    vec2<size_t>        m_size;
    std::vector<color>  m_data;

    #pragma pack(1)
    struct header {

        byte     idLen;
        byte     colorMap;
        byte     imgType;
        uint16_t cmapBeg;
        uint16_t cmapLen;
        byte     cmapBits;
        uint16_t x0;
        uint16_t y0;
        uint16_t width;
        uint16_t height;
        byte     bitsPerPixel;
        byte     imgDesc;
    };

    static constexpr int size = sizeof(header);

    public:

        tga(color* data, vec2<size_t> size);
        bool write(std::string const& file);
};