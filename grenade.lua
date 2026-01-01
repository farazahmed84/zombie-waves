--[[local function create_grenade(x, y, angle, target_y)
    local grenade = {
        x = x,
        y = y,
        r = 10,
        explosion_radius = 100,
        speed = 300,
        angle = angle,
        target_y = target_y,
        exploded = false,
        explode_timer = 0,
        power = 9,
        load = function(self, dt)
            if not self.exploded then
                self.x = self.x + math.cos(self.angle) * self.speed * dt
                self.y = self.y + math.sin(self.angle) * self.speed * dt
            end
        end,

        draw = function(self)
            if not self.exploded then
                love.graphics.draw(grenade_icon, self.x, self.y, 0, 0.25, 0.25, grenade_icon:getWidth()/2, grenade_icon:getHeight()/2)
            else
                love.graphics.setColor(1, 0, 0, 0.4)
                love.graphics.rectangle("fill", self.x - self.explosion_radius, self.y - self.explosion_radius, self.explosion_radius * 2, self.explosion_radius * 2)
                love.graphics.setColor(1, 1, 1)
                explosion_sound:play()
            end
        end
    }

    return grenade
end

return create_grenade]]
local function create_grenade(x, y, target_x, target_y)
    local grenade = {
        start_x = x,
        start_y = y,
        target_x = target_x,
        target_y = target_y,
        x = x,
        y = y,
        r = 10,
        t = 0,
        duration = 1,
        explosion_radius = 100,
        exploded = false,
        explode_timer = 0.3,
        arc_height = 150,

        load = function(self, dt)
            if not self.exploded then
                self.t = self.t + dt / self.duration
                if self.t >= 1 then
                    self.t = 1
                    self.exploded = true
                    self.explode_timer = 0.3
                end

                self.x = self.start_x + (self.target_x - self.start_x) * self.t
                local sin_t = math.sin(math.pi * self.t)
                self.y = self.start_y + (self.target_y - self.start_y) * self.t - self.arc_height * sin_t
            else
                self.explode_timer = self.explode_timer - dt
            end
        end,

        draw = function(self)
            if not self.exploded then
                love.graphics.draw(grenade_icon, self.x, self.y, 0, 0.25, 0.25, grenade_icon:getWidth() / 2, grenade_icon:getHeight() / 2)
            else
                love.graphics.setColor(1, 0, 0, 0.4)
                love.graphics.rectangle("fill", self.x - self.explosion_radius, self.y - self.explosion_radius, self.explosion_radius * 2, self.explosion_radius * 2)
                love.graphics.setColor(1, 1, 1)
                explosion_sound:play()
            end
        end
    }

    return grenade
end

return create_grenade