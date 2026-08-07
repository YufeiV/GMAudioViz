var _cw = camera_get_view_width(camera_get_active());
var _ch = camera_get_view_height(camera_get_active());
var _pulse = clamp(global.aviz_pulse, 0, 1);
var _bandDrawMax = max(global.aviz_band_display_max * (1 - _pulse * 0.25), 0.025);

draw_set_color(c_white);
draw_set_alpha(1);
gpu_set_blendmode(bm_normal);

// 1) Waveform envelope.
aviz_draw_waveform(global.aviz_samples, global.aviz_fft_size,
    20, 20, _cw * 0.45, 90, c_lime, 0.26 + _pulse * 0.18);

// 2) Oscilloscope with pulse-driven glow.
aviz_draw_oscilloscope(global.aviz_samples, global.aviz_fft_size,
    20, 130, _cw * 0.45, 90, c_aqua, 0.35 + _pulse * 0.85);

// 3) Full FFT bins in dB, curved so quieter motion remains visible.
aviz_draw_bars(global.aviz_spectrum_db, global.aviz_fft_size div 2 + 1,
    _cw * 0.47, 20, _cw * 0.51, 90, c_yellow, 0, 0, -72, 0.55);

// 4) Visual log bands. First pass is a soft glow, second pass is the crisp body.
draw_set_alpha(0.22 + _pulse * 0.35);
aviz_draw_bars(global.aviz_bands, global.aviz_band_count,
    _cw * 0.47, 130, _cw * 0.51, 90, c_fuchsia, 1, max(_bandDrawMax * 0.85, 0.02), 0, 0.32);
draw_set_alpha(1);
aviz_draw_bars(global.aviz_bands, global.aviz_band_count,
    _cw * 0.47, 130, _cw * 0.51, 90, c_fuchsia, 2, _bandDrawMax, 0, 0.42);

// 5) Ring visualizer, using the same pulse so beats visibly breathe.
draw_set_alpha(0.12 + _pulse * 0.24);
draw_circle_color(220, 320, 32 + _pulse * 28, c_orange, c_orange, false);
draw_set_alpha(1);
aviz_draw_ring(global.aviz_bands, global.aviz_band_count,
    220, 320, 68 - _pulse * 5, 122 + _pulse * 42, c_orange,
    _bandDrawMax, 0, 0.42, 0.06 + _pulse * 0.12);

// 6) Waterfall: feed in Draw because it renders into surfaces.
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
