function love.load()
    Font = love.graphics.newFont("IBM_Plex_Sans/Regular.ttf", 20)
    FontHeight = Font:getHeight()

    TileFont = love.graphics.newFont("IBM_Plex_Sans/Medium.ttf", 26)
    TileFontHeight = TileFont:getHeight()

    love.graphics.setFont(Font)

    -- Game Params
    ROWS = 5
    ---@alias tile integer Positive power of 2
    ---@type tile
    Next = 2
    ---@type tile
    Max = 2

    Message = "Press a number key 1 to 5"
    ---@type "begin"|"animating"|"end"
    State = "begin"
    Count = 0

    ---@alias rgb number[]
    ---@alias hex string
    ---@alias colorInfo {bg: rgb, fg: rgb}
    ---@type { [tile|"fallback"]: colorInfo }
    TileColor = {}
    ---`{ HEX, is-fg? }`
    ---Interminably disappointed at love to use... not HEX, not even 256 integers,
    ---but *floating point* RGB for colors!
    ---@type { [tile]: {bg: hex, fg: boolean} }
    local color_tmp = {
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
    -- Convert hex to rgb
    for k, v in pairs(color_tmp) do
        ---@type rgb
        local rgb = {}
        local hex = v.bg
        -- A little less cryptic than `for i = 1, 5, 2 do`
        for _, i in ipairs({1, 3, 5}) do
            rgb[#rgb + 1] = tonumber(hex:sub(i, i+1), 16) / 256
            i = i + 1
        end
        ---@type colorInfo
        local converted = {}
        converted.bg = rgb
        converted.fg = v.fg and {1, 1, 1} or {0, 0, 0}
        TileColor[k] = converted
    end
    ---@type colorInfo
    ColumnColor = {bg = {34/256, 33/256, 35/256}, fg = {1, 1, 1}}
    ---For tiles larger than the maximum defined tile
    ---@type colorInfo
    TileColor.fallback = {bg = {1, 1, 1}, fg = {0, 0, 0}}

    ---Map of `Max` number to what the maximum `Next` allowed when producing
    ---the random `Next`. The maximum `Next` is inclusive.
    ---@type {[tile|"fallback"]: tile}
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
        fallback = 64
    }

    ---@type number[][]
    Grid = {}
    ---@type number[] The next index used for insertion.
    ---`GridTops[col]` is the row number of the next item inserted into `col`.
    GridTops = {}
    ---@type boolean[][] `GridAnim[row][col]` Indicates whether tile at `row`
    ---and `col` is currently in animation. Refer to `AnimSlideBegin`.
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
    ---@type number Understood as animation frame, used as the row of the tile
    ---to be placed, which is currently in vertical animation. See `love.draw`
    AnimSlideRow = -1
    ---@alias tileCoords {row: integer, col: integer}
    ---@type tileCoords
    ---The coordinates of the current tile in sliding animation (insertion).
    AnimSlide = {row = 0, col = 0}

    --- Check for collapse at new insertion position. Newly inserted tile at `Grid[y][x]`
    --- @param x integer
    --- @param y integer
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
        ---@type tile
        local cap = NextMap[Max] or NextMap.fallback
        Next = 2 ^ math.random(math.log(cap))
        -- INFO: Use this for quickly producing large tiles for debugging.
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
        AnimSlide.row, AnimSlide.col = 0, 0
        GridAnim[row][col] = false
        AnimSlideRow = -1
        -- HACK: Not sensibly resetting to previous values
        State = "begin"
        Message = "Yay"
        -- Motion of whatever collapsing of tiles must be done after the tile
        -- in question finishes making their animated entrance.
        Collapse(col, row)
        UpdateNext()
    end
end

function love.update(_)
    if State == "animating" then
        AnimSlideNext()
    end
end

function love.draw()
    local tile_width = 90
    local tile_padding_top = math.floor(tile_width / 2 - TileFontHeight / 2)
    -- I do not miss CSS flexbox
    local tile_gap = 10
    local radius = tile_width / 8

    ---Draw a single tile with the correct background and text.
    ---@param tr integer Grid\[`tr`\][tc]
    ---@param tc integer Grid[tr]\[`tc`\]
    ---@param row integer Draws at `row + tile_padding_top`
    ---@param col integer Where to draw
    local function draw_tile(tr, tc, row, col)
        local fg = (TileColor[Grid[tr][tc]] or TileColor.fallback).fg
        local bg = (TileColor[Grid[tr][tc]] or TileColor.fallback).bg

        love.graphics.setColor(unpack(bg))
        love.graphics.rectangle("fill", col, row, tile_width, tile_width, radius)

        row = row + tile_padding_top
        love.graphics.setColor(unpack(fg))
        love.graphics.printf(tostring(Grid[tr][tc]), TileFont, col, row, tile_width, "center")
    end

    --[[ Columns ]]--

    love.graphics.setColor(unpack(ColumnColor.bg))
    for y = 1, ROWS do
        love.graphics.rectangle(
            'fill',
            y * tile_gap + (y - 1) * tile_width,
            tile_gap,
            tile_width,
            (ROWS - 1) * tile_gap + ROWS * tile_width,
            radius
        )
    end

    --[[ Grid ]]--

    ---Top left y coordinate
    local anim_bottom = (ROWS - 1) * (tile_gap + tile_width) + math.floor(tile_width / 2)
    ---@type {row: integer, col: integer, tc: integer, tr: integer}?
    local anim = nil
    local row = tile_gap
    ---Number of occupied cells to determine whether game is over.
    Count = 0
    for tr = 1, ROWS do
        local col = tile_gap
        for tc = 1, ROWS do
            -- Draw the tile in animation after everything else to put it on
            -- the topmost layer.
            if GridAnim[tr][tc] then
                anim = { row = anim_bottom - AnimSlideRow, col = col, tr = tr, tc = tc }
                if anim.row < row then
                    anim = nil
                    AnimSlideEnd()
                else
                    goto continue
                end
            end

            if Grid[tr][tc] > 0 then
                Count = Count + 1
                draw_tile(tr, tc, row, col)
            end

            ::continue::
            col = col + tile_width + tile_gap
        end
        row = row + tile_width + tile_gap
    end

    if Count == ROWS ^ 2 and State ~= "end" then
        State = "end"
        -- Avoids overwriting new messages on top
        Message = "GAME OVER"
    end

    love.graphics.setColor(1, 1, 1)
    local col = tile_gap
    for x = 1, ROWS do
        love.graphics.printf(tostring(GridTops[x]), col, row, tile_width, "center")
        col = col + tile_width + tile_gap
    end
    row = row + tile_gap + FontHeight

    love.graphics.setColor(1, 1, 1)
    row = row + FontHeight
    love.graphics.print("Next: " .. tostring(Next), 10, row)
    row = row + FontHeight
    love.graphics.print(Message, 10, row)

    -- Animating tile must be above all others
    if anim then
        draw_tile(anim.tr, anim.tc, anim.row, anim.col)
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
            -- Defers collapsing & updating next to after animation finishes.
            -- See `AnimSlideEnd`.
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
        Message = "Invalid key lol, try harder"
    end
end
