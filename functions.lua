function calculate_distance(x1, y1, x2, y2) 
    local distance = math.sqrt((x2 - x1)^2 + (y2 - y1)^2)
    return distance
end

function calculate_angle(x1,y1, x2,y2) 
    return math.atan2(y2-y1, x2-x1)
end

function check_collision(a, b)
    return a.x < b.x + b.w and
           a.x + a.w > b.x and
           a.y < b.y + b.h and
           a.y + a.h > b.y
end

--Distance Between Two Points
--distance = math.sqrt((x2 - x1)^2 + (y2 - y1)^2)

--Angle From A to B
--angle = math.atan2(y2 - y1, x2 - x1)

--Move in a Direction
--x = x + math.cos(angle) * speed * dt
--y = y + math.sin(angle) * speed * dt

--AABB Collision Detection (Box vs Box)
--[[function check_collision(a, b)
    return a.x < b.x + b.w and
           a.x + a.w > b.x and
           a.y < b.y + b.h and
           a.y + a.h > b.y
end]]

--Normalize Direction (Shrink to 1 unit step)
--[[length = math.sqrt(dx^2 + dy^2)
nx = dx / length
ny = dy / length]]

--Stay Inside Window Bounds
--[[x = math.max(0, math.min(x, screen_width - sprite_width))
y = math.max(0, math.min(y, screen_height - sprite_height))]]

--Separation Between Entities
--[[if dist < desired_minimum then
    sep_x = sep_x + (dx / dist)
    sep_y = sep_y + (dy / dist)
end]]