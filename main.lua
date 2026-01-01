math.randomseed(os.time())
require 'functions'

function love.load()
    -- maximize window
    if love.system.getOS() == "Windows" then
        local ffi = require("ffi")

        ffi.cdef[[
            typedef void* HWND;
            HWND GetActiveWindow(void);
            bool ShowWindow(HWND hWnd, int nCmdShow);
        ]]

        local SW_MAXIMIZE = 3
        local hwnd = ffi.C.GetActiveWindow()
        ffi.C.ShowWindow(hwnd, SW_MAXIMIZE)
    end

    game_state = 'menu'
    game_paused = 0
    
    love.graphics.setDefaultFilter("nearest", "nearest")
    mouse_cursor = love.mouse.newCursor("images/cursor.png", hotspot_x, hotspot_y)

    title_sound = love.audio.newSource("sounds/title.wav", "static")
    play_title_sound = false

    game_bg = love.audio.newSource("sounds/game.wav", "stream")
    zombie_sound = love.audio.newSource("sounds/zombie.wav", "stream")
    play_game_sound = false

    bullet_sound = love.audio.newSource("sounds/bullet.mp3", "static")
    death_sound = love.audio.newSource("sounds/death.wav", "static")
    explosion_sound = love.audio.newSource("sounds/explosion.wav", "static")

    backgrounds = {
        love.graphics.newImage('images/castle.jpg'),
        love.graphics.newImage('images/dead-forest.jpg'),
        love.graphics.newImage('images/terrace.jpg'),
        love.graphics.newImage('images/throne-room.jpg'),
        --love.graphics.newImage('images/background.jpg')
    }

    bullet_icon = love.graphics.newImage('images/bullet.png')
    grenade_icon = love.graphics.newImage('images/grenade.png')
    
    create_player = require 'player'

    player_type = 1

    spawn_player()

    create_zombie = require 'zombie'

    create_bullet = require 'bullet'

    create_grenade = require 'grenade'
end

function love.update(dt)
    if game_state == 'start' then
        if not player.player_shooting and not player.player_throwing_grenade then
            player.temp_y = player.position.y
            -- PLAYER MOVEMENT
            local vx, vy = 0, 0

            if love.keyboard.isDown('d') then
                vx = vx + 1
                player.player_left_right_direction = "right"
            end
            if love.keyboard.isDown('a') then
                vx = vx - 1
                player.player_left_right_direction = "left"
            end
            if love.keyboard.isDown('w') then
                vy = vy - 1
            end
            if love.keyboard.isDown('s') then
                vy = vy + 1
            end

            if vx ~= 0 or vy ~= 0 then
                local d = math.sqrt(vx^2 + vy^2)
                vx = vx / d
                vy = vy / d
                player:walk(dt, vx, vy)
            else
                player.player_last_walked_at = 0
                player.player_walk = 0
                player.player_pose = player.animation.idle
            end 
        elseif player.player_throwing_grenade then
            player:throw(dt)
        elseif player.player_shooting then
            player:shoot(dt)
        end

        -- Auto-fire when mouse is held
        if player.player_shooting and player.fire_timer <= 0 and player.catridge > 0 then
            local bx, by, angle

            if player_type == 1 then
                by = player.position.y + (player.player_pose:getHeight() * 2 / 2) - 15
            else
                by = player.position.y + 15
            end

            if player.player_left_right_direction == "right" then
                bx = player.position.x + player.player_pose:getWidth() * 2 + 5
                angle = calculate_angle(bx, by, love.graphics.getWidth(), by)
            else
                bx = player.position.x - player.player_pose:getWidth() + 5
                angle = calculate_angle(bx, by, 0, by)
            end

            table.insert(bullets, create_bullet(bx, by, angle))
            player.catridge = player.catridge - 1
            if player.catridge == 0 then
                player.player_reloading = true
            end
            player.fire_timer = player.fire_rate
        end

        -- Reduce fire cooldown
        if player.fire_timer > 0 then
            player.fire_timer = player.fire_timer - dt
        end

        -- load grenade
        if player.player_throw_grenade then
            local bx, by, angle

            by = player.position.y - 5

            if player.player_left_right_direction == "right" then
                bx = player.position.x + 5
                target_x = player.position.x + 600
                target_y = player.position.y + player.player_pose:getHeight() * 2
                angle = calculate_angle(bx, by, target_x, target_y)
            else
                bx = player.position.x + 5
                target_x = player.position.x - 600
                target_y = player.position.y + player.player_pose:getHeight() * 2    
                angle = calculate_angle(bx, by, target_x, target_y)
            end

            table.insert(grenades, create_grenade(bx, by, target_x, target_y))

            player.grenades = player.grenades - 1
            player.player_throw_grenade = false
        end

        for i = #bullets, 1, -1 do
            bullets[i]:load(dt)

            -- Optional: remove bullets off screen
            if bullets[i].x > love.graphics.getWidth() or bullets[i].x < 0 then
                table.remove(bullets, i)
            end
        end

        -- grenades detection
        for i = #grenades, 1, -1 do
            local g = grenades[i]
            g:load(dt)

            -- If already exploded, count down to remove
            if g.exploded then
                g.explode_timer = g.explode_timer - dt
                if g.explode_timer <= 0 then
                    table.remove(grenades, i)
                end
            else
                local exploded = false

                -- 1. Check direct zombie hit
                for j = #zombies, 1, -1 do
                    local z = zombies[j]

                    local sx = z.sx or 2
                    local sy = z.sy or 2

                    local z_hitbox = {
                        x = z.position.x,
                        y = z.position.y,
                        w = z.zombie_pose:getWidth() * sx,
                        h = z.zombie_pose:getHeight() * sy
                    }

                    local grenade_hitbox = {
                        x = g.x,
                        y = g.y,
                        w = g.r,
                        h = g.r
                    }

                    if check_collision(z_hitbox, grenade_hitbox) then
                        exploded = true
                        break
                    end
                end

                -- 2. Check if grenade reached target y
                if not exploded and g.y >= g.target_y then
                    exploded = true
                end

                -- 3. Trigger explosion
                if exploded then
                    local explosion_hitbox = {
                        x = g.x - g.explosion_radius,
                        y = g.y - g.explosion_radius,
                        w = g.explosion_radius * 2,
                        h = g.explosion_radius * 2
                    }

                    for j = #zombies, 1, -1 do
                        local z = zombies[j]

                        local sx = z.sx or 2
                        local sy = z.sy or 2

                        local z_hitbox = {
                            x = z.position.x,
                            y = z.position.y,
                            w = z.zombie_pose:getWidth() * sx,
                            h = z.zombie_pose:getHeight() * sy
                        }

                        if check_collision(z_hitbox, explosion_hitbox) then
                            z.lives = z.lives - player.grenade_power
                            if z.lives <= 0 then
                                table.remove(zombies, j)
                                player.score = player.score + 1
                            else
                                z.hit_timer = 0.3
                            end
                        end
                    end

                    g.exploded = true
                    g.explode_timer = 0.3
                end

                -- 4. Remove grenade if it flies offscreen
                if g.x < 0 or g.x > love.graphics.getWidth() or g.y < 0 or g.y > love.graphics.getHeight() then
                    table.remove(grenades, i)
                end
            end
        end


        -- bullet and zombie detection
        for i = #zombies, 1, -1 do
            local z = zombies[i]
            for j = #bullets, 1, -1 do
                local sx = z.sx or 2
                local sy = z.sy or 2
                local b = bullets[j]
                local x = { x = z.position.x, y = z.position.y, w = z.zombie_pose:getWidth() * sx, h = z.zombie_pose:getHeight() * sy }
                local y = { x = b.x, y = b.y, w = b.w, h = b.w }

                if check_collision(x, y) then
                    table.remove(bullets, j)

                    if z.lives <= 0 then
                        table.remove(zombies, i)
                        player.score = player.score + 1
                    else
                        z.lives = z.lives - math.ceil((player.bullet_power + current_wave) / 3)
                        z.hit_timer = 0.3 -- flicker duration in seconds
                    end

                    break
                end
            end
        end        

        for i = 1, #zombies do
            local z = zombies[i]

            -- ✅ Flicker logic here
            if z.hit_timer and z.hit_timer > 0 then
                z.hit_timer = z.hit_timer - dt
                if z.hit_timer <= 0 then
                    z.opacity = 1
                else
                    z.opacity = z.opacity == 1 and 0 or 1
                end
            end

            -- Move toward player
            -- zombie foot
            local sx = z.sx or 2
            local sy = z.sy or 2
            local flip = z.position.x >= player.position.x
            local zx = flip
                and (z.position.x + (z.zombie_pose:getWidth() * sx) / 2)
                or (z.position.x + (z.zombie_pose:getWidth() * sx) - (z.zombie_pose:getWidth() * sx) / 2)
            local zy = z.position.y + (z.zombie_pose:getHeight() * sy)

            -- player foot
            local px = player.position.x + (player.player_pose:getWidth() * 2) / 2
            local py = player.position.y + (player.player_pose:getHeight() * 2)

            -- now calculate real angle foot-to-foot
            local angle = calculate_angle(zx, zy, px, py)

            local separation_x, separation_y = 0, 0

            -- Separation from other zombies
            for j = 1, #zombies do
                if i ~= j then
                    local other = zombies[j]
                    local dx = z.position.x - other.position.x
                    local dy = z.position.y - other.position.y
                    local dist = calculate_distance(z.position.x, z.position.y, other.position.x, other.position.y)

                    local min_distance = 40 -- minimum distance between zombies
                    if dist < min_distance and dist > 0 then
                        separation_x = separation_x + (dx / dist)
                        separation_y = separation_y + (dy / dist)
                    end

                end
            end

            -- Apply separation steering
            local sep_strength = 100
            local final_angle_x = math.cos(angle) + separation_x * sep_strength
            local final_angle_y = math.sin(angle) + separation_y * sep_strength
            local final_angle = math.atan2(final_angle_y, final_angle_x)

            z:load(dt, final_angle)
        end

        for i = 1, #zombies do
            local z = zombies[i]
            -- player feet
            local px = player.position.x + (player.player_pose:getWidth() * 2) / 2
            local py = player.position.y + (player.player_pose:getHeight() * 2)

            -- zombie feet
            local sx = z.sx or 2
            local sy = z.sy or 2
            local flip = z.position.x >= player.position.x
            local zx = flip
                and (z.position.x + (z.zombie_pose:getWidth() * sx) / 2)
                or (z.position.x + (z.zombie_pose:getWidth() * sx) - (z.zombie_pose:getWidth() * sx) / 2)
            local zy = z.position.y + (z.zombie_pose:getHeight() * sy)

            local dist = calculate_distance(zx, zy, px, py)

            if dist <= 30 then
                player.player_pose = player.animation.dead
                player.position.y  = player.position.y + player.animation.idle:getHeight() * 2
                death_sound:play()
                game_state = 'over'
                break
            end
            --[[if player_hit(z) then
                player.player_pose = player.animation.dead
                player.position.y  = player.position.y + player.animation.idle:getHeight() * 2
                death_sound:play()
                game_state = 'over'
                break            -- one hit is enough
            end]]
        end

        if #zombies == 0 then
            current_wave = current_wave + 1
            spawn_wave(current_wave)
        end
    end
end

function love.draw()
    if game_state == 'start' or game_state == 'paused' or game_state == 'exit' or game_state == 'over' then
        title_sound:stop()
        if not play_game_sound then
            game_bg:setVolume(0.5)
            game_bg:setLooping(true)
            game_bg:play()

            zombie_sound:setLooping(true)
            zombie_sound:play()
            play_game_sound = true
        end
        love.mouse.setCursor(nil)
        love.graphics.draw(background, 0, 0)
        love.graphics.printf("WAVE "..current_wave, love.graphics.newFont(30), 0, 10, love.graphics.getWidth(), "center")
        love.graphics.printf("KILLS: "..player.score, love.graphics.newFont(12), 0, 45, love.graphics.getWidth(), "center")

        -- ✅ draw player and zombies in correct Y order
        local drawables = {}

        -- Add zombies
        for i = 1, #zombies do
            local z = zombies[i]

            local sx = z.sx or 2
            local sy = z.sy or 2

            local z_feet_y = z.position.y + z.zombie_pose:getHeight() * sy
            table.insert(drawables, {entity = z, y = z_feet_y})
        end

        -- Add bullets
        for i = #bullets, 1, -1  do
            table.insert(drawables, {entity = bullets[i], y = bullets[i].y})
        end

        -- Draw grenades (add this with other drawables or just after bullets)
        for i = 1, #grenades do
            table.insert(drawables, {entity = grenades[i], y = grenades[i].y})
        end

        -- Add player
        local player_feet_y = player.position.y + player.player_pose:getHeight() * 2
        table.insert(drawables, {entity = player, y = player_feet_y})

        -- Sort by Y value (lower is behind)
        table.sort(drawables, function(a, b)
            return a.y < b.y
        end)

        -- Draw in order
        for i = 1, #drawables do
            drawables[i].entity:draw()
        end

        for i = 1, player.catridge do
            love.graphics.draw(bullet_icon, i * 25, 50, 0, 0.38, 0.38)
        end

        for i = 1, player.grenades do
            love.graphics.draw(grenade_icon, i * 38, 110, 0, 0.5, 0.5)
        end

        if game_state == 'paused' then
            love.graphics.setColor(1, 1, 1, 0.8)
            love.graphics.printf("PAUSED", love.graphics.newFont(50), 0, love.graphics.getHeight() / 2.5 - 25, love.graphics.getWidth(), "center")
            love.graphics.setColor(1, 1, 1, 1)
        end

        if game_state == 'exit' then
            love.graphics.setColor(1, 1, 1, 0.8)
            love.graphics.printf("EXIT? (Y/N)", love.graphics.newFont(50), 0, love.graphics.getHeight() / 2.5 - 25, love.graphics.getWidth(), "center")
            love.graphics.setColor(1, 1, 1, 1)
        end

        if game_state == 'over' then 
            play_game_sound = false
            play_title_sound = false
            love.graphics.printf("Game Over", love.graphics.newFont(50), 0, love.graphics.getHeight() / 2 - 25, love.graphics.getWidth(), "center")
            love.graphics.printf("Press Enter to Return to Menu", love.graphics.newFont(40), 0, love.graphics.getHeight() / 1.6 - 20, love.graphics.getWidth(), "center")
            love.graphics.printf("Kills: " .. player.score, love.graphics.newFont(18), 0, love.graphics.getHeight() / 1.48 - 9, love.graphics.getWidth(), "center")
            if player.score > score_read() then
                love.filesystem.write("score.txt", tostring(player.score))
            end
        end

    elseif game_state == 'menu' then
         play_game_sound = false
         game_bg:stop()
         zombie_sound:stop()
         if not play_title_sound then
            title_sound:play()
            play_title_sound = true
         end         
         love.mouse.setCursor(mouse_cursor)
         love.graphics.draw(background, 0, 0)
         love.graphics.printf("ZOMBIE WAVES", love.graphics.newFont(50), 0, love.graphics.getHeight() / 3 - 25, love.graphics.getWidth(), "center" )
         love.graphics.printf("v1.2", love.graphics.newFont(20), love.graphics.getWidth() / 1.6, love.graphics.getHeight() / 3 - 8, love.graphics.getWidth(), "left", math.pi / -6 )
         love.graphics.setColor(25/255, 200/255, 121/255)
         love.graphics.rectangle("fill", love.graphics.getWidth()/2 - 125, love.graphics.getHeight() / 2.5, 250, 50)
         love.graphics.setColor(1,1,1)
         love.graphics.setFont(love.graphics.newFont(40))
         love.graphics.print("START", love.graphics.getWidth() / 2 - 60, love.graphics.getHeight() / 2.5 + 3)
         love.graphics.setColor(25/255, 200/255, 121/255)
         love.graphics.rectangle("fill", love.graphics.getWidth()/2 - 125, love.graphics.getHeight() / 2, 250, 50)
         love.graphics.setColor(1,1,1)
         love.graphics.print("EXIT", love.graphics.getWidth() / 2 - 40, love.graphics.getHeight() / 2 + 3)
         love.graphics.printf("Developed by Faraz Ahmed", love.graphics.newFont(24), 0, love.graphics.getHeight() / 1.65, love.graphics.getWidth(), "center")
         love.graphics.printf("www.farazthewebguy.com", love.graphics.newFont(16), 0, love.graphics.getHeight() / 1.52, love.graphics.getWidth(), "center")
         score = score_read()
         love.graphics.printf("High Score: " .. score, love.graphics.newFont(16), 0, love.graphics.getHeight() / 1.45, love.graphics.getWidth(), "center")
         love.graphics.printf("W = Up, A = Left, S = Down, D = Right, Mouse 1 = Fire, R = Reload, G = Grenade, Space = Pause, F = Fullscreen", love.graphics.newFont(20), 0, love.graphics.getHeight() / 1.35, love.graphics.getWidth(), "center")
         love.graphics.setFont(love.graphics.newFont(16))
    elseif game_state == 'selection'  then
        love.graphics.draw(backgrounds[2], 0, 0)
        player_1 = love.graphics.newImage('images/soldier1-idle.png')
        player_2 = love.graphics.newImage('images/soldier2-idle.png')
        love.graphics.printf("EXPERT SHOOTER", love.graphics.newFont(30), love.graphics.getWidth() * 0.25, love.graphics.getHeight() / 2 - player_1:getHeight() - 150, love.graphics.getWidth(), "left")
        love.graphics.printf("Max 40 Bullets. Starts with 2 Grenades", love.graphics.newFont(16), love.graphics.getWidth() * 0.25 - 18, love.graphics.getHeight() / 2 - player_1:getHeight() - 100, love.graphics.getWidth(), "left")
        love.graphics.printf("Press 1 to Select", love.graphics.newFont(25), love.graphics.getWidth() * 0.25 + 30, love.graphics.getHeight() / 2 - player_1:getHeight() - 70, love.graphics.getWidth(), "left")
        love.graphics.printf("GRENADE EXPERT", love.graphics.newFont(30), love.graphics.getWidth() * 0.55, love.graphics.getHeight() / 2 - player_1:getHeight() - 150, love.graphics.getWidth(), "left")
        love.graphics.printf("Max 20 Bullets. Starts with 5 Grenades", love.graphics.newFont(16), love.graphics.getWidth() * 0.55 - 18, love.graphics.getHeight() / 2 - player_1:getHeight() - 100, love.graphics.getWidth(), "left")
        love.graphics.printf("Press 2 to Select", love.graphics.newFont(25), love.graphics.getWidth() * 0.55 + 30, love.graphics.getHeight() / 2 - player_1:getHeight() - 70, love.graphics.getWidth(), "left")
        love.graphics.draw(player_1, love.graphics.getWidth() * 0.33, love.graphics.getHeight() / 2 + player_1:getHeight(), 0, 2)
        love.graphics.draw(player_2, love.graphics.getWidth() - love.graphics.getWidth() * 0.33, love.graphics.getHeight() / 2 + player_2:getHeight(), 0, -2, 2)
        --local b = { x = love.graphics.getWidth() * 0.33, y = love.graphics.getHeight() / 2 + player_1:getHeight() , w = player_1:getWidth() * 2, h = player_1:getHeight() * 2 }
        --local c = { x =  love.graphics.getWidth() - love.graphics.getWidth() * 0.33 - player_2:getWidth() * 2, y = love.graphics.getHeight() / 2 + player_2:getHeight() , w = player_2:getWidth() * 2, h = player_2:getHeight() * 2 }
        --love.graphics.rectangle("line", b.x, b.y, b.w, b.h)
        --love.graphics.rectangle("line", c.x, c.y, c.w, c.h)
    end

    --love.graphics.print(#bullets, 0, 0)
    if player.catridge == 0 and game_state ~= 'over'  and game_state ~= 'menu' then
        love.graphics.printf("RELOAD (Press R)", love.graphics.newFont(50), 0, love.graphics.getHeight() / 2 - 25, love.graphics.getWidth(), "center")
    end
end

function love.mousepressed(x, y, button)
    if button == 1 and game_state == 'start' then
        player.player_shooting = true
        if (player.catridge == 0) then
            player.player_reloading = true
        end

    elseif button == 1 and game_state == 'menu' then
        local a = { x = x, y = y, w = 1, h = 1 }
        local b = { x = love.graphics.getWidth() / 2 - 125, y = love.graphics.getHeight() / 2.5, w = 250, h = 50 }
        local c = { x = love.graphics.getWidth() / 2 - 125, y = love.graphics.getHeight() / 2, w = 250, h = 50 }

        if check_collision(a, b) then
             -- reset all game data before starting
             game_state = 'selection'
            --game_state = 'start'             
            --spawn_player()
            --spawn_wave(current_wave)
        elseif check_collision(a, c) then
            love.event.quit()
        end
    elseif button == 1 and game_state == 'selection' then
        local a = { x = x, y = y, w = 1, h = 1 }
        local b = { x = love.graphics.getWidth() * 0.33, y = love.graphics.getHeight() / 2 + player_1:getHeight() , w = player_1:getWidth() * 2, h = player_1:getHeight() * 2 }
        local c = { x =  love.graphics.getWidth() - love.graphics.getWidth() * 0.33 - player_2:getWidth() * 2, y = love.graphics.getHeight() / 2 + player_2:getHeight() , w = player_2:getWidth() * 2, h = player_2:getHeight() * 2 }

        if check_collision(a, b) then
             -- reset all game data before starting
            player_type = 1
            game_state = 'start'
            spawn_player()
            spawn_wave(current_wave)
        elseif check_collision(a, c) then
             -- reset all game data before starting
            player_type = 2
            game_state = 'start'
            spawn_player()
            spawn_wave(current_wave)
        end 
    elseif button == 1 and game_state == 'over' then
        game_state = 'menu'        
    end
end

function love.mousereleased(x, y, button)
    if button == 1 and game_state == 'start' then
        player.player_shooting = false -- allow movement again
        player.position.y = player.temp_y
    end
end

function love.keypressed(key, scancode, isrepeat)
    if key == "r" and game_state == "start" and player.catridge == 0 then
        if player_type == 1 then
            player.catridge = 13 + current_wave * 2
            if player.catridge > 40 then
                player.catridge = 40
            end
        elseif player_type == 2 then
            player.catridge = 6 + current_wave * 2
            if player.catridge > 20 then
                player.catridge = 20
            end
        end
        player.position.y = player.temp_y
    elseif key == "return" and game_state == "over" then
        game_state = "menu"
    elseif key =="space" and (game_state == "start" or  game_state == "paused") then
        game_state = game_state == 'paused' and 'start' or 'paused'
    elseif key =="escape" and (game_state == "start" or  game_state == "paused" or game_state == "exit") then
        game_state = game_state == 'exit' and 'start' or 'exit'
    elseif key == "y" and game_state == 'exit' then
        play_game_sound = false
        play_title_sound = false
        if player.score > score_read() then
            love.filesystem.write("score.txt", tostring(player.score))
        end
        game_state = 'menu'
    elseif key == "n" and game_state == 'exit' then
        game_state = 'start'
    elseif key == "g" and game_state == 'start' and player.grenades > 0 then
        player.player_throwing_grenade = true
    elseif (key == "1" or key == "2") and game_state == 'selection' then
        player_type = tonumber(key)
        game_state = 'start'
        spawn_player()
        spawn_wave(current_wave)
    end

    if key == "f" then
		fullscreen = not fullscreen
		love.window.setFullscreen(fullscreen)
	end
end

function spawn_wave(wave)
    --zombies_to_spawn = math.floor((wave * 10) * 0.75)
    --zombies_lives = math.ceil((wave * 3) / 1.5)
    --zombies_walk_speed = 25 + math.ceil((wave * 25) * 0.20)
    if current_background > #backgrounds then
        current_background = 1
    end
    background = backgrounds[current_background]    
    current_background = current_background + 1
    
    zombies_to_spawn = math.floor((wave * 10) * 0.33)
    zombies_lives = math.ceil((wave * 3) / 2.5)
    zombies_walk_speed = 13 + math.ceil((wave * 10) * 0.10)

    if player_type == 1 then
        player.grenades = 2
        player.grenade_power = player.grenade_power + 1
        if player.grenade_power > 20 then player.grenade_power = 20 end
    elseif player_type == 2 then
        player.grenades = 5
        player.grenade_power = player.grenade_power + 1
        if player.grenade_power > 40 then player.grenade_power = 40 end
    end
    
    for i = 1, zombies_to_spawn do
        local z = create_zombie()
        zombie_type = math.random(1, 3)
        c = zombie_type == 2 and 12 or 10
        for j = 1, c do
            z.animation.idle = love.graphics.newImage('images/' .. 'zombie' .. zombie_type .. '-idle.png')
            table.insert(z.animation.walk, love.graphics.newImage('images/' .. 'zombie' .. zombie_type .. '-walk' .. j .. '.png'))
        end
        z.position.x = math.random(love.graphics.getWidth(), love.graphics.getWidth() + 50)
        z.position.y = math.random(love.graphics.getHeight() / 2, love.graphics.getHeight() + 50)
        z.lives = zombies_lives
        z.walk_speed = zombies_walk_speed
        table.insert(zombies, z)
    end

    -- add a quick zombie after every 3 levels
    if wave % 3 == 0 then
        local z = create_zombie()
        c = 10
        zombie_type = 4
        for j = 1, c do
            z.animation.idle = love.graphics.newImage('images/' .. 'zombie' .. zombie_type .. '-idle.png')
            table.insert(z.animation.walk, love.graphics.newImage('images/' .. 'zombie' .. zombie_type .. '-walk' .. j .. '.png'))
        end
        z.position.x = math.random(love.graphics.getWidth(), love.graphics.getWidth() + 50)
        z.position.y = math.random(love.graphics.getHeight() / 2, love.graphics.getHeight() + 50)
        z.lives = zombies_lives + 15
        z.walk_speed = zombies_walk_speed + 20
        table.insert(zombies, z)
    end
    -- add a quick zombie after every 5 levels
    if wave % 5 == 0 then
        local z = create_zombie()
        c = 10
        zombie_type = 5
        for j = 1, c do
            z.animation.idle = love.graphics.newImage('images/' .. 'zombie' .. zombie_type .. '-idle.png')
            table.insert(z.animation.walk, love.graphics.newImage('images/' .. 'zombie' .. zombie_type .. '-walk' .. j .. '.png'))
        end
        z.position.x = math.random(love.graphics.getWidth(), love.graphics.getWidth() + 50)
        z.position.y = math.random(love.graphics.getHeight() / 2, love.graphics.getHeight() + 50)
        z.lives = current_wave * 10
        z.walk_speed = zombies_walk_speed + 50
        z.sx = 0.25
        z.sy = 0.25
        table.insert(zombies, z)
    end
end 

function spawn_player()
    current_wave = 1
    current_background = 1
    background = backgrounds[current_background]

    player = create_player()
    local gc = 0
    local wc = 0
    if player_type == 1 then
        player.catridge = 15
        gc = 9
        wc = 7
    else
        player.catridge = 8
        gc = 8
        wc = 8
    end
    for i=1,wc do
        table.insert(player.animation.walk, love.graphics.newImage('images/' .. 'soldier' .. player_type .. '-walk' .. i .. '.png'))
    end
    for i=1,4 do
        table.insert(player.animation.shoot, love.graphics.newImage('images/' .. 'soldier' ..player_type .. '-shoot' .. i .. '.png'))
    end
    for i=1,gc do
        table.insert(player.animation.grenade, love.graphics.newImage('images/' .. 'soldier' ..player_type .. '-grenade' .. i .. '.png'))
    end

    zombies = {}
    bullets = {}
    grenades = {}
end

function score_read()
    if love.filesystem.getInfo("score.txt") then
        local saved_score_string = love.filesystem.read("score.txt")
        local saved_score = tonumber(saved_score_string) or 0
        return saved_score
    else
        return 0
    end
end

function player_hit(zombie)
    local sx = zombie.sx or 2
    local sy = zombie.sy or 2

    local z_box = {
        x = zombie.position.x,
        y = zombie.position.y,
        w = zombie.zombie_pose:getWidth()  * sx,
        h = zombie.zombie_pose:getHeight() * sy
    }

    local p_box = {
        x = player.position.x,
        y = player.position.y,
        w = player.player_pose:getWidth()  * 2,
        h = player.player_pose:getHeight() * 2
    }

    return check_collision(z_box, p_box)
end