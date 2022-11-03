function init()
  animator.setParticleEmitterOffsetRegion("energy", mcontroller.boundBox())
  animator.setParticleEmitterBurstCount("energy", 50)
  animator.burstParticleEmitter("energy")
  
  animator.setParticleEmitterEmissionRate("energy", config.getParameter("emissionRate", 10))
  animator.setParticleEmitterActive("energy", true)
end

function update(dt)
  status.setResourcePercentage("energy", 1)
end

function uninit()
  
end
