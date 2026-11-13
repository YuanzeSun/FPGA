# 共用工具

`prepare_gowin_fs.py` 从现有 PicoRV32 工程提取，使用 Python 标准库，不访问 USB。

```bash
python3 tools/prepare_gowin_fs.py --input path/to/design.fs --output path/to/design-gowin.fs
```

只处理器件 ID 为 `0x1100481B`、启用 CRC 的未压缩位流：712 行配置帧，后面可带 RAM 初始化帧，每帧 2904 位。脚本检查格式与 footer 校验和，并确认输出配置行与输入一致。

输入、输出必须为不同文件。升级 Apicula 或改用压缩位流时，先重新核对格式；脚本不验证每一帧 CRC，也不代替构建、时序或上板检查。
