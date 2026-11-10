# 素材来源与许可范围

根目录 MIT 许可适用于本项目的原创代码、着色器、制作脚本、文档与原创合成音效。下表列明生成美术和第三方素材，第三方许可不被 MIT 替换。

| 内容 | 来源 | 许可 / 说明 |
| --- | --- | --- |
| `scripts/`、`shaders/`、项目制作工具 | Ziho 的 Codex 辅助开发项目 | MIT |
| `assets/audio/*.wav` | `tools/make_audio.py` 与 `tools/make_combat_audio.py` 程序合成 | MIT；不含下载的游戏录音 |
| 主角、史莱姆、短剑、浮岛村落、祭坛、守灯人 GLB 及其贴图 | 作者提供参考图并使用 Hi3D 生成，经工具脚本优化和绑定 | 作者在其可授权范围内按 MIT 提供；来源文件名和网格数据见 `assets/models/manifest.json` |
| `assets/concepts/`、`assets/effects/stargate-sigil.png` | 本项目的 AI 生成美术 | 作者在其可授权范围内按 MIT 提供；星门生成提示词随文件保留 |
| 主角动作及 `tools/motion-source/` 的 UAL 1 / 2 Standard | Quaternius | CC0 1.0；原始 `License.txt` 随各包保留 |
| `assets/fonts/Chinese.ttf` | Noto Sans SC，Google Fonts / Adobe | SIL OFL 1.1，见 `assets/fonts/NotoSansSC-OFL.txt` |
| `assets/fonts/Display.ttf` | Inter，The Inter Project Authors | SIL OFL 1.1，见 `assets/fonts/Inter-OFL.txt` |
| `tools/model-prep/` 的 npm 依赖 | glTF Transform、meshoptimizer、sharp 等 | 依赖本身不打包，安装时使用各包许可证，精确版本见 lockfile |

Noto Sans SC 从官方可变字体实例化为 400 字重；Inter 实例化为 700 字重、14 optical size。保留字体内部作者信息、原许可和来源说明。

官方来源：

- [Quaternius Universal Animation Library](https://quaternius.com/packs/universalanimationlibrary.html)
- [Quaternius Universal Animation Library 2](https://quaternius.com/packs/universalanimationlibrary2.html)
- [Noto Sans SC / Google Fonts](https://github.com/google/fonts/tree/main/ofl/notosanssc)
- [Inter / Google Fonts](https://github.com/google/fonts/tree/main/ofl/inter)

开发原型曾使用《英雄联盟》亚索挥剑 / 命中录音及系统商业字体。公开仓库不包含这些文件，运行时也不引用它们；公开版演示重新录制并使用合成音效。
