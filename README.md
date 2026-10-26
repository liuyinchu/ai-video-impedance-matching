# 阻抗匹配：为什么接通了，信号还会回来？

一支面向初学者的中文科普视频，用自绘动态图解区分线路无反射、最大功率传输和音频电压桥接。

## 成品

- `output/impedance-matching.mp4`：1280 × 720、30 fps，H.264 视频及中文语音。
- `output/impedance-matching.zh-CN.srt`：中文字幕，成片中也已烧录字幕。
- `output/index.html`：本地播放页，附章节跳转与下载链接。
- `output/cover.png` / `output/cover.jpg`：发布封面；生成提示词和方法见 `output/cover-production.txt`。
- `output/video-description.txt`：发布标题、简介、章节与话题。
- `output/contact-sheet.png`：12 幕概览。
- `output/chapters.txt`：章节时间。
- `content/scenes.json`：可编辑的分镜与配音稿。
- `content/sources.md`：一手技术依据与算例边界。

所有代码、配音、画面与视频均在远端仓库制作：
`/Users/yangshuyun/workspace/dev/ai-video/ai-video-1026-sol`。

## 重新制作

需要 macOS、Xcode Command Line Tools / Swift、Ruby 标准库与可访问微软在线语音服务的网络。无需下载素材、安装依赖或使用 Python。

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

`prepare` 为每句合成微软神经语音 MP3，保存时间轴；缓存会比较文本、语音与语速。
默认 `NARRATION_VOICE=zh-CN-YunxiNeural`（微软云希普通话男声），`NARRATION_RATE=-8%`。
`silent` 和 `mux` 可分别执行画面编码及音轨合成。
`verify` 完整解码每一帧，检查帧时间戳连续性、视频参数和时长，并逐个20秒区间检查音轨非静音。
字幕每块不超过30字，优先按标点分割，块内时间按字符数比例估计；逐句音频起点与时间轴严格一致。

## 制作说明

- 配音使用微软在线神经语音云希男声；[微软语音列表](https://learn.microsoft.com/azure/cognitive-services/speech-service/language-support?tabs=tts)。
- Swift + CoreGraphics / CoreText 绘制，AVFoundation 编码与混音；无第三方视觉素材。
- 青色为入射电压波，橙色为反射电压波；反射动画仅示意一次末端反射，省略源端再次反射。
- 50 Ω 线路接 25 / 50 / 100 Ω 纯电阻，清楚区分反射电压幅度与反射功率比例。
- 最大功率示例为 10 V 固定直流戴维南源与 50 Ω 内阻；共轭匹配另行限定线性源与工作频率。
- 技术内容参照 Analog Devices、Keysight 与 Texas Instruments，链接见 `content/sources.md`。
- 大型视频和构建缓存由 Git 忽略；可复现源文件及字幕保留在版本控制中。

## 播放预览

在远端仓库运行：

```sh
/usr/bin/ruby scripts/preview-server.rb
```

预览服务监听远端 127.0.0.1:18786，明确返回 video/mp4、Accept-Ranges: bytes，并禁用缓存，避免成片更新后浏览器混用旧数据。通过 SSH 转发访问：

```sh
ssh -N -L 18786:127.0.0.1:18786 yangshuyun@10.10.10.1
```

然后打开 http://127.0.0.1:18786/index.html 。播放器使用完整预加载、明确的播放按钮与错误提示。
追加 ?diagnostic=1 可显示仅用于复核的播放事件、缓冲范围和当前位置。

## 完整工程备份与恢复

[下载完整工程与成片](https://github.com/liuyinchu/ai-video-impedance-matching/releases/tag/backup-2026-10-26) · [备份与恢复说明](backup/2026-10-26/README.md) · [自动校验记录](https://github.com/liuyinchu/ai-video-impedance-matching/blob/backup-verified-2026-10-26/verification.json)

完整快照包含原工程的 313 个文件（含 .git、build、配音、视频及被 Git 忽略的输出），采用分块 Git 备份并由 GitHub Actions 重组为 Release 附件。只有在解压逐文件检查与 Release 下载回验均通过后，才生成校验记录。
