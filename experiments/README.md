# 正式项目

以下十个项目均有上板验证记录。项目的具体功能、构建和操作方法在各自README中，验证范围在`reports/validation.json`中。

| 项目 | CPU | 运行时钟 | 已验收配置 User Code |
| --- | --- | --- | --- |
| [LED 闪烁](led-blink/README.md) | 无 | 27 MHz | `0x000053D2` |
| [六灯流水灯](led-chaser/README.md) | 无 | 27 MHz | `0x00004F45` |
| [PicoRV32 最小串口 SoC](picorv32-uart/README.md) | PicoRV32 | 27 MHz | `0x00001835` |
| [PicoRV32 RV32IMC SoC](picorv32-full/README.md) | PicoRV32 | 13.5 MHz | `0x00001265` |
| [PicoRV32 扩展参数 SoC](picorv32-max/README.md) | PicoRV32 | 13.5 MHz | `0x0000DACA` |
| [自写 RV32I CPU](simple-rv32i/README.md) | SimpleRV32I | 13.5 MHz | `0x00008C00` |
| [自写 CPU 算法实验台](rv32i-algorithms/README.md) | SimpleRV32I | 13.5 MHz | `0x0000201B` |
| [HDMI Pong](hdmi-pong/README.md) | 无 | 25.2 MHz | `0x0000CFD8` |
| [HDMI 三游戏合集](hdmi-arcade/README.md) | 无 | 25.2 MHz | `0x0000BF66` |
| [RISC-V 游戏与中文显示](risc-playground/README.md) | PicoRV32 | 25.2 MHz | `0x0000C335` |

从硬件基础开始可按LED、PicoRV32串口、自写CPU、算法台、HDMI项目的顺序阅读。CPU算法台无需显示器；HDMI项目需要直接连接显示器。
