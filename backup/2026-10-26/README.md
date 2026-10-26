# 完整快照恢复说明

原工程的完整压缩快照按最多 8 MiB 分成 9 块，并保存在本目录的 chunks 中。源代码与原有 Git 提交仍在 main 历史里。

```sh
cd backup/2026-10-26
shasum -a 256 -c parts.sha256
cat chunks/part-* > ai-video-impedance-matching-full-2026-10-26.tar.gz
shasum -a 256 -c snapshot.sha256
mkdir restored
tar -xzf ai-video-impedance-matching-full-2026-10-26.tar.gz -C restored
```

Linux 可用 sha256sum 替代 shasum -a 256。完整归档包含 .git、build、output 以及忽略文件。file-manifest.json 记录全部文件、目录、权限、大小和 SHA-256。

[Release 附件](https://github.com/liuyinchu/ai-video-impedance-matching/releases/tag/backup-2026-10-26)
[自动回验记录](https://github.com/liuyinchu/ai-video-impedance-matching/blob/backup-verified-2026-10-26/verification.json)
