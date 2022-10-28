require "/scripts/vec2.lua"

function update()
    localAnimator.clearDrawables()
    localAnimator.clearLightSources()

    local starTable = animationConfig.animationParameter("starTable")
    local starIndex = animationConfig.animationParameter("starIndex")
    local projectileStack = animationConfig.animationParameter("projectileStack")

    -- bullet trails
    for i, projectile in ipairs(projectileStack) do
        local bulletLine = worldify(projectile.origin, projectile.destination)
        localAnimator.addDrawable({
        line = bulletLine,
        width = (projectile.width or 1) * projectile.lifetime/projectile.maxLifetime,
        fullbright = true,
        color = brighten(projectile.hitscanColor or {255,100,255}, 3)
        }, "Player-1")
    end
    
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

function worldify(alfa, beta)
    -- local playerPos = animationConfig.animationParameter("playerPos")
    local a = alfa
    local b = beta
    local xmax = world.size()[1]
    local dispvec = world.distance(b, a)
    if a[1] > xmax/2 then 
      a[1] = -1 * (xmax - a[1])
    end
    b = vec2.add(a, dispvec)
    return {a, b}
end

function brighten(rgb, amount)
    return redistribute_rgb(rgb[1] * amount, rgb[2] * amount, rgb[3] * amount)
end

function redistribute_rgb(r, g, b)
    local threshold = 254.999
    local m = math.max(r, g, b)
    if m <= threshold then
        return {r, g, b}
    end
    local total = r + g + b
    if total > 3 * threshold then
        return {threshold, threshold, threshold}
    end
    local x = (3 * threshold - total) / (3 * m - total)
    local gray = threshold - x * m
    return {gray + x * r, gray + x * g, gray + x * b}
end

-- https://stackoverflow.com/questions/141855/programmatically-lighten-a-color/141943#141943
--[[

def clamp_rgb(r, g, b):
    return min(255, int(r)), min(255, int(g)), min(255, int(b))

def redistribute_rgb(r, g, b):
    threshold = 255.999
    m = max(r, g, b)
    if m <= threshold:
        return int(r), int(g), int(b)
    total = r + g + b
    if total >= 3 * threshold:
        return int(threshold), int(threshold), int(threshold)
    x = (3 * threshold - total) / (3 * m - total)
    gray = threshold - x * m
    return int(gray + x * r), int(gray + x * g), int(gray + x * b)


--]]