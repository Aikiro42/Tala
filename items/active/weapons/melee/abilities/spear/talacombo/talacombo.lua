require "/scripts/interp.lua"
require "/scripts/vec2.lua"
require "/scripts/util.lua"

-- Melee primary ability
TalaCombo = WeaponAbility:new()

local thrown = false

local isShiftHeld = false

local dmgListener

local canDodge

function TalaCombo:init()
  self.comboStep = 1

  self.energyUsage = self.energyUsage or 0

  self:computeDamageAndCooldowns()

  self.weapon:setStance(self.stances.idle)

  self.edgeTriggerTimer = 0
  self.flashTimer = 0
  self.cooldownTimer = self.cooldowns[1]
  self.shiftHeldTime = -1

  -- dodge
  self.dodgeCooldownTimer = self.dodgeParams.cooldown

  self.animKeyPrefix = self.animKeyPrefix or ""

  dmgListener = damageListener("inflictedDamage", function(notifications)
    for _,notification in pairs(notifications) do
      if notification.sourceEntityId == activeItem.ownerEntityId() then
        self:screenShake()
        if notification.healthLost > 0 then
          status.giveResource("energy", status.resourceMax("energy") * self.energyStealRate)
        end
      end
    end
  end)

  self.weapon.onLeaveAbility = function()
    -- self.weapon:setStance(self.stances.idle)
    thrown = false
  end

  self.activeTime = config.getParameter("activeTime", 2)
  self.activeTimer = 0
  animator.setAnimationState("blade", "inactive")

end

-- Ticks on every update regardless if this is the active ability
function TalaCombo:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)
  dmgListener:update()

  -- flags
  isShiftHeld = shiftHeld
  canDodge = self.shiftHeldTime >= 0 and (self.shiftHeldTime < self.dodgeParams.triggerTime or self.dodgeParams.triggerTime <= 0) and self.dodgeCooldownTimer == 0 and not shiftHeld

  self.dodgeCooldownTimer = math.max(0, self.dodgeCooldownTimer - self.dt)

  -- activation logic

  -- controls whether you're holding the item or not
  if animator.animationState("blade") == "inactive" and not thrown then
    activeItem.setHoldingItem(false)
  else
    activeItem.setHoldingItem(true)
  end

  -- dodging
  if shiftHeld then
    if self.shiftHeldTime < 0 then
      self.shiftHeldTime = 0
    end
    self.shiftHeldTime = self.shiftHeldTime + self.dt
  elseif canDodge and not self.weapon.currentAbility then
      self:setState(self.dodge)
  else
    self.shiftHeldTime = -1
  end

  -- controls the presence of the weapon
  if self.activeTimer > 0 then
    if animator.animationState("blade") == "inactive" and not thrown then
      animator.setAnimationState("blade", "extend")
    end
    if not self.weapon.currentAbility then
      self.activeTimer = math.max(0, self.activeTimer - self.dt)
    end
  elseif self.activeTimer == 0 then
    if animator.animationState("blade") == "active" then
      animator.setAnimationState("blade", "retract")
    end
  end

  -- ready indicator
  if self.cooldownTimer > 0 then
    self.cooldownTimer = math.max(0, self.cooldownTimer - self.dt)
    if self.cooldownTimer == 0 then
      self:readyFlash()
    end
  end

  -- ready indicator
  if self.flashTimer > 0 then
    self.flashTimer = math.max(0, self.flashTimer - self.dt)
    if self.flashTimer == 0 then
      animator.setGlobalTag("bladeDirectives", "")
    end
  end

  -- edge trigger
  self.edgeTriggerTimer = math.max(0, self.edgeTriggerTimer - dt)
  if self.lastFireMode ~= (self.activatingFireMode or self.abilitySlot) and fireMode == (self.activatingFireMode or self.abilitySlot) then
    self.edgeTriggerTimer = self.edgeTriggerGrace
  end
  self.lastFireMode = fireMode

  -- actual activation
  if not self.weapon.currentAbility and self:shouldActivate() then
      self.activeTimer = self.activeTime
      if shiftHeld and status.resourcePercentage("energy") == 1then
        self:setState(self.javelinCharge)
      else
        self:setState(self.windup)
      end
  end
end

function TalaCombo:dodge()

  self:demanifest()
  
  local dodgeDirection
  if mcontroller.xVelocity() ~= 0 then
    dodgeDirection = mcontroller.movingDirection()
  else
    dodgeDirection = mcontroller.facingDirection()
  end
  animator.playSound("dodge")
  status.addEphemeralEffect("taladodge", self.dodgeParams.time)
  util.wait(self.dodgeParams.time, function(dt)
    mcontroller.setVelocity({self.dodgeParams.speed*dodgeDirection, 0})
  end)
  mcontroller.setXVelocity(mcontroller.xVelocity() * self.dodgeParams.endXVelMult)

  self.dodgeCooldownTimer = self.dodgeParams.cooldown

end

function TalaCombo:javelinCharge()
  -- lerp
  -- self.weapon:setStance(self.stances.javelinCharge)
  status.setResourcePercentage("energy", 0)
  local chargeTimer = 0
  local maxChargeTime = self.stances.javelinCharge.duration
  while self.fireMode == self.activatingFireMode or self.abilitySlot do
    local chargeProgress = chargeTimer / maxChargeTime
    self.weapon:updateAim()

    self.weapon.relativeWeaponRotation = util.toRadians(interp.sin(chargeProgress, math.deg(self.weapon.relativeWeaponRotation), self.stances.javelinCharge.weaponRotation))
    self.weapon.relativeArmRotation = util.toRadians(interp.sin(chargeProgress, math.deg(self.weapon.relativeArmRotation), self.stances.javelinCharge.armRotation))

    chargeTimer = chargeTimer + self.dt
    if chargeTimer >= maxChargeTime then self:setState(self.javelinFire) end
    coroutine.yield()
  end


end

function TalaCombo:javelinFire()

  thrown = true

  local projOrigin = vec2.add(mcontroller.position(), activeItem.handPosition())

  self.weapon:setStance(self.stances.javelinFire)
  self.weapon:updateAim()
  animator.setAnimationState("blade", "inactive")
  
  local javelinProjectile = world.spawnProjectile(
    "talajavelin",
    projOrigin,
    activeItem.ownerEntityId(),
    world.distance(activeItem.ownerAimPosition(), projOrigin),
    false,
    {
      power = status.resourceMax("energy"),
      damageType = "IgnoresDef",
    }
  )

  util.wait(self.stances.javelinFire.duration)
  self.weapon:setStance(self.stances.idle)
  self.activeTimer = 0
  self.comboStep = 1
  
end

function TalaCombo:getJavelinDamage()
  return status.resourceMax("energy") * activeItem.ownerPowerMultiplier() * config.getParameter("level", 1) * config.getParameter("damageLevelMultiplier", 1)
end


-- State: windup
function TalaCombo:windup()
  local stance = self.stances["windup"..self.comboStep]

  self.weapon:setStance(stance)

  self.edgeTriggerTimer = 0

  if stance.hold then
    while self.fireMode == (self.activatingFireMode or self.abilitySlot) do
      coroutine.yield()
    end
  else
    util.wait(stance.duration)
  end

  if self.energyUsage then
    status.overConsumeResource("energy", self.energyUsage)
  end

  if self.stances["preslash"..self.comboStep] then
    self:setState(self.preslash)
  else
    self:setState(self.fire)
  end
end

-- State: preslash
-- brief frame in between windup and fire
function TalaCombo:preslash()
  local stance = self.stances["preslash"..self.comboStep]

  self.weapon:setStance(stance)
  self.weapon:updateAim()

  util.wait(stance.duration)

  self:setState(self.fire)
end

-- State: fire
function TalaCombo:fire()
  local stance = self.stances["fire"..self.comboStep]

  self.weapon:setStance(stance)
  self.weapon:updateAim()

  local animStateKey = self.animKeyPrefix .. (self.comboStep > 1 and "fire"..self.comboStep or "fire")
  animator.setAnimationState("swoosh", animStateKey)
  animator.playSound(animStateKey)

  local swooshKey = self.animKeyPrefix .. (self.elementalType or self.weapon.elementalType) .. "swoosh"
  animator.setParticleEmitterOffsetRegion(swooshKey, self.swooshOffsetRegions[self.comboStep])
  animator.burstParticleEmitter(swooshKey)

  util.wait(stance.duration, function()
    local damageArea = partDamageArea("swoosh")
    self.weapon:setDamage(self.stepDamageConfig[self.comboStep], damageArea)
    -- mcontroller.controlApproachVelocity(vec2.mul(vec2.norm(world.distance(activeItem.ownerAimPosition(), mcontroller.position())), 10), 1000)
  end)

  self:setState(self.wait)
end

function TalaCombo:demanifest()
  self.activeTimer = 0
  self.comboStep = 1
end


-- State: wait
-- waiting for next combo input
function TalaCombo:wait()
  local stance = self.stances["wait"..(self.comboStep)]
  stance.allowFlip = true
  self.weapon:setStance(stance)

  util.wait(stance.duration, function()

    -- interrupts combo to use alt ability
    if self.fireMode == "alt" then
      self:setState(self.demanifest)
      return
    end

    if canDodge then self:setState(self.dodge) return end

    if self:shouldActivate() then
      if not isShiftHeld then
        self.comboStep = (self.comboStep % self.comboSteps) + 1
        self:setState(self.windup)
      else
        self:setState(self.javelinCharge)
      end
      return
    end
  end)

  self.cooldownTimer = math.max(0, self.cooldowns[self.comboStep] - stance.duration)
  self.comboStep = 1
end

function TalaCombo:shouldActivate()
  if self.cooldownTimer == 0 and (self.energyUsage == 0 or not status.resourceLocked("energy")) then
    if self.comboStep > 1 then
      return self.edgeTriggerTimer > 0
    else
      return self.fireMode == (self.activatingFireMode or self.abilitySlot)
    end
  end
end

function TalaCombo:readyFlash()
  animator.setGlobalTag("bladeDirectives", self.flashDirectives)
  self.flashTimer = self.flashTime
end

function TalaCombo:computeDamageAndCooldowns()
  local attackTimes = {}
  for i = 1, self.comboSteps do
    local attackTime = self.stances["windup"..i].duration + self.stances["fire"..i].duration
    if self.stances["preslash"..i] then
      attackTime = attackTime + self.stances["preslash"..i].duration
    end
    table.insert(attackTimes, attackTime)
  end

  self.cooldowns = {}
  local totalAttackTime = 0
  local totalDamageFactor = 0
  self.javelinDamage = 0
  for i, attackTime in ipairs(attackTimes) do
    self.stepDamageConfig[i] = util.mergeTable(copy(self.damageConfig), self.stepDamageConfig[i])
    self.stepDamageConfig[i].timeoutGroup = "primary"..i

    local damageFactor = self.stepDamageConfig[i].baseDamageFactor
    self.stepDamageConfig[i].baseDamage = damageFactor * self.baseDps * self.fireTime
    if self.stepDamageConfig[i].baseDamage > self.javelinDamage then
      self.javelinDamage = self.stepDamageConfig[i].baseDamage
    end
    totalAttackTime = totalAttackTime + attackTime
    totalDamageFactor = totalDamageFactor + damageFactor

    local targetTime = totalDamageFactor * self.fireTime
    local speedFactor = 1.0 * (self.comboSpeedFactor ^ i)
    table.insert(self.cooldowns, (targetTime - totalAttackTime) * speedFactor)
  end
end

function TalaCombo:uninit()
  self.weapon:setDamage()
end

function TalaCombo:screenShake(amount, shakeTime)
  local amount = amount or 0.5
  local cam = world.spawnProjectile(
    "invisibleprojectile",
    vec2.add(mcontroller.position(), {sb.nrand(amount), sb.nrand(amount)}),
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