# 已验证的环境与实验

记录日期：2026 年 11 月 13 日，Asia/Shanghai。以下来自本机安装信息和已有实验日志。

## 工具组合

| 项目 | 版本或设置 |
| --- | --- |
| 系统 | Windows 11，WSL Ubuntu-24.04 |
| Yosys | 0.33，Ubuntu 包 `0.33-5build2` |
| nextpnr-gowin | `0.6-3build5`，旧 Gowin 后端 |
| Apicula | Ubuntu 包 `python3-apycula 0.10.0+dfsg1-1` |
| Icarus Verilog | `12.0-2build2` |
| RISC-V GCC | `13.2.0-11ubuntu1+12` |
| RISC-V binutils | `2.42-1ubuntu1+6` |
| Python | WSL 3.12.3，Windows 3.13.5 |
| Windows Programmer | V1.9.11.02 build2518，`C:\GowinProgrammer` |
| Cable | USB Debugger A，index 4，默认通道 0，2MHz |
| 驱动 | 既有 FTDI 2.12.36.20，未额外安装驱动或升级下载器固件 |
| 器件 ID | `0x1100481B` |
| 串口 | COM6，115200 8N1，无流控 |

Programmer 压缩包 SHA256：

```text
b58f259865ea956e93b293bcd81536e6abad087fc006b7b8b5de070346ef52c6
```

这是一套跑通过的组合，不是各工具最新版本的清单。apt 安装包的具体版本已在本轮整理时重新查询。

## 已有实验

| 实验目录 | 已完成的验证 | 当次 User Code |
| --- | --- | --- |
| TangNano9K-LED | 构建、SRAM 加载，用户确认约半秒亮灭；后续内部 Flash 写入和重载通过 | `0x000053D2` |
| TangNano9K-LED-Chaser | 仿真、27 MHz 时序、SRAM 加载读回 | `0x00004F45` |
| TangNano9K-PicoRV32-UART | C 固件、SRAM、UART 收发、GPIO、连续计数 | `0x00001835` |
| TangNano9K-PicoRV32-Full | RV32IMC 仿真、13.5 MHz 时序、SRAM、实机串口自检 | `0x00001265` |
| TangNano9K-PicoRV32-Max | 官方参数核对、仿真、时序、SRAM、实机功能与新应答 | `0x0000DACA` |

Flash 成功写入约 8 秒，重载后 User Code 为 `0x000053D2`，状态为 `0x0001F020`。此次没有逐字节 Flash Verify，真实断电启动尚未测试。走马灯的后续实物观察不并入这份自动测试记录。

Full、Max 使用 4 KiB 程序 ROM、512 字节数据 RAM。Max 最终占用 7772/8640 SLICE；快速乘法器候选超过容量，没有加载。此结果只对应当时的工程与映射方式。

## 来源

CPU 和 UART 来自 Sipeed 示例仓库，固定提交 `c3b795799f23de91982be52db4273a8eea100cdb`。哈希见 [来源记录](evidence/cpu-provenance.json)。

保留的简短原始记录：[Flash 重载后读回](evidence/flash-readback.log)、[Max 串口测试结果](evidence/cpu-max-serial.json)。完整构建日志继续保存在各实验目录，迁入仓库时选取需要的部分放进 `reports/`。

板卡资料：[Tang Nano 9K](https://wiki.sipeed.com/hardware/zh/tang/Tang-Nano-9K/Nano-9K.html)。
