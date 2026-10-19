# Third-party notices

This project is an unofficial fan-made desktop companion for
[DeepSeek Harness](https://github.com/deepseek-ai). It is not affiliated with,
endorsed by, or sponsored by DeepSeek.

## Q-version whale girl sprites

`assets/whale/*.png` (idle / working / celebrate / error / sleep / think frames)

- Source: [vlln/whale-girl](https://github.com/vlln/whale-girl)
- License: MIT — Copyright (c) 2026 Sam Gao (vlln)
- Full text: [`assets/whale/LICENSE.txt`](assets/whale/LICENSE.txt)

## Character design

The "鲸鱼娘" (whale girl) is a community-created DeepSeek fan persona. The
character concept and the "DeepSeek" name/logo belong to their respective
owners. This repository ships only the MIT-licensed chibi sprite set above.

## Optional full-body artwork (NOT included)

The optional `mascot: "whale"` mode expects a local file at
`assets/whale.png`. That artwork is not part of this repository: it is a
circulated fan illustration, and it is intentionally excluded so the
repository only redistributes assets with a clear license. If you supply your
own copy, use it for personal, non-commercial purposes and respect the original
artist.

## Fonts, sounds, icons

- `assets/chime.wav` was generated for this project and is covered by the MIT
  license above.
- `assets/fish.ico` / `assets/fish.png` are derived from the MIT chibi sprites.
- No fonts are bundled; the UI uses fonts already installed on Windows
  (Microsoft YaHei UI, Segoe UI).

## Liquid-glass material

The "liquid glass" bubble material is inspired by
[WXperia/liquid-glass-vue](https://github.com/WXperia/liquid-glass-vue)
(package `@wxperia/liquid-glass-vue`, MIT).

- No Vue/TypeScript code or shader files are copied into this repository.
- The WPF implementation is independent: it uses flat translucent light
layers, adaptive text contrast and a specular border (no screen capture,
blur or shader) to approximate the referenced material.
- The reference project's package metadata declares the MIT license.
