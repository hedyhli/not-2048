function love.load()
    love.graphics.setNewFont(20)
    ROWS = 5
    Message = "Press a number key 1 to 5"
    Grid = {}
    --- @type number[] Next index for insertion
    GridTops = {}
    Next = 2
    for y = 1, ROWS do
        Grid[y] = {}
        GridTops[y] = 1
        for x = 1, ROWS do
            Grid[y][x] = 0
        end
    end
end

function love.draw()
    local tile_width = 95
    local tile_color = {54/256, 58/256, 78/256}
    local tile_padding = {15, math.floor(tile_width / 2 - 15)}

    local row = 10
    for y = 1, ROWS do
        local col = 10
        for x = 1, ROWS do
            love.graphics.setColor(unpack(tile_color))
            love.graphics.rectangle('fill', col, row, tile_width, tile_width)
            love.graphics.setColor(1, 1, 1)
            if Grid[y][x] > 0 then
                love.graphics.print(tostring(Grid[y][x]), col + tile_padding[1], row + tile_padding[2])
            end
            col = col + tile_width + 10
        end
        row = row + tile_width + 10
    end

    love.graphics.setColor(1, 1, 1)
    row = row + 10
    love.graphics.print("Next: " .. tostring(Next), 10, row)
    row = row + 25
    love.graphics.print(Message, 10, row)
end

function love.keypressed(key)
    local col = tonumber(key)
    if col and col > 0 and col <= ROWS then
        local row = GridTops[col]
        if row <= ROWS then
            Grid[row][col] = Next
            GridTops[col] = row + 1
            Message = "Yay"
        else
            Message = "Row is full!"
        end
    else
        Message = "Invalid key"
    end
end
