function init()
  self.runboost = config.getParameter("runboost", 1)
  self.jumpboost = config.getParameter("jumpboost", 1)

  sb.logInfo("[TALA] " .. self.runboost .. " " .. self.jumpboost)

end

function update(dt)
  mcontroller.controlModifiers({
    speedModifier = self.jumpboost,
    airJumpModifier = self.runboost,
    runningSuppressed = self.runboost < 1,
  })
end

function uninit()
end
