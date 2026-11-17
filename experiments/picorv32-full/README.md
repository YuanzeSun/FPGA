# PicoRV32 RV32IMC SoC

官方PicoRV32运行RV32IMC固件，包含乘除法、压缩指令、计数器、中断、PCPI与trace接口配置。CPU为13.5MHz。

## 构建

在仓库根目录执行：

```powershell
powershell.exe -NoProfile -File tools/build.ps1 -Project picorv32-full
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

CPU实例参数在`src/pico_uart_soc.v`；固件自检和中断服务例程在`firmware/`；功能参数见`features.json`。串口命令`p`查询、`m`乘除法、`i`软件中断、`?`状态、`0`到`5`选灯。

实际CPU RTL仿真、时序和板上串口自检通过。ROM为4KiB，数据RAM为512字节。 已验收配置为`0x00001265`，摘要见[验证记录](reports/validation.json)。User Code用于识别配置，完整文件校验使用SHA256；它们不代替实际功能观察。
