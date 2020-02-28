#include "tga.h"

tga::tga(color* data, vec2<size_t> size):
    m_size(size)
{
    if (data)
    {
        size_t dataSize = size.x * size.y * NO_COMP;

        m_data.resize(dataSize);
        std::memcpy(m_data.data(), data, dataSize);
    }

}

bool tga::write(std::string const& file)
{
    header imgHeader;
    ZeroMemory(&imgHeader, sizeof(header));

    imgHeader.imgType       = 2;
    imgHeader.width         = m_size.x;
    imgHeader.height        = m_size.y;
    imgHeader.bitsPerPixel  = 24;

    std::ofstream img(file, std::ios::binary | std::ios::trunc);

    img.write((const char*)&imgHeader, sizeof(header));

    for (auto color : m_data)
    {
        img.put(color.b);
        img.put(color.g);
        img.put(color.r);
    }

    return true;
}
