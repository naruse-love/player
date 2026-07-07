# Coriander Player v1.5.2 Release Notes

> 基于 [Ferry-200/coriander_player](https://github.com/Ferry-200/coriander_player) v1.5.1 的增强改版

## 📦 下载

前往 [Releases](https://github.com/naruse-love/player/releases/latest) 下载最新安装包。

---

## ✨ 新增功能

### 🎵 播放统计系统
- **完整播放追踪**：自动记录每首歌的播放次数、有效收听时长
- **多种筛选视图**：支持按今天、本周、本月、上月、全部及自定义时间范围筛选
- **统计图表**：直方图展示收听时段分布（按小时/按天/按月），Y 轴和柱上标签显示格式化时长（如 `1h30m`、`45min`）
- **排行榜**：本时段热门 Top 10 播放次数排行 + 最多收听 Top 10 累计时长排行
- **每日详情**：按天分组展示所有播放记录

### 🔊 逐字歌词全面支持
- **QRC 格式**（QQ 音乐逐字歌词）解析与显示
- **KRC 格式**（酷狗音乐逐字歌词）解析与显示
- **ELRC 格式**（增强型逐字歌词）解析与显示
- **逐字桌面歌词**：桌面歌词窗口同步展示逐字效果
- **智能格式检测**：自动识别 LRC / QRC / KRC / ELRC 格式

### 💾 歌词管理增强
- **在线歌词保存到本地**：在歌词菜单中将匹配到的在线歌词保存为 `.lrc` 文件到歌曲同目录
- **歌词写入音频标签**：将歌词直接写入音频文件元数据（支持 mp3、flac、m4a、ogg、opus 等格式）
- **翻译时间轴对齐**：QRC / KRC / ELRC 翻译行通过时间戳精准匹配

### 🔄 播放体验优化
- **播放列表持久化**：关闭应用后自动保存当前播放列表和播放进度，下次启动自动恢复
- **持续收听时长追踪**：精准追踪每首歌的有效收听时间（基于增量进度累加，抗回拖作弊）
- **快捷键支持**：`Space` 播放/暂停、`Ctrl+←/→` 切歌、`Esc` 返回

### 🛠️ 技术改进
- **Rust 后端增强**：新增 `tag_writer`（歌词写入标签）、`installed_font`（字体枚举）、`system_theme`（系统主题色获取）等模块
- **Flutter 升级**：适配 Flutter 3.44.0，Material You 动态配色
- **数据目录迁移**：从 `com.example/coriander_player` 迁移到 `Documents/coriander_player`，数据更安全
- **依赖更新**：`material_symbols_icons` 升级至 4.2951.0，`flutter_rust_bridge` 2.11.1

### 🔧 CI/CD
- **GitHub Actions 自动构建**：手动触发自动构建 Windows 安装包
- **集成 BASS 音频库**：自动下载并打包 BASS 库及插件
- **集成桌面歌词组件**：自动构建 `desktop_lyric` 并打包

---

## 🐛 问题修复

- 修复原版播放列表状态丢失问题
- 修复 BASS 插件加载路径错误
- 修复统计数据中快进/回退导致的收听时长不准确
- 修复 KRC 歌词括号被误识别为 QRC 的问题
- 修复自定义日期范围空指针崩溃
- 修复自动切歌时播放计数不准确
- 修复歌词标签写入时的文件锁问题
- 修复桌面歌词中逐字歌词相对时间戳逻辑
- 修复 QRC / KRC / ELRC 翻译行缺失问题

---

## 📋 格式支持

### 音乐格式
mp3, mp2, mp1, ogg, wav/wave, aif/aiff/aifc, asf/wma, aac/adts, m4a, ac3, amr/3ga, flac, mpc, mid, wv/wvc, opus, dsf/dff, ape

### 内嵌歌词支持
aac, aiff, flac, m4a, mp3, ogg, opus, wav（标签需 UTF-8 编码）

### 外挂歌词格式
- LRC（标准逐行歌词）
- QRC（QQ 音乐逐字歌词）
- KRC（酷狗音乐逐字歌词）
- ELRC（增强型逐字歌词）
- 外挂 LRC 编码：UTF-8 / UTF-16

---

## 🙏 致谢

- [Ferry-200](https://github.com/Ferry-200) — 原版 Coriander Player 作者
- [music_api](https://github.com/yhsj0919/music_api) — 歌曲匹配和歌词获取
- [Lofty](https://crates.io/crates/lofty) — 音频标签读写
- [BASS](https://www.un4seen.com/bass.html) — 音频播放引擎
- [flutter_rust_bridge](https://pub.dev/packages/flutter_rust_bridge) — Dart/Rust FFI 桥梁
- [Silicon7921](https://github.com/Silicon7921) — 应用图标设计
