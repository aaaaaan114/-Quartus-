# 架构与文件用途

## 功能与数据流

工程实现 24 小时 BCD 数字时钟、可编辑闹钟及整点蜂鸣提示。FPGA 的唯一工作时钟为板载 `CLOCK_50`；`tick_1hz` 和 `tick_1khz` 是主时钟域内的使能信号，不连接任何模块的时钟输入。

1. 顶层对 `KEY[0]` 的复位释放做双级同步，对拨码做双级同步；两个操作按键分别进入 `debounce`。
2. `clk_divider` 提供走时及按键采样使能；`debounce` 将按键转换成单周期事件，顶层将事件路由到当前编辑目标。
3. `time_counter` 维护当前时间；`alarm_ctrl` 保存闹钟时间。两者独立，编辑闹钟不暂停当前走时。
4. 当前时间的自然整点事件进入 `hourly_chime`；报时使能与闹钟匹配使能进行逻辑或，交给 `buzzer_driver`。
5. 顶层在当前时间与闹钟设定值之间选择显示内容，译码后输出到六位共阳极数码管，同时保留三盏状态 LED。

## RTL：实际运行在 FPGA 上的代码

| 文件 / 模块 | 输入、输出与职责 | 关键行为 |
| --- | --- | --- |
| [`rtl/digital_clock_top.v`](../rtl/digital_clock_top.v) / `digital_clock_top` | 板级入口。输入 `CLOCK_50`、`KEY[3:0]`、`SW[1:0]`；输出 `HEX0` 至 `HEX5`、`LEDR[2:0]` 和 `BUZZER`。实例化其余六个模块，管理复位、设置模式、事件路由及显示选择 | `KEY[1]` 在正常、设时、设分之间切换；`KEY[2]` 递增。编辑闹钟时显示闹钟的时分及 `00` 秒；同时按模式键与递增键时优先切换模式。`KEY[3]` 保留 |
| [`rtl/clk_divider.v`](../rtl/clk_divider.v) / `clk_divider` | 输入主时钟和复位；输出 `tick_1hz`、`tick_1khz`。按 `CLK_HZ` 计数产生两种使能 | 默认每 50,000,000 周期走一秒、每 50,000 周期采样一次按键；没有内部派生时钟，修正原来的 2Hz 秒节拍 |
| [`rtl/debounce.v`](../rtl/debounce.v) / `debounce` | 输入原始按键、主时钟、复位和毫秒采样使能；输出 `key_pulse` | 先双级同步，再按毫秒采样稳定状态；按下、释放都经消抖。按下只产生一个主时钟周期事件，长按不自动重复，避免低速模块漏采样 |
| [`rtl/time_counter.v`](../rtl/time_counter.v) / `time_counter` | 输入秒使能、校时模式和时/分递增事件；输出 8 位 BCD `hour`、`min`、`sec` 及 `hour_rollover` | 正常走时按 60 秒、60 分、24 小时回绕。校时期间保留秒值并暂停走时，递增事件不等待秒节拍；只有自然经过 `xx:59:59` 的同一时钟沿触发整点事件 |
| [`rtl/alarm_ctrl.v`](../rtl/alarm_ctrl.v) / `alarm_ctrl` | 输入设置模式、闹钟递增事件、使能和当前时分；输出设定的 `alarm_hour`、`alarm_min` 及 `alarm_trig` | 设定值供顶层显示。正常模式下，时分匹配且使能开启时持续触发，下一分钟结束；任何编辑状态均抑制触发，关闭 `SW[0]` 停止闹钟 |
| [`rtl/hourly_chime.v`](../rtl/hourly_chime.v) / `hourly_chime` | 输入自然整点事件；输出 `chime_en`。按 `CLK_HZ * CHIME_SECONDS` 个主时钟周期计时 | 默认持续精确 2 秒。复位或手动设成整点不触发；已触发后，即使暂停当前走时，也会按实际主时钟到期 |
| [`rtl/buzzer_driver.v`](../rtl/buzzer_driver.v) / `buzzer_driver` | 输入声音使能、主时钟和复位；输出蜂鸣器控制信号 | `ACTIVE_BUZZER=1` 输出响停电平，`0` 输出音频方波；`BUZZER_ACTIVE_LOW` 选择触发极性。无源默认 2kHz；空闲及复位时输出对应极性的关闭电平 |

## 仿真：只在电脑上运行的代码

| 文件 | 用途及覆盖内容 |
| --- | --- |
| [`simulation/run.py`](../simulation/run.py) | 无第三方 Python 依赖的测试入口。检查 53 个引脚唯一且完整、源文件与 SDC 存在；先以 Verilog-2005 编译 RTL，再以 SystemVerilog 编译并运行测试。可用 `--bench` 选择测试，或 `IVERILOG_BIN` 指定仿真器位置；输出日志及该次运行结果到 `simulation/build/` |
| [`simulation/tb_clk_divider.sv`](../simulation/tb_clk_divider.sv) | 使用真实 50MHz 默认参数，连续模拟 100,000,000 个主时钟周期，逐周期核对秒、毫秒使能及总次数，检查复位后重新计时 |
| [`simulation/tb_time_alarm_chime.sv`](../simulation/tb_time_alarm_chime.sv) | 将外部秒使能加速，穷举 86,400 秒并与独立 BCD 期望值比较；验证午夜进位、手动和闹钟设置回绕、暂停、整点同拍触发、精确持续时间以及闹钟匹配和关闭 |
| [`simulation/tb_buzzer.sv`](../simulation/tb_buzzer.sv) | 并行实例化有源/无源、正/反极性四种驱动，验证默认 50MHz 下每 12,500 周期翻转得到 2kHz；检查停响、复位和再次启动时的相位 |
| [`simulation/tb_top.sv`](../simulation/tb_top.sv) | 从顶层按键及拨码输入进行端到端验证，使用较短的逻辑秒加速。覆盖复位同步、抖动、有效短按、长按不重复、单周期事件、两种设置目标与显示、走时暂停/继续、闹钟使能及整点与闹钟重叠时连续发声 |

测试不强制改写 DUT 内部寄存器、时间或按键事件。RTL 与测试源码分开列出，Quartus 工程只编译 `rtl/`。

## 工程配置与文档

| 文件 | 用途 |
| --- | --- |
| [`digital_clock.qpf`](../digital_clock.qpf) | Quartus 工程入口，指定 `digital_clock` 工程版本 |
| [`digital_clock.qsf`](../digital_clock.qsf) | 指定 Cyclone V 芯片、顶层、七个 RTL 文件、输出目录、蜂鸣器参数、53 个引脚位置及 3.3V I/O 标准；蜂鸣器默认分配到 `GPIO_0[0] / PIN_AC18` |
| [`digital_clock.sdc`](../digital_clock.sdc) | 创建周期 20ns 的唯一主时钟，计算时钟不确定性；排除异步外部输入和无外部采样时钟的显示/声音输出，内部寄存器路径仍需满足时序 |
| [`.gitignore`](../.gitignore) | 排除 Quartus 数据库与输出、仿真构建结果、波形和交付压缩包，防止机器生成的文件进入源码提交 |
| [`README.md`](../README.md) | 工程编译、下载、按键操作、蜂鸣器接线及参数、仿真与实板核查的使用入口 |
| [`docs/verification.md`](verification.md) | 已执行的检查、仿真参数与结果，以及尚未完成的 Quartus 和实板验证 |
| `docs/architecture.md` | 当前这份逐文件说明，解释模块接口、协作方式及原始代码的迁移关系 |

## 原始代码归档

以下六个文件保持原始内容，仅从仓库根目录移动到 `reference/`，供审查时对比；它们没有列入 QSF，也没有列入仿真源文件。

| 原始文件 | 原用途及现在的对应实现 |
| --- | --- |
| `reference/分频模块` | 原 1kHz 时钟和标称 1Hz 脉冲发生器；对应 `rtl/clk_divider.v`，改为单一主时钟下的两个使能信号 |
| `reference/按键消抖模块` | 原 1kHz 时钟下的按键消抖；对应 `rtl/debounce.v`，在主时钟域输出单周期事件 |
| `reference/计时核心` | 原 BCD 时分秒计数与校时；对应 `rtl/time_counter.v`，修正按键事件采样并提供自然整点事件 |
| `reference/闹钟模块` | 原闹钟时间寄存器及匹配判断；对应 `rtl/alarm_ctrl.v`，增加设定值输出用于显示 |
| `reference/整点报时` | 原基于当前分秒判断的 LED 报时控制；对应 `rtl/hourly_chime.v`，改为自然整点事件驱动的定长提示 |
| `reference/顶层模块` | 原模块连接、按键模式和数码管译码；对应 `rtl/digital_clock_top.v`，增加同步、闹钟显示和蜂鸣器接线；声音波形单独由新增的 `rtl/buzzer_driver.v` 负责 |
