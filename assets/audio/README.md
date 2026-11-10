# 开源版音效

本目录的 WAV 全部由本项目 Python 脚本程序合成，按 MIT 许可提供。没有第三方游戏录音，也没有循环背景低鸣。

按以下顺序重建：

```sh
python tools/make_audio.py
python tools/make_combat_audio.py
```

第二步需要 NumPy。它生成独立的普通挥剑、技能挥剑、轻击、重击和技能命中声音，以及受伤、闪避和星门声音。第一步生成提示、祭坛、药水等基础声音。生成后重新在 Godot 中导入。
