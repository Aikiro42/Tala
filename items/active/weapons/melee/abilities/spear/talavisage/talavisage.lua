require "/scripts/util.lua"
require "/scripts/status.lua"
require "/scripts/vec2.lua"
require "/items/active/weapons/weapon.lua"

TalaVisage = WeaponAbility:new()

local changedStarIndex = true
local shiftHeldTimer = 0
local fireHeld = false
local starListener

function TalaVisage:init()

  sb.logInfo("[TALA] randStarProperties = " .. sb.printJson(self.randStarProperties))

  self.cooldownTimer = self.cooldownTime
  self.phase = 0
  self.starIndex = 1
  self.starPos = {{0, 0, ""}, {0, 0, ""}, {0, 0, ""}}
  self.starTable = {}
  self.switchGracePeriod = 0.2
  self:updateStarPos()
  activeItem.setScriptedAnimationParameter("starIndex", self.starIndex)
  starListener = damageListener("inflictedDamage", function(notifications)
    for _,notification in pairs(notifications) do
      sb.logInfo("[TALA] Damage Notif: " .. sb.printJson(notification))
      if notification.sourceEntityId == activeItem.ownerEntityId() then
        if notification.healthLost > 0 then
          self:addStar()
        end
      end
    end
  end)

end

function TalaVisage:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)

  -- increments
  self.phase = self.phase >= 2 * math.pi and 0 or self.phase + self.dt * self.orbitSpeed
  self.cooldownTimer = math.max(0, self.cooldownTimer - dt)

  -- updates
  self:updateStarPos()
  starListener:update()
  activeItem.setScriptedAnimationParameter("starIndex", self.starIndex)
  activeItem.setScriptedAnimationParameter("starTable", self.starTable)

  -- activation
  if shiftHeld then
    changedStarIndex = false
    shiftHeldTimer = shiftHeldTimer + self.dt
  elseif not changedStarIndex then
    changedStarIndex = true
    if shiftHeldTimer <= self.switchGracePeriod and #self.starTable > 0 then
      self.starIndex = (self.starIndex % #self.starTable) + 1
    end 
    shiftHeldTimer = 0
  end



  if not self.weapon.currentAbility
    and #self.starTable > 0
    and self.fireMode == "alt"
    and not fireHeld
    and self.cooldownTimer == 0
    and status.overConsumeResource("energy", self.energyUsage) then

    self:setState(self.fire)
  elseif self.fireMode ~= "alt" then
    fireHeld = false
  end
end

function TalaVisage:fire()

  fireHeld = true


  -- hide the sprite
  self.starTable[self.starIndex].sprite = "/assetmissing.png"

  -- fire the star
  if self.starTable[self.starIndex].projectileType ~= "hitscan" then
    self:fireProjectiles()
  else
    -- hitscan
  end

  -- remove star from startable
  table.remove(self.starTable, self.starIndex)

  self.starIndex = 1

  self.cooldownTimer = self.cooldownTime
end

function TalaVisage:fireProjectiles()
  sb.logInfo("[TALA] " .. sb.printJson(self.starTable))
  local shots = self.starTable[self.starIndex].burstCount
  local soundPlayed = false
  while shots > 0 do

    shots = shots - 1

    world.spawnProjectile(
      self.starTable[self.starIndex].projectileType,
      self:firePosition(),
      activeItem.ownerEntityId(),
      self:aimVector(self.starTable[self.starIndex].inaccuracy),
      false,
      self.starTable[self.starIndex].projectileParams
    )
      
    -- effects
    if not soundPlayed then
      animator.playSound("fireStar")
    end

    if self.starTable[self.starIndex].burstTime == 0 then
      soundPlayed = true
    end

    self:screenShake(0.05, 0.01)

    if shots > 0 then util.wait(self.starTable[self.starIndex].burstTime) end

  end
end


function TalaVisage:firePosition()
  local a = self.starPos[self.starIndex]
  return self.starTable[self.starIndex].position
end

function TalaVisage:aimVector(inaccuracy)
  local aimVector = vec2.rotate(world.distance(activeItem.ownerAimPosition(), self:firePosition()), sb.nrand(inaccuracy or 0, 0))
  -- aimVector[1] = aimVector[1] * mcontroller.facingDirection()
  return aimVector
end

function TalaVisage:damageAmount()
  return self.baseDamage * config.getParameter("damageLevelMultiplier")
end

function TalaVisage:uninit()
  status.clearPersistentEffects("weaponMovementAbility")
end

function TalaVisage:updateStarPos()

  for i, star in ipairs(self.starTable) do
    local phaseOffset = 2 * math.pi * (i-1) / #self.starTable
    self.starTable[i].position[1] = mcontroller.position()[1] + self.starOffset[1] * math.cos(self.phase + phaseOffset)
    self.starTable[i].position[2] = mcontroller.position()[2] + self.starOffset[2] * math.sin(self.phase + phaseOffset)
    self.starTable[i].zindex = math.sin(self.phase + phaseOffset) >= 0 and "+1" or "-1"
  end

  activeItem.setScriptedAnimationParameter("starPos", self.starTable)

end

function TalaVisage:screenShake(amount, shakeTime)
  local shake_dir = vec2.mul(self:aimVector(0), -1 * (amount or 0.1))
  local cam = world.spawnProjectile(
    "invisibleprojectile",
    vec2.add(mcontroller.position(), shake_dir),
    0,
    {0, 0},
    false,
    {
      power = 0,
      timeToLive = shakeTime or 0.01,
      damageType = "NoDamage"
    }
  )
  activeItem.setCameraFocusEntity(cam)
end

function TalaVisage:addStar()

  if #self.starTable >= self.maxStars then
    table.remove(self.starTable, 1)
  end

  local type = math.random(1, #self.randStarProperties)
  --[[
    Each item in the starTable contains the following:
    - sprite path
    - number of shots fired
    - projectile type
    - projectile parameters
    - position
    - zindex
  ]]--
  local new = #self.starTable + 1
  local toMerge = {
    position = {0, 0},
    zindex = "-1"
  }
  self.starTable[new] = util.mergeTable(copy(self.randStarProperties[type]), toMerge)
  sb.logInfo("[TALA] " .. sb.printJson(self.starTable))
end