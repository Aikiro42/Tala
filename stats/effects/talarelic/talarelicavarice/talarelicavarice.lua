function init()

  animator.playSound("consume")
  
  self.dice = config.getParameter("dice", 20)
  self.winAmount = config.getParameter("winAmount", 1000)

  local diceRoll = math.random(1, self.dice)
  if diceRoll == 1 then
    status.setResourcePercentage("energy", 0)
    status.setResourcePercentage("health", 0)
  elseif diceRoll == self.dice then
    world.spawnItem("money", mcontroller.position(), self.winAmount)
  else
    status.setResourcePercentage("energy", diceRoll/self.dice)
    status.setResourcePercentage("health", diceRoll/self.dice)
  end

  effect.expire()


end

function update(dt)
  effect.expire()
end

function uninit()
end
