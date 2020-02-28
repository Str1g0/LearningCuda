#include "Stopwatch.h"

bool stopwatch::start()
{
    if (m_isRunning)
        return false;

    m_isRunning = true;
    m_start = hclock::now();
}

bool stopwatch::stop()
{
    if(!m_isRunning)
        return false;

    m_isRunning = false;
    m_end = hclock::now();
    m_lastTime = m_end - m_start;
}
