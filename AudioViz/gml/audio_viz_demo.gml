// SPDX-License-Identifier: MIT
//
// ============================================================================
//  AudioViz demo object template
// ----------------------------------------------------------------------------
//  Paste each section into the matching event of an obj_audio_viz_demo object.
//  Requirements:
//    - The AudioViz extension wrapper script is included in the project.
//    - A GameMaker sound resource named snd_song exists.
//    - A matching audio file named song.ogg is available in working_directory.
// ============================================================================

// ----------------------------------------------------------------------------
//  Create event
// ----------------------------------------------------------------------------
global.aviz_fft_size = 1024;
global.aviz_band_count = 64;
global.aviz_file = -1;
global.aviz_inst = -1;
global.aviz_rate = 44100;
global.aviz_read_pos = 0;
global.aviz_last_read = -1;
global.aviz_record_buf = noone;
global.aviz_recorder = -1;
global.aviz_band_display_max = 0.12;
global.aviz_energy_fast = 0;
global.aviz_energy_slow = 0;
global.aviz_flux = 0;
global.aviz_pulse = 0;
global.aviz_level_peak = 0;
global.aviz_level_rms = 0;

global.aviz_file = aviz_file_open(working_directory + "song.ogg");
if (global.aviz_file > 0) {
    global.aviz_rate = aviz_file_sample_rate(global.aviz_file);
    global.aviz_inst = audio_play_sound(snd_song, 0, true);
    show_debug_message("AudioViz: frames=" + string(aviz_file_frames(global.aviz_file))
        + " rate=" + string(global.aviz_rate)
        + " channels=" + string(aviz_file_channels(global.aviz_file)));
} else {
    show_debug_message("AudioViz: cannot open " + working_directory + "song.ogg (error="
        + string(global.aviz_file) + ")");
}

global.aviz_samples = buffer_create(global.aviz_fft_size * 4, buffer_fixed, 1);
global.aviz_spectrum = buffer_create((global.aviz_fft_size div 2 + 1) * 4, buffer_fixed, 1);
global.aviz_spectrum_db = buffer_create((global.aviz_fft_size div 2 + 1) * 4, buffer_fixed, 1);
global.aviz_bands_target = buffer_create(global.aviz_band_count * 4, buffer_fixed, 1);
global.aviz_bands = buffer_create(global.aviz_band_count * 4, buffer_fixed, 1);
buffer_fill(global.aviz_bands_target, 0, buffer_f32, 0, global.aviz_band_count * 4);
buffer_fill(global.aviz_bands, 0, buffer_f32, 0, global.aviz_band_count * 4);
global.aviz_waterfall = aviz_waterfall_create(320, 128, 2);

// ----------------------------------------------------------------------------
//  Step event
// ----------------------------------------------------------------------------
if (global.aviz_file > 0) {
    var _tp = (global.aviz_inst >= 0) ? audio_sound_get_track_position(global.aviz_inst) : -1;
    if (_tp >= 0) {
        global.aviz_read_pos = _tp * global.aviz_rate;
    } else {
        var _fps = game_get_speed(gamespeed_fps);
        if (_fps <= 0) _fps = 60;
        global.aviz_read_pos += global.aviz_rate / _fps;
    }

    var _total = aviz_file_frames(global.aviz_file);
    if (_total > global.aviz_fft_size &&
        global.aviz_read_pos >= _total - global.aviz_fft_size) {
        global.aviz_read_pos = 0;
    }

    global.aviz_last_read = aviz_file_read_into(global.aviz_samples, global.aviz_file,
        floor(global.aviz_read_pos), global.aviz_fft_size);
    if (global.aviz_last_read < global.aviz_fft_size) {
        var _got = max(global.aviz_last_read, 0);
        buffer_fill(global.aviz_samples, _got * 4, buffer_f32, 0,
            (global.aviz_fft_size - _got) * 4);
    }
} else if (global.aviz_recorder > -1 && global.aviz_record_buf != noone) {
    var _sz = buffer_get_size(global.aviz_record_buf);
    var _copy = min(global.aviz_fft_size * 4, _sz);
    buffer_copy(global.aviz_record_buf, _sz - _copy, _copy, global.aviz_samples, 0);
} else {
    buffer_fill(global.aviz_samples, 0, buffer_f32, 0, global.aviz_fft_size * 4);
}

aviz_analyze_spectrum_into(global.aviz_spectrum,
    global.aviz_samples, global.aviz_fft_size, global.aviz_fft_size);
aviz_analyze_spectrum_db_into(global.aviz_spectrum_db,
    global.aviz_samples, global.aviz_fft_size, global.aviz_fft_size);
aviz_visual_bands_into(global.aviz_bands_target,
    global.aviz_spectrum, global.aviz_fft_size div 2 + 1, global.aviz_band_count);

var _lvl = aviz_level(global.aviz_samples, global.aviz_fft_size);
global.aviz_level_peak = max(_lvl.peak, 0);
global.aviz_level_rms = max(_lvl.rms, 0);

var _bandMax = 0;
var _energy = 0;
var _flux = 0;
for (var _i = 0; _i < global.aviz_band_count; _i++) {
    var _target = buffer_peek(global.aviz_bands_target, _i * 4, buffer_f32);
    var _prev = buffer_peek(global.aviz_bands, _i * 4, buffer_f32);
    var _rate = (_target > _prev) ? 0.68 : 0.16;
    var _smooth = lerp(_prev, _target, _rate);

    buffer_poke(global.aviz_bands, _i * 4, buffer_f32, _smooth);
    _bandMax = max(_bandMax, _smooth);
    _energy += _smooth;
    _flux += max(_smooth - _prev, 0);
}

_energy /= global.aviz_band_count;
_flux /= global.aviz_band_count;
global.aviz_flux = _flux;
global.aviz_energy_fast = lerp(global.aviz_energy_fast, _energy, 0.48);
global.aviz_energy_slow = lerp(global.aviz_energy_slow, _energy, 0.04);

var _fluxHit = (_flux / max(global.aviz_band_display_max, 0.035)) * 5;
var _energyHit = max(0, (global.aviz_energy_fast - global.aviz_energy_slow)
    / max(global.aviz_energy_slow, 0.02)) * 0.65;
var _hit = clamp(max(_fluxHit, _energyHit), 0, 1);
global.aviz_pulse = max(global.aviz_pulse * 0.82, _hit);

var _targetMax = max(_bandMax * 1.1, 0.04);
var _gainRate = (_targetMax > global.aviz_band_display_max) ? 0.12 : 0.04;
global.aviz_band_display_max = clamp(
    lerp(global.aviz_band_display_max, _targetMax, _gainRate),
    0.04,
    1.2
);

// ----------------------------------------------------------------------------
//  Draw event
// ----------------------------------------------------------------------------
var _cw = camera_get_view_width(camera_get_active());
var _ch = camera_get_view_height(camera_get_active());
var _pulse = clamp(global.aviz_pulse, 0, 1);
var _bandDrawMax = max(global.aviz_band_display_max * (1 - _pulse * 0.25), 0.025);

draw_set_color(c_white);
draw_set_alpha(1);
gpu_set_blendmode(bm_normal);

aviz_draw_waveform(global.aviz_samples, global.aviz_fft_size,
    20, 20, _cw * 0.45, 90, c_lime, 0.26 + _pulse * 0.18);
aviz_draw_oscilloscope(global.aviz_samples, global.aviz_fft_size,
    20, 130, _cw * 0.45, 90, c_aqua, 0.35 + _pulse * 0.85);
aviz_draw_bars(global.aviz_spectrum_db, global.aviz_fft_size div 2 + 1,
    _cw * 0.47, 20, _cw * 0.51, 90, c_yellow, 0, 0, -72, 0.55);

draw_set_alpha(0.22 + _pulse * 0.35);
aviz_draw_bars(global.aviz_bands, global.aviz_band_count,
    _cw * 0.47, 130, _cw * 0.51, 90, c_fuchsia, 1, max(_bandDrawMax * 0.85, 0.02), 0, 0.32);
draw_set_alpha(1);
aviz_draw_bars(global.aviz_bands, global.aviz_band_count,
    _cw * 0.47, 130, _cw * 0.51, 90, c_fuchsia, 2, _bandDrawMax, 0, 0.42);

draw_set_alpha(0.12 + _pulse * 0.24);
draw_circle_color(220, 320, 32 + _pulse * 28, c_orange, c_orange, false);
draw_set_alpha(1);
aviz_draw_ring(global.aviz_bands, global.aviz_band_count,
    220, 320, 68 - _pulse * 5, 122 + _pulse * 42, c_orange,
    _bandDrawMax, 0, 0.42, 0.06 + _pulse * 0.12);

aviz_waterfall_feed(global.aviz_waterfall, global.aviz_spectrum_db,
    global.aviz_fft_size div 2 + 1, 0, -72);
aviz_waterfall_draw(global.aviz_waterfall, max(20, _cw - 340), 240, 1);

draw_set_color(c_white);
draw_set_alpha(1);
draw_text(20, _ch - 30, "peak=" + string(global.aviz_level_peak)
    + "  rms=" + string(global.aviz_level_rms)
    + "  pulse=" + string(global.aviz_pulse)
    + "  flux=" + string(global.aviz_flux));

if (global.aviz_file > 0) {
    draw_set_color(c_silver);
    draw_set_alpha(1);
    draw_text(20, _ch - 60, "pos=" + string(floor(global.aviz_read_pos))
        + "  read=" + string(global.aviz_last_read)
        + "  frames=" + string(aviz_file_frames(global.aviz_file)));
}

// ----------------------------------------------------------------------------
//  Clean Up event
// ----------------------------------------------------------------------------
if (global.aviz_file > 0) aviz_file_close(global.aviz_file);
if (global.aviz_record_buf != noone) buffer_delete(global.aviz_record_buf);
buffer_delete(global.aviz_samples);
buffer_delete(global.aviz_spectrum);
buffer_delete(global.aviz_spectrum_db);
buffer_delete(global.aviz_bands_target);
buffer_delete(global.aviz_bands);
aviz_waterfall_destroy(global.aviz_waterfall);
