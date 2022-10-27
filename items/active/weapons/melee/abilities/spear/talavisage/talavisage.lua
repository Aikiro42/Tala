require "/scripts/util.lua"
require "/scripts/status.lua"
require "/scripts/vec2.lua"
require "/items/active/weapons/weapon.lua"

TalaVisage = WeaponAbility:new()

local shiftHeldGraceTimer = 0
local isWalking = false
local starListener

function TalaVisage:init()
  self.cooldownTimer = self.cooldownTime
  self.phase = 0
  self.stars = self.maxStars
  self.starIndex = 1
  self.starPos = {{0, 0, ""}, {0, 0, ""}, {0, 0, ""}}
  self.switchGracePeriod = 0.2
  self:updateStarPos()

  starListener = damageListener("inflictedDamage", function(notifications)
    for _,notification in pairs(notifications) do
      if notification.sourceEntityId == activeItem.ownerEntityId() then
        sb.logInfo("[TALA]" .. sb.printJson(notification))
        if notification.healthLost > 0 then
          -- if killed, add star
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

  -- activation

  if not shiftHeld and isWalking then
    if shiftHeldGraceTimer <= self.switchGracePeriod then
      self.starIndex = self.starIndex >= 3 and 1 or self.starIndex + 1
    end
    isWalking = false
    shiftHeldGraceTimer = 0
  else
    isWalking = true
    shiftHeldGraceTimer = shiftHeldGraceTimer + dt
  end

  if not self.weapon.currentAbility
    and self.stars > 0
    and self.fireMode == "alt"
    and self.cooldownTimer == 0
    and status.overConsumeResource("energy", self.energyUsage) then

    self:setState(self.fire)
  end
end

function TalaVisage:fire()

  -- spawn projectle
  world.spawnProjectile(
    "neomagnumbullet",
    self:firePosition(),
    activeItem.ownerEntityId(),
    self:aimVector(),
    false,
    {}
  )

  -- sfx
  animator.playSound("fireStar")

  -- vfx
  self:screenShake(0.05, 0.01)

  self.cooldownTimer = self.cooldownTime
end


function TalaVisage:firePosition()
  local a = self.starPos[self.starIndex]
  return {a[1], a[2]}
end

function TalaVisage:aimVector()
  local aimVector = world.distance(activeItem.ownerAimPosition(), self:firePosition())
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

  for i = 0, 2 do
    local actualPhase = self.phase + (2 * math.pi * i / 3)
    self.starPos[i+1] = {
      mcontroller.position()[1] + self.starOffset[1] * math.cos(actualPhase),
      mcontroller.position()[2] + self.starOffset[2] * math.sin(actualPhase),
      math.sin(actualPhase) >= 0 and "+1" or "-1"
    }
  end

  activeItem.setScriptedAnimationParameter("starPos", self.starPos)

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