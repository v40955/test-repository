local p = peripheral.wrap('front')
local modem = peripheral.find("modem") or error("No modem attached", 0)
local frequency = 1849
modem.open(frequency)

local cannon = {
    angle = 0,              -- live tracking
    status = 0,             -- 0 = assembled, 1 = disassembled
    reaimStatus = 0,        -- 1 = pending reaim
    reaim = 0,              -- target angle to restore to
    lastBeforeFire = 0      -- angle before firing
}
local lastCannonStatus = 0
local slowGear = false
local lastGearToggle = false
local slowSpeed = false
local lastSpeedToggle = false

local cos, sin, deg = math.cos, math.sin, math.deg

function receiver()
    while true do
        local _, _, _, _, data = os.pullEvent("modem_message")
        
        if type(data) == "table" then
            if data.command == "reaim" then
                print("Received reaim command.")
                cannon.status = 1
                sleep(2.05)
                cannon.status = 0
                
            
            end
        end
    end
end

function drive_gear()
    while true do
        local speedToggle = redstone.getInput('bottom')  -- input signal for gear toggle
        if speedToggle and not lastSpeedToggle then
            slowSpeed = not slowSpeed
            print("Drive gear toggled:", slowSpeed and "SLOW" or "FAST")
        end
        
        -- Output control: turn on/off based on slowSpeed
        if slowSpeed then
            rs.setOutput('bottom', true)   -- slow gear active
        else
            rs.setOutput('bottom', false)  -- fast gear
        end

        lastSpeedToggle = speedToggle
        sleep(0.05)
    end
end


function pitch_controls()
    while true do
        local gearToggle = redstone.getInput('top')
        if gearToggle and not lastGearToggle then
            slowGear = not slowGear
            print("Manual Gear Mode:", slowGear and "Slow" or "Fast")
        end
    lastGearToggle = gearToggle
        local up = redstone.getInput("front")
        local down = redstone.getInput("back")
        local base_rpm = slowGear and 4 or 12
        local control = (down and base_rpm or 0) + (up and -base_rpm or 0)
        if cannon.status == 0 then
            p.setTargetSpeed(control)
            
        end
        sleep(0.05)
    end
end
local lastang = 0
-- Gun angle estimator (outside of reaim)
local function calculate_gun_angle()
    while true do
        
        
        local pitchRpm = p.getTargetSpeed()
        local cannonAngleChange=pitchRpm*360/60/20/8

        if cannon.status==1 then--or cannon.reaimStatus == 1 then 
            sleep(0.1)
            cannon.angle=0
            --print("stopped calculating angle ", cannon.angle)
        else
            cannon.angle=math.min(math.max((cannon.angle-cannonAngleChange), -25),50)
            cannon.reaim=cannon.angle
        end
        if lastang~=cannon.angle then
            print("angle: ", cannon.angle)
        end
            
        lastang=cannon.angle
            
        
        sleep()
    end
end
-- Reaim logic
local function reaim_pitch()
   while true do
    if cannon.status ~=lastCannonStatus then
        
        if cannon.status==1 then
            cannon.lastBeforeFire = cannon.angle
            print("reaim: ", cannon.reaim)
            --cannon.reaimStatus=1
            local pitchRpm=(cannon.reaim*8*20*60/360) 
            --sleep(0.1)
            --p.setTargetSpeed(pitchRpm)
            --sleep(0.25)
            p.setTargetSpeed(0)
            print("disassembled rpm: "..pitchRpm)
            cannon.reaimStatus = 1
        elseif cannon.status==0 then
            local target_angle = cannon.lastBeforeFire
            print("target_angle: ", target_angle)
            local halved = target_angle*0.5
            local doubled = target_angle*2
            local quadrupled = target_angle*4
            local pitchRpm=-(target_angle*8*20*60/360)
            print('assembled rpm: '..pitchRpm)
            sleep(0.1)
            p.setTargetSpeed(pitchRpm)
            sleep(0.25)
            p.setTargetSpeed(0)
            
            print('new angle: ', cannon.angle)
            

            --cannon.angle=cannon.reaim
            
            
            if math.abs(cannon.angle - doubled) < 1 then--or math.abs(cannon.angle - halved) < 1 or math.abs(cannon.angle - quadrupled) < 1 then
                print("fixed doubling")
                p.setTargetSpeed(-pitchRpm)
                sleep(0.125)
                p.setTargetSpeed(0)
            elseif cannon.angle == 0  then
                print("fixed zeroing")
                p.setTargetSpeed(pitchRpm)
                sleep(0.25)
                p.setTargetSpeed(0)
            elseif cannon.angle == (-target_angle) then
                p.setTargetSpeed(pitchRpm)
                sleep(0.5)
                p.setTargetSpeed(0)
             
            end

            cannon.reaimStatus=0
        end
    end
    lastCannonStatus = cannon.status
    sleep()
   end
end

print("PVP_11 is running")
parallel.waitForAny(receiver, pitch_controls, calculate_gun_angle, reaim_pitch, drive_gear)