// SPDX-License-Identifier: GPL-2.0-or-later

package ${YYAndroidPackageName};

import com.audioviz.extension.MainActivity;

import static com.audioviz.extension.MainActivity.*;

public class class_AudioViz {
    public String AudioViz_GetVersion() {
        return JNIAudioVizGetVersion();
    }
    public double AudioViz_AnalyzeSpectrum(String samples, double frames, double fftSize, String out) {
        return JNIAudioVizAnalyzeSpectrum(samples, frames, fftSize, out);
    }
    public double AudioViz_AnalyzeSpectrumDB(String samples, double frames, double fftSize, String out) {
        return JNIAudioVizAnalyzeSpectrumDB(samples, frames, fftSize, out);
    }
    public double AudioViz_WaveformPeaks(String samples, double frames, double segments, String out) {
        return JNIAudioVizWaveformPeaks(samples, frames, segments, out);
    }
    public double AudioViz_Bands(String spectrum, double bins, double bandCount, String out) {
        return JNIAudioVizBands(spectrum, bins, bandCount, out);
    }
    public double AudioViz_BandsLog(String spectrum, double bins, double bandCount, String out) {
        return JNIAudioVizBandsLog(spectrum, bins, bandCount, out);
    }
    public double AudioViz_VisualBands(String spectrum, double bins, double bandCount, String out) {
        return JNIAudioVizVisualBands(spectrum, bins, bandCount, out);
    }
    public double AudioViz_Level(String samples, double frames, String out) {
        return JNIAudioVizLevel(samples, frames, out);
    }
    public double AudioViz_ApplyWindow(String samples, double frames, double windowType, String out) {
        return JNIAudioVizApplyWindow(samples, frames, windowType, out);
    }
    public double AudioViz_Downmix(String samples, double frames, double channels, String out) {
        return JNIAudioVizDownmix(samples, frames, channels, out);
    }
    public double AudioViz_FileOpen(String path) {
        return JNIAudioVizFileOpen(path);
    }
    public double AudioViz_FileFrames(double handle) {
        return JNIAudioVizFileFrames(handle);
    }
    public double AudioViz_FileSampleRate(double handle) {
        return JNIAudioVizFileSampleRate(handle);
    }
    public double AudioViz_FileChannels(double handle) {
        return JNIAudioVizFileChannels(handle);
    }
    public double AudioViz_FileRead(double handle, double startFrame, double frames, String out) {
        return JNIAudioVizFileRead(handle, startFrame, frames, out);
    }
    public double AudioViz_FileSpectrum(double handle, double startFrame, double fftSize, String out) {
        return JNIAudioVizFileSpectrum(handle, startFrame, fftSize, out);
    }
    public double AudioViz_FileClose(double handle) {
        return JNIAudioVizFileClose(handle);
    }
}
