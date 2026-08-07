// SPDX-License-Identifier: GPL-2.0-or-later

package com.audioviz.extension;

public class MainActivity {
    public static native String JNIAudioVizGetVersion();
    public static native double JNIAudioVizAnalyzeSpectrum(String samples, double frames, double fftSize, String out);
    public static native double JNIAudioVizAnalyzeSpectrumDB(String samples, double frames, double fftSize, String out);
    public static native double JNIAudioVizWaveformPeaks(String samples, double frames, double segments, String out);
    public static native double JNIAudioVizBands(String spectrum, double bins, double bandCount, String out);
    public static native double JNIAudioVizBandsLog(String spectrum, double bins, double bandCount, String out);
    public static native double JNIAudioVizVisualBands(String spectrum, double bins, double bandCount, String out);
    public static native double JNIAudioVizLevel(String samples, double frames, String out);
    public static native double JNIAudioVizApplyWindow(String samples, double frames, double windowType, String out);
    public static native double JNIAudioVizDownmix(String samples, double frames, double channels, String out);
    public static native double JNIAudioVizFileOpen(String path);
    public static native double JNIAudioVizFileFrames(double handle);
    public static native double JNIAudioVizFileSampleRate(double handle);
    public static native double JNIAudioVizFileChannels(double handle);
    public static native double JNIAudioVizFileRead(double handle, double startFrame, double frames, String out);
    public static native double JNIAudioVizFileSpectrum(double handle, double startFrame, double fftSize, String out);
    public static native double JNIAudioVizFileClose(double handle);

    static {
        System.loadLibrary("AudioViz");
    }
}
