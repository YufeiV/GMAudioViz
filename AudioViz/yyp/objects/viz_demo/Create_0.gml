global.aviz_fft_size = 1024;                       // FFT 长度(2 的幂)
global.aviz_band_count = 64;                       // 条形图/环形图的频带数
global.aviz_file = -1;
global.aviz_inst = -1;
global.aviz_rate = 44100;
global.aviz_read_pos = 0;                       // 当前读取位置(采样), 由 Step 每帧推进
global.aviz_last_read = -1;                     // 上一帧实际读到的采样数(调试用)
global.aviz_record_buf = noone;
global.aviz_recorder = -1;
global.aviz_band_display_max = 0.12;
global.aviz_energy_fast = 0;
global.aviz_energy_slow = 0;
global.aviz_flux = 0;
global.aviz_pulse = 0;
global.aviz_level_peak = 0;
global.aviz_level_rms = 0;

// --- A. 文件模式: 打开音频文件(用于按播放进度可视化) ---
global.aviz_file = aviz_file_open(working_directory + "song.ogg");
if (global.aviz_file > 0) {
    global.aviz_rate = aviz_file_sample_rate(global.aviz_file);
	var stream = audio_create_stream(working_directory + "song.ogg");
    global.aviz_inst = audio_play_sound(stream, 0, true);   // 需要 Stream 声音
    show_debug_message("AudioViz: frames=" + string(aviz_file_frames(global.aviz_file))
        + " rate=" + string(global.aviz_rate)
        + " channels=" + string(aviz_file_channels(global.aviz_file)));
} else {
    show_debug_message("AudioViz: 无法打开 " + working_directory + "song.ogg (error=" + string(global.aviz_file) + ")");
    show_debug_message("AudioViz: 请确认文件已放入游戏工作目录，且格式受支持(WAV/AIFF/AU/RAW/OGG)");
}

// --- 分析/绘制用的常驻缓冲(每帧复用, 避免反复分配) ---
global.aviz_samples = buffer_create(global.aviz_fft_size * 4, buffer_fixed, 1);
global.aviz_spectrum = buffer_create((global.aviz_fft_size div 2 + 1) * 4, buffer_fixed, 1);
global.aviz_spectrum_db = buffer_create((global.aviz_fft_size div 2 + 1) * 4, buffer_fixed, 1);
global.aviz_bands_target = buffer_create(global.aviz_band_count * 4, buffer_fixed, 1);
global.aviz_bands = buffer_create(global.aviz_band_count * 4, buffer_fixed, 1);
buffer_fill(global.aviz_bands_target, 0, buffer_f32, 0, global.aviz_band_count * 4);
buffer_fill(global.aviz_bands, 0, buffer_f32, 0, global.aviz_band_count * 4);
global.aviz_waterfall = aviz_waterfall_create(320, 128, 2);
