local function create_bullet(x, y, angle)
    local bullet = {
        x = x,
        y = y,
        w = 5,
        h = 5,        
        speed = 300,
        angle = angle,
        load = function(self, dt)
            self.x = self.x + math.cos(self.angle) * self.speed * dt
            self.y = self.y + math.sin(self.angle) * self.speed * dt
        end,
        draw = function(self)
            love.graphics.rectangle("fill", self.x, self.y, self.w, self.h)
        end
    }

    return bullet
end

return create_bullet
