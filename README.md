# PCF8575 NodeMCU Lua库使用文档

## 概述

PCF8575是一个16位I2C I/O扩展器，通过I2C接口为微控制器提供额外的GPIO引脚。本库为NodeMCU提供了完整的PCF8575控制功能，支持同时控制多个PCF8575设备。

## 特性

- 支持多个PCF8575设备同时工作
- 16位I/O控制（P00-P07, P10-P17）
- 单个引脚控制和读取
- 批量引脚控制
- 端口级别控制（P0端口和P1端口）
- 设备管理功能
- 完整的错误处理

## 硬件连接

### PCF8575引脚说明

| 引脚 | 功能 | 描述 |
|------|------|------|
| VCC | 电源 | 3.3V或5V |
| GND | 地线 | 接地 |
| SDA | 数据线 | I2C数据线，需要上拉电阻 |
| SCL | 时钟线 | I2C时钟线，需要上拉电阻 |
| A0-A2 | 地址选择 | 用于设置I2C地址 |
| P00-P07 | I/O端口0 | 8位I/O引脚 |
| P10-P17 | I/O端口1 | 8位I/O引脚 |

### 连接示例

```
NodeMCU    PCF8575
  3.3V  ->  VCC
  GND   ->  GND
  D1    ->  SCL (需要4.7kΩ上拉电阻到VCC)
  D2    ->  SDA (需要4.7kΩ上拉电阻到VCC)
         ->  A0, A1, A2 (根据需要接GND或VCC设置地址)
```

## I2C地址配置

PCF8575的I2C地址由A2、A1、A0引脚状态决定：

| A2 | A1 | A0 | 写地址(十六进制) | 读地址(十六进制) |
|----|----|----|------------------|------------------|
| 0  | 0  | 0  | 0x40             | 0x41             |
| 0  | 0  | 1  | 0x42             | 0x43             |
| 0  | 1  | 0  | 0x44             | 0x45             |
| 0  | 1  | 1  | 0x46             | 0x47             |
| 1  | 0  | 0  | 0x48             | 0x49             |
| 1  | 0  | 1  | 0x4A             | 0x4B             |
| 1  | 1  | 0  | 0x4C             | 0x4D             |
| 1  | 1  | 1  | 0x4E             | 0x4F             |

## 库的使用

### 1. 导入库

```lua
local pcf8575 = require("pcf8575")
```

### 2. 初始化设备

```lua
-- 基本初始化（A2=A1=A0=0）
local device1 = pcf8575.setup(0, 2, 1)  -- I2C ID=0, SDA=D2, SCL=D1

-- 指定地址引脚状态
local device2 = pcf8575.setup(0, 2, 1, 0, 0, 1)  -- A2=0, A1=0, A0=1

-- 指定I2C速度
local device3 = pcf8575.setup(0, 2, 1, 0, 1, 0, i2c.FAST)  -- 快速模式

if device1 then
    print("设备1初始化成功")
else
    print("设备1初始化失败")
end
```

### 3. 批量控制所有引脚

```lua
-- 写入16位数据（所有引脚）
pcf8575.write_all(device1, 0xFFFF)  -- 所有引脚设为高电平
pcf8575.write_all(device1, 0x0000)  -- 所有引脚设为低电平
pcf8575.write_all(device1, 0xAAAA)  -- 交替高低电平

-- 读取16位数据（所有引脚状态）
local all_pins = pcf8575.read_all(device1)
if all_pins then
    print(string.format("所有引脚状态: 0x%04X", all_pins))
end
```

### 4. 单个引脚控制

```lua
-- 设置单个引脚
pcf8575.set_pin(device1, 0, 1)   -- 设置P00为高电平
pcf8575.set_pin(device1, 15, 0)  -- 设置P17为低电平

-- 读取单个引脚
local pin_state = pcf8575.get_pin(device1, 0)
if pin_state ~= nil then
    print("P00状态: " .. pin_state)
end

-- 切换引脚状态
pcf8575.toggle_pin(device1, 5)  -- 切换P05状态
```

### 5. 批量引脚控制

```lua
-- 同时设置多个引脚
local pin_config = {
    [0] = 1,   -- P00 = 高电平
    [1] = 0,   -- P01 = 低电平
    [5] = 1,   -- P05 = 高电平
    [10] = 0   -- P12 = 低电平
}
pcf8575.set_pins(device1, pin_config)
```

### 6. 端口级别控制

```lua
-- 控制P0端口（P00-P07）
pcf8575.set_port0(device1, 0xFF)  -- P0端口所有引脚设为高电平
pcf8575.set_port0(device1, 0x0F)  -- P00-P03高电平，P04-P07低电平

-- 控制P1端口（P10-P17）
pcf8575.set_port1(device1, 0xAA)  -- P1端口交替高低电平

-- 读取端口状态
local p0_state = pcf8575.get_port0(device1)
local p1_state = pcf8575.get_port1(device1)
print(string.format("P0端口: 0x%02X, P1端口: 0x%02X", p0_state, p1_state))
```

### 7. 设备管理

```lua
-- 获取设备信息
local info = pcf8575.get_device_info(device1)
if info then
    print("设备地址: " .. info.address_hex)
    print("当前状态: " .. info.last_state_hex)
end

-- 列出所有设备
local devices = pcf8575.list_devices()
for i, device in ipairs(devices) do
    print("设备" .. i .. ": " .. device)
end

-- 移除设备
pcf8575.remove_device(device1)
```

### 8. 工具函数

```lua
-- 引脚号转换为端口和位
local port, bit = pcf8575.pin_to_port_bit(10)  -- 返回 port=1, bit=2

-- 创建位掩码
local mask = pcf8575.create_mask({0, 2, 5, 8})  -- 为引脚0,2,5,8创建掩码
```

## 完整示例

### LED控制示例

```lua
local pcf8575 = require("pcf8575")

-- 初始化PCF8575
local device = pcf8575.setup(0, 2, 1)  -- I2C0, SDA=D2, SCL=D1

if not device then
    print("PCF8575初始化失败")
    return
end

print("PCF8575初始化成功")

-- LED跑马灯效果
local function led_chase()
    for i = 0, 15 do
        pcf8575.write_all(device, 2^i)  -- 只点亮一个LED
        tmr.delay(200000)  -- 延时200ms
    end
end

-- 执行跑马灯
led_chase()

-- 闪烁所有LED
for i = 1, 5 do
    pcf8575.write_all(device, 0xFFFF)  -- 全亮
    tmr.delay(500000)
    pcf8575.write_all(device, 0x0000)  -- 全灭
    tmr.delay(500000)
end
```

### 按键输入示例

```lua
local pcf8575 = require("pcf8575")

-- 初始化PCF8575
local device = pcf8575.setup(0, 2, 1)

if not device then
    print("PCF8575初始化失败")
    return
end

-- 设置P0端口为输出（LED），P1端口为输入（按键）
pcf8575.set_port0(device, 0x00)  -- LED全灭
pcf8575.set_port1(device, 0xFF)  -- 输入引脚设为高电平（启用内部上拉）

-- 按键扫描函数
local function scan_keys()
    local keys = pcf8575.get_port1(device)
    if keys then
        -- 检查每个按键（低电平有效）
        for i = 0, 7 do
            local key_pressed = (math.floor(keys / (2^i)) % 2) == 0
            if key_pressed then
                print("按键 " .. i .. " 被按下")
                -- 点亮对应的LED
                pcf8575.set_pin(device, i, 1)
            else
                -- 熄灭对应的LED
                pcf8575.set_pin(device, i, 0)
            end
        end
    end
end

-- 定时扫描按键
local timer = tmr.create()
timer:register(100, tmr.ALARM_AUTO, scan_keys)
timer:start()
```

### 多设备控制示例

```lua
local pcf8575 = require("pcf8575")

-- 初始化多个PCF8575设备
local device1 = pcf8575.setup(0, 2, 1, 0, 0, 0)  -- 地址0x40
local device2 = pcf8575.setup(0, 2, 1, 0, 0, 1)  -- 地址0x42
local device3 = pcf8575.setup(0, 2, 1, 0, 1, 0)  -- 地址0x44

local devices = {device1, device2, device3}

-- 检查设备初始化状态
for i, dev in ipairs(devices) do
    if dev then
        print("设备" .. i .. "初始化成功")
    else
        print("设备" .. i .. "初始化失败")
    end
end

-- 同步控制所有设备
local function sync_all_devices(pattern)
    for _, dev in ipairs(devices) do
        if dev then
            pcf8575.write_all(dev, pattern)
        end
    end
end

-- 创建流水灯效果
local patterns = {0x0001, 0x0002, 0x0004, 0x0008, 0x0010, 0x0020, 0x0040, 0x0080}

for _, pattern in ipairs(patterns) do
    sync_all_devices(pattern)
    tmr.delay(200000)
end
```

## 错误处理

库中的所有函数都包含错误处理机制：

- 初始化失败时返回`nil`
- 读取操作失败时返回`nil`
- 写入操作失败时返回`false`
- 成功操作返回相应的数据或`true`

建议在使用时始终检查返回值：

```lua
local result = pcf8575.set_pin(device, 5, 1)
if not result then
    print("设置引脚失败")
end

local pin_state = pcf8575.get_pin(device, 5)
if pin_state == nil then
    print("读取引脚失败")
else
    print("引脚状态: " .. pin_state)
end
```

## 注意事项

1. **上拉电阻**: SDA和SCL线路必须连接4.7kΩ上拉电阻到VCC
2. **电源电压**: 确保PCF8575的VCC电压与NodeMCU兼容
3. **I2C地址**: 确保每个PCF8575设备有唯一的I2C地址
4. **引脚编号**: 引脚编号范围为0-15（P00-P07为0-7，P10-P17为8-15）
5. **默认状态**: PCF8575上电时所有引脚默认为高电平
6. **准双向I/O**: PCF8575的引脚为准双向，可以直接用作输入或输出

## API参考

### 初始化函数

- `pcf8575.setup(id, sda, scl, a2, a1, a0, speed)` - 初始化PCF8575设备

### 批量控制函数

- `pcf8575.write_all(device_handle, data)` - 写入16位数据
- `pcf8575.read_all(device_handle)` - 读取16位数据

### 单引脚控制函数

- `pcf8575.set_pin(device_handle, pin, state)` - 设置单个引脚
- `pcf8575.get_pin(device_handle, pin)` - 读取单个引脚
- `pcf8575.toggle_pin(device_handle, pin)` - 切换引脚状态

### 多引脚控制函数

- `pcf8575.set_pins(device_handle, pin_states)` - 批量设置引脚

### 端口控制函数

- `pcf8575.set_port0(device_handle, data)` - 设置P0端口
- `pcf8575.set_port1(device_handle, data)` - 设置P1端口
- `pcf8575.get_port0(device_handle)` - 读取P0端口
- `pcf8575.get_port1(device_handle)` - 读取P1端口

### 设备管理函数

- `pcf8575.get_device_info(device_handle)` - 获取设备信息
- `pcf8575.list_devices()` - 列出所有设备
- `pcf8575.remove_device(device_handle)` - 移除设备

### 工具函数

- `pcf8575.pin_to_port_bit(pin)` - 引脚号转换
- `pcf8575.create_mask(pins)` - 创建位掩码

## 版本历史

- v1.0 - 初始版本，包含所有基本功能
