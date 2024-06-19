function love.load()
    Font = love.graphics.newFont("IBM_Plex_Sans/Regular.ttf", 20)
    BoldFont = love.graphics.newFont("IBM_Plex_Sans/Medium.ttf", 26)
    BoldFontHeight = BoldFont:getHeight()
    love.graphics.setFont(Font)
    FontHeight = Font:getHeight()
    ROWS = 5
    Message = "Press a number key 1 to 5"
    ---@alias rgb number[]
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
        [16]  = {bg = "A89877", fg = true},
        [32]  = {bg = "FCAA67", fg = false},
        [64]  = {bg = "9582FF", fg = true},
        [128] = {bg = "2165BF", fg = true},
        [256] = {bg = "43CDC6", fg = false},
        [512] = {bg = "C996B3", fg = false},
        [1024] = {bg = "C95270", fg = true},
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

    Grid = {}
    ---@type number[] Next index for insertion, actually index by x.
    GridTops = {}
    GridAnim = {}
    for y = 1, ROWS do
        Grid[y] = {}
        GridAnim[y] = {}
        GridTops[y] = 1
        for x = 1, ROWS do
            Grid[y][x] = 0
            GridAnim[y][x] = false
        end
    end
    AnimSlideRow = -1
    AnimSlide = {row = 0, col = 0}

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
        Next = 2 ^ math.random(math.log(cap))
        -- Next = cap
    end

    function AnimSlideBegin(row, col)
        GridAnim[row][col] = true
        AnimSlide = {row = row, col = col}
        AnimSlideRow = 0
        State = "animating"
    end

    function AnimSlideNext()
        AnimSlideRow = AnimSlideRow + 30
    end

    function AnimSlideEnd()
        local row, col = AnimSlide.row, AnimSlide.col
        GridAnim[row][col] = false
        AnimSlideRow = -1
        Collapse(col, row)
        State = "begin"
        Message = "Yay"
    end
end

function love.update(_)
    if AnimSlideRow >= 0 then
        AnimSlideNext()
    end
end

function love.draw()
    local tile_width = 90
    local tile_padding_top = math.floor(tile_width / 2 - BoldFontHeight / 2)
    local tile_gap = 10

    local bot_row = (ROWS - 1) * (tile_gap + tile_width)
    local has_anim = false
    local anim = {row = 0, col = 0, value = 0, bg = {}, fg = {}}

    local row = tile_gap
    Count = 0
    for y = 1, ROWS do
        local col = tile_gap
        for x = 1, ROWS do
            local fg = (ColorPalette[Grid[y][x]] or FallbackColor).fg
            local bg = (ColorPalette[Grid[y][x]] or FallbackColor).bg

            if GridAnim[y][x] then
                anim = {
                    row = bot_row - AnimSlideRow,
                    col = col,
                    value = tostring(Grid[y][x]),
                    bg = bg,
                    fg = fg,
                }
                if anim.row < row then
                    AnimSlideEnd()
                else
                    has_anim = true
                    love.graphics.setColor(unpack(ColorPalette[0].bg))
                    love.graphics.rectangle('fill', col, row, tile_width, tile_width)
                    goto continue
                end
            end

            ---@cast bg rgb
            love.graphics.setColor(unpack(bg))
            love.graphics.rectangle('fill', col, row, tile_width, tile_width)

            ---@cast fg rgb
            love.graphics.setColor(unpack(fg))
            if Grid[y][x] > 0 then
                Count = Count + 1
                love.graphics.printf(
                    tostring(Grid[y][x]),
                    BoldFont,
                    col,
                    row + tile_padding_top,
                    tile_width,
                    "center"
                )
            end
            ::continue::
            col = col + tile_width + tile_gap
        end
        row = row + tile_width + tile_gap
    end

    if Count == ROWS ^ 2 then
        State = "end"
        Message = "GAME OVER"
    end

    love.graphics.setColor(1, 1, 1)
    local col = tile_gap
    for x = 1, ROWS do
        love.graphics.printf(tostring(GridTops[x]), col, row, tile_width, "center")
        col = col + tile_width + tile_gap
    end
    row = row + math.floor(tile_width / 2)

    love.graphics.setColor(1, 1, 1)
    row = row + FontHeight
    love.graphics.print("Next: " .. tostring(Next), 10, row)
    row = row + FontHeight
    love.graphics.print(Message, 10, row)

    -- Animating tile must be above all others
    if has_anim then
        love.graphics.setColor(unpack(anim.bg))
        love.graphics.rectangle('fill', anim.col, anim.row, tile_width, tile_width)
        love.graphics.setColor(unpack(anim.fg))
        love.graphics.printf(anim.value, BoldFont, anim.col, anim.row + tile_padding_top, tile_width, "center")
    end
end

function love.keypressed(key)
    if State == "end" then
        Message = "Game is already over. Get over it!"
        return
    end
    if State == "animating" then
        Message = "Please wait for animation to finish"
        return
    end
    local col = tonumber(key)
    if col and col > 0 and col <= ROWS then
        local row = GridTops[col]
        if row <= ROWS then
            Grid[row][col] = Next
            GridTops[col] = row + 1
            UpdateNext()
            AnimSlideBegin(row, col)
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
