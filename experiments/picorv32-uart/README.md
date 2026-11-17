# PicoRV32 最小串口 SoC

官方PicoRV32运行RV32I C固件，通过串口收发、GPIO和计时器展示最小SoC。CPU为27MHz。

## 构建

在仓库根目录执行：

```powershell
powershell.exe -NoProfile -File tools/build.ps1 -Project picorv32-uart
```

准备方法见[环境说明](../../docs/environment.md)。构建脚本不访问USB，结果位于本项目`build/`。

## 加载与串口

构建完成后进入本项目目录：

```powershell
python scripts/program_sram.py
powershell.exe -NoProfile -File scripts/test_serial.ps1 -PortName COM6 -BaudRate 115200
powershell.exe -NoProfile -File scripts/console.ps1 -PortName COM6 -BaudRate 115200
```

自动测试和交互控制台依次运行，下载前先关闭占用串口的窗口。默认115200、8N1，无流控；其他端口可通过参数指定。

## 代码与验收

先读`firmware/main.c`，再看`src/pico_uart_soc.v`如何连接CPU总线、程序ROM、数据RAM、UART与GPIO。CPU和UART原始文件位于`src/vendor/`。

C固件仿真、时序、SRAM、串口新应答、GPIO与连续计数通过。 已验收配置为`0x00001835`，摘要见[验证记录](reports/validation.json)。User Code用于识别配置，完整文件校验使用SHA256；它们不代替实际功能观察。
