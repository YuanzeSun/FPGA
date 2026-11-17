# 加载与固化

## 选择操作

| 操作 | 作用 | 断电后 |
| --- | --- | --- |
| SRAM加载 | 调试当前项目 | 配置丢失 |
| 内部配置Flash写入 | 保存上电程序 | 配置保留 |
| 从Flash重载 | 运行已经保存的配置 | 不修改Flash |

日常项目启动器只加载SRAM。下载前关闭其他串口控制台和Programmer实例。

## 当前下载配置

Programmer V1.9.11.02 build2518，GW1NR-9C，USB Debugger A，cable-index 4，2MHz。本机单板连接时使用默认通道0。设备实际ID必须为0x1100481B；重新连接或使用多板时应重新识别目标。

在仓库根目录读取本机配置并检查设备：

```powershell
$cfg = Import-PowerShellDataFile config/local.psd1
$cli = $cfg.ProgrammerCli
$linkArgs = @('--device',$cfg.Device,'--cable-index',[string]$cfg.CableIndex,'--frequency',$cfg.Frequency)
& $cli --scan-cables F
& $cli @linkArgs --run 0
```

## SRAM

项目提供`program_sram.py`或启动器时，优先使用它们。它们检查构建、位流SHA256和器件ID，并记录下载与读回。

通用加载示例：

```powershell
$fs = (Resolve-Path experiments/led-blink/build/tangnano9k-led-gowin.fs).Path
Get-FileHash -LiteralPath $fs -Algorithm SHA256
& $cli @linkArgs --run 2 --fsFile $fs
& $cli @linkArgs --run 0
```

同时检查退出码、完成信息、User Code和状态位：DONE bit13、READY bit15为1，错误位bits0..3为0。User Code是配置标识，不能代替完整文件SHA256、串口新应答或实屏观察。

## 内部配置Flash

需要替换上电程序时，在SRAM验收后单独执行：

```powershell
& $cli @linkArgs --run 5 --fsFile $fs
& $cli @linkArgs --run 1
& $cli @linkArgs --run 0
```

操作编号对应本页列出的Programmer版本。仓库LED闪烁版本已完成Flash写入、重载和真实断电启动验收。其他项目的验收记录以各自reports为准。
