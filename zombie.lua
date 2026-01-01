-- zombie.lua
local function create_zombie()
    local file = 'zombie1'
    local idle = love.graphics.newImage('images/' .. file .. '-idle.png')

    local zombie = {
        current_zombie_walk = 0,
        zombie_last_walked_at = 0,
        zombie_pose = idle,
        file = file,
        lives = 3,
        opacity = 1,
        hit_timer = 0,
        boss = false,
        sx = 2,
        sy = 2,
        facing = "left", -- default facing direction
        animation = {
            idle = idle,
            walk = {},
            speed = 0.12       
        },        
        walk_speed = 30,
        position = {
            x = love.graphics.getWidth() - idle:getWidth() - 10,
            y = (love.graphics.getHeight() / 2) - (idle:getHeight() / 2)
        },
        load = function (self, dt, angle) 
            local total_walks = #self.animation.walk

            if self.current_zombie_walk == total_walks then
                self.current_zombie_walk = 0
            end
            if self.current_zombie_walk == 0 or self.zombie_last_walked_at >= self.animation.speed then
                self.current_zombie_walk = self.current_zombie_walk + 1
                self.zombie_pose = self.animation.walk[self.current_zombie_walk]   
                self.zombie_last_walked_at = 0
            end

            self.position.x = self.position.x + math.cos(angle) * self.walk_speed * dt
            self.position.y = self.position.y + math.sin(angle) * self.walk_speed * dt
            self.zombie_last_walked_at = self.zombie_last_walked_at + dt

            -- Correct facing update based on visible width
            local visible_width = self.zombie_pose:getWidth() * (self.sx or 2)
            local dx = player.position.x - self.position.x

            if math.abs(dx) > visible_width / 2 then
                self.facing = dx > 0 and "right" or "left"
            end
        end,

        draw = function(self)
            love.graphics.setColor(1, 1, 1, self.opacity or 1)
            local sx = self.sx or 2
            local sy = self.sy or 2
            local offset_x = self.zombie_pose:getWidth() * sx

            if self.facing == "right" then
                love.graphics.draw(self.zombie_pose, self.position.x, self.position.y, 0, sx, sy)
            else
                love.graphics.draw(self.zombie_pose, self.position.x + offset_x, self.position.y, 0, -sx, sy)
            end

            love.graphics.setColor(1, 1, 1, 1)

            -- Draw bounding box for debugging
            --[[local bbox_x = self.position.x
            local bbox_y = self.position.y
            local bbox_w = self.zombie_pose:getWidth() * sx
            local bbox_h = self.zombie_pose:getHeight() * sy

            love.graphics.setColor(1, 0, 0, 0.4)
            love.graphics.rectangle("line", bbox_x, bbox_y, bbox_w, bbox_h)
            love.graphics.setColor(1, 1, 1)]]
        end
    }

    return zombie
end

return create_zombie
