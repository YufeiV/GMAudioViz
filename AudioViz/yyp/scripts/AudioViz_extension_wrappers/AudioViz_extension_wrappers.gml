// SPDX-License-Identifier: MIT
//
// ============================================================================
//  AudioViz - GML wrapper layer
// ----------------------------------------------------------------------------
//  Analysis wrappers:   aviz_analyze_spectrum(_db), aviz_waveform_peaks,
//                       aviz_bands(_log), aviz_level, aviz_apply_window,
//                       aviz_downmix
//  File wrappers:       aviz_file_open / frames / rate / channels / read /
//                       spectrum / close
//  Draw helpers:        aviz_draw_waveform, aviz_draw_oscilloscope,
//                       aviz_draw_bars, aviz_draw_ring,
//                       aviz_waterfall_*
//
//  The raw AudioViz_* extension functions must be registered in the GMS
//  extension editor with the External Names from README.md and marked Hidden.
//  Users should only ever call the aviz_* wrappers below.
//
//  Buffers:
//    - samples buffers hold float32 mono PCM (-1..1)
//    - spectrum buffers hold float32 bins (linear 0..~1, or dB -120..0)
//    - wrappers that "return a buffer" allocate it; always buffer_delete()
//      it when done.
// ============================================================================

#region general
/// @function                aviz_version()
/// @description             Returns the AudioViz extension version string.
/// @return {String}
/// @self
function aviz_version() {
    return AudioViz_GetVersion();
}

/// @function                aviz_spectrum_bins(_fftSize)
/// @description             Number of spectrum bins produced for a given FFT size (fftSize/2 + 1).
/// @param {Real}            _fftSize  FFT size (power of two, >= 16)
/// @return {Real}
/// @self
function aviz_spectrum_bins(_fftSize) {
    return (_fftSize div 2) + 1;
}

/// @function                aviz_buffer_frames(_buffer)
/// @description             Number of float32 values stored in a buffer (buffer size in bytes / 4).
/// @param {Real}            _buffer  buffer id
/// @return {Real}
/// @self
function aviz_buffer_frames(_buffer) {
    return buffer_get_size(_buffer) div 4;
}
#endregion

#region spectrum analysis
/// @function                aviz_analyze_spectrum_into(_outBuffer, _samplesBuffer, _frames, _fftSize)
/// @description             FFT-analyzes float32 PCM samples and writes linear magnitudes into _outBuffer
///                          (must hold fftSize/2+1 floats). A Hann window is applied internally.
/// @param {Real}            _outBuffer     destination buffer (float32, bins = fftSize/2 + 1)
/// @param {Real}            _samplesBuffer source buffer (float32 mono samples)
/// @param {Real}            _frames        number of samples to analyze
/// @param {Real}            _fftSize       FFT size (power of two, >= 16)
/// @return {Real}           number of bins written, or a negative error code
/// @self
function aviz_analyze_spectrum_into(_outBuffer, _samplesBuffer, _frames, _fftSize) {
    return AudioViz_AnalyzeSpectrum(
        string(buffer_get_address(_samplesBuffer)),
        _frames,
        _fftSize,
        string(buffer_get_address(_outBuffer))
    );
}

/// @function                aviz_analyze_spectrum(_samplesBuffer, _frames, _fftSize)
/// @description             FFT-analyzes float32 PCM samples and returns a new buffer with linear
///                          magnitude bins (0..~1). Caller must buffer_delete() the result.
/// @param {Real}            _samplesBuffer source buffer (float32 mono samples)
/// @param {Real}            _frames        number of samples to analyze
/// @param {Real}            _fftSize       FFT size (power of two, >= 16)
/// @return {Real}           new buffer id (float32, bins = fftSize/2 + 1), or a negative error code
/// @self
function aviz_analyze_spectrum(_samplesBuffer, _frames, _fftSize) {
    var _bins = aviz_spectrum_bins(_fftSize);
    var _out = buffer_create(_bins * 4, buffer_fixed, 1);
    var _r = aviz_analyze_spectrum_into(_out, _samplesBuffer, _frames, _fftSize);
    if (_r < 0) {
        buffer_delete(_out);
        return _r;
    }
    return _out;
}

/// @function                aviz_analyze_spectrum_db_into(_outBuffer, _samplesBuffer, _frames, _fftSize)
/// @description             Same as aviz_analyze_spectrum_into but writes dBFS values clamped to -120..0.
/// @param {Real}            _outBuffer     destination buffer (float32, bins = fftSize/2 + 1)
/// @param {Real}            _samplesBuffer source buffer (float32 mono samples)
/// @param {Real}            _frames        number of samples to analyze
/// @param {Real}            _fftSize       FFT size (power of two, >= 16)
/// @return {Real}           number of bins written, or a negative error code
/// @self
function aviz_analyze_spectrum_db_into(_outBuffer, _samplesBuffer, _frames, _fftSize) {
    return AudioViz_AnalyzeSpectrumDB(
        string(buffer_get_address(_samplesBuffer)),
        _frames,
        _fftSize,
        string(buffer_get_address(_outBuffer))
    );
}

/// @function                aviz_analyze_spectrum_db(_samplesBuffer, _frames, _fftSize)
/// @description             FFT-analyzes float32 PCM samples and returns a new buffer with dBFS bins
///                          (-120..0). Caller must buffer_delete() the result.
/// @param {Real}            _samplesBuffer source buffer (float32 mono samples)
/// @param {Real}            _frames        number of samples to analyze
/// @param {Real}            _fftSize       FFT size (power of two, >= 16)
/// @return {Real}           new buffer id (float32), or a negative error code
/// @self
function aviz_analyze_spectrum_db(_samplesBuffer, _frames, _fftSize) {
    var _bins = aviz_spectrum_bins(_fftSize);
    var _out = buffer_create(_bins * 4, buffer_fixed, 1);
    var _r = aviz_analyze_spectrum_db_into(_out, _samplesBuffer, _frames, _fftSize);
    if (_r < 0) {
        buffer_delete(_out);
        return _r;
    }
    return _out;
}
#endregion

#region waveform / bands / level
/// @function                aviz_waveform_peaks_into(_outBuffer, _samplesBuffer, _frames, _segments)
/// @description             Computes min/max peak pairs for _segments time slices.
///                          Writes 2 floats per segment (min, max) into _outBuffer.
/// @param {Real}            _outBuffer     destination buffer (float32, 2 * _segments)
/// @param {Real}            _samplesBuffer source buffer (float32 mono samples)
/// @param {Real}            _frames        number of samples to process
/// @param {Real}            _segments      number of slices (>= 1)
/// @return {Real}           _segments, or a negative error code
/// @self
function aviz_waveform_peaks_into(_outBuffer, _samplesBuffer, _frames, _segments) {
    return AudioViz_WaveformPeaks(
        string(buffer_get_address(_samplesBuffer)),
        _frames,
        _segments,
        string(buffer_get_address(_outBuffer))
    );
}

/// @function                aviz_waveform_peaks(_samplesBuffer, _frames, _segments)
/// @description             Returns a new buffer with min/max peak pairs (2 floats per segment).
///                          Caller must buffer_delete() the result.
/// @param {Real}            _samplesBuffer source buffer (float32 mono samples)
/// @param {Real}            _frames        number of samples to process
/// @param {Real}            _segments      number of slices (>= 1)
/// @return {Real}           new buffer id, or a negative error code
/// @self
function aviz_waveform_peaks(_samplesBuffer, _frames, _segments) {
    var _out = buffer_create(_segments * 8, buffer_fixed, 1);
    var _r = aviz_waveform_peaks_into(_out, _samplesBuffer, _frames, _segments);
    if (_r < 0) {
        buffer_delete(_out);
        return _r;
    }
    return _out;
}

/// @function                aviz_bands_into(_outBuffer, _spectrumBuffer, _bins, _bandCount)
/// @description             Aggregates a spectrum buffer into _bandCount equal-width bands (mean).
/// @param {Real}            _outBuffer      destination buffer (float32, _bandCount)
/// @param {Real}            _spectrumBuffer spectrum buffer (float32 bins)
/// @param {Real}            _bins           number of bins in the spectrum buffer
/// @param {Real}            _bandCount      number of bands to produce
/// @return {Real}           _bandCount, or a negative error code
/// @self
function aviz_bands_into(_outBuffer, _spectrumBuffer, _bins, _bandCount) {
    return AudioViz_Bands(
        string(buffer_get_address(_spectrumBuffer)),
        _bins,
        _bandCount,
        string(buffer_get_address(_outBuffer))
    );
}

/// @function                aviz_bands(_spectrumBuffer, _bins, _bandCount)
/// @description             Returns a new buffer with _bandCount linear bands (mean of each group).
/// @param {Real}            _spectrumBuffer spectrum buffer (float32 bins)
/// @param {Real}            _bins           number of bins in the spectrum buffer
/// @param {Real}            _bandCount      number of bands to produce
/// @return {Real}           new buffer id, or a negative error code
/// @self
function aviz_bands(_spectrumBuffer, _bins, _bandCount) {
    var _out = buffer_create(_bandCount * 4, buffer_fixed, 1);
    var _r = aviz_bands_into(_out, _spectrumBuffer, _bins, _bandCount);
    if (_r < 0) {
        buffer_delete(_out);
        return _r;
    }
    return _out;
}

/// @function                aviz_bands_log_into(_outBuffer, _spectrumBuffer, _bins, _bandCount)
/// @description             Aggregates a spectrum buffer into log-spaced bands (mean, DC bin skipped),
///                          which matches how human hearing perceives frequency better than linear bands.
/// @param {Real}            _outBuffer      destination buffer (float32, _bandCount)
/// @param {Real}            _spectrumBuffer spectrum buffer (float32 bins)
/// @param {Real}            _bins           number of bins in the spectrum buffer
/// @param {Real}            _bandCount      number of bands to produce
/// @return {Real}           _bandCount, or a negative error code
/// @self
function aviz_bands_log_into(_outBuffer, _spectrumBuffer, _bins, _bandCount) {
    return AudioViz_BandsLog(
        string(buffer_get_address(_spectrumBuffer)),
        _bins,
        _bandCount,
        string(buffer_get_address(_outBuffer))
    );
}

/// @function                aviz_visual_bands_into(_outBuffer, _spectrumBuffer, _bins, _bandCount)
/// @description             Aggregates spectrum bins into log-spaced, visual-reactive bands.
///                          Uses RMS/peak blending so narrow musical peaks remain visible.
/// @param {Real}            _outBuffer      destination buffer (float32, _bandCount)
/// @param {Real}            _spectrumBuffer spectrum buffer (float32 bins)
/// @param {Real}            _bins           number of bins in the spectrum buffer
/// @param {Real}            _bandCount      number of bands to produce
/// @return {Real}           _bandCount, or a negative error code
/// @self
function aviz_visual_bands_into(_outBuffer, _spectrumBuffer, _bins, _bandCount) {
    return AudioViz_VisualBands(
        string(buffer_get_address(_spectrumBuffer)),
        _bins,
        _bandCount,
        string(buffer_get_address(_outBuffer))
    );
}

/// @function                aviz_visual_bands(_spectrumBuffer, _bins, _bandCount)
/// @description             Returns a new buffer with visual-reactive log-spaced bands.
/// @param {Real}            _spectrumBuffer spectrum buffer (float32 bins)
/// @param {Real}            _bins           number of bins in the spectrum buffer
/// @param {Real}            _bandCount      number of bands to produce
/// @return {Real}           new buffer id, or a negative error code
/// @self
function aviz_visual_bands(_spectrumBuffer, _bins, _bandCount) {
    var _out = buffer_create(_bandCount * 4, buffer_fixed, 1);
    var _r = aviz_visual_bands_into(_out, _spectrumBuffer, _bins, _bandCount);
    if (_r < 0) {
        buffer_delete(_out);
        return _r;
    }
    return _out;
}

/// @function                aviz_bands_log(_spectrumBuffer, _bins, _bandCount)
/// @description             Returns a new buffer with _bandCount log-spaced bands.
/// @param {Real}            _spectrumBuffer spectrum buffer (float32 bins)
/// @param {Real}            _bins           number of bins in the spectrum buffer
/// @param {Real}            _bandCount      number of bands to produce
/// @return {Real}           new buffer id, or a negative error code
/// @self
function aviz_bands_log(_spectrumBuffer, _bins, _bandCount) {
    var _out = buffer_create(_bandCount * 4, buffer_fixed, 1);
    var _r = aviz_bands_log_into(_out, _spectrumBuffer, _bins, _bandCount);
    if (_r < 0) {
        buffer_delete(_out);
        return _r;
    }
    return _out;
}

/// @function                aviz_level(_samplesBuffer, _frames)
/// @description             Returns { peak, rms, avg, dc } metering values for float32 samples.
/// @param {Real}            _samplesBuffer source buffer (float32 mono samples)
/// @param {Real}            _frames        number of samples to process
/// @return {Struct}         { peak : Real, rms : Real, avg : Real, dc : Real }
/// @self
function aviz_level(_samplesBuffer, _frames) {
    var _out = buffer_create(16, buffer_fixed, 1);
    var _r = AudioViz_Level(
        string(buffer_get_address(_samplesBuffer)),
        _frames,
        string(buffer_get_address(_out))
    );
    if (_r < 0) {
        buffer_delete(_out);
        return { peak: -1, rms: -1, avg: -1, dc: -1 };
    }
    var _peak = buffer_read(_out, buffer_f32);
    var _rms  = buffer_read(_out, buffer_f32);
    var _avg  = buffer_read(_out, buffer_f32);
    var _dc   = buffer_read(_out, buffer_f32);
    buffer_delete(_out);
    return { peak: _peak, rms: _rms, avg: _avg, dc: _dc };
}

/// @function                aviz_apply_window(_samplesBuffer, _frames, _windowType)
/// @description             Applies a window function to float32 samples in place.
///                          0 = none, 1 = Hann, 2 = Hamming, 3 = Blackman, 4 = Blackman-Harris.
/// @param {Real}            _samplesBuffer buffer holding float32 samples (modified in place)
/// @param {Real}            _frames        number of samples
/// @param {Real}            _windowType    window type (0..4)
/// @return {Real}           _frames, or a negative error code
/// @self
function aviz_apply_window(_samplesBuffer, _frames, _windowType) {
    return AudioViz_ApplyWindow(
        string(buffer_get_address(_samplesBuffer)),
        _frames,
        _windowType,
        string(buffer_get_address(_samplesBuffer))
    );
}

/// @function                aviz_downmix_into(_outBuffer, _samplesBuffer, _frames, _channels)
/// @description             Downmixes interleaved multi-channel float32 samples to mono float32.
/// @param {Real}            _outBuffer     destination buffer (float32, _frames)
/// @param {Real}            _samplesBuffer source buffer (float32 interleaved, _frames * _channels)
/// @param {Real}            _frames        number of frames
/// @param {Real}            _channels      number of interleaved channels (>= 1)
/// @return {Real}           _frames, or a negative error code
/// @self
function aviz_downmix_into(_outBuffer, _samplesBuffer, _frames, _channels) {
    return AudioViz_Downmix(
        string(buffer_get_address(_samplesBuffer)),
        _frames,
        _channels,
        string(buffer_get_address(_outBuffer))
    );
}
#endregion

#region audio files (libsndfile)
/// @function                aviz_file_open(_path)
/// @description             Opens an audio file (wav/aiff/flac/ogg/mp3...) for reading and returns a
///                          handle. The file is decoded on demand; supported formats depend on the
///                          libsndfile build (current build: WAV, AIFF, AU, RAW, OGG Vorbis, ...).
/// @param {String}          _path  absolute or relative path (UTF-8)
/// @return {Real}           file handle (> 0), or a negative error code
/// @self
function aviz_file_open(_path) {
    return AudioViz_FileOpen(_path);
}

/// @function                aviz_file_frames(_handle)
/// @description             Total number of sample frames in an open audio file.
/// @param {Real}            _handle  file handle from aviz_file_open
/// @return {Real}           frame count, or a negative error code
/// @self
function aviz_file_frames(_handle) {
    return AudioViz_FileFrames(_handle);
}

/// @function                aviz_file_sample_rate(_handle)
/// @description             Sample rate of an open audio file (Hz).
/// @param {Real}            _handle  file handle from aviz_file_open
/// @return {Real}           sample rate, or a negative error code
/// @self
function aviz_file_sample_rate(_handle) {
    return AudioViz_FileSampleRate(_handle);
}

/// @function                aviz_file_channels(_handle)
/// @description             Channel count of an open audio file.
/// @param {Real}            _handle  file handle from aviz_file_open
/// @return {Real}           channel count, or a negative error code
/// @self
function aviz_file_channels(_handle) {
    return AudioViz_FileChannels(_handle);
}

/// @function                aviz_file_read_into(_outBuffer, _handle, _startFrame, _frames)
/// @description             Reads up to _frames frames starting at _startFrame and writes mono float32
///                          samples into _outBuffer (multi-channel files are downmixed).
/// @param {Real}            _outBuffer   destination buffer (float32, at least _frames)
/// @param {Real}            _handle      file handle from aviz_file_open
/// @param {Real}            _startFrame  first frame to read (0-based)
/// @param {Real}            _frames      maximum number of frames to read
/// @return {Real}           frames actually read (may be < _frames at EOF), or a negative error code
/// @self
function aviz_file_read_into(_outBuffer, _handle, _startFrame, _frames) {
    return AudioViz_FileRead(
        _handle,
        _startFrame,
        _frames,
        string(buffer_get_address(_outBuffer))
    );
}

/// @function                aviz_file_read(_handle, _startFrame, _frames)
/// @description             Returns a new buffer with mono float32 samples read from the file
///                          (downmixed). Caller must buffer_delete() the result.
/// @param {Real}            _handle      file handle from aviz_file_open
/// @param {Real}            _startFrame  first frame to read (0-based)
/// @param {Real}            _frames      maximum number of frames to read
/// @return {Real}           new buffer id, or a negative error code
/// @self
function aviz_file_read(_handle, _startFrame, _frames) {
    var _out = buffer_create(_frames * 4, buffer_grow, 1);
    var _r = aviz_file_read_into(_out, _handle, _startFrame, _frames);
    if (_r < 0) {
        buffer_delete(_out);
        return _r;
    }
    buffer_resize(_out, max(_r, 0) * 4);
    return _out;
}

/// @function                aviz_file_spectrum(_handle, _startFrame, _fftSize)
/// @description             Reads _fftSize frames from the file and returns a new buffer with linear
///                          magnitude spectrum bins (Hann window applied).
/// @param {Real}            _handle      file handle from aviz_file_open
/// @param {Real}            _startFrame  first frame to read (0-based)
/// @param {Real}            _fftSize     FFT size (power of two, >= 16)
/// @return {Real}           new buffer id (float32, fftSize/2 + 1 bins), or a negative error code
/// @self
function aviz_file_spectrum(_handle, _startFrame, _fftSize) {
    var _bins = aviz_spectrum_bins(_fftSize);
    var _out = buffer_create(_bins * 4, buffer_fixed, 1);
    var _r = AudioViz_FileSpectrum(
        _handle,
        _startFrame,
        _fftSize,
        string(buffer_get_address(_out))
    );
    if (_r < 0) {
        buffer_delete(_out);
        return _r;
    }
    return _out;
}

/// @function                aviz_file_close(_handle)
/// @description             Closes an open audio file and frees its resources.
/// @param {Real}            _handle  file handle from aviz_file_open
/// @return {Real}           1 on success, 0 if the handle was not open
/// @self
function aviz_file_close(_handle) {
    return AudioViz_FileClose(_handle);
}
#endregion

#region draw helpers
/// @function                aviz_draw_waveform(_samplesBuffer, _frames, _x, _y, _w, _h, _color, _fillAlpha)
/// @description             Draws a waveform (min/max envelope) from float32 samples into the given rect.
/// @param {Real}            _samplesBuffer buffer with float32 mono samples
/// @param {Real}            _frames        number of samples
/// @param {Real}            _x             left edge
/// @param {Real}            _y             top edge
/// @param {Real}            _w             width
/// @param {Real}            _h             height
/// @param {Real}            _color         stroke/fill color
/// @param {Real}            _fillAlpha     fill opacity (default 0.35)
/// @self
function aviz_draw_waveform(_samplesBuffer, _frames, _x, _y, _w, _h, _color, _fillAlpha = 0.35) {
    var _segments = clamp(_w div 2, 8, 256);
    var _peaks = aviz_waveform_peaks(_samplesBuffer, _frames, _segments);
    if (_peaks < 0) return;

    var _midY = _y + _h * 0.5;
    var _scale = _h * 0.5;
    var _segW = _w / _segments;
    var _i;

    // filled min/max envelope: one quad per segment.
    // Uses only basic draw_* functions so it renders identically on every GMS
    // version and primitive pipeline (draw_primitive_* can silently produce
    // nothing with the new non-legacy primitive system).
    draw_set_alpha(_fillAlpha);
    for (_i = 0; _i < _segments; _i++) {
        var _mn = buffer_peek(_peaks, _i * 8, buffer_f32);
        var _mx = buffer_peek(_peaks, _i * 8 + 4, buffer_f32);
        var _x0 = _x + _i * _segW;
        var _x1 = _x + (_i + 1) * _segW;
        draw_rectangle_color(_x0, _midY - _mx * _scale, _x1, _midY - _mn * _scale,
            _color, _color, _color, _color, false);
    }

    // min / max outlines
    draw_set_alpha(1);
    draw_set_color(_color);
    for (_i = 0; _i < _segments - 1; _i++) {
        var _mn0 = buffer_peek(_peaks, _i * 8, buffer_f32);
        var _mn1 = buffer_peek(_peaks, (_i + 1) * 8, buffer_f32);
        draw_line_color(_x + (_i + 0.5) * _segW, _midY - _mn0 * _scale,
            _x + (_i + 1.5) * _segW, _midY - _mn1 * _scale, _color, _color);
    }
    for (_i = 0; _i < _segments - 1; _i++) {
        var _mx0 = buffer_peek(_peaks, _i * 8 + 4, buffer_f32);
        var _mx1 = buffer_peek(_peaks, (_i + 1) * 8 + 4, buffer_f32);
        draw_line_color(_x + (_i + 0.5) * _segW, _midY - _mx0 * _scale,
            _x + (_i + 1.5) * _segW, _midY - _mx1 * _scale, _color, _color);
    }

    draw_set_alpha(1);
    buffer_delete(_peaks);
}

/// @function                aviz_draw_oscilloscope(_samplesBuffer, _frames, _x, _y, _w, _h, _color, _glow)
/// @description             Draws the raw samples as a line (analog oscilloscope style), with an optional
///                          phosphor glow. Good for a "live" window of ~128..2048 samples.
/// @param {Real}            _samplesBuffer buffer with float32 mono samples
/// @param {Real}            _frames        number of samples (>= 2)
/// @param {Real}            _x             left edge
/// @param {Real}            _y             top edge
/// @param {Real}            _w             width
/// @param {Real}            _h             height
/// @param {Real}            _color         line color
/// @param {Real}            _glow          glow strength 0..1 (default 0.4)
/// @self
function aviz_draw_oscilloscope(_samplesBuffer, _frames, _x, _y, _w, _h, _color, _glow = 0.4) {
    if (_frames < 2) return;
    var _midY = _y + _h * 0.5;
    var _scale = _h * 0.5;
    var _dx = _w / (_frames - 1);
    var _pass, _i;

    // three overlapping polyline passes for a phosphor glow
    for (_pass = 0; _pass < 3; _pass++) {
        var _alpha = 1;
        if (_pass == 0) _alpha = _glow * 0.15;
        else if (_pass == 1) _alpha = _glow * 0.4;
        draw_set_alpha(_alpha);
        for (_i = 0; _i < _frames - 1; _i++) {
            var _s0 = buffer_peek(_samplesBuffer, _i * 4, buffer_f32);
            var _s1 = buffer_peek(_samplesBuffer, (_i + 1) * 4, buffer_f32);
            draw_line_color(_x + _i * _dx, _midY - _s0 * _scale,
                _x + (_i + 1) * _dx, _midY - _s1 * _scale, _color, _color);
        }
    }
    draw_set_alpha(1);
}

/// @function                aviz_draw_bars(_valuesBuffer, _count, _x, _y, _w, _h, _color, _gap, _maxValue, _minValue, _response)
/// @description             Draws a bar chart from float32 values (e.g. spectrum or band buffers).
///                          Values are normalized with (_value - _minValue) / (_maxValue - _minValue).
/// @param {Real}            _valuesBuffer buffer with float32 values
/// @param {Real}            _count        number of bars
/// @param {Real}            _x            left edge
/// @param {Real}            _y            top edge
/// @param {Real}            _w            width
/// @param {Real}            _h            height
/// @param {Real}            _color        bar color
/// @param {Real}            _gap          gap between bars in px (default 2)
/// @param {Real}            _maxValue     value mapped to full height (default 1)
/// @param {Real}            _minValue     value mapped to zero height (default 0)
/// @param {Real}            _response     display curve; < 1 exaggerates quieter values (default 1)
/// @self
function aviz_draw_bars(_valuesBuffer, _count, _x, _y, _w, _h, _color, _gap = 2, _maxValue = 1, _minValue = 0, _response = 1) {
    if (_count <= 0 || _w <= 0 || _h <= 0) return;
    _gap = max(_gap, 0);
    var _barW = (_w - _gap * (_count - 1)) / _count;
    if (_barW <= 0) return;
    var _range = _maxValue - _minValue;
    if (_range <= 0) return;

    for (var _i = 0; _i < _count; _i++) {
        var _v = (buffer_peek(_valuesBuffer, _i * 4, buffer_f32) - _minValue) / _range;
        _v = clamp(_v, 0, 1);
        if (_response > 0 && _response != 1) _v = power(_v, _response);
        var _bx = _x + _i * (_barW + _gap);
        var _by = _y + _h - _v * _h;
        draw_rectangle_color(_bx, _by, _bx + _barW, _y + _h, _color, _color, _color, _color, false);
    }
}

/// @function                aviz_draw_ring(_valuesBuffer, _count, _x, _y, _innerRadius, _outerRadius, _color, _maxValue, _minValue, _response, _minFill)
/// @description             Draws a circular (ring) chart: each value is a wedge whose outer radius grows
///                          with the normalized value. Values are normalized like aviz_draw_bars.
/// @param {Real}            _valuesBuffer  buffer with float32 values
/// @param {Real}            _count         number of wedges
/// @param {Real}            _x             center x
/// @param {Real}            _y             center y
/// @param {Real}            _innerRadius   base radius of the ring
/// @param {Real}            _outerRadius   radius reached at max value
/// @param {Real}            _color         wedge color
/// @param {Real}            _maxValue      value mapped to _outerRadius (default 1)
/// @param {Real}            _minValue      value mapped to _innerRadius (default 0)
/// @param {Real}            _response      display curve; < 1 exaggerates quieter values (default 1)
/// @param {Real}            _minFill       minimum visible fill for non-zero values, 0..1 (default 0)
/// @self
function aviz_draw_ring(_valuesBuffer, _count, _x, _y, _innerRadius, _outerRadius, _color, _maxValue = 1, _minValue = 0, _response = 1, _minFill = 0) {
    if (_count <= 0 || _outerRadius <= _innerRadius) return;
    var _range = _maxValue - _minValue;
    if (_range <= 0) return;
    var _step = 360 / _count;

    for (var _i = 0; _i < _count; _i++) {
        var _v = (buffer_peek(_valuesBuffer, _i * 4, buffer_f32) - _minValue) / _range;
        _v = clamp(_v, 0, 1);
        if (_response > 0 && _response != 1) _v = power(_v, _response);
        if (_v > 0 && _minFill > 0) _v = max(_v, clamp(_minFill, 0, 1));
        var _r1 = _innerRadius + (_outerRadius - _innerRadius) * _v;
        var _a0 = _i * _step;
        var _a1 = (_i + 1) * _step;
        var _x0a = _x + lengthdir_x(_innerRadius, _a0);
        var _y0a = _y + lengthdir_y(_innerRadius, _a0);
        var _x1a = _x + lengthdir_x(_r1, _a0);
        var _y1a = _y + lengthdir_y(_r1, _a0);
        var _x0b = _x + lengthdir_x(_innerRadius, _a1);
        var _y0b = _y + lengthdir_y(_innerRadius, _a1);
        var _x1b = _x + lengthdir_x(_r1, _a1);
        var _y1b = _y + lengthdir_y(_r1, _a1);
        draw_triangle_color(_x0a, _y0a, _x1a, _y1a, _x1b, _y1b,
            _color, _color, _color, false);
        draw_triangle_color(_x0a, _y0a, _x1b, _y1b, _x0b, _y0b,
            _color, _color, _color, false);
    }
}
#endregion

#region waterfall
/// @function                aviz_waterfall_create(_w, _h, _rowHeight)
/// @description             Creates a waterfall renderer (scrolling spectrum history) and returns a struct.
///                          The surface starts empty; feed it a spectrum each frame with aviz_waterfall_feed.
/// @param {Real}            _w           surface width in px
/// @param {Real}            _h           surface height in px
/// @param {Real}            _rowHeight   height of one spectrum row in px (default 2)
/// @return {Struct}         waterfall handle
/// @self
function aviz_waterfall_create(_w, _h, _rowHeight = 2) {
    var _surf = surface_create(_w, _h);
    var _scratch = surface_create(_w, _h);
    surface_set_target(_surf);
    draw_clear_alpha(c_black, 0);
    surface_reset_target();
    surface_set_target(_scratch);
    draw_clear_alpha(c_black, 0);
    surface_reset_target();
    return { surface: _surf, scroll: _scratch, w: _w, h: _h, rowHeight: _rowHeight };
}

/// @function                aviz_waterfall_feed(_waterfall, _spectrumBuffer, _bins, _maxValue, _minValue)
/// @description             Scrolls the waterfall down one row and draws a new row from the spectrum buffer.
///                          The spectrum is drawn with a blue->red heat map. Call once per frame.
/// @param {Struct}          _waterfall      handle from aviz_waterfall_create
/// @param {Real}            _spectrumBuffer buffer with float32 spectrum bins
/// @param {Real}            _bins           number of bins (should be <= waterfall width)
/// @param {Real}            _maxValue       value mapped to red/hot (default 1; use 0 for dB buffers)
/// @param {Real}            _minValue       value mapped to blue/cold (default 0; use -60 for dB buffers)
/// @self
function aviz_waterfall_feed(_waterfall, _spectrumBuffer, _bins, _maxValue = 1, _minValue = 0) {
    var _rowH = _waterfall.rowHeight;
    if (_bins <= 0 || _waterfall.w <= 0 || _waterfall.h <= 0) return;
    if (_rowH <= 0 || _rowH >= _waterfall.h) return;
    var _range = _maxValue - _minValue;
    if (_range <= 0) return;

    // GameMaker 在窗口尺寸变化/GPU 重置后会丢弃 surface, 这里自动重建
    if (!surface_exists(_waterfall.surface)) _waterfall.surface = surface_create(_waterfall.w, _waterfall.h);
    if (!surface_exists(_waterfall.scroll)) _waterfall.scroll = surface_create(_waterfall.w, _waterfall.h);

    var _surf = _waterfall.surface;
    var _scratch = _waterfall.scroll;

    // 1) 把旧内容整体下移 _rowH 到临时表面。
    //    注意: 绝不能直接 draw_surface_part(_surf) —— _surf 此刻正绑定为渲染目标,
    //    GameMaker 会报 "Trying to set texture that is also bound as surface" 并跳过绘制。
    surface_set_target(_scratch);
    draw_clear_alpha(c_black, 0);
    draw_surface_part(_surf, 0, 0, _waterfall.w, _waterfall.h - _rowH, 0, _rowH);
    surface_reset_target();

    // 2) 把滚动后的内容拷回主表面
    surface_set_target(_surf);
    draw_clear_alpha(c_black, 0);
    draw_surface(_scratch, 0, 0);

    // 3) 在最上方画最新一行 (蓝->红热力图)
    var _cols = max(1, floor(_waterfall.w));
    draw_set_alpha(1);
    for (var _xCol = 0; _xCol < _cols; _xCol++) {
        var _i0 = floor(_xCol * _bins / _cols);
        var _i1 = floor((_xCol + 1) * _bins / _cols);
        if (_i1 <= _i0) _i1 = _i0 + 1;
        if (_i1 > _bins) _i1 = _bins;

        var _peak = buffer_peek(_spectrumBuffer, _i0 * 4, buffer_f32);
        for (var _i = _i0 + 1; _i < _i1; _i++) {
            _peak = max(_peak, buffer_peek(_spectrumBuffer, _i * 4, buffer_f32));
        }

        var _v = (_peak - _minValue) / _range;
        _v = clamp(_v, 0, 1);
        var _col = make_colour_hsv(170 * (1 - _v), 255, 60 + _v * 195);
        draw_rectangle_color(_xCol, 0, _xCol + 1, _rowH,
            _col, _col, _col, _col, false);
    }

    // 4) 恢复之前的渲染目标
    surface_reset_target();
}

/// @function                aviz_waterfall_draw(_waterfall, _x, _y, _alpha)
/// @description             Draws the waterfall at (_x, _y).
/// @param {Struct}          _waterfall  handle from aviz_waterfall_create
/// @param {Real}            _x          left edge
/// @param {Real}            _y          top edge
/// @param {Real}            _alpha      opacity 0..1 (default 1)
/// @self
function aviz_waterfall_draw(_waterfall, _x, _y, _alpha = 1) {
    if (surface_exists(_waterfall.surface)) {
        draw_surface_ext(_waterfall.surface, _x, _y, 1, 1, 0, c_white, _alpha);
    }
}

/// @function                aviz_waterfall_destroy(_waterfall)
/// @description             Frees the waterfall surface.
/// @param {Struct}          _waterfall  handle from aviz_waterfall_create
/// @self
function aviz_waterfall_destroy(_waterfall) {
    if (surface_exists(_waterfall.surface)) surface_free(_waterfall.surface);
    if (surface_exists(_waterfall.scroll)) surface_free(_waterfall.scroll);
    _waterfall.surface = -1;
    _waterfall.scroll = -1;
}
#endregion
