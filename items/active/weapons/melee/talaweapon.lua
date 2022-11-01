require "/scripts/util.lua"
require "/scripts/vec2.lua"
require "/items/active/weapons/weapon.lua"

local dmgListener

function init()
  animator.setGlobalTag("paletteSwaps", config.getParameter("paletteSwaps", ""))
  animator.setGlobalTag("directives", "")
  animator.setGlobalTag("bladeDirectives", "")

  self.weapon = Weapon:new()

  self.weapon:addTransformationGroup("weapon", {0,0}, util.toRadians(config.getParameter("baseWeaponRotation", 0)))
  self.weapon:addTransformationGroup("swoosh", {0,0}, math.pi/2)

  local primaryAbility = getPrimaryAbility()
  self.weapon:addAbility(primaryAbility)

  local secondaryAttack = getAltAbility()
  if secondaryAttack then
    self.weapon:addAbility(secondaryAttack)
  end

  self.essenceChance = config.getParameter("essenceChance", 0.2)
  self.minEssence = config.getParameter("minEssence", 1)
  self.maxEssence = config.getParameter("maxEssence", 10)

  dmgListener = damageListener("inflictedDamage", function(notifications)
    for _,notification in pairs(notifications) do
      if notification.sourceEntityId == activeItem.ownerEntityId() and notification.healthLost > 0 then
        rollEssence()
      end
    end
  end)

  self.weapon:init()

end

function rollEssence()
  math.randomseed(os.clock() * 4294967296)
  local roll = math.random()
  if roll < self.essenceChance then
    world.spawnItem("essence", mcontroller.position(), math.random(self.minEssence, self.maxEssence))
  end
end

function update(dt, fireMode, shiftHeld)

  dmgListener:update()

  self.weapon:update(dt, fireMode, shiftHeld)

  mcontroller.controlModifiers({
    speedModifier = 1.5,
    airJumpModifier = 1.5
  })
  --[[
  local nowActive = self.weapon.currentAbility ~= nil
  if nowActive then
    if self.activeTimer == 0 then
      animator.setAnimationState("blade", "extend")
      activeItem.setHoldingItem(true)
    end
    self.activeTimer = self.activeTime
  elseif self.activeTimer > 0 then
    self.activeTimer = math.max(0, self.activeTimer - dt)
    if self.activeTimer == 0 then
      animator.setAnimationState("blade", "retract")
    end
  end
  --]]
end

function uninit()
  self.weapon:uninit()
end
