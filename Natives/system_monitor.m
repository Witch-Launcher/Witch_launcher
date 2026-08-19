#import "system_monitor.h"

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CoreFoundation/CoreFoundation.h>
#import <mach/mach.h>
#import <mach/mach_host.h>
#import <mach/processor_info.h>
#import <IOKit/IOKitLib.h>

static uint32_t *tmPrevTicks;
static size_t tmPrevTickCount;
static natural_t tmPrevCpuCount;

int tm_cpu_usage(tm_cpu_usage_t *out) {
    if (!out) return -1;

    natural_t cpuCount = 0;
    processor_info_array_t info = NULL;
    mach_msg_type_number_t infoCount = 0;
    kern_return_t kr = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO,
                                           &cpuCount, &info, &infoCount);
    if (kr != KERN_SUCCESS || cpuCount == 0 || info == NULL) {
        if (info) {
            vm_deallocate(mach_task_self(), (vm_address_t)info, infoCount * sizeof(integer_t));
        }
        return -1;
    }

    int n = MIN(cpuCount, TM_MAX_CORES);
    out->coreCount = n;
    out->total = 0;

    processor_cpu_load_info_t load = (processor_cpu_load_info_t)info;
    int stateCount = CPU_STATE_MAX;
    BOOL havePrev = (tmPrevTicks != NULL) && (tmPrevCpuCount == cpuCount) &&
                    (tmPrevTickCount == (size_t)cpuCount * (size_t)stateCount);

    for (int i = 0; i < n; i++) {
        int64_t user = load[i].cpu_ticks[CPU_STATE_USER];
        int64_t system = load[i].cpu_ticks[CPU_STATE_SYSTEM];
        int64_t nice = load[i].cpu_ticks[CPU_STATE_NICE];
        int64_t idle = load[i].cpu_ticks[CPU_STATE_IDLE];

        double totalTicks = (double)(user + system + nice + idle);
        if (havePrev && totalTicks > 0) {
            int64_t du = user - (int64_t)tmPrevTicks[i * stateCount + CPU_STATE_USER];
            int64_t ds = system - (int64_t)tmPrevTicks[i * stateCount + CPU_STATE_SYSTEM];
            int64_t dn = nice - (int64_t)tmPrevTicks[i * stateCount + CPU_STATE_NICE];
            int64_t di = idle - (int64_t)tmPrevTicks[i * stateCount + CPU_STATE_IDLE];
            int64_t dTotal = du + ds + dn + di;
            double pct = dTotal > 0 ? (double)(du + ds + dn) * 100.0 / (double)dTotal : 0.0;
            out->cores[i] = MAX(0.0, MIN(100.0, pct));
        } else {
            out->cores[i] = -1.0;
        }
        out->total += out->cores[i];
    }
    out->total = n > 0 ? out->total / n : 0.0;

    size_t ticksBytes = (size_t)cpuCount * (size_t)stateCount * sizeof(uint32_t);
    uint32_t *newTicks = malloc(ticksBytes);
    if (newTicks) {
        for (int i = 0; i < (int)cpuCount; i++) {
            for (int s = 0; s < stateCount; s++) {
                newTicks[i * stateCount + s] = load[i].cpu_ticks[s];
            }
        }
        free(tmPrevTicks);
        tmPrevTicks = newTicks;
        tmPrevTickCount = (size_t)cpuCount * (size_t)stateCount;
        tmPrevCpuCount = cpuCount;
    }

    vm_deallocate(mach_task_self(), (vm_address_t)info, infoCount * sizeof(integer_t));
    return 0;
}

double tm_cpu_usage_percent(void) {
    tm_cpu_usage_t usage;
    if (tm_cpu_usage(&usage) != 0) {
        return -1.0;
    }
    return usage.total;
}

double tm_gpu_usage_percent(void) {
    double usage = -1.0;

    io_iterator_t iterator = MACH_PORT_NULL;
    if (IOServiceGetMatchingServices(MACH_PORT_NULL, IOServiceMatching("IOGPU"), &iterator) != kIOReturnSuccess) {
        return -1.0;
    }

    for (io_registry_entry_t entry = IOIteratorNext(iterator); entry; entry = IOIteratorNext(iterator)) {
        CFMutableDictionaryRef props = NULL;
        if (IORegistryEntryCreateCFProperties(entry, &props, kCFAllocatorDefault, kNilOptions) == kIOReturnSuccess && props) {
            CFTypeRef perf = CFDictionaryGetValue(props, CFSTR("PerformanceStatistics"));
            if (perf && CFGetTypeID(perf) == CFDictionaryGetTypeID()) {
                CFTypeRef value = CFDictionaryGetValue((CFDictionaryRef)perf, CFSTR("Device Utilization %"));
                if (value && CFGetTypeID(value) == CFNumberGetTypeID()) {
                    CFNumberGetValue((CFNumberRef)value, kCFNumberDoubleType, &usage);
                }
            }
            CFRelease(props);
        }
        IOObjectRelease(entry);
        if (usage >= 0.0) {
            break;
        }
    }
    IOObjectRelease(iterator);

    if (usage < 0.0) {
        return -1.0;
    }
    return usage > 100.0 ? 100.0 : usage;
}

double tm_battery_temperature_celsius(void) {
    double celsius = -1.0;

    io_service_t service = IOServiceGetMatchingService(MACH_PORT_NULL, IOServiceMatching("AppleSmartBattery"));
    if (service == MACH_PORT_NULL) {
        return -1.0;
    }

    CFMutableDictionaryRef props = NULL;
    if (IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, kNilOptions) == kIOReturnSuccess && props) {
        CFTypeRef value = CFDictionaryGetValue(props, CFSTR("Temperature"));
        if (value && CFGetTypeID(value) == CFNumberGetTypeID()) {
            int raw = 0;
            if (CFNumberGetValue((CFNumberRef)value, kCFNumberIntType, &raw)) {
                // Older firmwares report in 0.1°C steps, newer ones in 0.01°C.
                double t = raw > 500 ? (double)raw / 100.0 : (double)raw / 10.0;
                celsius = MAX(0.0, MIN(120.0, t));
            }
        }
        CFRelease(props);
    }
    IOObjectRelease(service);

    return celsius;
}

double tm_battery_percent(void) {
    static BOOL monitoringEnabled = NO;
    if (!monitoringEnabled) {
        UIDevice.currentDevice.batteryMonitoringEnabled = YES;
        monitoringEnabled = YES;
    }
    float level = UIDevice.currentDevice.batteryLevel;
    if (level < 0.0f) {
        return -1.0;
    }
    return MIN(100.0, MAX(0.0, level * 100.0));
}