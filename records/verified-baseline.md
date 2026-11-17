# 验收基线

更新日期：2026-11-17，Asia/Shanghai。记录正式实现的已完成验证，板上当前配置以最后一次实际加载为准。

开发板Tang Nano 9K，器件GW1NR-LV9QN88PC6/I5，ID0x1100481B。构建环境见[环境说明](../docs/environment.md)，加载配置见[下载说明](../docs/programming.md)。

| 项目 | CPU | 运行时钟 | 已验收配置 User Code |
| --- | --- | --- | --- |
| [LED 闪烁](../experiments/led-blink/README.md) | 无 | 27 MHz | `0x000053D2` |
| [六灯流水灯](../experiments/led-chaser/README.md) | 无 | 27 MHz | `0x00004F45` |
| [PicoRV32 最小串口 SoC](../experiments/picorv32-uart/README.md) | PicoRV32 | 27 MHz | `0x00001835` |
| [PicoRV32 RV32IMC SoC](../experiments/picorv32-full/README.md) | PicoRV32 | 13.5 MHz | `0x00001265` |
| [PicoRV32 扩展参数 SoC](../experiments/picorv32-max/README.md) | PicoRV32 | 13.5 MHz | `0x0000DACA` |
| [自写 RV32I CPU](../experiments/simple-rv32i/README.md) | SimpleRV32I | 13.5 MHz | `0x00008C00` |
| [自写 CPU 算法实验台](../experiments/rv32i-algorithms/README.md) | SimpleRV32I | 13.5 MHz | `0x0000201B` |
| [HDMI Pong](../experiments/hdmi-pong/README.md) | 无 | 25.2 MHz | `0x0000CFD8` |
| [HDMI 三游戏合集](../experiments/hdmi-arcade/README.md) | 无 | 25.2 MHz | `0x0000BF66` |
| [RISC-V 游戏与中文显示](../experiments/risc-playground/README.md) | PicoRV32 | 25.2 MHz | `0x0000C335` |

每个项目的reports/validation.json记录已验收位流的SHA256、源码摘要、时序和实物范围。User Code用于识别配置，不能代替SHA256。

LED闪烁已完成内部Flash与真实断电启动观察；流水灯已确认实物顺序。PicoRV32三个串口SoC均有板上功能记录。自写CPU完成26组指令对照，算法台完成4204项主机参考检查和32条板上命令，两类检查分别记录。

Pong、三款Arcade与四个RISC程序的640×480显示均经用户确认。RISC高清输出720p60、1080p30和1080p45均经显示器模式与稳定运动确认。算法状态灯、完整游戏手动分支和长期稳定性未作为已完成检查；45Hz的验证边界见[视频实现](../docs/video.md)。

PicoRV32与UART来源固定为Sipeed TangNano-9K-example提交c3b795799f23de91982be52db4273a8eea100cdb；各项目保留版权头和provenance.json。SimpleRV32I为本项目自行实现的多周期RV32I核心。
