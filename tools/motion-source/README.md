# 动作素材与重建

本目录中的 Universal Animation Library 1 / 2 Standard 来自 Quaternius，采用 CC0 许可。原版 License.txt 随各包保留。

- https://quaternius.com/packs/universalanimationlibrary.html
- https://quaternius.com/packs/universalanimationlibrary2.html

本工程使用各包 Unreal-Godot 目录中的 UAL1_Standard.glb、UAL2_Standard.glb 作为姿势来源，对应 _RM.glb 提供根位移。发行压缩包仅保留这四个 GLB、许可证和说明，不包含冗余 Unity FBX 或下载压缩包。

`tools/retarget_motion.py` 使用 Blender 5.2 的 Python API，读取 `blender/animation-v1-backup/CloudWanderer_Combat.blend` 中的基础骨架与蒙皮，再适配源动作。包内保留这份基础绑定用于重建，原版动作不用于游戏运行。

重建命令（在工程目录执行）：

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background --python tools/retarget_motion.py
```

角色仍使用用户提供的 Hi3D 模型。没有替换人物外观。源动作经过身材适配、腿部 IK、部分收势压缩与位移提取；不宣称为本项目录制的动作捕捉。
