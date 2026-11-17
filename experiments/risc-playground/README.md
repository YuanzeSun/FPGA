# RISC-V 游戏与中文显示

官方PicoRV32执行C贪吃蛇、迷宫、方块消除和中文情书。CPU25.2MHz，60Hz逻辑计时；FPGA提供显存、字符渲染和HDMI。

## 构建

在仓库根目录执行：

```powershell
powershell.exe -NoProfile -File tools/build.ps1 -Project risc-playground
```

准备方法见[环境说明](../../docs/environment.md)。构建脚本不访问USB，结果位于本项目`build/`。

## 高清与控制

在仓库根目录选择输出模式：

```powershell
powershell.exe -NoProfile -File tools/build.ps1 -Project risc-playground -Mode 1080p45
```

Mode还可选720p60、1080p30、all。构建先准备C固件和CPU仿真证据，再生成所选HD模式。

| 启动器 | HDMI输出 | 已验收User Code |
| --- | --- | --- |
| Play-RISC.cmd | 640×480／60Hz | 0x0000F156 |
| Play-720p60.cmd | 1280×720／60Hz | 0x0000F2BA |
| Play-1080p30.cmd | 1920×1080／30Hz | 0x0000A9B3 |
| Play-1080p45.cmd | 1920×1080／45Hz | 0x0000C335 |

构建后双击所选启动器，选择1贪吃蛇、2迷宫、3方块、4情书，再按Enter。方向键/WASD移动，F/J硬降或拆信，空格暂停，R重开，Tab自动，1/2/3/4切换，Esc退出。默认COM6、115200、8N1。

字符画布为640×480，1080p按2倍放大。45Hz是当前板子和显示器实测通过的自定义模式；串行IO验证边界见[视频实现](../../docs/video.md)。中文正文在`assets/letter.txt`，修改后用项目`scripts/build.ps1`重新生成字形和固件。

## 代码与验收

地址映射、CPU参数、显存和串口协议见[CPU与显存](docs/cpu-profile.md)。

`firmware/`实现程序逻辑；`src/risc_soc.v`实现CPU总线与外设；`src/hd/hd_tile_stream.v`读取双缓冲显存并绘制；`hd_top.v`组织独立时钟和视频链路。

四个640×480程序实屏正常，720p60、1080p30和1080p45均经显示器模式和稳定运动确认。高清实屏使用贪吃蛇；自动化还核对方块与中文完整画面。 已验收配置为`0x0000C335`，摘要见[验证记录](reports/validation.json)。User Code用于识别配置，完整文件校验使用SHA256；它们不代替实际功能观察。
