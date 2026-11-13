# PicoRV32 与串口

## C 程序在哪里编译

C 代码由 WSL 中的 `riscv64-unknown-elf-gcc` 交叉编译，生成给 FPGA 里的 RISC-V CPU 执行的机器码。工具名带 `riscv64`，也可以通过 `-march=rv32imc -mabi=ilp32` 生成当前实验所需的 32 位程序。

现有工程的构建顺序是：

```text
C 和启动汇编 → ELF → 二进制与 ROM 初始化文件
Verilog SoC 和 ROM 内容 → 仿真 → 综合 → 布局布线 → FPGA 位流
```

固件随位流初始化到片内存储。修改 C 后需要重新构建并加载位流；当前工程没有独立的串口固件加载器。编译选项、链接地址和内存容量保留在项目脚本及 `firmware/link.ld` 中。

## 现有 CPU 配置

最小版用于先跑通 C、LED 和 UART；Full、Max 版使用 RV32IMC，加入乘除法、压缩指令、计数器、中断等功能。Max 是本机这套外围和工具链下可放入芯片的参数组合，并非把所有参数设成 1。

快速乘法器候选超出资源，因此最终使用迭代乘法器；M 扩展仍保留。额外的 ALU、比较流水级会改变周期数。[PicoRV32 参数说明](https://github.com/YosysHQ/picorv32#verilog-module-parameters)

复现 CPU 工程时，保留 RTL 参数、`-march`、ROM/RAM 地址、CPU 时钟和串口分频之间的对应关系。Full、Max 的 CPU 为 13.5 MHz，源晶振仍是 27 MHz。

## 串口怎么接

板载 USB 已提供 UART 桥，直接用 Windows 的 COM 口，不需要额外 USB 转串口模块。本机枚举为 COM6，换 USB 口或电脑后先查看实际编号。

当前实验使用 **115200、8 数据位、无校验、1 停止位、无流控**。FPGA TX 在管脚 17，RX 在管脚 18，参见 [官方 PicoTiny 约束](https://github.com/sipeed/TangNano-9K-example/blob/c3b795799f23de91982be52db4273a8eea100cdb/picotiny/project/picotiny.cst)。

在已迁入的 CPU 实验目录运行：

```powershell
powershell.exe -NoProfile -File .\scripts\test_serial.ps1 -PortName COM6 -BaudRate 115200
powershell.exe -NoProfile -File .\scripts\console.ps1 -PortName COM6 -BaudRate 115200
```

先运行自动测试，结束后再开交互控制台。Full、Max 的常用命令为 `p` 查询应答、`m` 测乘除法、`i` 触发软件中断、`?` 查询状态、`0` 到 `5` 选灯；按键不用回车。

串口桥可能积压旧输出。测试时先读空，再发送本次随机字符并核对应答，观察计数器持续增长。只看到启动文字，不能说明当前程序正在响应。脚本应在 `finally` 中关闭并释放串口，下载前也先退出控制台。
