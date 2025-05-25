-- PCF8575 使用示例
-- 这个示例展示了PCF8575库的基本用法
-- 传输到设备时需要去除中文

-- 导入PCF8575库
local pcf8575 = require("pcf8575")

-- 配置参数
local I2C_ID = 0     -- I2C总线ID
local SDA_PIN = 2    -- SDA引脚 (D2)
local SCL_PIN = 1    -- SCL引脚 (D1)

-- 初始化PCF8575设备
print("正在初始化PCF8575...")
local device = pcf8575.setup(I2C_ID, SDA_PIN, SCL_PIN, 0, 0, 0)  -- A2=A1=A0=0

if not device then
    print("错误: PCF8575初始化失败!")
    print("请检查:")
    print("1. 硬件连接是否正确")
    print("2. I2C上拉电阻是否已连接")
    print("3. PCF8575电源是否正常")
    return
end

print("PCF8575初始化成功!")

-- 显示设备信息
local info = pcf8575.get_device_info(device)
if info then
    print("设备信息:")
    print("  I2C地址: " .. info.address_hex)
    print("  SDA引脚: D" .. info.sda)
    print("  SCL引脚: D" .. info.scl)
    print("  当前状态: " .. info.last_state_hex)
end

-- 示例1: 基本LED控制
print("\n=== 示例1: 基本LED控制 ===")

-- 全部点亮
print("点亮所有LED...")
pcf8575.write_all(device, 0xFFFF)
tmr.delay(1000000)  -- 延时1秒

-- 全部熄灭
print("熄灭所有LED...")
pcf8575.write_all(device, 0x0000)
tmr.delay(1000000)

-- 示例2: 单个引脚控制
print("\n=== 示例2: 单个引脚控制 ===")

-- 逐个点亮LED
for i = 0, 15 do
    print("点亮引脚 P" .. string.format("%02d", i))
    pcf8575.set_pin(device, i, 1)
    tmr.delay(200000)  -- 延时200ms
    pcf8575.set_pin(device, i, 0)
end

-- 示例3: 跑马灯效果
print("\n=== 示例3: 跑马灯效果 ===")

for round = 1, 3 do
    print("第" .. round .. "轮跑马灯")
    for i = 0, 15 do
        pcf8575.write_all(device, 2^i)
        tmr.delay(150000)  -- 延时150ms
    end
end

-- 示例4: 端口控制
print("\n=== 示例4: 端口控制 ===")

-- 控制P0端口（低8位）
print("控制P0端口...")
local p0_patterns = {0x01, 0x03, 0x07, 0x0F, 0x1F, 0x3F, 0x7F, 0xFF}
for _, pattern in ipairs(p0_patterns) do
    pcf8575.set_port0(device, pattern)
    pcf8575.set_port1(device, 0x00)  -- P1端口保持熄灭
    tmr.delay(300000)
end

-- 控制P1端口（高8位）
print("控制P1端口...")
local p1_patterns = {0x80, 0xC0, 0xE0, 0xF0, 0xF8, 0xFC, 0xFE, 0xFF}
for _, pattern in ipairs(p1_patterns) do
    pcf8575.set_port0(device, 0x00)  -- P0端口保持熄灭
    pcf8575.set_port1(device, pattern)
    tmr.delay(300000)
end

-- 示例5: 批量引脚控制
print("\n=== 示例5: 批量引脚控制 ===")

-- 同时控制多个引脚
local pin_configs = {
    {[0]=1, [2]=1, [4]=1, [6]=1, [8]=1, [10]=1, [12]=1, [14]=1},  -- 偶数引脚
    {[1]=1, [3]=1, [5]=1, [7]=1, [9]=1, [11]=1, [13]=1, [15]=1},  -- 奇数引脚
    {[0]=1, [1]=1, [14]=1, [15]=1},  -- 四角
    {[6]=1, [7]=1, [8]=1, [9]=1}     -- 中间
}

for i, config in ipairs(pin_configs) do
    print("批量控制模式 " .. i)
    pcf8575.write_all(device, 0x0000)  -- 先全部熄灭
    pcf8575.set_pins(device, config)
    tmr.delay(800000)
end

-- 示例6: 闪烁效果
print("\n=== 示例6: 闪烁效果 ===")

for i = 1, 5 do
    print("闪烁 " .. i .. "/5")
    pcf8575.write_all(device, 0xFFFF)  -- 全亮
    tmr.delay(300000)
    pcf8575.write_all(device, 0x0000)  -- 全灭
    tmr.delay(300000)
end

-- 示例7: 读取引脚状态
print("\n=== 示例7: 读取引脚状态 ===")

-- 设置一些引脚为高电平
pcf8575.set_pins(device, {[0]=1, [5]=1, [10]=1, [15]=1})

-- 读取所有引脚状态
local all_state = pcf8575.read_all(device)
if all_state then
    print("所有引脚状态: " .. string.format("0x%04X", all_state))
end

-- 读取单个引脚状态
for _, pin in ipairs({0, 5, 10, 15}) do
    local state = pcf8575.get_pin(device, pin)
    if state ~= nil then
        print("引脚P" .. string.format("%02d", pin) .. "状态: " .. state)
    end
end

-- 读取端口状态
local p0_state = pcf8575.get_port0(device)
local p1_state = pcf8575.get_port1(device)
if p0_state and p1_state then
    print("P0端口状态: " .. string.format("0x%02X", p0_state))
    print("P1端口状态: " .. string.format("0x%02X", p1_state))
end

-- 示例8: 引脚切换
print("\n=== 示例8: 引脚切换 ===")

-- 设置初始状态
pcf8575.write_all(device, 0x0000)

-- 切换几个引脚的状态
local toggle_pins = {0, 3, 7, 12, 15}
for round = 1, 3 do
    print("切换轮次 " .. round)
    for _, pin in ipairs(toggle_pins) do
        pcf8575.toggle_pin(device, pin)
        tmr.delay(200000)
    end
end

-- 最后清理
print("\n=== 示例完成 ===")
pcf8575.write_all(device, 0x0000)  -- 熄灭所有LED
print("所有LED已熄灭")
print("示例程序执行完毕!")

-- 显示最终设备信息
local final_info = pcf8575.get_device_info(device)
if final_info then
    print("\n最终设备状态: " .. final_info.last_state_hex)
end
