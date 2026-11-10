# 开发、重建与验证

## 环境

- 运行：Godot 4.7.2 标准版，Forward+。已验证 Apple M3 Pro / macOS / Metal；其他平台尚未实机验证。
- 绑定、动作和场景模型重建：Blender 5.2.2，脚本使用 Blender Python API 和其自带 NumPy。
- 初始模型优化：Node.js 22+，在 `tools/model-prep/` 执行 `npm ci`。
- 合成音效：Python 3 + NumPy。
- 演示视频：Godot Movie Maker + FFmpeg。

游戏运行不需要后四项。所有运行时资源均已随仓库提交，首次运行需要 Godot 导入。

## 验证命令

在仓库根目录执行。`godot` 可替换成实际可执行文件路径。

```sh
godot --headless --editor --path . --import
godot --headless --path . -- --self-test
godot --headless --path . --fixed-fps 60 -- --test-route
godot --headless --path . --fixed-fps 60 --script res://tools/verify_merchant_audio.gd
godot --headless --path . --fixed-fps 60 --script res://tools/verify_combat_spacing.gd
```

| 入口 | 检查内容 |
| --- | --- |
| `--self-test` | 模型骨骼与动作、相机、追击、任务前置、伤害、药水、连击、闪避、祭坛和通关 |
| `--test-route` | 同玩家路径的真实移动、攻击、闪避、交互，自动跑完 3 座祭坛、Boss 与星门 |
| `verify_merchant_audio.gd` | NPC 待机连续性、固定下身、暂停与对话行为，空挥 / 正反斩 / 技能音效触发 |
| `verify_combat_spacing.gd` | 普攻、技能、走入接触、贴身攻击、横移与怪物扑击的身体间距 |

这些测试使用专用模式，不读取或覆盖正常游戏存档。测试应退出为 0，并打印相应的 PASS 结果。`--headless` 验证逻辑，不等于 GPU 画面验证。

`tools/verify_replay_audio.gd` 会主动拒绝在普通项目名称下运行：它必须在另一个副本中，将 `application/config/name` 设置为 `Skyward Replay Verification` 后使用，因为测试会创建与修改该测试项目的用户存档。不要为了运行它修改日常游戏的用户数据。

## 存档

游戏使用 Godot `user://skyward-save.cfg` 保存章节进度。重新挑战会将上一局备份为 `user://skyward-save.cfg.previous`。`user://` 是 Godot 管理的应用用户数据目录，不在 Git 仓库里。

正常模式会读取已有进度，完成章节后可以重新挑战。`--demo`、截图、自动路线和逻辑测试模式不会覆盖正常存档。

## 实机截图与视频

```sh
# 实机截图，不读取 / 覆盖正常进度
godot --path . --script res://tools/capture_showcase.gd -- --shot=overview
godot --path . --script res://tools/capture_showcase.gd -- --shot=keeper
godot --path . -- --capture --intro --time=2 --capture-name=title.png
godot --path . -- --capture --portal-preview --time=3 --capture-name=portal.png
godot --path . -- --capture --altar-preview --altar-lit --time=3 --capture-name=altar.png

# 自动游玩录制；生成的 AVI 可能较大，captures/ 已被 Git 忽略
godot --path . --resolution 1280x720 --fixed-fps 30 \
  --write-movie captures/demo.avi -- \
  --capture --autoplay --time=42 --capture-name=demo-final.png

# 转成便于观看和分发的 MP4
ffmpeg -i captures/demo.avi -c:v libx264 -crf 23 -pix_fmt yuv420p \
  -c:a aac -b:a 128k -movflags +faststart captures/demo.mp4
```

自动路线可以在不同帧率和硬件上产生不同战斗节奏；上述 42 秒是录制时长，不是通关时间保证。正常游玩由玩家操控。

### 首次开源发布验证（2026-11-10）

Godot 4.7.2 / macOS / Apple M3 Pro：无缓存资源导入、游戏自检、完整自动路线、NPC 与音效检查、战斗间距检查均通过。自动路线完成 4 次击杀（3 只普通史莱姆 + Boss）、3 枚风晶、41 次攻击和 16 次闪避，游戏内用时约 62 秒。另以 Metal 实际渲染了 README 截图和 1280 × 720 / 30 FPS 的演示录像。

## 重建角色动作

现有绑定源文件与 CC0 动作源已包含在仓库。要重做第二版主角动作，在仓库根目录运行：

```sh
blender --background --python tools/retarget_motion.py
```

它读取 `blender/animation-v1-backup/CloudWanderer_Combat.blend` 和 `tools/motion-source/`，更新主角 `.blend`、运行时 GLB、`motion.json` 与统计报告。执行后重新导入 Godot 资源。

macOS 的 Blender 命令通常为 `/Applications/Blender.app/Contents/MacOS/Blender`。基础绑定脚本 `tools/rig_hero.py` 会写入当前主角输出文件；需要重建基础绑定时请在新分支或副本中进行，再运行动作重定向。

## 使用自己的 Hi3D 模型

最初的高精度模型不是游戏运行依赖，也未重复放入仓库。以下重建命令需要自行提供对应 GLB：

```sh
blender --background --python tools/prepare_altar.py -- /path/to/altar.glb
blender --background --python tools/rig_merchant.py -- /path/to/merchant.glb
```

首批四种模型的优化：

```sh
cd tools/model-prep
npm ci
node prepare-rpg.mjs /path/to/Hi3D-models
```

输入目录的 GLB 文件名需要分别包含「少年」「史莱姆」「短剑」「村落」。输出写入 `assets/models/`；运行前使用新分支或副本保留现有美术。这些脚本针对当前资产比例设计，不是适用于任意角色的一键通用绑定器。

## 重建音效

```sh
python3 -m venv .venv
. .venv/bin/activate
python -m pip install numpy
python tools/make_audio.py
python tools/make_combat_audio.py
```

先生成基础效果，再覆盖为较柔和的战斗音效。第二个脚本也输出试听和峰值统计到 `captures/`。公开版在 `game.gd` 中按事件加载对应 WAV，空挥不播放命中声。

## 提交内容

保留源文件、`.gd.uid`、运行时资源、Blender 绑定与第三方许可证。不要提交 `.godot/`、导入缓存、用户存档、临时录制、`node_modules/`、密钥或原始下载包。

GLB 已包含纹理；Godot 导入时生成在模型目录的 JPG/PNG 被忽略。所有文件都低于 GitHub 普通 Git 的单文件限制，当前无需 Git LFS。
