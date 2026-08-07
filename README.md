# AudioViz — GameMaker Studio 2 音频可视化扩展

AudioViz 是一个基于 C++ 原生扩展的 GameMaker Studio 2 音频可视化库，提供一整套
**分析 + 绘制** 函数，让你可以轻松实现：

| 可视化 | 说明 | 对应函数 |
|---|---|---|
| 波形图 | min/max 包络 | `aviz_draw_waveform` |
| 频谱图 | FFT 幅度谱条形图 | `aviz_analyze_spectrum` + `aviz_draw_bars` |
| 条形图 | 线性/对数频带均衡器 | `aviz_bands` / `aviz_bands_log` + `aviz_draw_bars` |
| 瀑布图 | 滚动频谱历史（热力图） | `aviz_waterfall_*` |
| 环形图 | 频带环绕圆环 | `aviz_bands` + `aviz_draw_ring` |
| 模拟示波器 | 原始采样折线 + 余辉 | `aviz_draw_oscilloscope` |
| 电平表 | peak / RMS / 平均 / DC | `aviz_level` |

核心算法（FFT、频带聚合、峰值检测、窗函数）在 C++ 中完成（FFTW + libsndfile），
GML 层负责缓冲桥接和绘制，性能足够每帧实时分析 1024~4096 点 FFT。

---

## 目录结构

```
GMAudioViz/
├── AudioViz/                        # 扩展项目
│   ├── AudioViz.cpp                 # C++ 核心（17 个导出函数）
│   ├── CMakeLists.txt               # 构建脚本（链接 FFTW/libsndfile 静态库）
│   ├── CMakePresets.json            # CMake 预设（Windows x64 等）
│   ├── native-lib.cpp               # Android JNI 桥（预留）
│   ├── AndroidSource/Java/          # Android Java 类（预留）
│   ├── iOSSource/                   # iOS Objective-C++ 桥（预留）
│   ├── gml/
│   │   ├── extension_wrappers.gml   # 全部 aviz_* 包装函数 + 绘制函数
│   │   └── audio_viz_demo.gml       # 演示对象 obj_audio_viz_demo 的事件代码
│   ├── scripts/build_extension.ps1  # 构建扩展 DLL 的脚本
│   ├── tools/smoke_test.cpp         # 无需 GMS 的 DLL 冒烟测试（开发用）
│   └── README.md
├── scripts/build_thirdparty.ps1     # 构建 FFTW + libogg/libvorbis + libsndfile 静态库
├── fftw-3.3.11/                     # FFTW 3.3.11 源码
├── libsndfile/                      # libsndfile 源码
└── third_party/dist/                # 构建产物：include/ + lib/（fftw3.lib, sndfile.lib）
```

---

## 一、构建扩展（Windows x64）

### 1. 构建第三方静态库（只需一次）

需要 Visual Studio（含 C++ 工具链）+ 随 VS 附带的 CMake/Ninja。在 **VS Developer
PowerShell**（或 x64 Native Tools Command Prompt）中运行：

```powershell
powershell -ExecutionPolicy Bypass -File scripts/build_thirdparty.ps1
```

产物输出到 `third_party/dist/`：

- `include/fftw3.h`、`include/sndfile.h`、`include/ogg/*.h`、`include/vorbis/*.h`
- `lib/fftw3.lib`、`lib/sndfile.lib`、`lib/ogg.lib`、`lib/vorbis.lib`、`lib/vorbisenc.lib`

> libsndfile 已启用 **Ogg Vorbis** 外部编解码（WAV/AIFF/AU/RAW/OGG 等均可读取）。
> 本地 libsndfile 打了小补丁：把上游「必须同时有 Vorbis+FLAC+Opus」的要求放宽为
> 只依赖 Vorbis+Ogg（由 `scripts/patch_libsndfile.cmake` 在构建时应用）。FLAC、
> Opus、MP3 暂未启用；如需可仿照 `scripts/build_thirdparty.ps1` 加入对应外部库。

### 2. 构建 AudioViz.dll

仍在 VS Developer PowerShell 中：

```powershell
powershell -ExecutionPolicy Bypass -File AudioViz/scripts/build_extension.ps1 `
    -ProjectDir AudioViz -Preset x64-release
```

产物：`AudioViz/out/build/x64-release/AudioViz.dll`（x64 Release）。

也可以直接 `cmake --preset x64-release && cmake --build out/build/x64-release`
或在 Visual Studio 中打开 `AudioViz/CMakeLists.txt` 构建。

### 3. （可选）运行冒烟测试

`tools/smoke_test.cpp` 在无 GameMaker 的情况下直接加载 `AudioViz.dll`，验证 FFT
峰值位置、波形峰值、电平、WAV 解码与文件频谱：

```powershell
cl /nologo /EHsc tools/smoke_test.cpp /Fe:smoke_test.exe
# 把 AudioViz.dll 复制到同一目录后运行
smoke_test.exe
```

---

## 二、在 GameMaker Studio 2 中集成

### 1. 创建扩展并注册函数

1. 在 GMS 资源树中右键 → **Create → Extension**，命名为 `AudioViz`。
2. 为该扩展添加下面 **17 个函数**。每项配置：
   - **Name**：GML 中调用的名字（建议与 External Name 相同）
   - **External Name**：必须与下表完全一致（区分大小写，否则运行时找不到函数）
   - **Return Type** / **Argument Type**：按下表
   - 勾选 **Hidden**（用户只调用 `aviz_*` 包装函数）

| External Name | 返回类型 | 参数（按顺序） |
|---|---|---|
| `AudioViz_GetVersion` | String | 无 |
| `AudioViz_AnalyzeSpectrum` | Real | String, Real, Real, String |
| `AudioViz_AnalyzeSpectrumDB` | Real | String, Real, Real, String |
| `AudioViz_WaveformPeaks` | Real | String, Real, Real, String |
| `AudioViz_Bands` | Real | String, Real, Real, String |
| `AudioViz_BandsLog` | Real | String, Real, Real, String |
| `AudioViz_VisualBands` | Real | String, Real, Real, String |
| `AudioViz_Level` | Real | String, Real, String |
| `AudioViz_ApplyWindow` | Real | String, Real, Real, String |
| `AudioViz_Downmix` | Real | String, Real, Real, String |
| `AudioViz_FileOpen` | Real | String |
| `AudioViz_FileFrames` | Real | Real |
| `AudioViz_FileSampleRate` | Real | Real |
| `AudioViz_FileChannels` | Real | Real |
| `AudioViz_FileRead` | Real | Real, Real, Real, String |
| `AudioViz_FileSpectrum` | Real | Real, Real, Real, String |
| `AudioViz_FileClose` | Real | Real |

说明：

- **String 参数 = GMS 缓冲地址**（`string(buffer_get_address(buff))`），C++ 端负责转换。
- 每个函数最多 4 个混合类型参数，符合 GMS 限制。
- `AudioViz_GetVersion` 返回扩展版本号字符串。

### 2. 添加 DLL 代理文件并勾选平台

1. 在扩展的 **Options → Windows** 里：勾选 **Windows** 平台，设置
   **Copies to: Windows**。
2. 把 `AudioViz.dll` 添加为 Windows 的 **proxy file**。
3. （其他平台同理：Ubuntu 用 `.so`、macOS 用 `.dylib`、Android 用
   `AndroidSource/libs/lib.jar`——Android/iOS 目前为预留支持，需要先把
   FFTW/libsndfile 构建到对应 ABI，见「跨平台」一节。）

### 3. 导入 GML 包装函数

新建脚本（或直接把文件拖进项目），导入
`AudioViz/gml/extension_wrappers.gml`。该文件定义了全部 `aviz_*` 分析函数和
`aviz_draw_*` / `aviz_waterfall_*` 绘制函数，带完整 JSDoc，Feather 会自动提示。

---

## 三、使用示例

### 数据源 A：播放音频文件并同步可视化（推荐）

把音乐文件（如 `song.ogg`）放到游戏工作目录或 datafiles。`snd_song` 建议勾选
**Stream**（可与播放精确同步）；未勾选时 demo 会自动用帧计数器推进读取位置，
波形/频谱依然持续滚动。

```gml
// Create
global.aviz_fft = 1024;
global.aviz_file = aviz_file_open(working_directory + "song.ogg");   // libsndfile 解码
global.aviz_rate = aviz_file_sample_rate(global.aviz_file);
global.aviz_inst = audio_play_sound(snd_song, 0, true);
global.aviz_read_pos = 0;   // 当前读取位置(采样), Step 里推进
global.aviz_samples  = buffer_create(global.aviz_fft * 4, buffer_fixed, 1);
global.aviz_spectrum = buffer_create((global.aviz_fft div 2 + 1) * 4, buffer_fixed, 1);

// Step：优先按播放进度取一窗样本；取不到(非 Stream)时用帧计数器自走
var _tp = (global.aviz_inst >= 0) ? audio_sound_get_track_position(global.aviz_inst) : -1;
if (_tp >= 0) {
    global.aviz_read_pos = _tp * global.aviz_rate;
} else {
    global.aviz_read_pos += global.aviz_rate / game_get_speed(gamespeed_fps);
}
var _total = aviz_file_frames(global.aviz_file);
if (global.aviz_read_pos >= _total - global.aviz_fft) global.aviz_read_pos = 0;
aviz_file_read_into(global.aviz_samples, global.aviz_file, floor(global.aviz_read_pos), global.aviz_fft);
aviz_analyze_spectrum_into(global.aviz_spectrum, global.aviz_samples, global.aviz_fft, global.aviz_fft);

// Draw：条形图 / 环形图 / 波形图
aviz_draw_bars(global.aviz_spectrum, global.aviz_fft div 2 + 1, 40, 40, 400, 160, c_lime, 1, 1, 0);
aviz_draw_waveform(global.aviz_samples, global.aviz_fft, 40, 240, 400, 100, c_aqua);

// Clean Up
aviz_file_close(global.aviz_file);
buffer_delete(global.aviz_samples);
buffer_delete(global.aviz_spectrum);
```

### 数据源 B：录音源实时可视化（可选）

GameMaker 的录音功能把音频录制进缓冲（通常是麦克风等输入源，且只在部分平台
可用）。开启录音后，把 PCM 缓冲交给 `aviz_analyze_spectrum_into` 即可，绘制部分
与文件模式完全相同。完整示例（含 Audio Recording 异步事件）见
`gml/audio_viz_demo.gml`。

### 瀑布图

```gml
waterfall = aviz_waterfall_create(256, 128, 2);   // 宽 256px, 高 128px, 每行 2px
// Step 每帧:
aviz_waterfall_feed(waterfall, global.aviz_spectrum, bins, 1, 0);   // 线性谱 0..1
// dB 谱用: aviz_waterfall_feed(waterfall, spec, bins, 0, -60);
// Draw:
aviz_waterfall_draw(waterfall, 640, 40);
```

### 电平表

```gml
var _lvl = aviz_level(global.aviz_samples, global.aviz_fft);
draw_text(10, 10, "peak=" + string(_lvl.peak) + " rms=" + string(_lvl.rms));
```

---

## 四、GML API 速览

### 分析（全部基于 float32 缓冲）

| 函数 | 说明 |
|---|---|
| `aviz_analyze_spectrum[_db][_into]` | FFT 幅度谱（线性或 dB，内部加 Hann 窗） |
| `aviz_waveform_peaks[_into]` | 每段 min/max 采样对 |
| `aviz_bands[_log][_into]` | Analysis bands (linear/log mean) |
| `aviz_visual_bands[_into]` | Visual-reactive log bands (RMS/peak blend) |
| `aviz_level` | peak / rms / avg / dc |
| `aviz_apply_window` | 0=矩形 1=Hann 2=Hamming 3=Blackman 4=Blackman-Harris |
| `aviz_downmix_into` | 多声道转单声道 |
| `aviz_buffer_frames` / `aviz_spectrum_bins` | 工具函数 |

### 文件（libsndfile）

| 函数 | 说明 |
|---|---|
| `aviz_file_open(_path)` | 打开音频文件，返回句柄 |
| `aviz_file_frames/_sample_rate/_channels(_handle)` | 文件信息 |
| `aviz_file_read[_into](_handle, _startFrame, _frames)` | 读取单声道 float32（自动降混） |
| `aviz_file_spectrum(_handle, _startFrame, _fftSize)` | 直接读文件算频谱 |
| `aviz_file_close(_handle)` | 关闭文件 |

### 绘制

| 函数 | 说明 |
|---|---|
| `aviz_draw_waveform(...)` | 波形图（min/max 包络） |
| `aviz_draw_oscilloscope(...)` | 示波器折线（带余辉） |
| `aviz_draw_bars(...)` | 通用条形图（频谱/频带通用） |
| `aviz_draw_ring(...)` | 环形图 |
| `aviz_waterfall_create/feed/draw/destroy(...)` | 瀑布图 |

缓冲生命周期：**“返回缓冲”的包装函数会新建缓冲，用完必须 `buffer_delete`**；
`_into` 系列复用已有缓冲，适合每帧热循环。

---

## 五、常见问题

- **找不到函数 / 调用报错**：External Name 与 C++ 导出符号不一致（大小写敏感），
  或扩展平台勾选/Copies to 未配置。用 `dumpbin /exports AudioViz.dll` 可核对导出表。
- **DLL 无法加载**：必须是 x64 Release（GMS 桌面端只运行 64 位）；检查代理文件
  是否随构建打包。
- **音频文件打不开**：确认路径存在且文件名为 ASCII；Windows 上 C++ 端会优先按
  UTF-8 转换路径，但极少数情况回退 ANSI。当前 libsndfile 支持 WAV/AIFF/AU/RAW/
  OGG Vorbis；FLAC/Opus/MP3 尚未启用（如需请按 README「构建第三方库」一节扩展）。
  注意 OGG 必须是**纯音频**：带视频轨的混合 OGG（如 Theora+Vorbis 的 .ogv 改名
  .ogg）libsndfile 无法解码。可用 ffmpeg 提取音频轨：
  `ffmpeg -i song.ogg -vn -c:a libvorbis song_audio.ogg`。
- **`audio_sound_get_track_position` 返回 -1**：声音资源没有勾选 **Stream**。
  demo 已内置帧计数器回退，不勾选也能看到波形滚动；需要与播放精确同步时
  再在声音编辑器里勾选 Stream 即可。
- **瀑布图/条形图数值范围**：线性谱 `0..~1`，dB 谱 `-120..0`，绘图函数用
  `_maxValue/_minValue` 归一化。
- **崩溃**：多为缓冲大小不足或写越界。`_into` 系列请确保目标缓冲容量足够
  （如频谱缓冲 = `(fftSize div 2 + 1) * 4` 字节）。

---

## 六、跨平台（预留）

Android / iOS 的 JNI / Objective-C++ 桥已按真实 API 生成，但需要先把 FFTW 与
libsndfile 静态库构建到对应平台/ABI，并在 `CMakePresets.json` 中配置 NDK /
Xcode 工具链后才能真正编译。当前已验证并交付的平台为 **Windows x64**。

## 许可

本仓库按组件分别授权，完整许可证文本位于仓库根目录：

- GameMaker 资源、GML 包装器、示例项目和扩展元数据：MIT，见 `LICENSE-MIT.txt`。
- AudioViz 原生扩展实现、Android JNI/Java bridge、iOS Objective-C++ bridge 以及构建脚本：GPL-2.0-or-later，见 `LICENSE-GPL-2.0-or-later.txt`。
- `fftw-3.3.11`、`libsndfile`、`libogg`、libvorbis 和 libopus 等第三方源码继续遵循各自上游许可证，不受上述重新授权影响。
