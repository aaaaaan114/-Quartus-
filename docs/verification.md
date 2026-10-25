# 验证记录

验证日期：2026-10-25（Asia/Shanghai）。

## 来源和实现

- 原始仓库：`https://github.com/aaaaaan114/-Quartus-.git`。
- 基准提交：`bb36d8302d5bdbfe5008560608519b5b8cebb24c`。
- `reference/` 中保存六份原始源码，未修改内容。
- 引脚依据 2015-08-05 版 DE1-SoC 手册；通过 PDF 文本表格逐项交叉核对全部 53 个引脚，未发现缺项、复用或不一致。蜂鸣器对应表中 `GPIO_0[0] / PIN_AC18`。

## 已完成的验证

仿真器：Icarus Verilog 13.0 stable（MSYS2 Windows 构建）。仿真器及其依赖位于本机工具缓存，不属于工程，也未打入交付压缩包。

| 检查 | 结果 | 覆盖内容 |
| --- | --- | --- |
| RTL 编译 | 通过 | 七个模块以 Verilog-2005 模式编译，`-Wall` 未报告警告 |
| 工程静态检查 | 通过 | 53 个唯一管脚，七个源文件存在，SDC 存在 |
| `tb_clk_divider` | 通过 | 使用真实 50MHz 默认参数，连续运行 100,000,000 个主时钟周期；逐周期检查，恰好 2 次秒节拍、2000 次毫秒节拍，复位后重新计时 |
| `tb_time_alarm_chime` | 通过 | 穷举一天 86,400 次秒进位并核对独立 BCD 期望值；手动时/分回绕；校时暂停；自然整点同拍触发；暂停走时后提示仍按主时钟到期；闹钟设置回绕、编辑静音、匹配整分钟及关闭使能 |
| `tb_buzzer` | 通过 | 默认 50MHz 时钟，每 12,500 周期翻转一次，得到 2kHz；有源/无源与正反极性的四种组合；停止、复位和重启相位 |
| `tb_top` | 通过 | 实际按键输入经过双级同步和 20ms 消抖；抖动过滤、有效短按、长按不重复、单周期脉冲；时间/闹钟编辑与显示；编辑闹钟时走时继续；SW0 停响；整点与闹钟同拍开始及无缝重叠；整点期间关闭闹钟仍保留整点声音 |
| 文本检查 | 通过 | `git diff --check`，新增源码及脚本行尾检查 |

时间、闹钟和顶层测试使用缩短的分频参数加速仿真，没有强制或直接改写 DUT 内部时间、计数器或按键脉冲。整点持续时间在模块测试中使用 `CLK_HZ=1000` 验证精确 2000 个周期，在顶层用 `CLK_HZ=20000` 验证整点与闹钟的重叠行为。默认硬件时长为 50,000,000 × 2 个周期，即 2 秒。

本次分组运行命令：

```powershell
python simulation/run.py --bench tb_time_alarm_chime --bench tb_buzzer --bench tb_top
python simulation/run.py --bench tb_clk_divider
python simulation/run.py --bench tb_top
```

最后一次顶层测试包含新增的“整点期间关闭 SW0 不影响整点声音”检查。其余 RTL 在各轮测试间未改变。完整重跑用 `python simulation/run.py`；分组运行的 `results.json` 只记录该次所选测试，各测试的日志分别保留在 `simulation/build/`。

## 尚未完成

验证环境没有可用的 Quartus 安装，因此未执行 Quartus 综合、布局布线或 TimeQuest 时序分析，也没有生成 `.sof`。当前 QSF/SDC 已完成静态检查，仍需在支持该芯片的 Quartus Lite/Standard 环境中完成完整编译和内部寄存器时序检查。

没有连接 DE1-SoC 实板或蜂鸣器，尚未验证物理接线、实际模块触发极性、音量及晶振实测精度。HDL 仿真通过不等于已经完成实板验证。编译下载与上板核查步骤见根目录 README。
