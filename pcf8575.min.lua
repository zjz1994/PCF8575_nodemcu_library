local pcf8575 = {}
pcf8575.ADDR_BASE = 0x20
local devices = {}
local function calculate_address(a2, a1, a0)
    return pcf8575.ADDR_BASE + (a2 * 4) + (a1 * 2) + a0
end
function pcf8575.setup(id, sda, scl, a2, a1, a0, speed)
    a2 = a2 or 0
    a1 = a1 or 0
    a0 = a0 or 0
    speed = speed or i2c.SLOW
    local addr = calculate_address(a2, a1, a0)
    local device_key = string.format("%d_%02X", id, addr)
    i2c.setup(id, sda, scl, speed)
    local device = {
        id = id,
        address = addr,
        sda = sda,
        scl = scl,
        speed = speed,
        last_state = 0xFFFF
    }
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
function pcf8575.set_pin(device_handle, pin, state)
    local device = devices[device_handle]
    if not device or pin < 0 or pin > 15 then
        return false
    end
    local current_state = device.last_state
    if state == 0 then

        local bit_value = 2^pin
        if math.floor(current_state / bit_value) % 2 == 1 then
            current_state = current_state - bit_value
        end
    else

        local bit_value = 2^pin
        if math.floor(current_state / bit_value) % 2 == 0 then
            current_state = current_state + bit_value
        end
    end
    return pcf8575.write_all(device_handle, current_state)
end
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
function pcf8575.set_pins(device_handle, pin_states)
    local device = devices[device_handle]
    if not device then
        return false
    end
    local current_state = device.last_state
    for pin, state in pairs(pin_states) do
        if pin >= 0 and pin <= 15 then
            if state == 0 then          
                local bit_value = 2^pin
                if math.floor(current_state / bit_value) % 2 == 1 then
                    current_state = current_state - bit_value
                end
            else
                local bit_value = 2^pin
                if math.floor(current_state / bit_value) % 2 == 0 then
                    current_state = current_state + bit_value
                end
            end
        end
    end
    return pcf8575.write_all(device_handle, current_state)
end
function pcf8575.set_port0(device_handle, data)
    local device = devices[device_handle]
    if not device then
        return false
    end
    local current_state = device.last_state
    current_state = math.floor(current_state / 256) * 256 + (data % 256)
    return pcf8575.write_all(device_handle, current_state)
end
function pcf8575.set_port1(device_handle, data)
    local device = devices[device_handle]
    if not device then
        return false
    end
    local current_state = device.last_state
    current_state = (current_state % 256) + ((data % 256) * 256)
    return pcf8575.write_all(device_handle, current_state)
end
function pcf8575.get_port0(device_handle)
    local data = pcf8575.read_all(device_handle)
    if data then
        return data % 256
    end
    return nil
end
function pcf8575.get_port1(device_handle)
    local data = pcf8575.read_all(device_handle)
    if data then
        return math.floor(data / 256) % 256
    end
    return nil
end
function pcf8575.toggle_pin(device_handle, pin)
    local current_state = pcf8575.get_pin(device_handle, pin)
    if current_state ~= nil then
        return pcf8575.set_pin(device_handle, pin, 1 - current_state)
    end
    return false
end
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
function pcf8575.list_devices()
    local device_list = {}
    for handle, _ in pairs(devices) do
        table.insert(device_list, handle)
    end
    return device_list
end
function pcf8575.remove_device(device_handle)
    if devices[device_handle] then
        devices[device_handle] = nil
        return true
    end
    return false
end
function pcf8575.pin_to_port_bit(pin)
    if pin < 0 or pin > 15 then
        return nil, nil
    end
    local port = pin < 8 and 0 or 1
    local bit = pin % 8
    return port, bit
end
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
