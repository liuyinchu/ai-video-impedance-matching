# 阻抗匹配：为什么接通了，信号还会回来？

一支面向初学者的中文科普视频，用自绘动态图解区分线路无反射、最大功率传输和音频电压桥接。

## 成品

- `output/impedance-matching.mp4`：1280 × 720、30 fps，H.264 视频及中文语音。
- `output/impedance-matching.zh-CN.srt`：中文字幕，成片中也已烧录字幕。
- `output/index.html`：本地播放页，附章节跳转与下载链接。
- `output/contact-sheet.png`：12 幕概览。
- `output/chapters.txt`：章节时间。
- `content/scenes.json`：可编辑的分镜与配音稿。
- `content/sources.md`：一手技术依据与算例边界。

所有代码、配音、画面与视频均在远端仓库制作：
`/Users/yangshuyun/workspace/dev/ai-video/ai-video-1026-sol`。

## 重新制作

需要 macOS、Xcode Command Line Tools / Swift、系统中文 Tingting 语音与 Ruby 标准库。无需下载素材、安装依赖或使用 Python。

```sh
./scripts/render.sh
```

也可分步执行：

```sh
./scripts/build.sh
build/impedance-video prepare
build/impedance-video preview
build/impedance-video render
build/impedance-video verify
/usr/bin/ruby scripts/metadata.rb
```

`prepare` 为每句合成 AIFF，保存时间轴；缓存会比较文本、语音与语速。
默认 `NARRATION_VOICE=Tingting`，`NARRATION_RATE=165`。
`silent` 和 `mux` 可分别执行画面编码及音轨合成。
`verify` 检查实际解码帧、视频参数、音轨、时长和非静音采样。
字幕每块不超过30字，优先按标点分割，块内时间按字符数比例估计；逐句音频起点与时间轴严格一致。

## 制作说明

- Swift + CoreGraphics / CoreText 绘制，AVFoundation 编码与混音；无第三方视觉素材。
- 青色为入射电压波，橙色为反射电压波；反射动画仅示意一次末端反射，省略源端再次反射。
- 50 Ω 线路接 25 / 50 / 100 Ω 纯电阻，清楚区分反射电压幅度与反射功率比例。
- 最大功率示例为 10 V 固定直流戴维南源与 50 Ω 内阻；共轭匹配另行限定线性源与工作频率。
- 技术内容参照 Analog Devices、Keysight 与 Texas Instruments，链接见 `content/sources.md`。
- 大型视频和构建缓存由 Git 忽略；可复现源文件及字幕保留在版本控制中。
