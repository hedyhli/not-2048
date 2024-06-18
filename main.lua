function love.load()
    love.graphics.setNewFont(20)
    ROWS = 5
    Message = "Press a number key 1 to 5"
    Grid = {}
    --- @type number[] Next index for insertion, actually index by x.
    GridTops = {}
    Next = 2
    Max = 2
    for y = 1, ROWS do
        Grid[y] = {}
        GridTops[y] = 1
        for x = 1, ROWS do
            Grid[y][x] = 0
        end
    end

    --- Check for collapse at new insertion position. New tile is at Grid[y][x]
    --- @param x number
    --- @param y number
    function Collapse(x, y)
        local this = Grid[y][x]
        while y > 1 do
            local up = Grid[y-1][x]
            if up == this then
                this = up + this
                Max = math.max(Max, this)
                Grid[y-1][x] = this
                Grid[y][x] = 0
                GridTops[x] = GridTops[x] - 1
                y = y - 1
            else
                break
            end
        end
    end

    function UpdateNext()
        if Max > 4 then
            Next = 2 ^ math.random(math.log(Max, 2) - 1)
        end
    end
end

function love.draw()
    local tile_width = 90
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
    local col = 10
    for x = 1, ROWS do
        love.graphics.print(tostring(GridTops[x]), col, row)
        col = col + tile_width + 10
    end
    row = row + 20

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
            Collapse(col, row)
            UpdateNext()
            Message = "Yay"
        else
            if Grid[ROWS][col] == Next then
                Grid[ROWS][col] = Next * 2
                Collapse(col, ROWS)
                UpdateNext()
                Message = "Phew!"
            else
                Message = "Row is full and incollapsible!"
            end
        end
    else
        Message = "Invalid key"
    end
end
