-- PCF8575 I2C I/O Expander Library for NodeMCU
-- Author: AI Assistant
-- Version: 1.0
-- Description: A comprehensive library for controlling PCF8575 16-bit I2C I/O expander

local pcf8575 = {}

-- PCF8575 default I2C addresses (7-bit addressing)
pcf8575.ADDR_BASE = 0x20  -- Base address when A2=A1=A0=0

-- Internal storage for multiple PCF8575 instances
local devices = {}

-- Helper function to calculate I2C address based on A2, A1, A0 pins
-- @param a2: A2 pin state (0 or 1)
-- @param a1: A1 pin state (0 or 1) 
-- @param a0: A0 pin state (0 or 1)
-- @return: 7-bit I2C address
local function calculate_address(a2, a1, a0)
    return pcf8575.ADDR_BASE + (a2 * 4) + (a1 * 2) + a0
end

-- Initialize PCF8575 device
-- @param id: I2C bus ID (0 or 1)
-- @param sda: SDA pin number
-- @param scl: SCL pin number
-- @param a2: A2 pin state (0 or 1, default 0)
-- @param a1: A1 pin state (0 or 1, default 0)
-- @param a0: A0 pin state (0 or 1, default 0)
-- @param speed: I2C speed (default i2c.SLOW)
-- @return: device handle or nil on error
function pcf8575.setup(id, sda, scl, a2, a1, a0, speed)
    a2 = a2 or 0
    a1 = a1 or 0
    a0 = a0 or 0
    speed = speed or i2c.SLOW
    
    local addr = calculate_address(a2, a1, a0)
    local device_key = string.format("%d_%02X", id, addr)
    
    -- Initialize I2C bus
    i2c.setup(id, sda, scl, speed)
    
    -- Create device instance
    local device = {
        id = id,
        address = addr,
        sda = sda,
        scl = scl,
        speed = speed,
        last_state = 0xFFFF  -- All pins high by default
    }
    
    -- Test device communication
    i2c.start(id)
    if i2c.address(id, addr, i2c.RECEIVER) then
        local data = i2c.read(id, 2)
        i2c.stop(id)
        
        if data and #data == 2 then
            device.last_state = string.byte(data, 1) + (string.byte(data, 2) * 256)
            devices[device_key] = device
            return device_key
        end
    else
        i2c.stop(id)
    end
    
    return nil
end

-- Write 16-bit data to PCF8575
-- @param device_handle: device handle returned by setup()
-- @param data: 16-bit data to write (0x0000 - 0xFFFF)
-- @return: true on success, false on error
function pcf8575.write_all(device_handle, data)
    local device = devices[device_handle]
    if not device then
        return false
    end
    
    local low_byte = data % 256
    local high_byte = math.floor(data / 256) % 256
    
    i2c.start(device.id)
    local success = i2c.address(device.id, device.address, i2c.TRANSMITTER)
    if success then
        success = i2c.write(device.id, low_byte, high_byte)
        if success then
            device.last_state = data
        end
    end
    i2c.stop(device.id)
    
    return success
end

-- Read 16-bit data from PCF8575
-- @param device_handle: device handle returned by setup()
-- @return: 16-bit data or nil on error
function pcf8575.read_all(device_handle)
    local device = devices[device_handle]
    if not device then
        return nil
    end
    
    i2c.start(device.id)
    local success = i2c.address(device.id, device.address, i2c.RECEIVER)
    if success then
        local data = i2c.read(device.id, 2)
        i2c.stop(device.id)
        
        if data and #data == 2 then
            local result = string.byte(data, 1) + (string.byte(data, 2) * 256)
            device.last_state = result
            return result
        end
    else
        i2c.stop(device.id)
    end
    
    return nil
end

-- Set specific pin state
-- @param device_handle: device handle returned by setup()
-- @param pin: pin number (0-15)
-- @param state: pin state (0 or 1)
-- @return: true on success, false on error
function pcf8575.set_pin(device_handle, pin, state)
    local device = devices[device_handle]
    if not device or pin < 0 or pin > 15 then
        return false
    end
    
    local current_state = device.last_state
    
    if state == 0 then
        -- Clear bit: remove the bit at position 'pin'
        local bit_value = 2^pin
        if math.floor(current_state / bit_value) % 2 == 1 then
            current_state = current_state - bit_value
        end
    else
        -- Set bit: add the bit at position 'pin'
        local bit_value = 2^pin
        if math.floor(current_state / bit_value) % 2 == 0 then
            current_state = current_state + bit_value
        end
    end
    
    return pcf8575.write_all(device_handle, current_state)
end

-- Get specific pin state
-- @param device_handle: device handle returned by setup()
-- @param pin: pin number (0-15)
-- @return: pin state (0 or 1) or nil on error
function pcf8575.get_pin(device_handle, pin)
    if pin < 0 or pin > 15 then
        return nil
    end
    
    local data = pcf8575.read_all(device_handle)
    if data then
        return math.floor(data / (2^pin)) % 2
    end
    
    return nil
end

-- Set multiple pins at once using a table
-- @param device_handle: device handle returned by setup()
-- @param pin_states: table with pin numbers as keys and states as values
--                   example: {[0]=1, [1]=0, [5]=1}
-- @return: true on success, false on error
function pcf8575.set_pins(device_handle, pin_states)
    local device = devices[device_handle]
    if not device then
        return false
    end
    
    local current_state = device.last_state
    
    for pin, state in pairs(pin_states) do
        if pin >= 0 and pin <= 15 then
            if state == 0 then
                -- Clear bit: remove the bit at position 'pin'
                local bit_value = 2^pin
                if math.floor(current_state / bit_value) % 2 == 1 then
                    current_state = current_state - bit_value
                end
            else
                -- Set bit: add the bit at position 'pin'
                local bit_value = 2^pin
                if math.floor(current_state / bit_value) % 2 == 0 then
                    current_state = current_state + bit_value
                end
            end
        end
    end
    
    return pcf8575.write_all(device_handle, current_state)
end

-- Set port P0 (pins 0-7)
-- @param device_handle: device handle returned by setup()
-- @param data: 8-bit data for P0 port
-- @return: true on success, false on error
function pcf8575.set_port0(device_handle, data)
    local device = devices[device_handle]
    if not device then
        return false
    end
    
    local current_state = device.last_state
    current_state = math.floor(current_state / 256) * 256 + (data % 256)
    
    return pcf8575.write_all(device_handle, current_state)
end

-- Set port P1 (pins 8-15)
-- @param device_handle: device handle returned by setup()
-- @param data: 8-bit data for P1 port
-- @return: true on success, false on error
function pcf8575.set_port1(device_handle, data)
    local device = devices[device_handle]
    if not device then
        return false
    end
    
    local current_state = device.last_state
    current_state = (current_state % 256) + ((data % 256) * 256)
    
    return pcf8575.write_all(device_handle, current_state)
end

-- Get port P0 (pins 0-7)
-- @param device_handle: device handle returned by setup()
-- @return: 8-bit data or nil on error
function pcf8575.get_port0(device_handle)
    local data = pcf8575.read_all(device_handle)
    if data then
        return data % 256
    end
    return nil
end

-- Get port P1 (pins 8-15)
-- @param device_handle: device handle returned by setup()
-- @return: 8-bit data or nil on error
function pcf8575.get_port1(device_handle)
    local data = pcf8575.read_all(device_handle)
    if data then
        return math.floor(data / 256) % 256
    end
    return nil
end

-- Toggle specific pin
-- @param device_handle: device handle returned by setup()
-- @param pin: pin number (0-15)
-- @return: true on success, false on error
function pcf8575.toggle_pin(device_handle, pin)
    local current_state = pcf8575.get_pin(device_handle, pin)
    if current_state ~= nil then
        return pcf8575.set_pin(device_handle, pin, 1 - current_state)
    end
    return false
end

-- Get device information
-- @param device_handle: device handle returned by setup()
-- @return: device info table or nil
function pcf8575.get_device_info(device_handle)
    local device = devices[device_handle]
    if device then
        return {
            id = device.id,
            address = device.address,
            address_hex = string.format("0x%02X", device.address),
            sda = device.sda,
            scl = device.scl,
            speed = device.speed,
            last_state = device.last_state,
            last_state_hex = string.format("0x%04X", device.last_state)
        }
    end
    return nil
end

-- List all initialized devices
-- @return: table of device handles
function pcf8575.list_devices()
    local device_list = {}
    for handle, _ in pairs(devices) do
        table.insert(device_list, handle)
    end
    return device_list
end

-- Remove device from internal storage
-- @param device_handle: device handle to remove
-- @return: true if removed, false if not found
function pcf8575.remove_device(device_handle)
    if devices[device_handle] then
        devices[device_handle] = nil
        return true
    end
    return false
end

-- Utility function to convert pin number to port and bit
-- @param pin: pin number (0-15)
-- @return: port (0 or 1), bit (0-7)
function pcf8575.pin_to_port_bit(pin)
    if pin < 0 or pin > 15 then
        return nil, nil
    end
    
    local port = pin < 8 and 0 or 1
    local bit = pin % 8
    return port, bit
end

-- Utility function to create bit mask
-- @param pins: table of pin numbers
-- @return: 16-bit mask
function pcf8575.create_mask(pins)
    local mask = 0
    for _, pin in ipairs(pins) do
        if pin >= 0 and pin <= 15 then
            mask = mask + (2^pin)
        end
    end
    return mask
end

return pcf8575
