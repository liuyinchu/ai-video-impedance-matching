# 完整工程备份

本附件包含原工程的全部 313 个文件（74,924,507 字节），包括原始 .git 历史、构建缓存、两版配音素材、视频成片、分镜、封面、脚本和技术参考。原工程提交为 `e279f63d3e81e8df9bae2551d2f910a3dda6e8bc`。

- 完整工程：`ai-video-impedance-matching-full-2026-10-26.tar.gz`
- 文件级清单：`file-manifest.json`
- 附件校验：`SHA256SUMS`
- 成片、封面、字幕和简介也提供单独下载。

GitHub Actions 逐块校验、重组归档、解压比对每个文件与权限，并再次下载已发布附件进行 SHA-256 回验。成功后在 `backup-verified-2026-10-26` 分支写入 `verification.json`。

## 恢复

下载完整归档后，先核对 SHA256SUMS，再解压到空目录：

```sh
mkdir impedance-matching-restored
tar -xzf ai-video-impedance-matching-full-2026-10-26.tar.gz -C impedance-matching-restored
```

也可以从本仓库的 `backup/2026-10-26/chunks/` 重组完整归档；该备用副本独立于 Release 保留。
