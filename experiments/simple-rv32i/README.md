# SimpleRV32I

这是为 Tang Nano 9K 自行编写的一个多周期 RISC-V CPU。CPU、译码、ALU、寄存器组及串口均为本实验新写的 Verilog，按 RV32I 规范实现。

CPU 运行在 13.5 MHz，有 4 KiB 程序 ROM、1 KiB 数据与栈 RAM。配套 C 程序先做算术和内存自检，再每秒移动一次 LED，并通过串口报告计数。电脑发送 `p` 会收到 `PONG`，发送 `?` 可以查看状态。

## 从哪里看代码

| 文件 | 内容 |
| --- | --- |
| `src/rv32_alu.v` | 32 位加减、逻辑、比较和移位 |
| `src/rv32_regfile.v` | x1～x31 的保存和读写，x0 恒为零 |
| `src/rv32_decode.v` | 指令字段、立即数、运算类型与合法性 |
| `src/rv32_core.v` | PC、取指、执行、访存、写回和异常停机 |
| `src/simple_soc.v` | ROM、RAM、GPIO、串口寄存器与总线应答 |
| `src/uart.v` | 115200 波特率收发 |
| `src/top.v` | 时钟、启动复位和开发板连接 |
| `firmware/` | C 程序、启动汇编和链接脚本 |

建议先读 ALU 和寄存器组，再顺着译码器去看核心状态机。具体执行过程见 [CPU 设计说明](docs/CPU.md)。

## 指令与异常

实现 RV32I 的 40 条基础指令，使用小端存储。FENCE 在本系统的顺序总线上作为空操作完成；ECALL、EBREAK、非法指令、未对齐访问和总线访问错误会记录原因并停机，复位后重新运行。

本版不含 M 乘除法、C 压缩指令、CSR、特权模式和中断。它适合运行以 `-march=rv32i -mabi=ilp32` 编译的小型裸机程序。全灯点亮表示 CPU 异常停机。

## 编译与运行

Windows PowerShell 构建：

```powershell
powershell.exe -NoProfile -File tools/build.ps1 -Project simple-rv32i
```

脚本先编译 C，再做指令对照测试和串口仿真，最后综合、布局布线、生成位流并校验 CRC。

构建使用本机已有的 `/opt/fpga-tools/hdmi/venv`，其中是新版 Yosys、nextpnr-himbaechel 和 Apicula，能够推断专用块 RAM。C 编译器和 Icarus Verilog 使用 WSL 中原有的安装。

在本实验目录加载 SRAM：

```powershell
python scripts/program_sram.py
powershell.exe -NoProfile -File scripts/test_serial.ps1
```

想手动收发，可在加载后运行 `powershell.exe -NoProfile -File scripts/console.ps1`。按 `p`、`?` 不需要回车，Esc 退出；下载前先退出串口控制台。

下载脚本会核对源码、位流哈希和 FPGA ID。默认使用 `C:\GowinProgrammer` 的 V1.9.11.02、USB Debugger A、2MHz；串口默认为 COM6。只写 SRAM，断电后需要重新加载。

## 存储器与外设地址

| 地址 | 内容 |
| --- | --- |
| `0x00000000～0x00000FFF` | 程序 ROM，只读 |
| `0x00001000～0x000013FF` | 数据 RAM，栈顶为 `0x1400` |
| `0x40000000` | GPIO，低 6 位，1 表示点亮 |
| `0x40000004` | UART 发送，忙时总线等待 |
| `0x40000008` | UART 接收，无数据时返回 `0xFFFFFFFF` |
| `0x4000000C` | UART 状态：bit0 忙、bit1 有数据、bit2 接收溢出 |
| `0x40000010` | CPU 时钟计数器，32 位循环计数 |
| `0x40000014` | 异常原因码 |

## 验证记录

2026 年 11 月 15 日完成：26 组指令测试、2882 次逐条执行结果比对，C 固件与 UART 仿真、时序、位流 CRC、SRAM 下载读回及实机串口测试均通过。

实机自检为 `000000FF`，随机字符的新应答、PONG、持续计数和 GPIO 更新正常，计时器实测约 13.50 MHz。该验收配置User Code为 `0x00008C00`。六颗 LED 应每秒轮流点亮，实物观察待确认。

最终使用 4211/8640 LUT4、1354/6480 DFF、6/26 块 RAM，布局布线估计最高 32.43 MHz，通过 13.5 MHz 目标。

构建结果在 `build/build-result.json`，指令测试在 `build/isa-test/`，下载和实机串口记录分别在 `build/sram-test/`、`build/serial-test/`。实测摘要见 `reports/validation.json`。工具环境见[环境说明](../../docs/environment.md)。

指令对照覆盖全部 40 条指令、分支的两种结果和多种异常，还模拟了不同的存储器等待周期。这些是本实验的功能测试，不是官方一致性认证。

## 来源

CPU 依据 [RV32I 规范](https://docs.riscv.org/reference/isa/v20260120/unpriv/rv32.html) 独立实现；未引入第三方 CPU RTL。管脚依据 [Sipeed 板卡资料](https://wiki.sipeed.com/hardware/zh/tang/Tang-Nano-9K/Nano-9K.html)。时钟使用 Gowin rPLL 硬件原语；位流元数据处理复用了此前自行编写的辅助脚本。

统一构建命令在仓库根目录执行；直接运行项目脚本时应先进入本项目目录。环境见[环境说明](../../docs/environment.md)。
