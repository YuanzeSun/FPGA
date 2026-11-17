# 六灯流水灯

六颗用户LED每半秒依次点亮，三秒一轮。无CPU。

## 构建

在仓库根目录执行：

```powershell
powershell.exe -NoProfile -File tools/build.ps1 -Project led-chaser
```

准备方法见[环境说明](../../docs/environment.md)。构建脚本不访问USB，结果位于本项目`build/`。

## 加载

在本项目目录，用[下载流程](../../docs/programming.md)核对器件ID后加载`build/tangnano9k-led-chaser-gowin.fs`。SRAM仅用于临时运行；需要固定上电程序时单独执行Flash流程。

## 代码与验收

读`src/top.v`的步进计数器和六位输出编码；`sim/`及构建脚本检查始终恰好一灯点亮和完整循环。

仿真、时序、SRAM读回和实物顺序观察通过。 已验收配置为`0x00004F45`，摘要见[验证记录](reports/validation.json)。User Code用于识别配置，完整文件校验使用SHA256；它们不代替实际功能观察。
