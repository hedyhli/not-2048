function love.load()
    love.graphics.setNewFont(20)
    ROWS = 5
    Message = "Press a number key 1 to 5"
    Grid = {}
    ---@alias rgb number[]
    ---@type number[] Next index for insertion, actually index by x.
    GridTops = {}
    Next = 2
    Max = 2
    Count = 0
    State = "begin"

    ---@alias hex string
    ---@alias color hex|rgb
    ---@alias colorInfo {bg: color, fg: boolean|rgb}
    ---{ HEX, is-fg? }
    ---@type { [number]: colorInfo }
    ColorPalette = {
        [2]   = {bg = "473335", fg = true},
        [4]   = {bg = "4E5D5E", fg = true},
        [8]   = {bg = "548687", fg = true},
        [16]  = {bg = "A89877", fg = false},
        [32]  = {bg = "FCAA67", fg = false},
        [64]  = {bg = "9582FF", fg = false},
        [128] = {bg = "2165BF", fg = true},
        [256] = {bg = "43CDC6", fg = false},
        [512] = {bg = "C996B3", fg = false},
        [1024] = {bg = "C95270", fg = false},
    }
    FallbackColor = {bg = {1, 1, 1}, fg = {0, 0, 0}}
    -- Convert hex to rgb
    for _, v in pairs(ColorPalette) do
        ---@type rgb
        local rgb = {}
        local hex = v.bg
        -- A little less cryptic than `for i = 1, 5, 2 do`
        for _, i in ipairs({1, 3, 5}) do
            ---@cast hex string
            rgb[#rgb + 1] = tonumber(hex:sub(i, i+1), 16) / 256
            i = i + 1
        end
        ---@as rgb
        v.bg = rgb
        ---@as rgb
        v.fg = v.fg and {1, 1, 1} or {0, 0, 0}
    end
    ColorPalette[0] = {bg = {54/256, 58/256, 78/256}, fg = {1, 1, 1}}

    ---@type { [number]: number }
    NextMap = {
        [2] = 2,
        [4] = 2,
        [8] = 2,
        [16] = 4,
        [32] = 8,
        [64] = 8,
        [128] = 16,
        [256] = 32,
        [512] = 64,
        [1024] = 64,
    }
    NextTooHigh = 64
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
        local cap = NextMap[Max] or NextTooHigh
        -- Next = 2 ^ math.random(math.log(cap))
        Next = cap
    end
end

function love.draw()
    local tile_width = 90
    local tile_padding = {15, math.floor(tile_width / 2 - 15)}

    local row = 10
    Count = 0
    for y = 1, ROWS do
        local col = 10
        for x = 1, ROWS do
            local fg = (ColorPalette[Grid[y][x]] or FallbackColor).fg
            local bg = (ColorPalette[Grid[y][x]] or FallbackColor).bg

            ---@cast bg rgb
            love.graphics.setColor(unpack(bg))
            love.graphics.rectangle('fill', col, row, tile_width, tile_width)

            ---@cast fg rgb
            love.graphics.setColor(unpack(fg))
            if Grid[y][x] > 0 then
                Count = Count + 1
                love.graphics.print(
                    tostring(Grid[y][x]),
                    col + tile_padding[1],
                    row + tile_padding[2]
                )
            end
            col = col + tile_width + 10
        end
        row = row + tile_width + 10
    end

    if Count == ROWS ^ 2 then
        State = "end"
        Message = "GAME OVER"
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
    if State == "end" then
        Message = "Game is already over. Get over it!"
        return
    end
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
