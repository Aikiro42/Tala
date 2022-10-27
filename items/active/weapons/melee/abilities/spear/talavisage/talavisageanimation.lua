function update()
    localAnimator.clearDrawables()
    localAnimator.clearLightSources()

    local starTable = animationConfig.animationParameter("starTable")
    local starIndex = animationConfig.animationParameter("starIndex")
    local projectileStack = animationConfig.animationParameter("projectileStack")

    -- bullet trails
    --[[
    for i, projectile in ipairs(projectileStack) do
        local bulletLine = worldify(projectile.origin, projectile.destination)
        localAnimator.addDrawable({
        line = bulletLine,
        width = (projectile.width or 1) * projectile.lifetime/projectile.maxLifetime,
        fullbright = true,
        color = projectile.hitscanColor or {255,255,255}
        }, "Player-1")
    end
    --]]
    
    if starTable
    and #starTable > 0
    and starIndex >= 1
    and starIndex <= #starTable then
        for i, star in ipairs(starTable) do
            if i == starIndex then
                localAnimator.addDrawable({
                    image = "/items/active/weapons/melee/abilities/spear/talavisage/glow.png",
                    position = star.position,
                    fullbright = true,
                }, "Player" .. star.zindex)
                    
                if star.lightColor then
                    localAnimator.addLightSource({
                        position = star.position,
                        color = star.lightColor,
                        pointLight = true,
                    })
                end
            end


            localAnimator.addDrawable({
                image = star.sprite,
                position = star.position,
                fullbright = true,
            }, "Player" .. star.zindex)
        end
    end

end
