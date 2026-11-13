# FPGA 项目与开发工作流

从 Tang Nano 9K 开始，记录实验源码、构建方法和上板结果。开发环境是 Windows 11 + WSL Ubuntu：WSL 负责编译，Windows 负责下载和串口。

## 从哪里开始

| 要做的事 | 看这里 |
| --- | --- |
| 换电脑或重新装环境 | [环境搭建](docs/environment.md) |
| 修改 RTL 并生成位流 | [日常开发](docs/development.md) |
| 下载到 SRAM 或写入 Flash | [下载与固化](docs/programming.md) |
| 编译 C 程序并用串口调试 | [PicoRV32 与串口](docs/cpu-and-uart.md) |
| 下载慢、串口不通等问题 | [排错](docs/troubleshooting.md) |
| 添加实验、整理提交 | [仓库约定](docs/repository.md) |

常用顺序是：**修改源码 → 仿真 → 综合和布局布线 → 查看时序 → SRAM 加载 → 验证功能**。程序稳定后，再考虑写入 Flash。

## 目录

```text
docs/          操作指南
experiments/   实验，每个实验一个目录
tools/         共用的小工具
config/        本机配置示例
templates/     实验说明和运行记录模板
records/       已验证的工具组合与历史结果
```

本机已跑通的版本、下载器设置和实验结果见 [验证基线](records/verified-baseline.md)。它是一份历史记录，当前板上运行什么，以最近一次下载为准。

## 第一次使用

复制 `config/local.example.psd1` 为 `config/local.psd1`，按电脑上的实际路径和串口号修改。后者由 Git 忽略。

已有的 LED、走马灯和 PicoRV32 工程还在上一级实验总目录。后续迁入 `experiments/` 时，按 [仓库约定](docs/repository.md) 逐个整理。
