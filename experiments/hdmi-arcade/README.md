# HDMI 三游戏合集

一个纯Verilog位流运行接球躲避、打砖块、太空射击。640×480／60Hz，无软核CPU。

## 构建

在仓库根目录执行：

```powershell
powershell.exe -NoProfile -File tools/build.ps1 -Project hdmi-arcade
```

准备方法见[环境说明](../../docs/environment.md)。构建脚本不访问USB，结果位于本项目`build/`。

## 控制

构建后双击`Play-Arcade.cmd`，选择1接球、2打砖块、3太空射击，加载SRAM后按Enter手动操作。左右键或A/D移动，F/J发球或开火；空格暂停，R重开，Tab自动，1/2/3切换，Esc退出。

串口验收用`powershell.exe -NoProfile -File scripts/test_serial.ps1`。三款游戏共用一份位流，切换游戏不需要重新加载。

## 代码与验收

`src/catch_game.v`、`breakout_game.v`、`invaders_game.v`实现规则；`arcade_system.v`处理选择和控制；`arcade_render.v`绘图；`arcade_stream.v`连接正式视频输出。

三游戏的选择、移动、暂停、重开、碰撞和渲染仿真通过，三种画面均完成实屏确认。 已验收配置为`0x0000BF66`，摘要见[验证记录](reports/validation.json)。User Code用于识别配置，完整文件校验使用SHA256；它们不代替实际功能观察。
