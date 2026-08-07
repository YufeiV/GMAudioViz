// SPDX-License-Identifier: GPL-2.0-or-later
//
// AudioViz iOS bridge header. The Objective-C class name registered in GMS is
// "AudioViz". Requires FFTW/libsndfile built for iOS device + emulator (see
// README.md); this bridge is provided for future mobile support.

@interface AudioViz : NSObject
- (void) Init;
- (NSString*) AudioViz_GetVersion;
- (double) AudioViz_AnalyzeSpectrum:(char*)samples frames:(double)frames fftSize:(double)fftSize out:(char*)out;
- (double) AudioViz_AnalyzeSpectrumDB:(char*)samples frames:(double)frames fftSize:(double)fftSize out:(char*)out;
- (double) AudioViz_WaveformPeaks:(char*)samples frames:(double)frames segments:(double)segments out:(char*)out;
- (double) AudioViz_Bands:(char*)spectrum bins:(double)bins bandCount:(double)bandCount out:(char*)out;
- (double) AudioViz_BandsLog:(char*)spectrum bins:(double)bins bandCount:(double)bandCount out:(char*)out;
- (double) AudioViz_VisualBands:(char*)spectrum bins:(double)bins bandCount:(double)bandCount out:(char*)out;
- (double) AudioViz_Level:(char*)samples frames:(double)frames out:(char*)out;
- (double) AudioViz_ApplyWindow:(char*)samples frames:(double)frames windowType:(double)windowType out:(char*)out;
- (double) AudioViz_Downmix:(char*)samples frames:(double)frames channels:(double)channels out:(char*)out;
- (double) AudioViz_FileOpen:(char*)path;
- (double) AudioViz_FileFrames:(double)handle;
- (double) AudioViz_FileSampleRate:(double)handle;
- (double) AudioViz_FileChannels:(double)handle;
- (double) AudioViz_FileRead:(double)handle startFrame:(double)startFrame frames:(double)frames out:(char*)out;
- (double) AudioViz_FileSpectrum:(double)handle startFrame:(double)startFrame fftSize:(double)fftSize out:(char*)out;
- (double) AudioViz_FileClose:(double)handle;
@end
