function init()
  animator.playSound("consume")
  self.runboost = config.getParameter("runboost", 1)
  self.jumpboost = config.getParameter("jumpboost", 1)

end

function update(dt)
  mcontroller.controlModifiers({
    speedModifier = self.runboost,
    airJumpModifier = self.jumpboost
  })
end

function uninit()
  status.addEphemeralEffect("talareliclethargy")
end
