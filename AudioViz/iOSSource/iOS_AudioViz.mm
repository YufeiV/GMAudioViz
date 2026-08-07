// SPDX-License-Identifier: GPL-2.0-or-later

#import "iOS_AudioViz.h"
#import <dlfcn.h>

static void* dylibHandle = NULL;

@implementation AudioViz

- (void) Init {
    NSBundle* bundle = [NSBundle mainBundle];
    NSString* bundlePath = [bundle executablePath];
    NSString* bundleDir = [bundlePath stringByDeletingLastPathComponent];
    NSString* libPath_device = [bundleDir stringByAppendingPathComponent:@"games/AudioViz_iosdevice.dylib"];
    NSString* libPath_emu = [bundleDir stringByAppendingPathComponent:@"games/AudioViz_iosemulator.dylib"];

    dylibHandle = dlopen([libPath_device UTF8String], RTLD_LAZY);
    if (dylibHandle == NULL) {
        NSLog(@"yoyo: AudioViz iOS error loading dynamic library (device): %s", dlerror());
        dylibHandle = dlopen([libPath_emu UTF8String], RTLD_LAZY);
        if (dylibHandle == NULL) {
            NSLog(@"yoyo: AudioViz iOS error loading dynamic library (emulator): %s", dlerror());
        } else {
            NSLog(@"yoyo: AudioViz iOS dylib opened OK (emulator)");
        }
    } else {
        NSLog(@"yoyo: AudioViz iOS dylib opened OK (device)");
    }
}

static void* AV_SYM(const char* name) {
    if (dylibHandle == NULL) {
        NSLog(@"yoyo: AudioViz iOS dylib handle not opened OK");
        return NULL;
    }
    void* sym = dlsym(dylibHandle, name);
    if (sym == NULL) NSLog(@"yoyo: AudioViz iOS symbol not found: %s", name);
    return sym;
}

#define AV_CALL0(ret, name) \
    -(ret) AudioViz_##name { \
        ret (*fn)(void) = (ret(*)(void))AV_SYM("AudioViz_" #name); \
        return fn ? fn() : nil; \
    }

#define AV_CALL4_FFT(name) \
    -(double) AudioViz_##name:(char*)a frames:(double)b fftSize:(double)c out:(char*)d { \
        double (*fn)(char*, double, double, char*) = (double(*)(char*, double, double, char*))AV_SYM("AudioViz_" #name); \
        return fn ? fn(a, b, c, d) : -1; \
    }

#define AV_CALL4_SEGMENTS(name) \
    -(double) AudioViz_##name:(char*)a frames:(double)b segments:(double)c out:(char*)d { \
        double (*fn)(char*, double, double, char*) = (double(*)(char*, double, double, char*))AV_SYM("AudioViz_" #name); \
        return fn ? fn(a, b, c, d) : -1; \
    }

#define AV_CALL4_BANDS(name) \
    -(double) AudioViz_##name:(char*)a bins:(double)b bandCount:(double)c out:(char*)d { \
        double (*fn)(char*, double, double, char*) = (double(*)(char*, double, double, char*))AV_SYM("AudioViz_" #name); \
        return fn ? fn(a, b, c, d) : -1; \
    }

#define AV_CALL4_WINDOW(name) \
    -(double) AudioViz_##name:(char*)a frames:(double)b windowType:(double)c out:(char*)d { \
        double (*fn)(char*, double, double, char*) = (double(*)(char*, double, double, char*))AV_SYM("AudioViz_" #name); \
        return fn ? fn(a, b, c, d) : -1; \
    }

#define AV_CALL4_CHANNELS(name) \
    -(double) AudioViz_##name:(char*)a frames:(double)b channels:(double)c out:(char*)d { \
        double (*fn)(char*, double, double, char*) = (double(*)(char*, double, double, char*))AV_SYM("AudioViz_" #name); \
        return fn ? fn(a, b, c, d) : -1; \
    }

#define AV_CALL3(name) \
    -(double) AudioViz_##name:(char*)a frames:(double)b out:(char*)c { \
        double (*fn)(char*, double, char*) = (double(*)(char*, double, char*))AV_SYM("AudioViz_" #name); \
        return fn ? fn(a, b, c) : -1; \
    }

#define AV_CALL_DBL(name) \
    -(double) AudioViz_##name:(double)h { \
        double (*fn)(double) = (double(*)(double))AV_SYM("AudioViz_" #name); \
        return fn ? fn(h) : -1; \
    }

AV_CALL0(NSString*, GetVersion)
AV_CALL4_FFT(AnalyzeSpectrum)
AV_CALL4_FFT(AnalyzeSpectrumDB)
AV_CALL4_SEGMENTS(WaveformPeaks)
AV_CALL4_BANDS(Bands)
AV_CALL4_BANDS(BandsLog)
AV_CALL4_BANDS(VisualBands)
AV_CALL3(Level)
AV_CALL4_WINDOW(ApplyWindow)
AV_CALL4_CHANNELS(Downmix)

- (double) AudioViz_FileOpen:(char*)path {
    double (*fn)(char*) = (double(*)(char*))AV_SYM("AudioViz_FileOpen");
    return fn ? fn(path) : -1;
}

AV_CALL_DBL(FileFrames)
AV_CALL_DBL(FileSampleRate)
AV_CALL_DBL(FileChannels)

- (double) AudioViz_FileRead:(double)h startFrame:(double)s frames:(double)f out:(char*)o {
    double (*fn)(double, double, double, char*) = (double(*)(double, double, double, char*))AV_SYM("AudioViz_FileRead");
    return fn ? fn(h, s, f, o) : -1;
}

- (double) AudioViz_FileSpectrum:(double)h startFrame:(double)s fftSize:(double)n out:(char*)o {
    double (*fn)(double, double, double, char*) = (double(*)(double, double, double, char*))AV_SYM("AudioViz_FileSpectrum");
    return fn ? fn(h, s, n, o) : -1;
}

AV_CALL_DBL(FileClose)

@end
