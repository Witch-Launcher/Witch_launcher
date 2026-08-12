#ifndef SYSTEM_MONITOR_H
#define SYSTEM_MONITOR_H

#include <stdint.h>

#define TM_MAX_CORES 24

typedef struct {
    double total;                  // average CPU usage across cores, 0-100
    double cores[TM_MAX_CORES];    // per-core usage, 0-100
    int coreCount;                 // number of usable values in cores[]
} tm_cpu_usage_t;

// Samples CPU usage. Returns 0 on success, -1 on failure.
// Must be called a second time (a few hundred ms apart) for real values;
// the first call reports -1 (no data yet).
int tm_cpu_usage(tm_cpu_usage_t *out);

// Convenience wrapper returning the average usage (0-100), or -1 on failure.
double tm_cpu_usage_percent(void);

// Samples GPU utilization via IOKit IOGPU "Device Utilization %".
// Returns 0-100, or -1 when unavailable (unsupported device or GPU idle
// without a statistics entry).
double tm_gpu_usage_percent(void);

// Samples battery temperature via IOKit AppleSmartBattery "Temperature".
// Returns degrees Celsius (handles both 0.1 and 0.01 granularity), or -1
// when unavailable.
double tm_battery_temperature_celsius(void);

// Samples battery charge level via UIDevice. Returns 0-100, or -1 when
// unavailable.
double tm_battery_percent(void);

#endif