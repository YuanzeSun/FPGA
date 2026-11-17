# LED 闪烁

27MHz晶振驱动计数器，第一颗用户LED约半秒亮、半秒灭，其余五颗关闭。无CPU。

## 构建

在仓库根目录执行：

```powershell
powershell.exe -NoProfile -File tools/build.ps1 -Project led-blink
```

准备方法见[环境说明](../../docs/environment.md)。构建脚本不访问USB，结果位于本项目`build/`。

## 加载

在本项目目录，用[下载流程](../../docs/programming.md)核对器件ID后加载`build/tangnano9k-led-gowin.fs`。SRAM仅用于临时运行；需要固定上电程序时单独执行Flash流程。

## 代码与验收

读`src/top.v`中的计数器、翻转寄存器与低电平点亮逻辑。计数到13,499,999时翻转一次，完整亮灭周期为1秒。

当前版本完成SRAM、内部配置Flash写入和真实断电启动验收。 已验收配置为`0x000053D2`，摘要见[验证记录](reports/validation.json)。User Code用于识别配置，完整文件校验使用SHA256；它们不代替实际功能观察。
