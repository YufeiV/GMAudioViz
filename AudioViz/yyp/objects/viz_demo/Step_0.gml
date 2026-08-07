// 1) 取一帧 PCM 样本 (读取位置每帧推进, 不依赖 Stream 声音)
if (global.aviz_file > 0) {
    // 若声音支持获取播放进度(Stream), 就与播放同步; 否则用帧计数器自走,
    // 保证波形/频谱始终在推进。
    var _tp = (global.aviz_inst >= 0) ? audio_sound_get_track_position(global.aviz_inst) : -1;
    if (_tp >= 0) {
        global.aviz_read_pos = _tp * global.aviz_rate;
    } else {
        var _fps = game_get_speed(gamespeed_fps);
        if (_fps <= 0) _fps = 60;
        global.aviz_read_pos += global.aviz_rate / _fps;
    }
    // 循环: 接近文件末尾时回到开头
    var _total = aviz_file_frames(global.aviz_file);
    if (_total > global.aviz_fft_size &&
        global.aviz_read_pos >= _total - global.aviz_fft_size) {
        global.aviz_read_pos = 0;
    }
    global.aviz_last_read = aviz_file_read_into(global.aviz_samples, global.aviz_file,
        floor(global.aviz_read_pos), global.aviz_fft_size);
    // 不足一窗时(例如刚好到文件尾)把剩余部分填静音
    if (global.aviz_last_read < global.aviz_fft_size) {
        var _got = max(global.aviz_last_read, 0);
        buffer_fill(global.aviz_samples, _got * 4, buffer_f32, 0,
            (global.aviz_fft_size - _got) * 4);
    }
} else if (global.aviz_recorder > -1 && global.aviz_record_buf != noone) {
    // 录音模式: 从录音缓冲末尾复制最近 N 个 float32 样本
    // (录音缓冲的数据格式/写入方式因 runtime 而异, 此处仅作参考)
    var _sz = buffer_get_size(global.aviz_record_buf);
    var _copy = min(global.aviz_fft_size * 4, _sz);
    buffer_copy(global.aviz_record_buf, _sz - _copy, _copy, global.aviz_samples, 0);
} else {
    // 没有数据源时填入静音, 避免界面空白
    buffer_fill(global.aviz_samples, 0, buffer_f32, 0, global.aviz_fft_size * 4);
}

// 2) 频谱分析(内部已加 Hann 窗) + 频带聚合
aviz_analyze_spectrum_into(global.aviz_spectrum,
    global.aviz_samples, global.aviz_fft_size, global.aviz_fft_size);
aviz_analyze_spectrum_db_into(global.aviz_spectrum_db,
    global.aviz_samples, global.aviz_fft_size, global.aviz_fft_size);
aviz_visual_bands_into(global.aviz_bands_target,
    global.aviz_spectrum, global.aviz_fft_size div 2 + 1, global.aviz_band_count);

// 3) 瀑布图: 每帧把最新频谱推入
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
