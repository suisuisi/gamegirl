# 童年修复系列-SNES芯片组介绍及FPGA实现



![](https://files.mdnice.com/user/17442/3df4ba6d-d757-4011-9aea-1ec1c6d028ed.png)

超级任天堂1990年11月21日在日本开始发售，北美于1991年8月13日发售，欧洲于1992年4月11日发售。

超级任天堂，简称超任，是任天堂公司开发的家用游戏机。英文名称Super Famicom，简写SFC；在欧美洲销售的产品名为Super Nintendo Entertainment System，简写SNES。超级任天堂是任天堂红白机的后继机种。由于芯片组的复杂，中国鲜有“复制品”出现。

所以今天就来聊一聊SNES的芯片组及其特殊性，同时带来FPGA实现SNES的开源方案。

SNES和现今的PC芯片组很相似-CPU+显卡+声卡组成，同时SNES为了处理复杂的运算增加了一颗DSP芯片，下面就按照组成一个一个介绍。

下图是整机的框图：


![](https://files.mdnice.com/user/17442/7ed1bb87-eea4-46cb-892d-0fed8731e178.png)

整机的总线互联如下：


![](https://files.mdnice.com/user/17442/91036fa0-2b7d-4783-95f0-2b630e5f07b1.png)

CPU总线使用的是从6502继承过来的类ISA总线。

## CPU

SNES 的 CPU （中央处理单元）是基于 65c816 的处理器-5A22《公众号链接》。虽然它的时钟速度大约为 21 MHz，但它的有效速度要低得多： 3.58 MHz 用于快速访问（即 2100-$21FF 在 $00-$3F 中的硬件寄存器）；2.68 MHz 用于慢速访问（即 ROM 和 RAM） ) 和 1.79 MHz 用于非常慢的访问（即$4000-$41FFF在 $00 到 $3F 中的硬件寄存器 ）。这种变速模式来源于6502有一个叫做“ZERO-PAGE”的寻址模式，但是进行了进一步扩展。

它是一个带有 24 位总线的 16 位处理器（16 位数据指针和 8 位组指针）。支持16MB的寻址空间。它有一个计算器和两个寄存器，可以在8位或16位模式之间切换。

![](https://files.mdnice.com/user/17442/23d74c64-2e02-4529-98d9-8abb1d7b17db.png)

然而，它具有许多寻址模式。它使用可变宽度指令。单个指令的宽度可以根据某些寄存器的长度而变化。

## PPU

SNES有两个特制的图像处理器，主要运行于256×224的分辨率，最高支持512x448的分辨率，最大发色数32768色，最大同屏幕显示256色，最大活动块数为128个，并支持缩放、回旋、马赛克、半透明、窗口、光栅等特效。


![](https://files.mdnice.com/user/17442/4005003a-65ca-48af-b020-d200084595dd.png)


## 声优芯片

辅助CPU采用一颗SPC700（索尼推出），是一个8位的CPU核心，很接近6502，但有一些不同的寻址模式和复数/分割指令，与一个定制的数字声音信号处理器共同集成在一个模块中。SPC700和65c816通过一个4路双向通道（8位I/O端口）通讯。SPC700有自己独立的64K内存，可以用来存储声音采样或者从65c816下载的程序。 CPU有一个内建的64K ROM开机码，用来通过65c816从游戏ROM里加载更多的复杂程序或者采样数据。这个ROM可以被关闭，以存储开机码的64K RAM来代替它的工作。


![](https://files.mdnice.com/user/17442/08087656-8514-4970-8ae7-2cc5c5931d1c.jpg)


声音数字信号处理器（Sound DSP）只能播放压缩的声音采样。这种使用一固定比率的压缩算法，可以将16个16位声音采样压缩成8字节加一字节标题的形式。一个采样的最小单位是一个区块，区块的标题字节包含一个移位和一个过滤值（算法解压信息），再加上一个最后区块标记和一个循环标记。循环标记仅仅在最后区块标记存在时才使用。

在同一时间内，最多允许有8个声音通道同时播放声音采样，每个声音通道都有单独的左右声道音量和频率的调节。每个通道都可以定义一个硬件音量调节，并各自设置其回声效果，不过复合的回声效果必须受制于一个8路的FIR声音分流器。一个通道的声音输出可以用来调整在数字序列上的下一个声音通道的频率。 DSP也有一个白噪音源，可以播放一个替代采样数据的声音通道。所有的8个音源连同回声数据最后都混合到一个双通道的主音量控制下。 DSP有3个间隔定事器，头两个运行在8KHz下，最后一个是64KHz。游戏通常只使用三个中的一个来输出一个恒定的音乐回放频率。

![](https://files.mdnice.com/user/17442/05f77bfa-e543-4e92-a584-fceb1eb3048c.png)

顺便一提SNES的声音处理芯片SPC700是PS之父久多良木负责设计的，所以说索尼大法好可不是白叫的。

声优芯片和整机总线如下图所示：

![](https://files.mdnice.com/user/17442/776f0bb2-ed5e-424e-a89e-a6bdfb9611f7.png)

## 扩展芯片

### 数字信号处理器

SNES 的 S-DSP （数字信号处理器）用于向扬声器输出数据。产生的声音以 32 KHz 运行。S-DSP 使用比特率降低将所需的大小减少到原始大小的 9/16。S-DSP 是「自带鬼畜」，你输入一个PCM格式的音源进去，比如把F♂A乐器输入进去，然后往sound chip的寄存器里写入你要的包络，音调之类的，sound chip上的协处理器就会帮你处理输出，其实就和做音乐用的合成器播放软音源差不多。

### DSP-1 

DSP-1是一种主要用于数学和伪 3D 投影的芯片。这通常使用model 7。这是其中最常用的芯片。它也适用于 2D 旋转等。


![](https://files.mdnice.com/user/17442/2bd9eea6-b9ea-434d-9126-58ad6c755893.png)

![](https://files.mdnice.com/user/17442/e0ac0048-202e-484e-9d33-21cc6bed8c03.png)


![](https://files.mdnice.com/user/17442/fbdf852e-9037-4a5b-8094-717d82db4946.png)


### SA-1
SA-1是 CPU 的更快版本，但在访问方面存在一些差异。它带有“I-RAM”和“BW-RAM”。它通常以大约 11 MHz 的速度运行，当访问与 CPU 相同的东西时，它的速度为 5 MHz。


### GSU
GSU是著名的 SuperFX 芯片的技术名称。GSU 可用于绘制颜色。它在很多方面都比 SNES 的 CPU 更强大。它是一个伪RISC。它可用于绘制许多事物，例如精灵和对象的旋转或制作伪 3D 效果。



![](https://files.mdnice.com/user/17442/8f19e8d5-bd85-4680-aec7-42460e87ea18.png)

![](https://files.mdnice.com/user/17442/33651a92-268a-4579-9461-f2b8015342d9.png)

CX4是 Capcom 使用的芯片，它在三角和图形方面非常强大。它可以绘制线条、波浪和 3D 线框，旋转精灵并进行三角计算等。应用到的游戏包括：洛克人X2，洛克人X3 等卡普空街机移植作品。



![](https://files.mdnice.com/user/17442/9db76279-5dd6-4c73-8597-a77cace40be9.png)

## SDD-1


![](https://files.mdnice.com/user/17442/8aaa8480-9420-430b-ad5b-25cecbe2f92b.png)

数据解压芯片，解压使用 ASIC 无算压缩算法压制的数据，它活跃在 SFC 主 CPU 和 ROM之间，负责透明实时数据解压工作，针对一些资源太大的游戏，为了节省卡带空间成本而引入了该芯片，使用游戏包括：星之海洋，街霸 Alpha 2 等。


# SNES FPGA实现

## 硬件

还是GameGirl硬件


![](https://files.mdnice.com/user/17442/c8303ad1-4318-43c2-9425-9f8a9c5027a0.png)


![](https://files.mdnice.com/user/17442/e5f5eff5-01b8-4a13-b270-f261c1f354a0.png)

开源地址：

> https://github.com/suisuisi/gamegirl/tree/master/Hardware

## FPGA程序


![](https://files.mdnice.com/user/17442/929c93fd-882c-42e7-84e2-8421d4d7a19d.png)

上面的CPU和SPC700都已经介绍过了。

chip文件夹下还有上面介绍的芯片，组成芯片组：


![](https://files.mdnice.com/user/17442/bc7dfd19-f6fd-4080-86a0-4b2c87e1b25a.png)

开源地址：

> https://github.com/suisuisi/gamegirl/tree/master/CoreCPU/SNES

## 使用方法：

将编译产生的.rbf文件拷贝到SD卡的根目录：


![](https://files.mdnice.com/user/17442/4120d333-b94d-449d-9f92-9c4bd2a50da0.png)

产生的二进制文件在下面路径：

> https://github.com/suisuisi/gamegirl/tree/master/Binaries/cores/snes


然后将游戏同步放到SD卡里，通过OSD就可以选择游戏，注意游戏启动及中间过渡阶段会有黑屏，所以需要等待。。。

## 视频

时间仓促还没来得及拍视频，后续补上。





