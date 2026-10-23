# DSH 大肥鱼 · 宣传视频

`dsh-fish-buddy-promo-1080p60.mp4` —— 60 秒、1920×1080、60fps、H.264 + AAC 的项目宣传片，全部画面与配乐均由本目录脚本程序化生成。

- 画面：Pillow 在 2× 超采样画布上逐帧绘制（3840×2160 → 1920×1080 box 降采样），ffmpeg 编码 H.264 High@4.2，CRF 18，yuv420p。
- 音频：numpy 程序化合成 100 BPM A 小调 lofi（pad / 拨弦 / 贝斯 / 鼓组 / 铃音 / 环境音），完成瞬间使用项目自带的 `assets/chime.wav`，经 48 kHz 混音 + 卷积混响后 loudnorm 到 -14 LUFS。
- 场景：片头 → 实时进度 → 六种状态 → 完成提醒 → 更多细节 → 安装 → 片尾。

## 重新生成

依赖：Python 3.11+、Pillow、numpy；ffmpeg（默认使用 `imageio-ffmpeg` 自带二进制，可在 `build.py` 顶部改路径）。

```bash
pip install pillow numpy imageio-ffmpeg

python build.py --stills 4.5,12.5,29.5   # 导出关键帧到 preview/ 检查
python build.py --preview                # 960×540 快速动态预览
python build.py --all                    # 音频 + 正片 + 混流
```

产物：

| 文件 | 说明 |
| --- | --- |
| `dsh-fish-buddy-promo-1080p60.mp4` | 正片（含配乐） |
| `poster.png` | 封面帧 |
| `out/soundtrack.wav` | 48kHz 立体声配乐 |
| `preview/` | 预览视频与检查用静帧（可删除） |

## 素材来源

- Q 版鲸鱼娘帧动画：`assets/whale/*.png`，来自 [vlln/whale-girl](https://github.com/vlln/whale-girl)（MIT），见 `assets/whale/LICENSE.txt`。
- 全身立绘：`assets/whale.png`（仓库 `.gitignore` 中的本地素材，未随仓库分发）。片头、安装、片尾使用；如公开发布请先确认该立绘的授权。
- 托盘小鱼图标：`assets/fish-64.png`。
- 完成提示音：`assets/chime.wav`。
- 字体：Microsoft YaHei / Segoe UI / Consolas（Windows 系统字体）。

配乐与所有版式、动效均为脚本原创生成，不含第三方音乐。
