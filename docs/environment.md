# 构建环境

开发板为Tang Nano 9K，芯片GW1NR-LV9QN88PC6/I5，27MHz板载晶振，器件ID为0x1100481B。

## 工具组合

| 项目 | 构建工具 |
| --- | --- |
| LED、流水灯、三个PicoRV32串口项目 | WSL Yosys 0.33、nextpnr-gowin 0.6、Apicula 0.10 |
| 自写CPU与算法台 | WSL yowasp-yosys、Himbaechel Gowin后端、Apicula，版本见tools/requirements-fpga.txt |
| Pong、Arcade、RISC-V HDMI | Windows Gowin V1.9.11.03 Education，WSL Icarus Verilog与Apicula |
| C固件 | WSL riscv64-unknown-elf-gcc 13.2，按项目选择rv32i或rv32imc |
| 加载开发板 | Windows Gowin Programmer V1.9.11.02 build2518 |

Gowin编译器执行综合和布局布线；Programmer执行位流加载。项目按表中的组合复现，工具程序不进入Git。

## WSL

使用Ubuntu-24.04，Icarus Verilog 12；基础依赖为yosys、nextpnr-gowin、python3-apycula、iverilog、gcc-riscv64-unknown-elf和binutils-riscv64-unknown-elf。自写CPU工具环境的固定Python依赖在[requirements-fpga.txt](../tools/requirements-fpga.txt)。

已验证的专用虚拟环境位于`/opt/fpga-tools/hdmi/venv`。可在该目录建立虚拟环境并安装requirements；需要写入/opt时按本机权限设置目录。自写CPU脚本支持`FPGA_TOOLS_DIR`指定其bin目录，HDMI构建支持`FPGA_PYTHON`指定其中Python。WSL中的C编译器、Icarus和GCC需要可从PATH访问。

## 本机配置

在仓库根目录复制`config/local.example.psd1`为`config/local.psd1`，填写GowinShell、ProgrammerCli、WslDistro和LinuxPython。统一入口`tools/build.ps1`读取配置，不依赖用户名或仓库所在目录。

直接调用HDMI项目Python脚本时，可用环境变量`GOWIN_SH`指定gw_sh.exe，或者按项目中的`toolchain.local.example.json`创建`toolchain.local.json`。下载脚本支持`GOWIN_PROGRAMMER`指定Programmer CLI，默认`C:\GowinProgrammer\bin\programmer_cli.exe`。

配置文件由Git忽略。默认串口COM6、115200、8N1；串口脚本的PortName参数可以覆盖端口。Windows通过wsl.exe执行离线构建，通过Windows串口和下载工具连接板子。
