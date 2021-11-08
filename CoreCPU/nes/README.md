# nes
This is a port of Luddes NES core to the GameGirl. See his FPGANES blog at http://fpganes.blogspot.de for details. The original source code can be found at https://github.com/strigeus/fpganes.
Many changes ported from https://github.com/MiSTer-devel/NES_MiSTer.

# 概述

此页面包含 NES/Famicom 内核的操作说明。

# 链接
[核心二进制文件](https://github.com/suisuisi/gamegirl/tree/master/Binaries/cores/nes)

[FPGANES](http://fpganes.blogspot.de/)(原始来源)

[原始源代码](https://github.com/suisuisi/gamegirl/tree/master/CoreCPU/nes)

# 使用

将核心二进制文件（.rbf 文件）复制到*SD 卡根目录下。如果希望 GameGirl 在启动时自动加载它，可以将文件重命名为 core.rbf。

Rom 可以复制到 SD 卡上的任何位置，并通过 OSD 菜单进行选择。如果有很多文件，可以将它们存储到按字母顺序排列的子文件夹中，以便更快地访问它们。

# 控件

控制：

使用一两个游戏手柄

将按钮 3 和 4 映射到选择和启动。

如果游戏手柄只有 2 个按钮，可以使用 OSD 菜单中的选择和启动

键盘上的F12打开OSD

GameGirl 上面板按钮：

（右）将 MiST 重置为默认内核
（中）打开 OSD 菜单
（左）使用当前 ROM 重置 NES

# OSD菜单

核心将以黑屏开始。按 F12 / 板载中间按键 进入 OSD 菜单：

![image](https://github.com/suisuisi/gamegirl/blob/master/CoreCPU/nes/src/nes_osd1.jpg?raw=true)


OSD 菜单 - 第 1 页

Load *.NES : 从 SD 卡加载 ROM
HQ2X : 主动 hq2x 图像增强，平滑像素（适用于大屏幕）
开始：按下开始按钮
选择：按下选择按钮
重置：重新启动 NES 核心


第二页包含一些常规选项：

固件和核心：允许切换到另一个核心或升级 单片机 固件
保存设置：将当前设置保存到SD卡以备下次启动
在 rom 选择屏幕中，m 可以按 Enter 选择一个 rom。

# 笔记

视频模式为 720x481p

# 兼容性
该表显示了内核支持的内存映射器；将运行大量商业 ROM（~87%）。

![image](https://github.com/suisuisi/gamegirl/blob/master/CoreCPU/nes/src/nes_mappers.jpg?raw=true)

# 视频
[![Watch the video](https://github.com/suisuisi/gamegirl/blob/master/CoreCPU/nes/src/%E6%B8%B8%E6%88%8F.jpg)](https://www.bilibili.com/video/BV1th411n7aL/)

