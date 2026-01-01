local function create_player()
local file = 'soldier1'
local idle = love.graphics.newImage('images/' .. file ..'-idle.png')
local dead = love.graphics.newImage('images/' .. file ..'-dead.png')
local reload = love.graphics.newImage('images/' .. file ..'-reload.png')
player = {
        player_walk = 0,
        player_shoot = 0,
        player_grenade = 0,
        player_last_walked_at = 0,
        player_last_shoot_at = 0,
        player_last_grenade_at = 0,
        player_left_right_direction = "right",
        player_pose = idle,
        player_shooting = false,
        player_throwing_grenade = false,
        player_throw_grenade = false,
        temp_y = 0,
        catridge = 12,
        grenades = 1,
        grenade_power = 9,
        bullet_power = 1,
        fire_rate = 0.2,       -- seconds between shots
        fire_timer = 0, 
        file = file,
        score = 0,
        animation = {                  
            idle = idle,
            dead = dead,
            reload = reload,
            walk = {
            },
            shoot = {
            },
            grenade = {
            },
            walk_speed = 0.12,
            shoot_speed = 0.06,
            grenade_speed = 0.12
        },
        walk_speed = 200,
        position = {
            x = 10,
            y = (love.graphics.getHeight() / 2) - (idle:getHeight() / 2)
        },
        walk = function (self, dt, vx, vy) 
            local total_walks = #self.animation.walk            

            if self.player_walk == total_walks then
                self.player_walk = 0
            end
            if self.player_walk == 0 or self.player_last_walked_at >= self.animation.walk_speed then
                self.player_walk = self.player_walk + 1
                self.player_pose = self.animation.walk[self.player_walk]   
                self.player_last_walked_at = 0
            end

            self.position.x = self.position.x + vx * self.walk_speed * dt
            self.position.y = self.position.y + vy * self.walk_speed * dt
            self.player_last_walked_at = self.player_last_walked_at + dt

            if self.position.x <= 10 then
                self.position.x = 10
            elseif self.position.x >= love.graphics.getWidth() - self.player_pose:getWidth() * 2 then
                self.position.x = love.graphics.getWidth() - self.player_pose:getWidth() * 2
            end

            if self.position.y <= (love.graphics.getHeight() / 2) - (self.player_pose:getHeight() / 2) then
                self.position.y = (love.graphics.getHeight() / 2) - (self.player_pose:getHeight() / 2)
            elseif self.position.y >= love.graphics.getHeight() - self.player_pose:getHeight() * 2 then
                self.position.y = love.graphics.getHeight() - self.player_pose:getHeight() * 2
            end
        end,
        shoot = function(self, dt)
            if player.catridge > 0 then
                local total_shoots = #self.animation.shoot
                if self.player_shoot == total_shoots then
                    self.player_shoot = 0
                end
                if self.player_shoot == 0 or self.player_last_shoot_at >= self.animation.shoot_speed then
                    self.player_shoot = self.player_shoot + 1
                    self.player_pose = self.animation.shoot[self.player_shoot]   
                    self.player_last_shoot_at = 0
                end
                self.player_last_shoot_at = self.player_last_shoot_at + dt
                bullet_sound:play()
            elseif self.player_reloading then
                self.player_pose = self.animation.reload
                self.position.y = self.position.y - (self.player_pose:getHeight() - self.animation.idle:getHeight()) * 2
                self.player_reloading = false
            end
        end,
        throw = function(self, dt)
            if player.grenades > 0 then
                local total_shoots = #self.animation.grenade
                if self.player_grenade == total_shoots then
                    self.player_grenade = 0
                    self.player_throwing_grenade = false
                    self.player_throw_grenade = true
                end
                if self.player_grenade == 0 or self.player_last_grenade_at >= self.animation.grenade_speed then
                    self.player_grenade = self.player_grenade + 1
                    self.player_pose = self.animation.grenade[self.player_grenade]   
                    self.player_last_grenade_at = 0
                end
                self.player_last_grenade_at = self.player_last_grenade_at + dt
            else
                self.player_pose = self.animation.idle
            end
        end,
        draw = function(self)
            if self.player_left_right_direction == "right" then
                love.graphics.draw(self.player_pose, self.position.x, self.position.y, 0, 2, 2)
            elseif self.player_left_right_direction == "left" then
                love.graphics.draw(self.player_pose, self.position.x + idle:getWidth(), self.position.y, 0, -2, 2)
            end
        end
    }

    return player
end

return create_player