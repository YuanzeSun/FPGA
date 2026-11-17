# PicoRV32 扩展参数 SoC

官方PicoRV32的扩展配置：RV32IMC、64位计数器、桶形移位、中断、PCPI、trace以及两级ALU和比较路径。CPU为13.5MHz。

## 构建

在仓库根目录执行：

```powershell
powershell.exe -NoProfile -File tools/build.ps1 -Project picorv32-max
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

参数位于`src/pico_uart_soc.v`和`features.json`。M扩展使用迭代乘法器；当前参数组合以资源和时序均满足为边界。串口命令与Full一致。

RTL仿真、时序、SRAM和板上串口功能通过。此配置为7772/8640 SLICE，ROM4KiB、RAM512字节。 已验收配置为`0x0000DACA`，摘要见[验证记录](reports/validation.json)。User Code用于识别配置，完整文件校验使用SHA256；它们不代替实际功能观察。
