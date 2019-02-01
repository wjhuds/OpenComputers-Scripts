local computer, component, robot = require('computer'), require('component'), require('robot')
local invctr, generator = component.inventory_controller, component.generator

-- local coordinates relative to bottom left corner of quarried area
curX, curY, curZ = 0, 0, 0
-- direction robot is facing [ forward = 0, right = 1, back = 2, left = 3]
direction = 0

local function report(msg)
  print(msg)
  if component.isAvailable('tunnel') then
    component.tunnel.send(msg)
  end
end

local function refuel()
  fuelRemaining = robot.count(1)
  if fuelRemaining > 0 and fuelRemaining <= 8 then
    report("FUEL LOW! " .. fuelRemaining .. " LEFT!")
  elseif fuelRemaining == 0 then
    report("FUEL CRITICAL! NO FUEL REMAINING IN GENERATOR!")
    return
  end
  generator.insert(8)
  report("FUEL IN GENERATOR: ".. generator.count())
end

-- wrapper for component.robot swing() to throw errors on fail
local function swing(side)
  if side == 0 then
    retVal, msg = robot.swingDown()
    if retVal ~= true then
      if string.find(msg, "air") then
        return
      end
      error("ERROR: CANNOT MINE BLOCK!" .. "\n" .. msg .. "\n X: " .. curX .. "\n Y: " .. curY .. "\n Z: " .. curZ)
    end
  else
    retVal, msg = robot.swing(side)
    if retVal ~= true then
      if string.find(msg, "air") then
        return
      end
      error("ERROR: CANNOT MINE BLOCK!" .. "\n" .. msg .. "\n X: " .. curX .. "\n Y: " .. curY .. "\n Z: " .. curZ)
    end
  end
end

-- wrapper for component.robot forward() to throw errors on fail
local function forward()
  retVal, msg = robot.forward()
  if retVal ~= true then
    error("ERROR: CANNOT MOVE FORWARD!" .. "\n" .. msg .. "\n X: " .. curX .. "\n Y: " .. curY .. "\n Z: " .. curZ)
  end
end

-- turn robot to desired direction
local function turn(side)
  while direction ~= side do
    robot.turnRight()
    direction = (direction + 1) % 4
  end
end

local function digRow(distance)
  refuel()
  for i = 1, distance do
    swing(3)
    forward()
  end
end

local function startNextRow()
  if direction == 3 then
    turn(0)
    swing(3)
    forward()
    turn(1)
  elseif direction == 1 then
    turn(0)
    swing(3)
    forward()
    turn(3)
  else
    error("ERROR: UNEXPECTED DIRECTION!" .. "\n X: " .. curX .. "\n Y: " .. curY .. "\n Z: " .. curZ)
  end
  curY = curY + 1
end

local function returnToCorner()
  turn(3)
  while curX > 0 do
    forward()
    curX = curX - 1
  end
  turn(2)
  while curY > 0 do
    forward()
    curY = curY - 1
  end
  turn(0)
  curX, curY = 0, 0
end

local function makeLayer(length, width)
  turn(1)
  for i=1, length - 1 do
    digRow(width)
    curX = direction == 1 and curX + width or curX - width
    startNextRow()
  end
  digRow(width)
  curX = direction == 1 and curX + width or curX - width
  returnToCorner()
end

local function startNextLayer()
  maxPower = computer.maxEnergy()
  curPower = computer.energy()
  while (maxPower / curPower) > 2 do
    refuel()
    sleep(60)
  end
  swing(0)
  retVal, msg = robot.down()
  if retVal ~= true then
    error("ERROR: CANNOT MOVE DOWNWARD!" .. "\n" .. msg .. "\n X: " .. curX .. "\n Y: " .. curY .. "\n Z: " .. curZ)
  end
end

local function quarry(width, length, depth)
  if width < 5 then
    error("ERROR: WIDTH MUST BE AT LEAST 5!")
  end
  if length < 5 then
    error("ERROR: LENGTH MUST BE AT LEAST 5!")
  end
  if depth < 5 then
    error("ERROR: DEPTH MUST BE AT LEAST 5!")
  end

  -- begin quarrying process
  while curZ < depth - 1 do
    makeLayer(length, width)
    startNextLayer()
  end
  makeLayer()
end

-- entry point
retVal, msg = pcall(quarry, 20 ,20, 50)
if retVal == true then
  report("STATUS: MINING COMPLETE.")
else
  report(msg)
end