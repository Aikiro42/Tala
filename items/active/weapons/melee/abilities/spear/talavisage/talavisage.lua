require "/scripts/util.lua"
require "/scripts/status.lua"
require "/scripts/vec2.lua"
require "/items/active/weapons/weapon.lua"

TalaVisage = WeaponAbility:new()

local fireHeld = false
local starListener
local projectileStack = {}

function TalaVisage:init()

  -- sb.logInfo("[TALA] randStarProperties = " .. sb.printJson(self.randStarProperties))
  self.hitCounter = 0
  self.cooldownTimer = self.cooldownTime
  self.phase = 0
  self.starIndex = 1
  self.starPos = {{0, 0, ""}, {0, 0, ""}, {0, 0, ""}}
  self.starTable = {}
  self.switchGracePeriod = 0.2
  self.orbitSpeed = self.minOrbitSpeed
  self:updateStarPos()
  activeItem.setScriptedAnimationParameter("starIndex", self.starIndex)
  starListener = damageListener("inflictedDamage", function(notifications)
    for _,notification in pairs(notifications) do
      -- sb.logInfo("[TALA] Damage Notif: " .. sb.printJson(notification))
      if notification.sourceEntityId == activeItem.ownerEntityId() and notification.healthLost > 0 then
        self.hitCounter = self.hitCounter + 1
        if self.hitCounter >= self.hitsPerStar then
          -- TODO: play sound
          self:addStar()
          self.hitCounter = 0
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
  status.addEphemeralEffect("talapassive")
  
  -- update projectile stack
  for i, projectile in ipairs(projectileStack) do
    projectileStack[i].lifetime = projectileStack[i].lifetime - dt
    projectileStack[i].origin = vec2.lerp((1 - projectileStack[i].lifetime/projectileStack[i].maxLifetime)*0.01, projectileStack[i].origin, projectileStack[i].destination)
    if projectileStack[i].lifetime <= 0 then
      table.remove(projectileStack, i)
    end
  end
  activeItem.setScriptedAnimationParameter("projectileStack", projectileStack)

  -- activation logic

  -- changing star index
  --[[
  if shiftHeld then
    shiftHeldTimer = shiftHeldTimer + self.dt
  elseif not changedStarIndex then
    changedStarIndex = true
    if shiftHeldTimer <= self.switchGracePeriod and #self.starTable > 0 then
      animator.setSoundPitch("switchstar", sb.nrand(0.1, 1))
      animator.playSound("switchstar")
      self.starIndex = (self.starIndex % #self.starTable) + 1
    end 
    shiftHeldTimer = 0
  end
  --]]

  -- lifesaver
  if status.resourcePercentage("health") <= 0.2 and #self.starTable > 0 then
    animator.playSound("saveroll")
    status.setResourcePercentage("health", 1)
    status.addEphemeralEffect("talaphase")
    self.starTable = {}
    self.starIndex = 1
  end

  if not self.weapon.currentAbility
    and #self.starTable > 0
    and self.fireMode == "alt"
    and not fireHeld
    and self.cooldownTimer == 0
    and status.consumeResource("energy", status.resourceMax("energy")/self.maxStars) then
      if not shiftHeld then
        self:setState(self.charge)
      else
        animator.setSoundPitch("switchstar", sb.nrand(0.1, 1))
        animator.playSound("switchstar")  
        self.starIndex = (self.starIndex % #self.starTable) + 1
        fireHeld = true
      end

  elseif self.fireMode ~= "alt" then
    fireHeld = false
  end
end

function TalaVisage:charge()
  local chargeTimer = 0
  animator.setSoundVolume("starscream", 0)
  animator.setSoundPitch("starscream", 1)
  animator.playSound("starscream", -1)
  while self.fireMode == "alt" do
    chargeTimer = math.min(self.chargeTime, chargeTimer + self.dt)
    self.orbitSpeed = math.min(self.maxOrbitSpeed, self.orbitSpeed + self.orbitAccel * self.dt)
    animator.setSoundVolume("starscream", self:orbitRatio())
    animator.setSoundPitch("starscream", 1 + self:orbitRatio())
    coroutine.yield()
  end
  animator.stopAllSounds("starscream")
  animator.setSoundVolume("starscream", 0)
  animator.setSoundPitch("starscream", 1)

  self:setState(self.fire)
end

function TalaVisage:fire()

  fireHeld = true

  -- hide the sprite
  self.starTable[self.starIndex].sprite = "/assetmissing.png"

  -- fire the star
  if self.starTable[self.starIndex].projectileType ~= "hitscan" then
    self:fireProjectiles()
  else
    self:fireHitscan()
  end

  -- remove star from startable
  table.remove(self.starTable, self.starIndex)

  self.starIndex = 1
  self.orbitSpeed = self.minOrbitSpeed

  self.cooldownTimer = self.cooldownTime

end

function TalaVisage:fireProjectiles()
  -- sb.logInfo("[TALA] " .. sb.printJson(self.starTable))
  local shots = self.starTable[self.starIndex].burstCount
  local params = copy(self.starTable[self.starIndex].projectileParams)
  params.power = self:damageAmount()
  local soundPlayed = false
  while shots > 0 do

    shots = shots - 1

    world.spawnProjectile(
      self.starTable[self.starIndex].projectileType,
      self:firePosition(),
      activeItem.ownerEntityId(),
      self:aimVector(self.starTable[self.starIndex].inaccuracy),
      false,
      params
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

-- hitscan shots are non-penetrating
function TalaVisage:fireHitscan()
  local shots = self.starTable[self.starIndex].burstCount
  local soundPlayed = false
  while shots > 0 do
    
    shots = shots - 1

    local hitreg = self:hitscan(self.starTable[self.starIndex].inaccuracy)
    if hitreg[3] then
      -- TODO: make custom status effect for tala
      world.sendEntityMessage(hitreg[3], "applyStatusEffect", "talahitscandamage", self:damageAmount(), entity.id())
    end

    local life = 0.3
    table.insert(projectileStack, {
      width = 2,
      origin = hitreg[1],
      destination = hitreg[2],
      lifetime = life,
      maxLifetime = life,
      hitscanColor = self.starTable[self.starIndex].lightColor
    })

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

function TalaVisage:hitscan(inaccuracy)
  local scanOrig = self:firePosition()
  local scanDest = vec2.add(scanOrig, vec2.mul(vec2.norm(self:aimVector(inaccuracy or 0)), self.range or 100))
  scanDest = world.lineCollision(scanOrig, scanDest, {"Block", "Dynamic"}) or scanDest

  local hitId = world.entityLineQuery(scanOrig, scanDest, {
    withoutEntityId = entity.id(),
    includedTypes = {"monster", "npc", "player"},
    order = "nearest"
  })
  local id = null
  if #hitId > 0 then
    if world.entityCanDamage(entity.id(), hitId[1]) then

      local aimAngle = vec2.angle(world.distance(scanDest, scanOrig))
      local entityAngle = vec2.angle(world.distance(world.entityPosition(hitId[1]), scanOrig))
      local rotation = aimAngle - entityAngle
      
      scanDest = vec2.rotate(world.distance(world.entityPosition(hitId[1]), scanOrig), rotation)
      scanDest = vec2.add(scanDest, scanOrig)

      id = hitId[1]

    end
  end

  world.debugLine(scanOrig, scanDest, {255,0,255})

  return {scanOrig, scanDest, id}

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

--[[

Damage is calculated depending on:
1. amount of Ancient Essence the wielder has divided by 10000. Holding over 100,000 AE won't give additional damage.
2. weapon tier
3. how close the stars are to max orbit speed times the number of stars accumulated
4. the owner's ATK stat

All factors are multiplicative to each other.

--]]
function TalaVisage:damageAmount()
  return math.min(10, ((world.entityCurrency(activeItem.ownerEntityId(), "essence") or 1)/10000)) * config.getParameter("damageLevelMultiplier") * (1 + self:orbitRatio() * #self.starTable) * activeItem.ownerPowerMultiplier()
end

function TalaVisage:orbitRatio()
  return (self.orbitSpeed - self.minOrbitSpeed)/self.maxOrbitSpeed
end

function TalaVisage:uninit()
  status.removeEphemeralEffect("talapassive")
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
  -- sb.logInfo("[TALA] " .. sb.printJson(self.starTable))
end