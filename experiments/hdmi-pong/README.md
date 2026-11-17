# HDMI Pong

纯Verilog Pong，640×480／60Hz。运动、碰撞、AI、比分、串口和绘图全部在FPGA上完成，无软核CPU。

## 构建

在仓库根目录执行：

```powershell
powershell.exe -NoProfile -File tools/build.ps1 -Project hdmi-pong
```

准备方法见[环境说明](../../docs/environment.md)。构建脚本不访问USB，结果位于本项目`build/`。

## 控制

构建后双击`Play-Pong.cmd`加载SRAM，按Enter切到手动。W/S或上下键移动球拍，空格暂停，R重开，A切换自动，Esc退出并恢复自动对战。控制窗口保持焦点。

单独加载用`python scripts/program_sram.py`；串口验收用`powershell.exe -NoProfile -File scripts/test_serial.ps1`。

## 代码与验收

`src/game/`提供规则、状态与绘图；`src/pong_stream.v`通过valid/ready交付像素；`src/svo_hdmi.v`和`src/hdmi/`完成同步、编码与串行输出。采用Sipeed时钟与视频链路。

UART、暂停、重开、自动模式、完整扫描、反压、颜色顺序、STA、CRC、SRAM和实屏稳定性通过。 已验收配置为`0x0000CFD8`，摘要见[验证记录](reports/validation.json)。User Code用于识别配置，完整文件校验使用SHA256；它们不代替实际功能观察。
