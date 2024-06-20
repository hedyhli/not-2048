-- TODO:
-- - Rewrite entrance anim
-- - Set AnimCell.delta intelligently
-- - Put Next into Model
-- - Check either left or right horizontal collapse
-- - Check both collapse
-- - Profit!

-- Global:
--   Grid, GetTile
-- Model:
--   AnimMerge
--   AnimEntrance

---@alias tileValue integer Positive power of 2
---@alias rgb number[] Float, fraction fof 255
---@alias hex string
---@alias colorInfo {bg: rgb, fg: rgb}
---@alias tileColorMap { [tileValue|"fallback"]: colorInfo }

---Convert HEX -> RGB and is-white? -> RGB
---Initializes the global `TileColor`.
--
---Interminably disappointed at love to use... not HEX, not even 256 integers,
---but *floating point* RGB for colors!
---@param hex_map { [tileValue]: {bg: hex, fg: boolean} }
---@param fallback_color colorInfo For tiles of value not included here.
function MakeTileColorTable(hex_map, fallback_color)
    ---@type tileColorMap
    TileColor = {}
    for k, v in pairs(hex_map) do
        ---@type rgb
        local rgb = {}
        local hex = v.bg
        -- A little less cryptic than `for i = 1, 5, 2 do`
        for _, i in ipairs({1, 3, 5}) do
            rgb[#rgb + 1] = tonumber(hex:sub(i, i+1), 16) / 255
            i = i + 1
        end
        ---@type colorInfo
        local converted = {}
        converted.bg = rgb
        converted.fg = v.fg and {1, 1, 1} or {0, 0, 0}
        TileColor[k] = converted
    end
    TileColor.fallback = fallback_color
end

---@type Tile The 2, 4, 8 etc blocks with their unique values & colors
local Tile = {}

---@class Tile
---@field value tileValue
---@field text string
---@field fg rgb
---@field bg rgb

-- WARN: Should NOT be used directly! Use `Tile.get` instead.
---@param val tileValue
---@param style colorInfo
function Tile:new(val, style)
    return setmetatable({
        value = val,
        text = tostring(val),
        bg = style.bg,
        fg = style.fg
    }, { __index = Tile })
end

---@alias tileMap {[tileValue]: Tile}
---Initialize the global `GetTile` (used by `Tile.get`)
---Requires `TileColor` (initialized by `MakeTileColorTable`)
function Tile.init_GetTile()
    ---@type tileMap
    GetTile = {}
    for t, style in pairs(TileColor) do
        if t ~= "fallback" then
            ---@cast t tileValue
            GetTile[t] = Tile:new(t, style)
        end
    end
end

---Get a Tile with its text & style by value.
---Requires `GetTile` (`Tile.init_GetTile()`), `TileColor` (`MakeTileColorTable()`)
---@param value tileValue
---@return Tile
function Tile.get(value)
    if GetTile[value] == nil then
        -- Tile value too high; save it to prevent this checking again next
        -- time.
        GetTile[value] = Tile:new(value, TileColor.fallback)
    end
    return GetTile[value]
end

---@type Cell Information about the visual representation of a `Tile`
local Cell = {}

---@alias Coord {tc: integer, tr: integer}
---@alias Position {row: integer, col: integer}

---@class Cell
---@field row integer Position
---@field col integer Position
---@field tr integer Coords
---@field tc integer Coords
---@field tile Tile The styling, text, and value

-- WARN: Should not ever be used after `InitGrid`.
---@param tile Tile
---@param coord Coord
---@param pos Position
function Cell:new(tile, coord, pos)
    return setmetatable({
        tile = tile,
        tr = coord.tr,
        tc = coord.tc,
        row = pos.row,
        col = pos.col,
    }, { __index = Cell })
end

---Wraps `Cell:new`
function Cell:new_empty(coord, pos)
    return Cell:new(Tile:new(0, {}), coord, pos)
end

---@alias CellGrid Cell[][]

---Initialize global `Grid`
function InitGrid()
    ---@type CellGrid
    Grid = {}
    local row = TileGap
    for tr = 1, ROWS do
        Grid[tr] = {}
        local col = TileGap
        for tc = 1, ROWS do
            Grid[tr][tc] = Cell:new_empty(
                {tr = tr, tc = tc},
                {row = row, col = col}
            )
            col = col + TileWidth + TileGap
        end
        row = row + TileWidth + TileGap
    end
end

---@class AnimCell A moving cell
local AnimCell = {}

---@class AnimCell
---@field target Cell Reference to Grid[coord.tr][coord.tc]. The cell to be modified
---@field dest Position Destination Cell.row+col (SHOULD BE IMMUTABLE)
---@field initial Position
---@field delta {dr: integer, dc: integer} Added to row/col of `dest` (NOT coords)
---@field done boolean

---Create an AnimCell instance using from and to coords.
-- NOTE: Not to be used directly! Use `AnimMerge:new` instead
---@param coord Coord Current position
---@param dest_coord Coord Destination position
function AnimCell:new(coord, dest_coord)
    local dest_cell = Grid[dest_coord.tr][dest_coord.tc]
    local target = Grid[coord.tr][coord.tc]
    return setmetatable({
        target = target,
        dest = {row = dest_cell.row, col = dest_cell.col},
        initial = {row = target.row, col = target.col},
        delta = {dr = -10, dc = 0},
        done = false,
    }, { __index = AnimCell })
end

---Update position of `self.target`, return whether this should be the last update.
-- NOTE: Note to be called directly! Use `AnimMerge:next` instead to update in batch.
---@return boolean ended Animation has ended
function AnimCell:next()
    local dr, dc = self.delta.dr, self.delta.dc
    local nrow, ncol = self.target.row + dr, self.target.col + dc

    if dr > 0 and (nrow > self.dest.row) then
        return true
    end
    if dr < 0 and (nrow < self.dest.row) then
        return true
    end
    if dc > 0 and (ncol > self.dest.row) then
        return true
    end
    if dc < 0 and (ncol < self.dest.row) then
        return true
    end

    -- Move it!
    self.target.row, self.target.col = nrow, ncol
    return false
end

---@type AnimMerge A merge-tile animation for collapses. SINGLETON
local AnimMerge = {}

---@class AnimMerge
---@field anim_cells AnimCell[] Animation information
---@field final Cell The final state of the `Cell` which the `cells` have merged into.
---@field new_tile Tile The tile to put into the `final` Cell after animation finishes
---@field active boolean Whether animation is running and should call `:next`

---Create the single AnimMerge instance to be used throughout the game.
function AnimMerge:new()
    return setmetatable({
        anim_cells = {},
        final = nil,
        new_tile = nil,
        active = false,
    }, { __index = AnimMerge })
end

---@param sources Coord[]
---@param final Cell
---@param new_tile Tile
function AnimMerge:init(sources, final, new_tile)
    local dest_coord = {tr = final.tr, tc = final.tc}

    ---@type AnimCell[]
    local anim_cells = {}
    for _, src_coord in ipairs(sources) do
        table.insert(anim_cells, AnimCell:new(src_coord, dest_coord))
    end

    self.anim_cells = anim_cells
    self.final = final
    self.new_tile = new_tile
    self.active = true
end

---@return boolean done Whether this animation set is fully complete.
---The client should call `AnimMerge:finish` if this method returns true.
-- WARN: Client reponsible for checking whether animation is active before calling
-- this function!
--
-- # Example
-- ```lua
-- if AM.active then
--   local done = AM.next()
--   if done then
--       AM.finish()
--       Collapse(AM.final.tc, AM.final.tr)
--   end
-- end
-- ```
function AnimMerge:next()
    local done = false
    for _, ac in pairs(self.anim_cells) do
        -- All should be assumed to end at the same time.
        done = ac:next()
        ac.done = done
    end
    return done
end

---Set destination Cell to have the new tile, make those moving cells empty tiles.
---Client responsible for calling `Collapse(self.final.tc, self.final.tr)`.
---@return AnimCell[] finished_cells
function AnimMerge:finish()
    self.final.tile = self.new_tile
    self.active = false
    local finished = {}
    local finished_keys = {}
    for k, ac in pairs(self.anim_cells) do
        if ac.done then
            ac.target.tile = Tile:new(0, {})
            ac.target.row = ac.initial.row
            ac.target.col = ac.initial.col
            table.insert(finished, ac)
            table.insert(finished_keys, k)
        end
    end
    for _, key in ipairs(finished_keys) do
        self.anim_cells[key] = nil
    end
    return finished
end


function love.load()
    Font = love.graphics.newFont("IBM_Plex_Sans/Regular.ttf", 20)
    FontHeight = Font:getHeight()

    TileFont = love.graphics.newFont("IBM_Plex_Sans/Medium.ttf", 26)
    TileFontHeight = TileFont:getHeight()

    love.graphics.setFont(Font)

    -- Game Params
    ROWS = 5
    ---@type tileValue
    Next = 2
    ---@type tileValue
    Max = 2
    TileWidth = 90
    TileGap = 10

    ---Computed
    Columns = {
        top = TileGap,
        bot = ROWS * (TileGap + TileWidth),
        cols = {}
    }
    for y = 1, ROWS do
        local col_end = y * (TileGap + TileWidth)
        Columns.cols[y] = {col_end - TileWidth, col_end}
    end

    Message = "Press a number key 1 to 5"
    ---@type "begin"|"animating"|"end"
    State = "begin"
    Count = 0

    --[[ Tiles & Colors ]]--

    MakeTileColorTable({
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
    }, {bg = {1, 1, 1}, fg = {0, 0, 0}})

    Tile.init_GetTile()

    ---@type colorInfo
    ColumnColor = {bg = {34/256, 33/256, 35/256}, fg = {1, 1, 1}}

    --[[ Next ]]--

    ---Map of `Max` number to what the maximum `Next` allowed when producing
    ---the random `Next`. The maximum `Next` is inclusive.
    ---@type {[tileValue|"fallback"]: tileValue}
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

    --[[ Grid ]]--

    InitGrid()
    ---@type number[] The next index used for insertion.
    ---`GridTops[col]` is the row number of the next item inserted into `col`.
    GridTops = {}
    ---@type boolean[][] `GridAnim[tr][tc]` Indicates whether tile at `row`
    ---and `col` is currently in entrance animation. Refer to `AnimSlideBegin`.
    GridAnim = {} -- TODO
    for tr = 1, ROWS do
        GridAnim[tr] = {}
        GridTops[tr] = 1
        for tc = 1, ROWS do
            GridAnim[tr][tc] = false
        end
    end

    --[[ Entrance animation ]]--
    ---@type number Understood as animation frame, used as the row of the tile
    ---to be placed, which is currently in vertical animation. See `love.draw`
    AnimSlideRow = -1
    ---@type Position
    ---The coordinates of the current tile in sliding animation (insertion).
    AnimSlide = {row = 0, col = 0}

    --[[ Model ]]--
    -- Model. Structure of globals that might change.
    Md = {
        AnimMerge = AnimMerge:new(),
        -- TODO
        AnimEntrance = nil,
        Next = 0,
    }

    --- Check for collapse at new insertion position. Newly inserted tile at `Grid[tr][tc]`
    ---@param tc integer
    ---@param tr integer
    ---@return boolean has_collapse
    function Collapse(tc, tr)
        -- This will only check a single collapse at a time.

        -- Checks
        -- 1. X Single up
        -- 2. - 2 Horz   @ #
        -- 3. -        # @
        -- 4. - 3 Horz # @ #
        -- 5. - Triangle #
        --               @ #
        -- 6. - 4        #
        --             # @ #  -- Not possible under current AnimMerge impl!
        -- All These must move the Right/Left tiles up,
        -- For those columns that moved, check for collapse again.

        local this = Grid[tr][tc]
        if tr <= 1 then
            return false
        end

        --[[ 1 ]]--
        local up = Grid[tr-1][tc]
        if up.tile.value == this.tile.value then
            local new_tile = Tile.get(this.tile.value * 2)
            Max = math.max(Max, new_tile.value)
            GridTops[tc] = GridTops[tc] - 1

            Md.AnimMerge:init({{tr = tr, tc = tc}}, up, new_tile)
            return true
        end
        return false
    end

    function UpdateNext()
        ---@type tileValue
        local cap = NextMap[Max] or NextMap.fallback
        ---@type tileValue
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
        if not Collapse(col, row) then
            UpdateNext()
        end
    end

    ---@param col integer
    function InsertTileAt(col)
        if State == "end" then
            Message = "Game is already over. Get over it!"
            return
        end
        if State == "animating" or Md.AnimMerge.active then
            Message = "Please wait for animation to finish"
            return
        end

        local row = GridTops[col]
        if row <= ROWS then
            Grid[row][col].tile = Tile.get(Next)
            GridTops[col] = row + 1
            -- Defers collapsing & updating next to after animation finishes.
            -- See `AnimSlideEnd`.
            AnimSlideBegin(row, col)
            Message = "Yay"
        else
            if Grid[ROWS][col].tile.value == Next then
                Grid[ROWS][col].tile = Tile.get(Next * 2)
                Collapse(col, ROWS)
                Message = "Phew!"
            else
                Message = "Row is full and incollapsible!"
            end
        end
    end
end

function love.update(_)
    if State == "animating" then
        AnimSlideNext()
    end
    if Md.AnimMerge.active then
        local done = Md.AnimMerge:next()
        if done then
            -- Several AnimMerges or singleton?
            -- CONFLICT:
            -- :finish() sets new_tile to AnimMerge.final Cell
            -- - Horizontal merges can trigger multiple subsequent merges
            -- - Left might have a merge going on at the same time as a right
            --   merge. Should they each have a :finish()?
            --   Because now Left will have a different new_tile/final than
            --   Right.
            local finished = Md.AnimMerge:finish()
            local has_collapse = Collapse(Md.AnimMerge.final.tc, Md.AnimMerge.final.tr)
            -- for _, ac in ipairs(finished) do
            --     has_collapse = Collapse(ac.target.tc, ac.target.tr)
            -- end
            if not has_collapse then
                UpdateNext()
            end
        end
    end
end

function love.draw()
    -- I do not miss CSS flexbox
    local tile_padding_top = math.floor(TileWidth / 2 - TileFontHeight / 2)
    local radius = TileWidth / 8

    ---Draw a single tile with the correct background and text.
    ---@param tile Tile The tile to draw
    ---@param row integer Draws at `row + tile_padding_top`
    ---@param col integer Where to draw
    local function draw_tile(tile, row, col)
        love.graphics.setColor(unpack(tile.bg))
        love.graphics.rectangle("fill", col, row, TileWidth, TileWidth, radius)

        row = row + tile_padding_top
        love.graphics.setColor(unpack(tile.fg))
        love.graphics.printf(tile.text, TileFont, col, row, TileWidth, "center")
    end

    --[[ Columns ]]--

    love.graphics.setColor(unpack(ColumnColor.bg))
    for y = 1, ROWS do
        love.graphics.rectangle(
            'fill',
            y * TileGap + (y - 1) * TileWidth,
            TileGap,
            TileWidth,
            (ROWS - 1) * TileGap + ROWS * TileWidth,
            radius
        )
    end

    --[[ Grid ]]--

    ---Top left y coordinate
    local anim_bottom = (ROWS - 1) * (TileGap + TileWidth) + math.floor(TileWidth / 2)
    ---@type {row: integer, col: integer, tile: Tile}?
    local anim = nil
    ---Number of occupied cells to determine whether game is over.
    -- TODO: Not actually true because some filled rows can still be collapsible
    Count = 0
    for tr = 1, ROWS do
        for tc = 1, ROWS do
            local cell = Grid[tr][tc]
            -- Draw the tile in animation after everything else to put it on
            -- the topmost layer.
            if GridAnim[tr][tc] then
                anim = {
                    row = anim_bottom - AnimSlideRow,
                    col = cell.col,
                    tile = cell.tile,
                }
                if anim.row < cell.row then
                    anim = nil
                    AnimSlideEnd()
                else
                    goto continue
                end
            end

            if cell.tile.value ~= 0 then
                Count = Count + 1
                draw_tile(cell.tile, cell.row, cell.col)
            end
            ::continue::
        end
    end
    local row = (TileGap + TileWidth) * ROWS

    if Count == ROWS ^ 2 and State ~= "end" then
        State = "end"
        -- Avoids overwriting new messages on top
        Message = "GAME OVER"
    end

    love.graphics.setColor(1, 1, 1)
    local col = TileGap
    for x = 1, ROWS do
        love.graphics.printf(tostring(GridTops[x]), col, row, TileWidth, "center")
        col = col + TileWidth + TileGap
    end
    row = row + TileGap + FontHeight

    love.graphics.setColor(1, 1, 1)
    row = row + FontHeight
    love.graphics.print("Next: " .. tostring(Next), 10, row)
    row = row + FontHeight
    love.graphics.print(Message, 10, row)

    -- Animating tile must be above all others
    if anim then
        draw_tile(anim.tile, anim.row, anim.col)
    end
end

function love.keypressed(key)
    local col = tonumber(key)
    if col and col > 0 and col <= ROWS then
        InsertTileAt(col)
    else
        Message = "Invalid key lol, try harder"
    end
end

function love.mousereleased(col, row, button, _, _)
    if button ~= 1 then
        Message = "Not the right button"
        return
    end
    if row < Columns.top or row > Columns.bot then
        Message = "Mouse out of range"
        return
    end
    local tc = 0
    for i, c in ipairs(Columns.cols) do
        if c[1] < col and col < c[2] then
            tc = i
            break
        end
    end
    if tc ~= 0 then
        InsertTileAt(tc)
    else
        Message = "Mouse out of range"
    end
end
