// SPDX-License-Identifier: GPL-2.0-or-later
//
// Temporary smoke test for AudioViz.dll (not part of the deliverable).
// Loads the DLL and exercises the exported API against a synthetic sine wave
// and a generated WAV file.
#define _CRT_SECURE_NO_WARNINGS
#define NOMINMAX
#include <windows.h>
#include <cstdio>
#include <cmath>
#include <cstdint>
#include <vector>
#include <string>

typedef const char* (*FN_VERSION)();
typedef double (*FN_FFT)(char*, double, double, char*);
typedef double (*FN_PEAKS)(char*, double, double, char*);
typedef double (*FN_BANDS)(char*, double, double, char*);
typedef double (*FN_LEVEL)(char*, double, char*);
typedef double (*FN_OPEN)(char*);
typedef double (*FN_FRAMES)(double);
typedef double (*FN_READ)(double, double, double, char*);
typedef double (*FN_SPECTRUM)(double, double, double, char*);
typedef double (*FN_CLOSE)(double);

static int failures = 0;

static void check(bool ok, const char* msg) {
    printf("%s %s\n", ok ? "[PASS]" : "[FAIL]", msg);
    if (!ok) failures++;
}

int main(int argc, char** argv) {
    HMODULE dll = LoadLibraryA("AudioViz.dll");
    if (!dll) {
        printf("[FAIL] LoadLibrary AudioViz.dll (error %lu)\n", GetLastError());
        return 1;
    }

    auto version = (FN_VERSION)GetProcAddress(dll, "AudioViz_GetVersion");
    auto fft     = (FN_FFT)GetProcAddress(dll, "AudioViz_AnalyzeSpectrum");
    auto peaks   = (FN_PEAKS)GetProcAddress(dll, "AudioViz_WaveformPeaks");
    auto bands   = (FN_BANDS)GetProcAddress(dll, "AudioViz_Bands");
    auto bandsLog = (FN_BANDS)GetProcAddress(dll, "AudioViz_BandsLog");
    auto visualBands = (FN_BANDS)GetProcAddress(dll, "AudioViz_VisualBands");
    auto level   = (FN_LEVEL)GetProcAddress(dll, "AudioViz_Level");
    auto open    = (FN_OPEN)GetProcAddress(dll, "AudioViz_FileOpen");
    auto frames  = (FN_FRAMES)GetProcAddress(dll, "AudioViz_FileFrames");
    auto read    = (FN_READ)GetProcAddress(dll, "AudioViz_FileRead");
    auto spec    = (FN_SPECTRUM)GetProcAddress(dll, "AudioViz_FileSpectrum");
    auto close   = (FN_CLOSE)GetProcAddress(dll, "AudioViz_FileClose");

    check(version && fft && peaks && bands && bandsLog && visualBands
            && level && open && frames && read && spec && close,
          "all exports resolved");

    printf("version: %s\n", version ? version() : "?");

    // ---- FFT on a 440 Hz sine @ 44100 Hz, 2048-point window ----
    const int n = 2048;
    std::vector<float> in(n);
    for (int i = 0; i < n; ++i) in[i] = (float)(0.8 * sin(2.0 * 3.141592653589793 * 440.0 * i / 44100.0));
    std::vector<float> out(n / 2 + 1);

    char addrIn[64], addrOut[64];
    sprintf(addrIn, "%llx", (unsigned long long)in.data());
    sprintf(addrOut, "%llx", (unsigned long long)out.data());

    int bins = (int)fft(addrIn, n, n, addrOut);
    check(bins == n / 2 + 1, "AnalyzeSpectrum returns correct bin count");

    int peakBin = -1;
    float peakVal = 0;
    for (int k = 1; k < bins; ++k) {
        if (out[k] > peakVal) { peakVal = out[k]; peakBin = k; }
    }
    int expect = (int)round(440.0 * n / 44100.0); // bin 20
    check(std::abs(peakBin - expect) <= 1, "spectrum peak at expected bin");
    printf("  peakVal=%.3f (Hann window coherent gain ~0.5 x amplitude 0.8 => ~0.4)\n", peakVal);
    check(peakVal > 0.3f && peakVal < 0.6f, "peak magnitude near full scale");

    // ---- waveform peaks ----
    std::vector<float> peaksOut(16 * 2);
    sprintf(addrOut, "%llx", (unsigned long long)peaksOut.data());
    int segs = (int)peaks(addrIn, n, 16, addrOut);
    check(segs == 16, "WaveformPeaks returns segment count");
    check(peaksOut[0] >= -1.0f && peaksOut[1] <= 1.0f && peaksOut[1] > 0.5f,
          "waveform peaks within [-1, 1] with positive max");

    // ---- bands ----
    char addrSpec[64];
    sprintf(addrSpec, "%llx", (unsigned long long)out.data());

    std::vector<float> bandOut(8);
    sprintf(addrOut, "%llx", (unsigned long long)bandOut.data());
    int bandCount = (int)bands(addrSpec, bins, 8, addrOut);
    check(bandCount == 8, "Bands returns band count");
    float bandMax = 0;
    for (float v : bandOut) bandMax = std::max(bandMax, v);
    check(bandMax > 0.0f, "Bands produces energy from spectrum");

    std::vector<float> logBandOut(8);
    sprintf(addrOut, "%llx", (unsigned long long)logBandOut.data());
    int logBandCount = (int)bandsLog(addrSpec, bins, 8, addrOut);
    check(logBandCount == 8, "BandsLog returns band count");

    std::vector<float> visualBandOut(8);
    sprintf(addrOut, "%llx", (unsigned long long)visualBandOut.data());
    int visualBandCount = (int)visualBands(addrSpec, bins, 8, addrOut);
    check(visualBandCount == 8, "VisualBands returns band count");
    float visualMax = 0;
    for (float v : visualBandOut) visualMax = std::max(visualMax, v);
    printf("  bandMax=%.3f visualMax=%.3f\n", bandMax, visualMax);
    check(visualMax > 0.05f, "VisualBands produces visible energy");

    // ---- level ----
    float lvl[4];
    sprintf(addrOut, "%llx", (unsigned long long)lvl);
    int l = (int)level(addrIn, n, addrOut);
    check(l == 4 && lvl[0] > 0.7f && lvl[0] <= 1.0f && lvl[1] > 0.4f, "Level metering sane");

    // ---- WAV file decode ----
    const char* wavPath = "smoke_test.wav";
    FILE* f = fopen(wavPath, "wb");
    int rate = 44100, ch = 1, framesWav = 8820; // 0.2 s
    struct {
        char riff[4]; uint32_t sz; char wave[4];
        char fmt[4]; uint32_t fsz; uint16_t audioFmt; uint16_t nch; uint32_t rate;
        uint32_t byterate; uint16_t blockalign; uint16_t bits;
        char data[4]; uint32_t dsz;
    } hdr = { {'R','I','F','F'}, 0, {'W','A','V','E'},
              {'f','m','t',' '}, 16, 1, (uint16_t)ch, (uint32_t)rate,
              (uint32_t)(rate * ch * 2), (uint16_t)(ch * 2), 16,
              {'d','a','t','a'}, 0 };
    hdr.sz = 36 + framesWav * ch * 2;
    hdr.dsz = framesWav * ch * 2;
    fwrite(&hdr, 1, sizeof(hdr), f);
    for (int i = 0; i < framesWav; ++i) {
        short s = (short)(32000 * sin(2.0 * 3.141592653589793 * 880.0 * i / rate));
        fwrite(&s, 2, 1, f);
    }
    fclose(f);

    double h = open((char*)wavPath);
    check(h > 0, "FileOpen succeeds on generated WAV");
    check(frames((double)(long long)h) == framesWav, "FileFrames matches");
    check(frames((double)(long long)h + 999) < 0, "invalid handle returns error");

    std::vector<float> samples(framesWav);
    sprintf(addrOut, "%llx", (unsigned long long)samples.data());
    double got = read(h, 0, framesWav, addrOut);
    check(got == framesWav, "FileRead returns all frames");
    float maxAbs = 0;
    for (int i = 0; i < framesWav; ++i) maxAbs = std::max(maxAbs, std::fabs(samples[i]));
    printf("  decoded maxAbs=%.3f (sine amplitude ~0.977)\n", maxAbs);
    check(maxAbs > 0.8f, "decoded samples roughly match sine");

    std::vector<float> fspec(n / 2 + 1);
    sprintf(addrOut, "%llx", (unsigned long long)fspec.data());
    bins = (int)spec(h, 0, n, addrOut);
    check(bins == n / 2 + 1, "FileSpectrum returns bins");
    peakBin = -1; peakVal = 0;
    for (int k = 1; k < bins; ++k) if (fspec[k] > peakVal) { peakVal = fspec[k]; peakBin = k; }
    int expect2 = (int)round(880.0 * n / rate);
    check(std::abs(peakBin - expect2) <= 1, "file spectrum peak at 880 Hz bin");

    check(close(h) == 1, "FileClose succeeds");
    check(close(h) == 0, "FileClose on closed handle returns 0");

    // ---- OGG Vorbis file decode (requires libsndfile built with Ogg Vorbis) ----
    const char* oggPath = "song.ogg";
    FILE* fogg = fopen(oggPath, "rb");
    if (fogg) {
        fclose(fogg);
        double h2 = open((char*)oggPath);
        check(h2 > 0, "FileOpen succeeds on OGG Vorbis file");
        if (h2 > 0) {
            check(frames(h2) > 0, "OGG FileFrames reports frames");
            std::vector<float> oggSamples(n);
            sprintf(addrOut, "%llx", (unsigned long long)oggSamples.data());
            double got2 = read(h2, 0, n, addrOut);
            check(got2 > 0, "OGG FileRead returns samples");
            float oggMax = 0;
            for (int i = 0; i < (int)got2; ++i) oggMax = std::max(oggMax, std::fabs(oggSamples[i]));
            printf("  ogg decoded maxAbs=%.3f (lossy, expect ~0.6..1.0)\n", oggMax);
            check(oggMax > 0.6f, "OGG decoded samples roughly match sine");
            std::vector<float> oggSpec(n / 2 + 1);
            sprintf(addrOut, "%llx", (unsigned long long)oggSpec.data());
            int bins3 = (int)spec(h2, 0, n, addrOut);
            check(bins3 == n / 2 + 1, "OGG FileSpectrum returns bins");
            int pk = -1; float pv = 0;
            for (int k = 1; k < bins3; ++k) if (oggSpec[k] > pv) { pv = oggSpec[k]; pk = k; }
            int expect3 = (int)round(880.0 * n / rate);
            check(std::abs(pk - expect3) <= 2, "OGG file spectrum peak near 880 Hz");
            check(close(h2) == 1, "OGG FileClose succeeds");
        }
    } else {
        printf("[SKIP] song.ogg not present - OGG decode tests skipped\n");
    }

    // ---- absolute-path probe (optional argv[1], e.g. C:\...\song.ogg) ----
    if (argc > 1) {
        double h3 = open(argv[1]);
        check(h3 > 0, "FileOpen succeeds on absolute path argument");
        if (h3 > 0) {
            check(frames(h3) > 0, "absolute path FileFrames reports frames");
            std::vector<float> absBuf(n);
            sprintf(addrOut, "%llx", (unsigned long long)absBuf.data());
            double got3 = read(h3, 0, n, addrOut);
            check(got3 > 0, "absolute path FileRead returns samples");
            check(close(h3) == 1, "absolute path FileClose succeeds");
        }
    }

    printf(failures == 0 ? "SMOKE TEST OK\n" : "SMOKE TEST FAILED (%d)\n", failures);
    FreeLibrary(dll);
    return failures == 0 ? 0 : 1;
}
