function init()
  -- invulnerability
  effect.addStatModifierGroup({{stat = "invulnerable", amount = 1}})

  -- turn transparent
  effect.setParentDirectives("?multiply=FFFFFF3F")

end

function update(dt)

  -- turn red and become transparent
  effect.setParentDirectives("?fade=FF00FF=0.5?multiply=FFFFFF3F")

  -- particles
  if mcontroller.xVelocity() ~= 0 or mcontroller.yVelocity() ~= 0 then
    if mcontroller.facingDirection() == 1 then
      animator.setParticleEmitterActive("dodgeRight", true)
      animator.setParticleEmitterActive("dodgeLeft", false)
    else
      animator.setParticleEmitterActive("dodgeRight", false)
      animator.setParticleEmitterActive("dodgeLeft", true)
    end
  else
    animator.setParticleEmitterActive("dodgeRight", false)
    animator.setParticleEmitterActive("dodgeLeft", false)
  end

end

function uninit()
  
end
