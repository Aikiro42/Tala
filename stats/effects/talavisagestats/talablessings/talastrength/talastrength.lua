function init()
  self.fallDamageMultiplier = config.getParameter("fallDamageMultiplier", 0.1)
  self.protectionModifier = config.getParameter("protectionModifier", 0.1)

  effect.addStatModifierGroup({{stat = "fallDamageMultiplier", effectiveMultiplier = self.fallDamageMultiplier}})
  effect.addStatModifierGroup({{stat = "protection", effectiveMultiplier = self.protectionModifier}})

end

function update(dt)
end

function uninit()  
end

