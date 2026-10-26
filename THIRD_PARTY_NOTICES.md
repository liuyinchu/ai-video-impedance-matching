# 第三方组件说明

## 微软在线神经语音协议客户端

`scripts/microsoft-tts.swift` 的 v2 令牌与请求协议实现派生或参考自 [rany2/edge-tts](https://github.com/rany2/edge-tts)，保留文件头归属说明，并以 LGPL-3.0 发布该客户端文件。

上游参考：
- [drm.py](https://github.com/rany2/edge-tts/blob/master/src/edge_tts/drm.py)
- [constants.py](https://github.com/rany2/edge-tts/blob/master/src/edge_tts/constants.py)
- [communicate.py](https://github.com/rany2/edge-tts/blob/master/src/edge_tts/communicate.py)

许可全文见 `third_party/edge-tts-LICENSE.txt` 与 `third_party/GPL-3.0.txt`。客户端 Swift 源码随本仓库提供，构建方式见 `scripts/microsoft-tts.sh`。该组件独立编译为命令行程序，主视频渲染器通过进程调用它。

配音来自 Microsoft Edge Online Neural，使用 `zh-CN-YunxiNeural`（云希，普通话男声）。语音可用性与服务行为由微软服务决定。
