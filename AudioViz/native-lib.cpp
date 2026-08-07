// SPDX-License-Identifier: GPL-2.0-or-later
//
// Android JNI bridge for AudioViz.
// Compiled only on Android. Requires FFTW/libsndfile static libs built for the
// target ABI (see README.md). JNI function names contain no underscores after
// the "JNI" prefix, and every jstring is released after use.

#include <jni.h>
#include <string>
#include "AudioViz.cpp"

#define AV_JSTR(env, j)  ((char*)env->GetStringUTFChars(j, 0))
#define AV_JREL(env, j, p) env->ReleaseStringUTFChars(j, p)

extern "C" {

JNIEXPORT jstring JNICALL Java_com_audioviz_extension_MainActivity_JNIAudioVizGetVersion(JNIEnv* env, jclass cl) {
    return env->NewStringUTF(AudioViz_GetVersion());
}

#define AV_BRIDGE_4(name, jname) \
    JNIEXPORT jdouble JNICALL Java_com_audioviz_extension_MainActivity_JNI##jname(JNIEnv* env, jclass cl, \
        jstring a0, jdouble a1, jdouble a2, jstring a3) { \
        char* s0 = AV_JSTR(env, a0); \
        char* s3 = AV_JSTR(env, a3); \
        jdouble r = name(s0, a1, a2, s3); \
        AV_JREL(env, a0, s0); \
        AV_JREL(env, a3, s3); \
        return r; \
    }

#define AV_BRIDGE_3(name, jname) \
    JNIEXPORT jdouble JNICALL Java_com_audioviz_extension_MainActivity_JNI##jname(JNIEnv* env, jclass cl, \
        jstring a0, jdouble a1, jstring a2) { \
        char* s0 = AV_JSTR(env, a0); \
        char* s2 = AV_JSTR(env, a2); \
        jdouble r = name(s0, a1, s2); \
        AV_JREL(env, a0, s0); \
        AV_JREL(env, a2, s2); \
        return r; \
    }

#define AV_BRIDGE_DBL(name, jname) \
    JNIEXPORT jdouble JNICALL Java_com_audioviz_extension_MainActivity_JNI##jname(JNIEnv* env, jclass cl, jdouble a0) { \
        return name(a0); \
    }

AV_BRIDGE_4(AudioViz_AnalyzeSpectrum, AudioVizAnalyzeSpectrum)
AV_BRIDGE_4(AudioViz_AnalyzeSpectrumDB, AudioVizAnalyzeSpectrumDB)
AV_BRIDGE_4(AudioViz_WaveformPeaks, AudioVizWaveformPeaks)
AV_BRIDGE_4(AudioViz_Bands, AudioVizBands)
AV_BRIDGE_4(AudioViz_BandsLog, AudioVizBandsLog)
AV_BRIDGE_4(AudioViz_VisualBands, AudioVizVisualBands)
AV_BRIDGE_3(AudioViz_Level, AudioVizLevel)
AV_BRIDGE_4(AudioViz_ApplyWindow, AudioVizApplyWindow)
AV_BRIDGE_4(AudioViz_Downmix, AudioVizDownmix)

JNIEXPORT jdouble JNICALL Java_com_audioviz_extension_MainActivity_JNIAudioVizFileOpen(JNIEnv* env, jclass cl, jstring a0) {
    char* s0 = AV_JSTR(env, a0);
    jdouble r = AudioViz_FileOpen(s0);
    AV_JREL(env, a0, s0);
    return r;
}

AV_BRIDGE_DBL(AudioViz_FileFrames, AudioVizFileFrames)
AV_BRIDGE_DBL(AudioViz_FileSampleRate, AudioVizFileSampleRate)
AV_BRIDGE_DBL(AudioViz_FileChannels, AudioVizFileChannels)

JNIEXPORT jdouble JNICALL Java_com_audioviz_extension_MainActivity_JNIAudioVizFileRead(JNIEnv* env, jclass cl,
        jdouble a0, jdouble a1, jdouble a2, jstring a3) {
    char* s3 = AV_JSTR(env, a3);
    jdouble r = AudioViz_FileRead(a0, a1, a2, s3);
    AV_JREL(env, a3, s3);
    return r;
}

JNIEXPORT jdouble JNICALL Java_com_audioviz_extension_MainActivity_JNIAudioVizFileSpectrum(JNIEnv* env, jclass cl,
        jdouble a0, jdouble a1, jdouble a2, jstring a3) {
    char* s3 = AV_JSTR(env, a3);
    jdouble r = AudioViz_FileSpectrum(a0, a1, a2, s3);
    AV_JREL(env, a3, s3);
    return r;
}

AV_BRIDGE_DBL(AudioViz_FileClose, AudioVizFileClose)

}
