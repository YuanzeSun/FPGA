# 环境搭建

## Windows 和 WSL 各做什么

| 环境 | 工具 | 用途 |
| --- | --- | --- |
| WSL Ubuntu 24.04 | Yosys、nextpnr-gowin、Apicula | 综合、布局布线、打包位流 |
| WSL Ubuntu 24.04 | Icarus Verilog | RTL 仿真 |
| WSL Ubuntu 24.04 | RISC-V GCC、binutils | 编译软核 CPU 的 C 固件 |
| Windows | Gowin Programmer | 通过板载下载器加载 FPGA |
| Windows | PowerShell 串口脚本 | 与板上的程序通信 |

Windows 用 `wsl.exe` 启动 Ubuntu 命令，用 `/mnt/c/...` 共享文件。这条流程用不到 SSH，也不需要把 USB 转交给 WSL。[WSL 命令说明](https://learn.microsoft.com/en-us/windows/wsl/basic-commands)

## WSL 工具

先在 PowerShell 用 `wsl.exe -l -v` 确认发行版名称。下面的安装命令在 **Ubuntu 终端**执行；已经安装过的电脑可直接检查版本。

```bash
sudo apt-get update
sudo apt-get --no-remove --no-install-recommends install yosys nextpnr-gowin python3-apycula iverilog
```

做 PicoRV32 实验时再安装交叉编译器：

```bash
sudo apt-get --no-remove --no-install-recommends install gcc-riscv64-unknown-elf binutils-riscv64-unknown-elf
```

查看实际安装版本：

```bash
dpkg-query -W yosys nextpnr-gowin python3-apycula iverilog gcc-riscv64-unknown-elf binutils-riscv64-unknown-elf
```

本仓库的旧实验使用 Ubuntu 仓库里的 Yosys 0.33、nextpnr-gowin 0.6、Apicula 0.10。新安装时 apt 的具体版本可能不同，保存版本输出，并先复现一个简单实验。构建脚本与工具版本要配套，不能只替换其中一项。

## Windows 下载工具

本机采用 [Sipeed 提供的 Programmer 1.9.11.02](https://dl.sipeed.com/shareURL/TANG/programmer/1.9.11.02)，包名为 `programmer1.9.11.02(build2518).Win64.zip`，是解压式软件。

解压后的目录层级应为：

```text
C:\GowinProgrammer\bin\programmer.exe
C:\GowinProgrammer\bin\programmer_cli.exe
```

本机只使用这一套 Windows FPGA 工具，所以放在 `C:\GowinProgrammer`。以后若增加第二套解压式工具，再统一放进 `C:\fpga\` 下的各自目录。

Win11 是否需要安装驱动，看设备能否正常枚举。本机现有 FTDI 驱动已能下载和使用串口，没有额外运行驱动安装器。接入后可在设备管理器查看 USB 设备及 COM 口；若异常，再按官方说明处理。

## 文件放在哪里

实验总目录使用桌面下的 `FPGA`，仓库是其中的 `fpga-projects`。例如 `C:\Users\<用户名>\Desktop\FPGA` 在 WSL 中对应 `/mnt/c/Users/<用户名>/Desktop/FPGA`。

直接在这个目录构建便于 Windows 下载器取文件。以后工程变大、文件访问成为瓶颈时，可以把构建移到 WSL 的 Linux 文件系统，再导出位流。[Windows 与 Linux 文件系统说明](https://learn.microsoft.com/en-us/windows/wsl/filesystems)
