# 下载与固化

## 选 SRAM 还是 Flash

| 操作 | 用途 | 断电后 |
| --- | --- | --- |
| SRAM 加载 | 日常调试，临时运行新设计 | 配置丢失，下次从 Flash 启动 |
| 内部配置 Flash 写入 | 固化已经验证的设计 | 保留新配置 |
| 从 Flash 重载 | 不拔 USB，重新加载已有配置 | 不改写 Flash |

板上的外部 SPI Flash 是另一项资源，不属于这里的内部配置 Flash 操作。

## 下载器设置

已验证的组合是 **Programmer V1.9.11.02 build2518、USB Debugger A、2MHz**。此版本对应 `--cable-index 4`，通道默认 0，本机单板连接时不指定 `--location`。

下面的 PowerShell 命令从仓库根目录执行，先准备本机配置：

```powershell
Copy-Item .\config\local.example.psd1 .\config\local.psd1
```

复制只需做一次。修改配置后，每次新开终端读取它：

```powershell
$cfg = Import-PowerShellDataFile .\config\local.psd1
$cli = $cfg.ProgrammerCli
$linkArgs = @('--device', $cfg.Device, '--cable-index', [string]$cfg.CableIndex, '--frequency', $cfg.Frequency)
```

先关闭串口控制台和其他 Programmer 实例，再枚举下载器、读取 ID：

```powershell
& $cli --scan-cables F
& $cli @linkArgs --run 0
```

看到实际 ID `0x1100481B` 后再下载。多块板同时连接时，要重新确定位置和目标，不能沿用单板设置。

## 加载 SRAM

把路径改成要运行的位流：

```powershell
$fs = (Resolve-Path '.\experiments\led-blink\build\design-gowin.fs').Path
Get-FileHash -LiteralPath $fs -Algorithm SHA256
& $cli @linkArgs --run 2 --fsFile $fs
& $cli @linkArgs --run 0
```

迁入的旧工程若已有带校验的 `scripts/program_sram.py`，优先使用项目脚本。它会核对构建结果、文件哈希、器件 ID，并保存下载与读回日志。

验收同时看退出码、完成日志和读回结果：User Code 应与本次位流一致，状态的 DONE bit13、READY bit15 应为 1，错误位 bits0..3 为 0。本机成功状态曾为 `0x0001F020`，无需要求整个状态字固定不变。

User Code 用于辨认本次配置；它不是文件的 SHA256，也不能代替功能测试。随后检查 LED、串口或项目规定的其他行为。

## 写入内部配置 Flash

SRAM 中确认功能正常、确定要替换上电配置后，再执行这一组命令：

```powershell
& $cli @linkArgs --run 5 --fsFile $fs
& $cli @linkArgs --run 1
& $cli @linkArgs --run 0
```

`--run 5` 会擦除并写入内部配置 Flash；`--run 1` 从中重载，`--run 0` 读回代码。操作编号按上述已验证的 Programmer 版本解释。[Gowin Programmer 手册](https://cdn.gowinsemi.com.cn/SUG502E.pdf)

记录“写入成功”“从 Flash 重载成功”和“真实断电启动通过”时要分开写。本机前两项已完成，真实断电测试留待现场方便时做。成功这轮没有执行逐字节 Flash Verify。
