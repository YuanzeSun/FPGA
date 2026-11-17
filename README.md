# Tang Nano 9K FPGA 项目

已经完成构建和上板验证的 Verilog、RISC-V 与 HDMI 项目。仓库保存正式源码、可执行的构建步骤和验收结果。

## 项目

| 项目 | CPU | 运行时钟 | 已验收配置 User Code |
| --- | --- | --- | --- |
| [LED 闪烁](experiments/led-blink/README.md) | 无 | 27 MHz | `0x000053D2` |
| [六灯流水灯](experiments/led-chaser/README.md) | 无 | 27 MHz | `0x00004F45` |
| [PicoRV32 最小串口 SoC](experiments/picorv32-uart/README.md) | PicoRV32 | 27 MHz | `0x00001835` |
| [PicoRV32 RV32IMC SoC](experiments/picorv32-full/README.md) | PicoRV32 | 13.5 MHz | `0x00001265` |
| [PicoRV32 扩展参数 SoC](experiments/picorv32-max/README.md) | PicoRV32 | 13.5 MHz | `0x0000DACA` |
| [自写 RV32I CPU](experiments/simple-rv32i/README.md) | SimpleRV32I | 13.5 MHz | `0x00008C00` |
| [自写 CPU 算法实验台](experiments/rv32i-algorithms/README.md) | SimpleRV32I | 13.5 MHz | `0x0000201B` |
| [HDMI Pong](experiments/hdmi-pong/README.md) | 无 | 25.2 MHz | `0x0000CFD8` |
| [HDMI 三游戏合集](experiments/hdmi-arcade/README.md) | 无 | 25.2 MHz | `0x0000BF66` |
| [RISC-V 游戏与中文显示](experiments/risc-playground/README.md) | PicoRV32 | 25.2 MHz | `0x0000C335` |

HDMI Pong、三游戏合集的游戏逻辑和绘图由 Verilog 硬件实现。RISC-V 游戏由官方 PicoRV32 执行 C 固件；SimpleRV32I 与算法实验台使用自行实现的 CPU。电脑负责构建、加载和发送输入。

RISC-V 游戏支持已实测的 **640×480／60 Hz、1280×720／60 Hz、1920×1080／30 Hz、1920×1080／45 Hz**。字符画布为640×480，1080p输出按整数2倍放大；输出分辨率与游戏逻辑分辨率分别说明，见[视频实现](docs/video.md)。

## 构建与运行

环境为 Windows 11 + WSL Ubuntu-24.04。先按[环境说明](docs/environment.md)准备工具和本机配置，在仓库根目录运行：

```powershell
Copy-Item config/local.example.psd1 config/local.psd1
# 修改local.psd1中的实际工具路径；配置文件不提交Git。
powershell.exe -NoProfile -File tools/build.ps1 -Project rv32i-algorithms
powershell.exe -NoProfile -File tools/build.ps1 -Project risc-playground -Mode 1080p45
```

构建不访问开发板。构建通过后，进入相应实验目录，使用其启动器或下载脚本加载SRAM。具体输入和控制方式见项目README；通用操作见[下载](docs/programming.md)。

## 阅读入口

- [项目目录](experiments/README.md)：功能、构建与控制方式。
- [开发流程](docs/development.md)：仿真、时序和位流检查。
- [CPU与串口](docs/cpu-and-uart.md)：C固件、地址映射和实际执行位置。
- [HDMI视频](docs/video.md)：像素流、跨时钟域、时序与分辨率。
- [验收基线](records/verified-baseline.md)：实际验证范围及记录。
- [仓库约定](docs/repository.md)：正式源码与验证摘要的组织方式。

`experiments/`每个项目都有独立源码、约束、仿真、脚本和`reports/validation.json`。`build/`、`impl/`、工具软件和本机配置不进入Git。第三方代码保留版权头，固定来源见各项目`provenance.json`。
