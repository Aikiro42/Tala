function update()
    localAnimator.clearDrawables()
    localAnimator.clearLightSources()

    local starPos = animationConfig.animationParameter("starPos")
    
    for i, pic in ipairs({"luz.png", "vi.png", "minda.png"}) do
        localAnimator.addDrawable({
            image = "/items/active/weapons/melee/abilities/spear/talavisage/" .. pic,
            position = {starPos[i][1], starPos[i][2]},
            fullbright = true,
        }, "Player" .. starPos[i][3])
    end

end
