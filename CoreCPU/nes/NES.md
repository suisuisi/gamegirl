现在回忆起小时候，总觉得那时候日子特别美好。



儿时的我们虽然没有手机，但是却一点也不会无聊。



尤其是和小伙伴们一起偷偷地玩游戏机。


![](https://files.mdnice.com/user/17442/4b0b3c20-d2c9-4bf2-9da1-b1da6e1947ac.png)

后来随着电脑和手机的普及，童年记忆里的老物件，也因为停产而逐渐远去。

儿时的游戏离我们原来越远，渐渐消失在我们生活中。


![](https://files.mdnice.com/user/17442/02df45a6-bcf5-4878-b7e6-afcb2e2c0265.gif)


为了找回童年的美好，今天我们动手做一台NES游戏机。


## 硬件模拟好在哪？

一般来说现在想玩老游戏有三种方法。

### 第一种方法是在二手市场淘换当年的原机原卡带，但是非常稀缺、价格昂贵，品相难以保证。

年代久远的游戏机只能输出模拟视频信号，需要更换芯片或用采集卡才能连接现代的数字显示器，会带来显示延迟。


![](https://files.mdnice.com/user/17442/13ff1157-24da-44a9-a100-0a00f6d72288.png)


### 第二种方法是软件模拟，虽然硬件性能今非昔比，手机上都可运行许多模拟器，但有兼容性问题，不是所有游戏都能稳定运行。

使用软件模拟还会出现操作输入延迟，和声音延迟。

对高难度的动作游戏来说，虽然延迟只有毫秒级别，但还是能感觉到手感不同，老游戏难度普遍又高，输入延迟使一些高级技巧难以操作。


![△经典超难红白机游戏《魔界村》](https://files.mdnice.com/user/17442/f6d5b60e-f458-4a19-b7f2-2bf8be302bfb.png)




对于音游来说，那就根本没法玩了。



![△GBA上的音游《节奏天国》](https://files.mdnice.com/user/17442/56b907e3-4f0d-4975-a6e9-e022a0379b14.png)



现在市面上有一些基于树莓派等环境的开源游戏机，任天堂、世嘉等也不断地推出官方迷你复刻版。



![](https://files.mdnice.com/user/17442/5514e3be-b1d4-4d4b-aadd-4f63709bf405.png)



但这些本质上还是使用现代硬件架构的软件模拟，不能解决软件模拟带来的问题。如任天堂迷你FC实际上是在ARM架构上运行Linux系统。


![](https://files.mdnice.com/user/17442/e60e0a37-9ee2-4572-8bf3-77b225963313.png)


### 第三种方法就是使用FPGA硬件模拟。

FPGA的全称是现场可编程门阵列，通过直接对芯片中的模块和逻辑单元编程来模拟老游戏机硬件的运行方式。


![](https://files.mdnice.com/user/17442/95c3214a-ef94-483f-b09d-ad93d5975c5a.png)


软件模拟器是用CPU做通用计算，按顺序执行代码，需要比被模拟的硬件运行频率快许多倍的CPU才能达到原硬件的运行速度。

FPGA通过编程重组生成专用电路，相当于“可变形的硬件”。

可以让被模拟硬件的不同芯片同时工作，耗费的资源更少，同时解决延迟问题。

还可以模拟大型游戏卡带中特制的增强芯片，解决游戏兼容性问题。


![△SFC星际火狐中的增强芯片负责渲染3D多边形](https://files.mdnice.com/user/17442/c2f4ea6c-a68c-4ad3-8402-5abc2042f395.png)




以及模拟老机种的音频芯片输出原汁原味的游戏音效。


![](https://files.mdnice.com/user/17442/ffdffbac-39d6-4678-841a-79d5e850d041.png)


此外，在测试中GameGirl输出的画面比原机清晰度更高，色彩也更鲜明。

## NES FC 小霸王 。。。傻傻分不清楚

查看《》主条目：第三代视频游戏机

总结一下，美国叫NES，日本叫FC，中国叫小霸王（山寨），其实都是任天堂和SEGA8位游戏机。

## 硬件介绍

GameGirl核心板+扩展板

FPGA核心板
- EP4ce22f17
- SDRAM:HY57V561620 32MB

![](https://files.mdnice.com/user/17442/7de38527-5c42-430c-9ba0-cd7db59116d5.png)


扩展板

- AT91SAM7S256
- MAX1304（SPI转USB）

![](https://files.mdnice.com/user/17442/93b917e8-a5b6-460d-b720-6e9ac76941a9.png)


实物如下：

![治好你的颈椎病](https://files.mdnice.com/user/17442/f706980d-3b14-4b5a-8aaa-032c080bcb65.jpg)



## 程序

https://github.com/suisuisi/gamegirl/tree/master/CoreCPU/nes


下载下来使用Quartus II进行编译，编译选项注意下面截图勾选：

![](https://files.mdnice.com/user/17442/ff309b60-f57a-4295-becf-5316d2242b5c.png)

编译后会产生.RBF文件：


![](https://files.mdnice.com/user/17442/30315dad-0483-4da0-86b7-0ecb68074f0a.png)




## SD卡准备

将上述文件拷贝到SD卡根目录下，并重新命名为core.rbf。

在SD卡上创建nes文件夹，将自己喜欢的游侠放到该目录下，支持.nes .nsf .bin等扩展文件名。

## 视频



