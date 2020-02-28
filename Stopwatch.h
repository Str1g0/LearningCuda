#pragma once

#include "common.h"
#include <chrono>

typedef std::conditional<std::chrono::high_resolution_clock::is_steady, 
                         std::chrono::high_resolution_clock, 
                         std::chrono::steady_clock>::type hclock;

class stopwatch
{
    hclock::time_point m_start;
    hclock::time_point m_end;

    hclock::duration m_lastTime;

    bool m_isRunning{ false };

    public:

        bool start();
        bool stop();

        template<typename T = hclock::duration>
        T get_time();

};

template<typename T>
inline T stopwatch::get_time()
{
    return std::chrono::duration_cast<T>(m_lastTime);
}
