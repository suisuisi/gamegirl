# 拯救童年系列-PC Engine/TurboGrafx-16介绍及FPGA实现

国内的很少有这款游戏机的体验，但是在日本这款游戏机是大受欢迎（曾在销量上打败任天堂的FC游戏机）。下面就简单介绍一下这款游戏机。

PC Engine（日版名：PCエンジン，美版名：TurboGrafx-16，简称PCE），是由Hudson Soft与日本电气（NEC）两家日本公司联手开发的家用游戏机，并在1987年10月30日由NEC的子公司“NEC Home Electronics”（简称NEC HE）推出。

TurboGrafx-16 具有 8 位CPU、16 位视频颜色编码器和 16 位视频显示控制器。该图形处理器能够同时显示482个色，能够在不同的分辨率之下同时发出512种颜色，并有着非常健全的图像镶嵌处理能力。Hudson设计的色度编码器能够传送出比FC游戏机和世嘉Mega Drive更生动与更色彩鲜艳的影像信号，不过该系统直到1990年才公开发表。

PC Engine也是世界第一部可选配CD模组的家用游戏机，使得它有CD载体的标准好处：更多储存空间、更便宜的载体成本、可播放Red Book标准的CD音乐。高效的设计、部分日本大型游戏软件厂商的支持、以及可加装CD-ROM的能力，使得PC Engine拥有题材广阔的游戏软件可供使用。其中HuCard和CD格式各拥有数百款游戏，而在1991年NEC推出SUPER CD-ROM后，PC ENGINE的游戏制造商都以CD作主力游戏媒体。

TurboGrafx-16未能打入北美市场，销量不佳，一直被归咎于延迟发布和劣质营销(尽管它的名称中带有“16”字样，并且将控制台作为 16 位平台进行营销，但它使用了 8 位 CPU），这种营销策略被一些人批评为具有欺骗性。

然而，在日本，较早推出市场的 PC Engine 非常成功。它获得了强大的第三方支持，并在 1987 年首次亮相时超过了Famicom（FC），最终成为Super Famicom（SFC）的主要竞争对手。

TurboGrafx-16 至少制造了 17 种不同的型号，包括便携式版本和那些集成了 CD-ROM 插件的版本。

增强型PC Engine SuperGrafx于 1989 年迅速推向市场。它具有许多性能增强功能，旨在取代标准的 PC Engine。它未能流行起来——仅发布了六款利用新增功能的游戏，很快就停产了。

整个系列于 1994 年停产，由仅在日本发售的PC-FX接替。


![](https://files.mdnice.com/user/17442/aa8e2488-e476-4ddb-a8c9-7ab428efcdd7.png)

<center>PC-Engine CoreGrafx CD-ROM</center>

![](https://files.mdnice.com/user/17442/08a06fe9-5756-4a8a-86e0-348197188098.png)

<center>TurboGrafx-16 CD-ROM</center>

![](https://files.mdnice.com/user/17442/502a58c3-c729-4b54-8409-f501cb39a893.png)


<center>SuperGrafx Super-CD-ROM</center>

![](https://files.mdnice.com/user/17442/50ea9402-d1a4-442d-981f-380e666b7618.png)

<center>PC Engine Super-CD-ROM</center>

![](https://files.mdnice.com/user/17442/931cc365-ccbd-43b2-bc77-59cd634809dc.png)

<center>PC-Engine-Duo</center>

![](https://files.mdnice.com/user/17442/869459f6-99b3-47b7-9f89-da23ac0b2ad0.png)

<center>PC-Engine-Duo-RX</center>

## TurboGrafx-16名作&移植主要游戏

![](https://files.mdnice.com/user/17442/a0fb8029-f6e8-4826-9893-4588c2022383.png)

上图中标红的是我个人比较倾向的游戏。

![](https://img.soogif.com/9IJg9cS2uVDOeEesiasQT7kvwdeumkkl.gif?scope=mdnice)

## 历史

PC Engine 是由开发视频游戏软件的Hudson Soft和NEC（一家凭借其PC-88和PC-98平台在日本个人计算机市场占据主导地位的公司）合作创建的。NEC 缺乏视频游戏行业的重要经验，因此向众多视频游戏工作室寻求支持。纯属巧合，NEC 有意进入利润丰厚的视频游戏市场，恰逢 Hudson 将当时先进的图形芯片设计出售给任天堂的失败。两家公司成功地联合起来开发了新系统。

PC Engine 于 1987 年 10 月 30 日在日本市场首次亮相，并取得了巨大的成功。PC Engine 拥有"优雅"、"引人注目"的设计，与竞争对手相比，它的体积非常小。再加上强大的软件阵容和来自南梦宫(Namco Limited 是一家日本跨国视频游戏和娱乐公司，总部位于东京大田区。拥有多个国际分支机构，包括加利福尼亚州圣克拉拉的南梦宫美国、伦敦的南梦宫欧洲、高雄的台湾南梦宫和中国大陆的上海南梦宫。)和科乐美(Konami Holdings Corporation 是一家日本娱乐集团和视频游戏公司。除了作为视频游戏开发商和发行商之外，它还生产和分销交易卡、动漫、特摄、弹球机、老虎机和街机柜。科乐美在世界各地设有赌场，并在日本各地经营健康和健身俱乐部。)等知名开发商的第三方支持，使 NEC 在日本市场暂时领先。PC Engine在发布的第一周就售出了 500,000 台。

1988 年，NEC 决定扩展到美国市场，并指示其美国业务为新受众开发新系统。NEC Technologies 的老板 Keith Schaefer 组建了一个团队来测试该系统。他们发现“PC Engine”这个名字缺乏热情，也觉得它的小尺寸不太适合美国消费者，他们通常更喜欢更大和“未来派”的设计。他们决定将该系统称为“TurboGrafx-16”，该名称代表其图形速度和强度以及 16 位GPU。他们还将硬件完全重新设计成一个大的黑色外壳。漫长的重新设计过程以及 NEC 对该系统在美国的可行性的质疑推迟了 TurboGrafx-16 的首次亮相。

![](https://files.mdnice.com/user/17442/de75db88-4d05-4a94-9ac9-38cafcc04fce.png)

<center>原始日本系统（顶部）和北美重新设计（底部）</center>

TurboGrafx-16 最终于1989 年 8 月下旬在纽约市和洛杉矶测试市场发布。这时在美国世嘉发布真正的 16 位世嘉 Genesis以测试市场两周后，这个时间点对 NEC 来说是灾难性的。与 NEC 不同的是，世嘉并没有浪费时间重新设计原始的日本 Mega Drive 系统，只对美学进行了细微的改动。

在美国首次亮相后，Genesis 迅速超越了 TurboGrafx-16。NEC 决定在 Alpha Zones中加入 Keith Courage，这是一款西方游戏玩家不知道的 Hudson Soft 游戏，但是Sega 将热门街机游戏《Altered Beast with the Genesis》集成到Genesis ，虽然成本很高，但是效果很好。NEC 在芝加哥的美国业务也对其潜力错误评估，迅速生产了 750,000 台，远高于实际需求。这对 Hudson Soft 来说是无所谓的，因为 NEC 向 Hudson Soft 支付了生产的每个TurboGrafx-16的版税，无论是否出售。到 1990 年，很明显该系统表现非常糟糕，并且被任天堂和世嘉的淘汰。

![](https://files.mdnice.com/user/17442/19e4c583-bf58-4615-8f81-084816fe6f34.png)

<center>The PC Engine box</center>

1989 年末，NEC 宣布计划推出TurboGrafx-16的投币式街机视频游戏版本。然而，NEC 在 1990 年初取消了该计划。

在欧洲，该控制台以其原始的日本名称 PC Engine 而闻名，而不是其美国名称 TurboGrafx-16。自日本的PC机进口吸引大批狂热的崇拜者，拥有一批具有可沿续PC机NTSC/PAL接口。1989 年，一家名为 Mention 的英国公司制造了一种改编的 PAL 版本，称为 PC Engine Plus。但是，该系统并未得到 NEC 的正式支持。

在看到 TurboGrafx-16 在美国受到影响后，NEC 决定取消他们在欧洲的发布。欧洲市场的设备已经生产出来，基本上是美国型号，经过修改后可以在 PAL 电视机上运行，并简单地标记为“TurboGrafx”。NEC 将此库存出售给分销商；在英国，Telegames于 1990 年以极其有限的数量发布了 TurboGrafx。该型号还通过选定的零售商在西班牙和葡萄牙发布。


![](https://files.mdnice.com/user/17442/0418c69e-9eb6-4ff5-ad19-23ace874ae73.png)

<center>带 CD-ROM 和接口单元的 PC Engine CoreGrafx</center>

从 1989 年 11 月到 1993 年，PC Engine 控制台及其一些附加组件由法国许可进口商 Sodipeng（Société de Distribution de la PC Engine，Guillemot International的子公司）从日本进口。PC Engine 主要通过主要零售商在法国和比荷卢经济联盟销售。它带有法语说明和一条 AV 电缆，以使其与SECAM电视机兼容。其推出价格为 1,790法郎。Sodipeng 于 1993 年破产。在英国，PC Engine 是作为非官方进口机器提供的。


TurboGrafx-16/PC Engine 是第一款能够通过可选附件玩 CD-ROM 游戏的视频游戏机。


![](https://files.mdnice.com/user/17442/711e9275-aff1-4558-91ba-3dd8198f9af4.png)

<center>TurboGrafx-16/PC Engine 是第一款能够通过可选附件玩 CD-ROM 游戏的视频游戏机</center>

到 1991 年 3 月，NEC 声称它已在美国销售了 750,000 台 TurboGrafx-16 控制台，并在全球销售了 500,000 台 CD-ROM。

为了在北美市场重新推出该系统，NEC 和 Hudson Soft 于 1992 年中期将北美系统的管理权转移给了一家名为 Turbo Technologies Inc. 的新合资企业，并发布了 TurboDuo，这是一款多合一的系统单元，包括CD-ROM驱动器，但在北美游戏机市场继续受到Genesis和SNES的冲击，始终没有很好的起色。

![](https://files.mdnice.com/user/17442/67970b49-e331-4d5b-8e1a-6dbd407fcd23.png)
<center>The TurboGrafx-16</center>

PC Engine 的最终授权发行版是1999 年 6 月 3 日的《大脑之死》第 1 部分和第 2 部分，采用超级 CD-ROM格式。

## 技术规格


![](https://files.mdnice.com/user/17442/3e940c63-b252-4f2b-b8ac-3aeb521dcbff.png)

<center>TurboGrafx-16 主板的俯视图</center>

TurboGrafx-16 使用Hudson Soft HuC6280 CPU——一个8 位CPU，用两个 16 位图形处理器修改，运行频率为 7.6 MHz。它具有 8 KB的RAM、64 KB 的视频 RAM，并且能够同时显示 512 色调色板中的482 种颜色。内置于 HuC6280 CPU 的声音硬件包括一个运行频率为 3.58 MHz的PSG和一个 5-10 位立体声 PCM。

TurboGrafx-16 游戏使用HuCard ROM 卡带格式，一种信用卡大小的薄卡，可插入控制台的前插槽。PC Engine HuCards 具有 38 个连接器引脚，而 TurboGrafx-16 HuCards（也称为“TurboChips”）具有 8 个这些引脚，以相反的顺序作为区域锁定方法。控制台上的电源开关还起到锁的作用，可防止在系统开机时移除 HuCard。TurboGrafx-16 的欧洲版本由于发行有限而没有自己的 PAL 格式的 HuCard，而是支持标准 HuCard 并输出 PAL 50 Hz 视频信号。


![](https://files.mdnice.com/user/17442/5f94c61d-9713-4968-b1ce-c8bc25e54fdb.png)


![](https://files.mdnice.com/user/17442/220391ff-8293-4489-8046-45dace279b49.png)

<center>A HuCard</center>

## 附加组件

### TurboGrafx-CD/CD-ROM²

该CD-ROM是 1988 年 12 月 4 日在日本发布的 PC Engine 的附加附件。除了标准 HuCard 外，该附加组件还允许控制台的核心版本以 CD-ROM 格式玩 PC Engine 游戏。这使得 PC Engine 成为第一个使用 CD-ROM 作为存储介质的视频游戏机。此外，PC Engine 还是第一台以 CD-ROM 格式提供游戏软件的类型的机器，无论是计算机还是游戏机。（而计算机上的第一个 CD-ROM 游戏软件是从 Mediagenic/Activision 的用于 Macintosh 计算机的 The Manhole 的软盘转换而来。黑白版本，于 1989 年 12 月发布）。TurboGrafx-CD 的发行价为 399.99 美元，不包括任何捆绑游戏。 Fighting Street和Monster Lair是 TurboGrafx-CD 的发布标题。

### Super CD-ROM 
1991 年，NEC 推出了 CD-ROM 系统的升级版本，称为Super CD-ROM，将 BIOS 更新到版本 3.0，并将缓冲区 RAM 从 64kB 增加到 256kB。此次升级以多种形式发布：第一个是9 月 21 日的PC Engine Duo，这是一款带有 CD-ROM 驱动器和系统内置升级 BIOS/RAM 的新型控制台。其次是超级系统卡10 月 26 日发布，是对现有 CD-ROM 附加组件的升级，可替代原始系统卡。尚未拥有原始 CD-ROM 附加组件的 PC Engine 所有者可以选择 Super-CD-ROM 单元，这是 12 月 13 日发布的附加组件的更新版本，它结合了 CD-ROM 驱动器、接口单元和超级系统卡合二为一。


### 街机卡
1994 年 3 月 12 日，NEC 推出了第三次升级，称为Arcade Card （アーケードカード，Ākēdo Kādo），将超级 CD-ROM 系统的板载 RAM 量增加到 2MB。此次升级发布了两种型号：Arcade Card Duo，专为已经配备 Super CD-ROM 系统的 PC Engine 控制台而设计；以及Arcade Card Pro，一种结合 Super CD-ROM系统功能的原始 CD-ROM 系统型号，将系统卡和街机卡合二为一。此附加组件的第一款游戏是Neo-Geo格斗游戏Fatal Fury 2和Art of Fighting 的移植版。世界英雄港口2和Fatal Fury Special是后来为这张卡发布的，还有几款在Arcade CD-ROM标准下发布的原创游戏。此时，对 TurboGrafx-16 和 Turbo Duo 的支持在北美已经逐渐减弱。因此，两种街机卡的北美版本都没有生产，尽管日本街机卡仍然可以通过 HuCard 转换器在北美控制台上使用。

## 附言

其实在不久的前期-2020 年 3 月 6 日，TurboGrafx-16计划重新制作发售-并命名为TurboGrafx-16 Mini（日本市场称作 PC Engine Core Grafx Mini）（学NES mini）,由于各种原因推迟到2020年5月22日北美销售，2020年6月5日欧洲销售。

![](https://files.mdnice.com/user/17442/19638bde-f615-4cef-aa2f-8f1ff15df14e.png)


# FPGA实现

## 硬件
参考这篇《》-GameGirl硬件。

## FPGA源码

> https://github.com/suisuisi/gamegirl/tree/master/CoreCPU/TurboGrafx16

## 编译
没什么注意的，源码是一个工程，使用Quartus II 13.1编译，同时各种配置及约束也在工程里，自己重新建工程注意勾选RBF文件产生选项及添加约束即可。

## 二进制文件

文件在这里：

> https://github.com/suisuisi/gamegirl/tree/master/Binaries/cores/pcengine

## 使用

拷贝到SD卡并命名core.rbf 即可上电启动，上电后通过OSD选择游戏文件即可。

## 注意

仅支持带有单个图像文件（FILE 关键字）的 CUE 文件！

详细说明见目录下的README。




## 演示视频如下：



## 参考链接

1、"ウィークエンド経済 第765号 あの失敗がこう生きた [Weekend Economics Issue 765. That Mistake Lived On.]". Asahi Shinbun (Evening Edition) (in Japanese). Osaka, Japan. December 1, 2001.

2、Anglin, Paul; Rand, Paul; Boone, Tim (August 15, 1992). "4 Page Review: BC Kid (Amiga)" (PDF). Computer and Video Games. No. 130 (September 1992). pp. 22–5.

3、"NEC PC Engine: A New Age Has Dawned". United Kingdom: Micro Media. Archived from the original on August 25, 2021. Retrieved August 25, 2021.

4、Guinness World Records Gamer's Edition (2008)

5、McFerran, Damien (November 2, 2012). "Feature: The Making Of The PC Engine". Nintendo Life. Archived from the original on July 30, 2019.

6、Nutt, Christian (September 12, 2014). "Stalled engine: The TurboGrafx-16 turns 25". Gamasutra. Archived from the original on June 27, 2017.

7、Therrien, Carl; Picard, Martin (April 29, 2015). "Enter the bit wars: A study of video game marketing and platform crafting in the wake of the TurboGrafx-16 launch". New Media & Society. 18 (10): 2323–2339. doi:10.1177/1461444815584333. S2CID 19553739.

8、Sartori, Paul (April 2, 2013). "TurboGrafx-16: the console that time forgot (and why it's worth re-discovering)". The Guardian. Archived from the original on July 1, 2018.

9、Stuart, Keith; Freeman, Will (February 27, 2016). "Why Kanye West is right to recommend the TurboGrafx-16". The Guardian. Archived from the original on June 22, 2017. Retrieved December 25, 2017.

