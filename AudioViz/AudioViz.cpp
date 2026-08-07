// SPDX-License-Identifier: GPL-2.0-or-later
//
// ============================================================================
//  AudioViz.cpp - GameMaker Studio 2 native extension core (C++)
// ----------------------------------------------------------------------------
//  Provides audio analysis primitives (FFT spectrum, waveform peaks, band
//  aggregation, level metering, window functions) and audio file decoding
//  (libsndfile) for audio visualization in GML.
//
//  Linked dependencies (static):
//    - FFTW 3        : fast Fourier transform
//    - libsndfile    : audio file decode (WAV / AIFF / FLAC / OGG / MP3 ...)
//
//  GML boundary rules (see skill references/cpp.md):
//    - Buffers cross the boundary as hex address strings.
//    - Every exported symbol must be registered in the GMS extension editor
//      with an identical External Name, return type and argument types.
// ============================================================================

#ifdef _WIN64
    #define GMS2EXPORT extern "C" __declspec(dllexport)
#else
    #define GMS2EXPORT extern "C"
#endif

#define NOMINMAX
#define _USE_MATH_DEFINES

#ifdef _WIN32
    #include <windows.h>            // MultiByteToWideChar (UTF-8 path support)
#endif

#include <cstring>
#include <string>
#include <vector>
#include <cmath>
#include <cstdint>
#include <algorithm>
#include <unordered_map>
#include <mutex>
#include <memory>

#include <fftw3.h>
#include <sndfile.h>

using namespace std;

// ---------------------------------------------------------------------------
//  Status / error codes (negative values are errors, >= 0 is success/count)
// ---------------------------------------------------------------------------
enum AudioVizStatus {
    AV_OK             = 0,
    AV_ERR_ADDRESS    = -1,   // invalid buffer address string
    AV_ERR_SIZE       = -2,   // invalid frame / segment / band count
    AV_ERR_FFT        = -3,   // invalid FFT size or FFT failure
    AV_ERR_WINDOW     = -4,   // invalid window type
    AV_ERR_NO_FILE    = -5,   // file handle not open
    AV_ERR_FILE_IO    = -6    // file open / read failure
};

// ---------------------------------------------------------------------------
//  Buffer address helper (required on every platform)
// ---------------------------------------------------------------------------
char* getGMSBuffAddress(char* _GMSBuffPtrStr) {
    /*
        @description    Converts a GMS buffer address string to a usable pointer in C++.
        @params         {char*} _GMSBuffPtrStr - The ptr to a GMS buffer as a string.
        @return         {char*} The pointer to the buffer. Now functions like memcpy will work.
    */
    size_t GMSBuffLongPointer = stoull(_GMSBuffPtrStr, NULL, 16); // hex string -> int64
    return (char*)GMSBuffLongPointer;                              // int64 -> char*
}

// Exception-safe variant: never let an exception cross the extern "C" boundary.
static char* buffAddrSafe(char* _addrStr) {
    if (_addrStr == nullptr) return nullptr;
    try {
        return getGMSBuffAddress(_addrStr);
    } catch (...) {
        return nullptr;
    }
}

// ---------------------------------------------------------------------------
//  FFTW plan cache (one r2c plan + scratch buffers per FFT size)
// ---------------------------------------------------------------------------
struct FFTPlan {
    int          n = 0;
    fftw_plan    plan = nullptr;
    double*      in  = nullptr;   // n doubles
    fftw_complex* out = nullptr;  // n/2+1 complex

    ~FFTPlan() {
        if (plan) fftw_destroy_plan(plan);
        if (in)   fftw_free(in);
        if (out)  fftw_free(out);
    }
};

static unordered_map<int, unique_ptr<FFTPlan>> g_fftPlans;
static mutex g_fftMutex;

static FFTPlan* getFFTPlan(int n) {
    lock_guard<mutex> lock(g_fftMutex);
    auto it = g_fftPlans.find(n);
    if (it != g_fftPlans.end()) return it->second.get();

    auto p = make_unique<FFTPlan>();
    p->n = n;
    p->in  = (double*)fftw_malloc(sizeof(double) * (size_t)n);
    p->out = (fftw_complex*)fftw_malloc(sizeof(fftw_complex) * (size_t)(n / 2 + 1));
    p->plan = fftw_plan_dft_r2c_1d(n, p->in, p->out, FFTW_ESTIMATE);
    if (!p->plan) return nullptr;

    FFTPlan* raw = p.get();
    g_fftPlans[n] = std::move(p);
    return raw;
}

// ---------------------------------------------------------------------------
//  Core analysis routines (float32 in/out, mono)
// ---------------------------------------------------------------------------

// Hann window coefficient (0..1)
static double hannWeight(int i, int n) {
    return 0.5 - 0.5 * cos(2.0 * M_PI * (double)i / (double)(n - 1));
}

// FFT magnitude spectrum. Applies a Hann window internally and zero-pads when
// frames < fftSize. Linear magnitudes are normalized so a full-scale sine wave
// reads ~1.0; dB output is 20*log10(mag) clamped to [-120, 0].
static int analyzeSpectrum(const float* samples, int frames, int fftSize, float* out, bool toDb) {
    if (!samples || !out || frames <= 0) return AV_ERR_SIZE;
    if (fftSize < 16 || (fftSize & (fftSize - 1)) != 0) return AV_ERR_FFT;

    FFTPlan* p = getFFTPlan(fftSize);
    if (!p || !p->plan) return AV_ERR_FFT;

    for (int i = 0; i < fftSize; ++i) {
        double w = hannWeight(i, fftSize);
        p->in[i] = (i < frames) ? (double)samples[i] * w : 0.0;
    }
    fftw_execute_dft_r2c(p->plan, p->in, p->out);

    int bins = fftSize / 2 + 1;
    double norm = 2.0 / (double)fftSize;
    for (int k = 0; k < bins; ++k) {
        double re = p->out[k][0], im = p->out[k][1];
        double mag = sqrt(re * re + im * im) * norm;
        if (k == 0) mag *= 0.5; // DC is not doubled
        if (toDb) {
            double db = 20.0 * log10(mag + 1e-9);
            if (db < -120.0) db = -120.0;
            out[k] = (float)db;
        } else {
            out[k] = (float)mag;
        }
    }
    return bins;
}

// Min/max peak pairs per segment (2 floats per segment: min, max).
static int waveformPeaks(const float* samples, int frames, int segments, float* out) {
    if (!samples || !out || frames <= 0 || segments <= 0) return AV_ERR_SIZE;
    for (int seg = 0; seg < segments; ++seg) {
        int start = (int)((int64_t)frames * seg / segments);
        int end   = (int)((int64_t)frames * (seg + 1) / segments);
        if (end <= start) end = start + 1;
        float mn = samples[start], mx = samples[start];
        for (int i = start + 1; i < end; ++i) {
            if (samples[i] < mn) mn = samples[i];
            if (samples[i] > mx) mx = samples[i];
        }
        out[seg * 2]     = mn;
        out[seg * 2 + 1] = mx;
    }
    return segments;
}

// Aggregate a spectrum buffer into bands. Linear mode uses equal-width groups;
// log mode uses log-spaced groups (skipping the DC bin), closer to musical ears.
static int bandsFromSpectrum(const float* spec, int bins, int bandCount, float* out, bool logSpacing) {
    if (!spec || !out || bins <= 0 || bandCount <= 0 || bandCount > bins) return AV_ERR_SIZE;

    if (!logSpacing) {
        for (int b = 0; b < bandCount; ++b) {
            int s = bins * b / bandCount;
            int e = bins * (b + 1) / bandCount;
            if (e <= s) e = s + 1;
            double sum = 0.0;
            for (int i = s; i < e; ++i) sum += spec[i];
            out[b] = (float)(sum / (double)(e - s));
        }
    } else {
        int lo = 1, hi = bins - 1;
        if (hi <= lo) { // tiny spectra: fall back to linear
            for (int b = 0; b < bandCount; ++b) out[b] = spec[b];
            return bandCount;
        }
        double logLo = log((double)lo);
        double logHi = log((double)hi);
        for (int b = 0; b < bandCount; ++b) {
            double t0 = (double)b / bandCount;
            double t1 = (double)(b + 1) / bandCount;
            int s = (int)floor(exp(logLo + t0 * (logHi - logLo)));
            int e = (int)ceil(exp(logLo + t1 * (logHi - logLo)));
            if (s < lo) s = lo;
            if (e > hi) e = hi;
            if (e <= s) e = s + 1;
            double sum = 0.0;
            for (int i = s; i < e; ++i) sum += spec[i];
            out[b] = (float)(sum / (double)(e - s));
        }
    }
    return bandCount;
}

// Visual-oriented log bands. This preserves the analytical Bands/BandsLog
// functions while providing a more reactive signal for animation: RMS catches
// broadband energy and peak prevents tonal partials from being averaged away.
static int visualBandsFromSpectrum(const float* spec, int bins, int bandCount, float* out) {
    if (!spec || !out || bins <= 1 || bandCount <= 0 || bandCount > bins) return AV_ERR_SIZE;

    int lo = 1;
    int hiExclusive = bins;
    double logLo = log((double)lo);
    double logHi = log((double)(hiExclusive - 1));

    for (int b = 0; b < bandCount; ++b) {
        double t0 = (double)b / (double)bandCount;
        double t1 = (double)(b + 1) / (double)bandCount;
        int s = (int)floor(exp(logLo + t0 * (logHi - logLo)));
        int e = (int)ceil(exp(logLo + t1 * (logHi - logLo)));
        if (s < lo) s = lo;
        if (e > hiExclusive) e = hiExclusive;
        if (e <= s) e = s + 1;

        double sumSq = 0.0;
        double peak = 0.0;
        int count = e - s;
        for (int i = s; i < e; ++i) {
            double v = spec[i];
            if (v < 0.0) v = 0.0;
            sumSq += v * v;
            if (v > peak) peak = v;
        }

        double rms = sqrt(sumSq / (double)count);
        double v = max(rms * 1.8, peak * 0.75);
        double center = ((double)b + 0.5) / (double)bandCount;
        double bassLift = 1.0 + 0.45 * max(0.0, 1.0 - center * 3.0);
        double airLift = 1.0 + 0.20 * max(0.0, (center - 0.65) / 0.35);
        out[b] = (float)min(v * bassLift * airLift, 4.0);
    }

    return bandCount;
}

// Level metering: writes 4 floats - [peak, rms, meanAbs, dcOffset].
static int levelFromSamples(const float* samples, int frames, float* out) {
    if (!samples || !out || frames <= 0) return AV_ERR_SIZE;
    double peak = 0.0, absSum = 0.0, sqSum = 0.0, dcSum = 0.0;
    for (int i = 0; i < frames; ++i) {
        double s = samples[i];
        double a = fabs(s);
        if (a > peak) peak = a;
        absSum += a;
        sqSum  += a * a;
        dcSum  += s;
    }
    out[0] = (float)peak;
    out[1] = (float)sqrt(sqSum / frames);
    out[2] = (float)(absSum / frames);
    out[3] = (float)(dcSum / frames);
    return 4;
}

// Apply a window in place (in/out may be the same buffer).
// 0 = rectangular (none), 1 = Hann, 2 = Hamming, 3 = Blackman, 4 = Blackman-Harris
static int applyWindow(float* in, int frames, int windowType, float* out) {
    if (!in || !out || frames <= 0) return AV_ERR_SIZE;
    if (windowType < 0 || windowType > 4) return AV_ERR_WINDOW;
    for (int i = 0; i < frames; ++i) {
        double w = 1.0;
        if (windowType > 0 && frames > 1) {
            double t = (double)i / (double)(frames - 1);
            switch (windowType) {
                case 1: w = 0.5 - 0.5 * cos(2.0 * M_PI * t); break;
                case 2: w = 0.54 - 0.46 * cos(2.0 * M_PI * t); break;
                case 3: w = 0.42 - 0.5 * cos(2.0 * M_PI * t) + 0.08 * cos(4.0 * M_PI * t); break;
                case 4: w = 0.35875 - 0.48829 * cos(2.0 * M_PI * t)
                             + 0.14128 * cos(4.0 * M_PI * t) - 0.01168 * cos(6.0 * M_PI * t); break;
            }
        }
        out[i] = (float)(in[i] * w);
    }
    return frames;
}

// Downmix interleaved multi-channel float32 to mono float32.
static int downmixSamples(const float* in, int frames, int channels, float* out) {
    if (!in || !out || frames <= 0 || channels <= 0) return AV_ERR_SIZE;
    if (channels == 1) {
        memcpy(out, in, (size_t)frames * sizeof(float));
        return frames;
    }
    for (int i = 0; i < frames; ++i) {
        double sum = 0.0;
        for (int c = 0; c < channels; ++c) sum += in[(size_t)i * channels + c];
        out[i] = (float)(sum / channels);
    }
    return frames;
}

// ---------------------------------------------------------------------------
//  Audio file registry (libsndfile)
// ---------------------------------------------------------------------------
struct AudioFileEntry {
    SNDFILE* sf = nullptr;
    int64_t  frames = 0;
    int      rate = 0;
    int      channels = 0;
};

static unordered_map<int64_t, AudioFileEntry> g_files;
static int64_t g_nextHandle = 1;
static mutex g_fileMutex;

// UTF-8 aware open: use sf_wchar_open on Windows, sf_open elsewhere.
static SNDFILE* openAudioFileUtf8(const char* path, SF_INFO* info) {
#ifdef _WIN32
    int wlen = MultiByteToWideChar(CP_UTF8, 0, path, -1, nullptr, 0);
    if (wlen > 0) {
        vector<wchar_t> wpath((size_t)wlen);
        MultiByteToWideChar(CP_UTF8, 0, path, -1, wpath.data(), wlen);
        SNDFILE* sf = sf_wchar_open(wpath.data(), SFM_READ, info);
        if (sf) return sf;
    }
    return sf_open(path, SFM_READ, info); // fallback: ANSI codepage
#else
    (void)path; (void)info;
    return sf_open(path, SFM_READ, info);
#endif
}

// Read up to `want` frames at `start` into mono float32 `out`.
// Returns frames actually read, or a negative error code.
static int64_t readFileFrames(int64_t handle, int64_t start, int64_t want, float* out) {
    if (!out) return AV_ERR_ADDRESS;
    if (want <= 0) return 0;

    lock_guard<mutex> lock(g_fileMutex);
    auto it = g_files.find(handle);
    if (it == g_files.end()) return AV_ERR_NO_FILE;

    AudioFileEntry& f = it->second;
    if (start < 0) start = 0;
    if (start >= f.frames || f.sf == nullptr) return 0;
    int64_t count = min(want, f.frames - start);

    sf_seek(f.sf, (sf_count_t)start, SEEK_SET);
    vector<float> tmp((size_t)count * (size_t)f.channels);
    sf_count_t got = sf_readf_float(f.sf, tmp.data(), (sf_count_t)count);
    if (got <= 0) return 0;

    if (f.channels == 1) {
        memcpy(out, tmp.data(), (size_t)got * sizeof(float));
    } else {
        for (sf_count_t i = 0; i < got; ++i) {
            double sum = 0.0;
            for (int c = 0; c < f.channels; ++c) sum += tmp[(size_t)i * f.channels + c];
            out[i] = (float)(sum / f.channels);
        }
    }
    return (int64_t)got;
}

// ---------------------------------------------------------------------------
//  Exported functions (register every symbol in the GMS extension editor)
// ---------------------------------------------------------------------------

// -- General ----------------------------------------------------------------

GMS2EXPORT char* AudioViz_GetVersion() {
    return (char*)"1.0.1";
}

// -- Analysis ---------------------------------------------------------------

GMS2EXPORT double AudioViz_AnalyzeSpectrum(char* samplesAddr, double frames, double fftSize, char* outAddr) {
    float* in  = (float*)buffAddrSafe(samplesAddr);
    float* out = (float*)buffAddrSafe(outAddr);
    if (!in || !out) return AV_ERR_ADDRESS;
    try {
        return analyzeSpectrum(in, (int)frames, (int)fftSize, out, false);
    } catch (...) {
        return AV_ERR_FFT;
    }
}

GMS2EXPORT double AudioViz_AnalyzeSpectrumDB(char* samplesAddr, double frames, double fftSize, char* outAddr) {
    float* in  = (float*)buffAddrSafe(samplesAddr);
    float* out = (float*)buffAddrSafe(outAddr);
    if (!in || !out) return AV_ERR_ADDRESS;
    try {
        return analyzeSpectrum(in, (int)frames, (int)fftSize, out, true);
    } catch (...) {
        return AV_ERR_FFT;
    }
}

GMS2EXPORT double AudioViz_WaveformPeaks(char* samplesAddr, double frames, double segments, char* outAddr) {
    float* in  = (float*)buffAddrSafe(samplesAddr);
    float* out = (float*)buffAddrSafe(outAddr);
    if (!in || !out) return AV_ERR_ADDRESS;
    try {
        return waveformPeaks(in, (int)frames, (int)segments, out);
    } catch (...) {
        return AV_ERR_SIZE;
    }
}

GMS2EXPORT double AudioViz_Bands(char* spectrumAddr, double bins, double bandCount, char* outAddr) {
    float* in  = (float*)buffAddrSafe(spectrumAddr);
    float* out = (float*)buffAddrSafe(outAddr);
    if (!in || !out) return AV_ERR_ADDRESS;
    try {
        return bandsFromSpectrum(in, (int)bins, (int)bandCount, out, false);
    } catch (...) {
        return AV_ERR_SIZE;
    }
}

GMS2EXPORT double AudioViz_BandsLog(char* spectrumAddr, double bins, double bandCount, char* outAddr) {
    float* in  = (float*)buffAddrSafe(spectrumAddr);
    float* out = (float*)buffAddrSafe(outAddr);
    if (!in || !out) return AV_ERR_ADDRESS;
    try {
        return bandsFromSpectrum(in, (int)bins, (int)bandCount, out, true);
    } catch (...) {
        return AV_ERR_SIZE;
    }
}

GMS2EXPORT double AudioViz_VisualBands(char* spectrumAddr, double bins, double bandCount, char* outAddr) {
    float* in  = (float*)buffAddrSafe(spectrumAddr);
    float* out = (float*)buffAddrSafe(outAddr);
    if (!in || !out) return AV_ERR_ADDRESS;
    try {
        return visualBandsFromSpectrum(in, (int)bins, (int)bandCount, out);
    } catch (...) {
        return AV_ERR_SIZE;
    }
}

GMS2EXPORT double AudioViz_Level(char* samplesAddr, double frames, char* outAddr) {
    float* in  = (float*)buffAddrSafe(samplesAddr);
    float* out = (float*)buffAddrSafe(outAddr);
    if (!in || !out) return AV_ERR_ADDRESS;
    try {
        return levelFromSamples(in, (int)frames, out);
    } catch (...) {
        return AV_ERR_SIZE;
    }
}

GMS2EXPORT double AudioViz_ApplyWindow(char* samplesAddr, double frames, double windowType, char* outAddr) {
    float* in  = (float*)buffAddrSafe(samplesAddr);
    float* out = (float*)buffAddrSafe(outAddr);
    if (!in || !out) return AV_ERR_ADDRESS;
    try {
        return applyWindow(in, (int)frames, (int)windowType, out);
    } catch (...) {
        return AV_ERR_WINDOW;
    }
}

GMS2EXPORT double AudioViz_Downmix(char* samplesAddr, double frames, double channels, char* outAddr) {
    float* in  = (float*)buffAddrSafe(samplesAddr);
    float* out = (float*)buffAddrSafe(outAddr);
    if (!in || !out) return AV_ERR_ADDRESS;
    try {
        return downmixSamples(in, (int)frames, (int)channels, out);
    } catch (...) {
        return AV_ERR_SIZE;
    }
}

// -- Audio files (libsndfile) ------------------------------------------------

GMS2EXPORT double AudioViz_FileOpen(char* path) {
    if (!path || !*path) return AV_ERR_FILE_IO;
    try {
        SF_INFO info;
        memset(&info, 0, sizeof(info));
        SNDFILE* sf = openAudioFileUtf8(path, &info);
        if (!sf || info.frames <= 0) {
            if (sf) sf_close(sf);
            return AV_ERR_FILE_IO;
        }
        lock_guard<mutex> lock(g_fileMutex);
        int64_t h = g_nextHandle++;
        AudioFileEntry e;
        e.sf = sf;
        e.frames = (int64_t)info.frames;
        e.rate = info.samplerate;
        e.channels = info.channels;
        g_files[h] = e;
        return (double)h;
    } catch (...) {
        return AV_ERR_FILE_IO;
    }
}

GMS2EXPORT double AudioViz_FileFrames(double handle) {
    lock_guard<mutex> lock(g_fileMutex);
    auto it = g_files.find((int64_t)handle);
    return it == g_files.end() ? AV_ERR_NO_FILE : (double)it->second.frames;
}

GMS2EXPORT double AudioViz_FileSampleRate(double handle) {
    lock_guard<mutex> lock(g_fileMutex);
    auto it = g_files.find((int64_t)handle);
    return it == g_files.end() ? AV_ERR_NO_FILE : (double)it->second.rate;
}

GMS2EXPORT double AudioViz_FileChannels(double handle) {
    lock_guard<mutex> lock(g_fileMutex);
    auto it = g_files.find((int64_t)handle);
    return it == g_files.end() ? AV_ERR_NO_FILE : (double)it->second.channels;
}

GMS2EXPORT double AudioViz_FileRead(double handle, double startFrame, double frames, char* outAddr) {
    float* out = (float*)buffAddrSafe(outAddr);
    if (!out) return AV_ERR_ADDRESS;
    try {
        return (double)readFileFrames((int64_t)handle, (int64_t)startFrame, (int64_t)frames, out);
    } catch (...) {
        return AV_ERR_FILE_IO;
    }
}

GMS2EXPORT double AudioViz_FileSpectrum(double handle, double startFrame, double fftSize, char* outAddr) {
    float* out = (float*)buffAddrSafe(outAddr);
    if (!out) return AV_ERR_ADDRESS;
    int n = (int)fftSize;
    if (n < 16 || (n & (n - 1)) != 0) return AV_ERR_FFT;
    try {
        vector<float> tmp((size_t)n);
        int64_t got = readFileFrames((int64_t)handle, (int64_t)startFrame, (int64_t)n, tmp.data());
        if (got < 0) return (double)got;
        if (got == 0) return 0;
        return analyzeSpectrum(tmp.data(), (int)got, n, out, false);
    } catch (...) {
        return AV_ERR_FILE_IO;
    }
}

GMS2EXPORT double AudioViz_FileClose(double handle) {
    lock_guard<mutex> lock(g_fileMutex);
    auto it = g_files.find((int64_t)handle);
    if (it == g_files.end()) return 0;
    if (it->second.sf) sf_close(it->second.sf);
    g_files.erase(it);
    return 1;
}
