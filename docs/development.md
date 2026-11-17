# 日常开发

## 一个实验放哪些文件

```text
experiments/<实验名>/
  README.md
  src/             Verilog 源码
  constraints/     管脚、电气属性和时钟约束
  sim/             测试平台
  scripts/         构建、下载、验证脚本
  firmware/        有软核 CPU 时使用
  reports/         需要长期保留的验证记录
  build/           可重新生成的文件
```

新实验先复制 [说明模板](../templates/experiment-readme.md)。写清预期行为、时钟、引脚和验收方法，再开始实现。

## 构建前核对

Tang Nano 9K 的器件名在不同工具里写法不同：

| 用途 | 值 |
| --- | --- |
| 芯片型号及 nextpnr 目标 | `GW1NR-LV9QN88PC6/I5` |
| nextpnr 和 Apicula 器件族 | `GW1N-9C` |
| Gowin Programmer 目标 | `GW1NR-9C` |
| 本机实际读到的器件 ID | `0x1100481B` |

板载晶振为 27 MHz，管脚 52；六颗用户 LED 对应 10、11、13、14、15、16，低电平点亮。管脚来源见 [Apicula 0.10 约束](https://raw.githubusercontent.com/YosysHQ/apicula/0.10.0/examples/tangnano9k.cst)。

引脚号和电气标准要分别核对。板卡LED所在bank为1.8V；新设计应按板卡原理图选择匹配VCCIO的电气标准，使用LVCMOS18作为该bank的参考。复现实测配置时使用项目自带约束，不跨项目混用。

## 编译顺序

先用 Icarus Verilog 检查复位、计数、状态切换等关键行为，再做综合和布局布线。下面是**单时钟 LED 工程**的基本命令，在 Ubuntu 的实验目录中执行，要求已有 `src/top.v` 和约束文件：

```bash
mkdir -p build
yosys -l build/yosys.log -p 'read_verilog src/top.v; synth_gowin -top top -json build/top.json; check -assert'
nextpnr-gowin --json build/top.json --write build/top_pnr.json --device GW1NR-LV9QN88PC6/I5 --family GW1N-9C --cst constraints/tangnano9k.cst --freq 27 --report build/timing.json --log build/nextpnr.log
gowin_pack -d GW1N-9C -o build/design.fs build/top_pnr.json
```

多模块、PLL 和 CPU 工程使用各自的 `scripts/build.py`，由脚本列出源文件并设置派生时钟。`--freq 27` 不能代替所有时钟的约束。

构建后检查三件事：结构检查通过，时序满足实际时钟，资源没有超限。保留命令、退出码、日志和工具版本；仅生成 `.fs` 文件还不算上板验证。

## 给 Windows 下载器准备位流

原始 `.fs` 保留一份，再生成带 Programmer 元数据的副本。在上面这个实验目录执行：

```bash
python3 ../../tools/prepare_gowin_fs.py --input build/design.fs --output build/design-gowin.fs
```

这个共用脚本适用于旧实验生成的、未压缩且启用 CRC 的 GW1N-9C 位流。它核对格式和配置校验和，补充 `CheckSum`、`UserCode` 注释，不改变配置数据；其他格式会拒绝处理。完整帧 CRC 的校验仍由构建流程负责，见 [工具说明](../tools/README.md)。

最后按 [下载流程](programming.md) 加载 SRAM，再验证实际功能。
