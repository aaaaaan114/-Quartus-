# DE1-SoC 数字时钟与蜂鸣闹钟

针对 Terasic DE1-SoC、Cyclone V `5CSEMA5F31C6`，使用板载 50MHz 时钟、六位共阳极数码管和外接蜂鸣器。无需 ARM/HPS 软件或音频 CODEC。

## 打开、编译与下载

1. 使用安装了 Cyclone V 器件支持的 Quartus Prime Lite/Standard，打开根目录 `digital_clock.qpf`。
2. 确认顶层为 `digital_clock_top`、器件为 `5CSEMA5F31C6`。工程已包含本板所用的全部 53 个引脚分配和 20ns 时钟约束。
3. 根据蜂鸣器类型调整 `digital_clock.qsf` 中的参数，然后执行 **Start Compilation**。成功后文件为 `output_files/digital_clock.sof`。
4. 在 Programmer 选择板载 USB-Blaster II，Auto Detect 后将 `.sof` 关联到 FPGA 器件，勾选 Program/Configure 并下载。
5. 将 `SW[0]` 关闭，按一下用户按键 `KEY[0]`，应显示 `00:00:00`，之后每秒加一。

也可以在已配置 Quartus 命令行的 PowerShell 中编译：

```powershell
quartus_sh --flow compile digital_clock
```

首次验证建议把工程放在只含英文和数字的路径，例如 `E:\fpga\digital_clock`，避免较旧 Quartus 对中文路径的兼容问题。当前工作目录中的工程内容可整体复制过去。

JTAG 下载 `.sof` 后断电会丢失配置。需要上电自动运行时，应在确认板卡硬件版本、配置存储器型号与 MSEL 设置后，按对应手册完成非易失配置；本工程不自动修改配置存储器。

## 按键、开关和显示

| 控件 | 功能 |
| --- | --- |
| `KEY[0]` | 低电平复位：当前时间、闹钟时间和模式归零；按住时静音 |
| `KEY[1]` | 正常 → 设置小时 → 设置分钟 → 正常 |
| `KEY[2]` | 当前设置项加一；长按只加一次，松开后才能再次递增 |
| `KEY[3]` | 保留 |
| `SW[0]` | 闹钟使能：上拨开启，下拨关闭 |
| `SW[1]` | 编辑目标：下拨设置当前时间，上拨设置闹钟 |
| `LEDR[0]` | 整点提示，持续 2 秒 |
| `LEDR[1]` | 当前时、分与闹钟匹配，且闹钟开启、处于正常模式 |
| `LEDR[2]` | 闹钟使能状态 |

六位从左到右显示 `HH MM SS`。正常模式始终显示当前时间；编辑闹钟时显示闹钟的时、分，秒位为 `00`。编辑当前时间时暂停走时并保留秒值；编辑闹钟时当前时间继续运行。

按键使用 20ms 消抖，短于该时间的按压会被滤除。同时按下模式键和递增键时，模式切换优先。复位使用的是四个 FPGA 用户按键中的 `KEY[0]`，不是旁边的 HPS_RESET/WARM_RESET。

设置当前时间的例子：`SW[1]=0`，按 `KEY[1]` 进入小时编辑，用 `KEY[2]` 调整；再按 `KEY[1]` 进入分钟编辑并调整；最后按 `KEY[1]` 返回正常。

设置闹钟的步骤相同，只需先把 `SW[1]` 拨到 1。编辑完成后，开启 `SW[0]`。所有编辑状态均暂时抑制闹钟响铃。

## 蜂鸣器接线和参数

DE1-SoC 板上没有蜂鸣器。本工程的 `BUZZER` 输出使用：

| 信号 | 位置 / 要求 |
| --- | --- |
| 模块 IN / SIG | `GPIO_0[0]`，FPGA 管脚 `PIN_AC18` |
| 模块 GND | 与开发板 GND 共地 |
| 模块 VCC | 按模块规格供电，使用兼容 3.3V 控制信号且带驱动电路的模块 |

`PIN_AC18` 是 FPGA 管脚名称，不是排针脚号。连接时依据板卡丝印和原理图定位 `GPIO_0[0]`；GPIO 只连接模块控制输入，裸蜂鸣器需要另加驱动电路。

在 `digital_clock.qsf` 中修改后重新编译：

```tcl
set_parameter -name ACTIVE_BUZZER 0
set_parameter -name BUZZER_ACTIVE_LOW 0
set_parameter -name TONE_HZ 2000
```

| 参数 | 值与含义 |
| --- | --- |
| `ACTIVE_BUZZER` | `0` 无源：输出方波；`1` 有源：输出响停电平 |
| `BUZZER_ACTIVE_LOW` | `0` 模块高电平触发；`1` 模块低电平触发，空闲输出高 |
| `TONE_HZ` | 无源模式音调，默认 2000Hz；有源模式的声音频率由模块自身决定 |
| `CLK_HZ` | 默认 50000000，与实际板载时钟一致 |
| `DEBOUNCE_MS` | 默认 20，按键消抖的毫秒采样数 |

时钟频率须为不小于 1000 的 1000 整数倍；消抖时间须至少为 1；音调须大于 0 且不超过时钟频率的一半。无源实际频率为 `CLK_HZ / (2 * floor(CLK_HZ / (2 * TONE_HZ)))`，默认参数恰好为 2kHz。

自然走时经过 `xx:59:59 → 下一小时:00:00` 时连续响 2 秒。复位和手动校时不会触发整点提示，时间在 `xx:00:00` 暂停也不会重复触发。已开始的整点提示按实际主时钟计满 2 秒，之后停止。

闹钟在正常模式、开启且时分匹配时持续响，到下一分钟停止。`SW[0]` 只控制闹钟，不关闭整点报时；两者重叠时连续发声。匹配分钟内关闭再开启 `SW[0]` 会恢复响铃。复位后闹钟时间为 `00:00`，因此若保持 `SW[0]=1`，复位释放后会因时间匹配而响铃。

## 仿真

安装 Icarus Verilog，并让 `iverilog`、`vvp` 位于 PATH；需要 Python 3.9 或更新版本，无第三方 Python 依赖。

```powershell
python simulation/run.py
```

如果仿真器没有加入 PATH，可以指定其目录：

```powershell
$env:IVERILOG_BIN = 'C:\iverilog\bin'
python simulation/run.py
```

测试包含：真实 50MHz 默认参数下连续 100,000,000 个周期的分频验证；完整 24 小时时间进位；手动设置和闹钟设置回绕；整点时机与精确持续时间；按键抖动、短按和长按；设置显示；闹钟匹配与停响；声音重叠；2kHz 输出与四种蜂鸣器类型/极性组合。测试结果保存在 `simulation/build/`。

只运行指定测试可使用 `python simulation/run.py --bench tb_top`。RTL 另外使用 Verilog-2005 模式编译检查，测试平台使用 SystemVerilog。

## 实板核查顺序

1. 暂不接蜂鸣器，下载后按 `KEY[0]`，核对六位显示，观察一分钟确认每秒走一次。
2. 用模式键、递增键检查小时和分钟编辑；确认调整闹钟时能看到设定值，当前时间仍在运行。
3. 接上匹配参数的蜂鸣器驱动模块；把闹钟设为当前分钟，返回正常模式并开启 `SW[0]`，检查发声和关闭开关停响。
4. 把当前时间设到 `xx:59`，等待自然走到下一整点，核对 `LEDR[0]` 与蜂鸣器同时提示 2 秒。手动调到 `xx:00` 本身不会报时。
5. 在 Quartus TimeQuest 检查 50MHz 内部寄存器路径的时序报告。SDC 只排除异步外部输入和没有外部采样时钟的显示/声音输出，内部同步器级间路径仍参与分析。

## 目录与来源

所有时序逻辑只使用主时钟。实际参与编译的代码如下：

| 代码文件 | 用途 |
| --- | --- |
| `rtl/digital_clock_top.v` | 顶层接线、复位释放同步、拨码同步、设置模式切换、显示选择与七段译码；将整点和闹钟声音合并 |
| `rtl/clk_divider.v` | 从主时钟产生单周期的 1Hz、1kHz 使能信号，分别用于走时和按键采样 |
| `rtl/debounce.v` | 同步低电平按键并做 20ms 消抖；每次按下仅输出一个主时钟周期的事件 |
| `rtl/time_counter.v` | 维护 BCD 时分秒、处理手动校时和 24 小时进位；仅自然跨整点时产生报时事件 |
| `rtl/alarm_ctrl.v` | 保存并输出可编辑的闹钟时、分；在正常模式且闹钟使能、时间匹配时触发 |
| `rtl/hourly_chime.v` | 将自然整点事件转换为精确持续 2 秒的提示使能，计时暂停也不延长或重复报时 |
| `rtl/buzzer_driver.v` | 将声音使能转换为有源蜂鸣器电平或无源蜂鸣器方波，支持触发极性配置 |

| 仿真文件 | 用途 |
| --- | --- |
| `simulation/run.py` | 检查工程引脚和源文件，编译 RTL，运行指定或全部测试并保存日志 |
| `simulation/tb_clk_divider.sv` | 在真实 50MHz 默认参数下逐周期检查两秒分频结果及复位行为 |
| `simulation/tb_time_alarm_chime.sv` | 检查完整一天的进位、手动设置、闹钟匹配及整点触发与持续时间 |
| `simulation/tb_buzzer.sv` | 检查 2kHz 音调、有源/无源和正反极性的四种组合，以及复位与重启 |
| `simulation/tb_top.sv` | 通过真实按键、拨码输入验证操作、显示、停响及整点与闹钟的重叠行为 |

`digital_clock.qpf` 是工程入口；`digital_clock.qsf` 列出器件、源文件、参数和引脚；`digital_clock.sdc` 定义主时钟及外部异步接口的时序约束。

逐文件接口、模块间数据流以及六份原始代码与新模块的对应关系见 [架构与文件用途](docs/architecture.md)。原始源码保存在 `reference/`，不参与编译；实际验证结果和未完成事项见 [验证记录](docs/verification.md)。

原始代码来自 [aaaaaan114/-Quartus-](https://github.com/aaaaaan114/-Quartus-/tree/bb36d8302d5bdbfe5008560608519b5b8cebb24c)。引脚依据《DE1-SoC User Manual》，2015-08-05 版本，手册页码 22、25-28（表 3-5 至表 3-11）。
