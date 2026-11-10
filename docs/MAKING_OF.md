# 从设定图到可玩的云海 RPG

项目的创作过程参考作者的[飞书制作记录](https://my.feishu.cn/wiki/SGgWwYn0riZXptkKUemcIOD2nkc)。这里把过程和仓库内可检查的文件对应起来，方便学习和继续修改。

## 1. 先做玩法，再解决美术

第一版直接让 AI 生成整个 3D 游戏，能得到角色移动、场景和一些基本交互，但由几何体拼成的人物与建筑缺少想要的美术细节。后续的关键变化是把工作分开：Codex 协助构建玩法和制作工具，美术先通过设定图确定，再交给 Hi3D 生成模型。

本章选择云海浮岛作为统一环境，并围绕一条短流程设计资产：少年与剑、史莱姆、村落、守灯人、水晶祭坛和星门。资产规模控制在一章可玩的范围内。

## 2. 生成 2D 设定图，再转成 GLB

通过 Codex 配合图像生成制作角色、建筑和道具参考图，明确卡通比例、色彩和材质。将参考图交给 Hi3D，导出带贴图的 GLB。

仓库保留了部分生成参考图：[`assets/concepts/`](../assets/concepts/)。星门符文的生成图及提示词位于 [`assets/effects/`](../assets/effects/)。完整的最初六份高精度模型没有重复放入仓库，运行游戏使用的是已优化的模型。

## 3. 为实时游戏处理模型

原始模型单个约有 100 万顶点，需要先减面，再控制贴图大小和材质开销。主要流程：合并重复数据、焊接顶点、简化网格、整理材质、压缩到 2K 贴图，最后导出 GLB。

| 资产 | 原始顶点数 | 优化后顶点数 |
| --- | ---: | ---: |
| 少年 | 1,018,534 | 49,753 |
| 史莱姆 | 1,014,629 | 29,979 |
| 短剑 | 1,024,589 | 18,224 |
| 浮空村落 | 1,072,955 | 183,524 |
| 水晶祭坛 | 1,017,514 | 67,629 |
| 守灯人 | 1,027,545 | 22,226 |

这些是模型准备阶段的网格统计，来自 [`manifest.json`](../assets/models/manifest.json)，不是整帧渲染负载或帧率数据。绑定和导出可能改变顶点布局。

- [`prepare-rpg.mjs`](../tools/model-prep/prepare-rpg.mjs)：glTF Transform + meshoptimizer + sharp，处理少年、史莱姆、短剑和村落。
- [`prepare_altar.py`](../tools/prepare_altar.py)：Blender 减面，祭坛统一到约 2.2 米高。
- [`rig_merchant.py`](../tools/rig_merchant.py)：商人模型减面、统一尺寸并绑定。
- [`prepare_scenery.py`](../tools/prepare_scenery.py)：从村落模型派生不含建筑的远景岛屿。

场景使用村落的实际三角网格碰撞；远景浮岛只用于背景，不是可到达的第二张地图。

## 4. 在 Blender 中绑定和适配动作

静态模型本身不能完成走路和挥剑。Codex 编写 Python 脚本，让 Blender 建立骨架、计算蒙皮权重，再导出包含动作的 GLB。

### 主角

[`rig_hero.py`](../tools/rig_hero.py) 构建基础绑定：根节点、身体、双臂、双腿、手脚与剑挂点，共 21 根骨骼。短剑通过右手刚性蒙皮，剑光在游戏里跟踪真实剑身轨迹。

后续用 [`retarget_motion.py`](../tools/retarget_motion.py) 将 Quaternius Universal Animation Library 1 / 2 Standard 的 CC0 动作适配到这个角色：

- 将来源骨骼映射到角色骨骼。
- 修正 A-pose / T-pose 的手臂方向差异。
- 根据腿长比例调整位移，以解析式 IK 修正脚底接触。
- 调整挥剑收势时间与动作衔接。
- 提取来源动作的根位移到 `assets/models/motion.json`，由 Godot 的碰撞逻辑控制实际移动。

导出 12 个动作：`Idle`、`BattleIdle`、`Walk`、`Run`、`Sprint`、`Slash_1`、`Slash_2`、`Slash_3`、`Spin`、`Dodge`、`Hurt`、`Celebrate`。实际普攻交替使用前两种挥砍，连续第三击加强伤害；不是三个完全不同的普攻姿势。

可编辑文件：[`CloudWanderer_Combat.blend`](../blender/CloudWanderer_Combat.blend)。重定向用的基础绑定也保存在 `blender/animation-v1-backup/`。来源动作保留在 `tools/motion-source/`，无需再次下载才能重定向。

### 守灯人

NPC 采用独立商人模型，约 1.96 米高、14 根骨骼、16 秒循环待机。脚和下身固定，胸部轻微呼吸，头部缓慢转动，双臂与手腕错开节奏。对话中仍会呼吸，暂停时停止。

可编辑文件：[`Merchant_Idle.blend`](../blender/Merchant_Idle.blend)。当前绑定没有独立的面部表情和手指控制。

## 5. 在 Godot 中组装玩法

项目通过代码生成大部分场景节点，根场景保持很小。主要职责如下：

| 文件 | 职责 |
| --- | --- |
| [`scripts/game.gd`](../scripts/game.gd) | 任务状态、战斗命中、升级、掉落、音效、存档与通关 |
| [`scripts/player.gd`](../scripts/player.gd) | 移动、连击输入、耐力、闪避、镜头和骨骼动作 |
| [`scripts/slime.gd`](../scripts/slime.gd) | 发现目标、追击、扑击预警、受击、死亡与 Boss 行为 |
| [`scripts/world.gd`](../scripts/world.gd) | 模型、碰撞、远景岛、灯光、草地、祭坛和星门 |
| [`scripts/hud.gd`](../scripts/hud.gd) | 主菜单、生命和耐力、任务、小地图、对话和结算 |

战斗手感并非只由播放动画决定：攻击伤害与动作时间对齐；空挥只有挥刀声音，实际接触才播放命中声音；命中停顿同步暂停动作；攻击前冲限制身体穿入敌人；闪避带短暂无敌窗口。

敌人采用短距离扇形探测避障。普通史莱姆约 13 米内发现玩家，过远后脱离返营。NPC 身边约 3.4 米是交谈安全区。这不是全地图导航网格系统。

## 6. 用着色器和程序特效补足氛围

- [`cloud_sea.gdshader`](../shaders/cloud_sea.gdshader)：通过体积噪声和光线步进构成云海。
- [`grass.gdshader`](../shaders/grass.gdshader)：草叶随时间摆动。
- [`altar_surface.gdshader`](../shaders/altar_surface.gdshader) / [`altar_halo.gdshader`](../shaders/altar_halo.gdshader)：水晶表面与光晕。
- [`portal.gdshader`](../shaders/portal.gdshader)：使用生成的符文贴图构成旋转封印，并与激活状态联动。

星门由外环、内圈、核心和后方能量幕组成。每点亮一座祭坛便提高亮度；击败 Boss 后封印渐隐，实体屏障解除。`game.gd` 的 `next_level_scene` 留出了下一关入口，目前默认显示第一章结算。

## 7. 按实机反馈迭代

开发过程中重点检查了镜头远近、追击距离、NPC 与玩家的身体间距、攻击贴身前冲、正反斩交替、音效提前量、祭坛光晕以及星门解锁后的碰撞。

发布版本重新检查从资源导入到完整通关的流程。自动化覆盖能帮助发现逻辑回归，最终画面仍需要通过真实渲染截图和录像判断。复现方法见 [开发与验证](DEVELOPMENT.md)。

## 继续改造

可以先从调整 `player.gd` 的移动和战斗参数、替换 `assets/models/` 的模型、修改 `world.gd` 的祭坛位置开始。更换角色时，需要同时检查骨骼命名、动作名称、武器挂点和身体比例，不能只换 GLB 文件名。

若扩展下一章，可新增场景并设置 `next_level_scene`；装备系统、多地图存档、完整导航和新平台适配仍需要进一步开发。
