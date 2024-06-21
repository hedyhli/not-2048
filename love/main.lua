----[[ Classes and helper functions ]]---------------------

---Whether all cell's tile values are equal
---@param items Cell[]
local function all_eq(items)
    local prev = items[1].tile.value
    for _, v in ipairs(items) do
        if v.tile.value ~= prev then
            return false
        end
        prev = v.tile.value
    end
    return true
end

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

----[[ Basic classes ]] -----------------------------------
--[[

CLASS Tile - Instantiated once for each 2, 4, 8 etc. It represents the value of
a Cell. All known tiles are instantiated during startup using the
`init_GetTile` classmethod. All new tiles (either from newly inserted Cells, or
from merges) are fetched using `Tile.get`. Each tile has its own background and
foreground color.

CLASS Cell - Instanciated once for each cell in the ROWS-by-ROWS grid. (See
param ROWS in `love.load`). It's the visual representation of a tile. All known
Cells are instantiated once during startup in the `InitGrid` function. Cells
are never created nor destroyed for the rest of the game.

The Grid is a 2D array of Cells. It is indexed by tr, the row number, and tc,
the column number. Each cell also knows of its tr and tc within the grid. Each
cell has fields row and col, which represents the top-left position of the cell
in pixels. These two fields are changed when a cell is in animation. The Tile
field changes during merges and insertion. Other fields are readonly.

--]]

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
---@field o_r integer Offset for animations
---@field o_c integer Off set for animations
---@field tr integer Coords
---@field tc integer Coords
---@field enlarge number Pixels added onto widths
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
        enlarge = 0,
        o_r = 0,
        o_c = 0,
    }, { __index = Cell })
end

---Compares tr, tc
---@param cell Cell
function Cell:eq(cell)
    return cell.tr == self.tr and cell.tc == self.tc
end

---@alias CellGrid Cell[][]

---Initialize global `Grid`
function InitGrid()
    ---@type CellGrid
    Grid = {}
    local row = TileGap
    for tr = 1, ROWS do
        Grid[tr] = {}
        local col = Margins
        for tc = 1, ROWS do
            Grid[tr][tc] = Cell:new(
                Tile:new(0, {}),
                {tr = tr, tc = tc},
                {row = row, col = col}
            )
            col = col + TileWidth + TileGap
        end
        row = row + TileWidth + TileGap
    end
end

----[[ ANIMATIONS ]]---------------------------------------
--[[

The classes all have the 'Ani' prefix in their name.

CLASS AniCell - the most basic class, which is responsible for moving a single
cell. It should not be used directly. Opt for AniMove *even if there's only one
cell to move*.

CLASS AniMove - for moving one or more cells towards a single destination at
the same time, then sets the new tile at the destination cell. It manages its
own list of AniCell instances, calling AniCell.next on each, simultaneously.
Most likely not to be called anywhere for within application functions. It is
used by AniSeq.

CLASS AniEnlarge - another basic class, but for the cell size scaling effect,
typically when a new merged cell is created after a series of AniMove's.

CLASS AniSeq - the singleton (for now) that interfaces directly with the rest
of the application. It represents a single Collapse operation which requires
one AniEnlarge and a few AniMove's. It is instantiated once during `love.load`
and newly reset each time a `Collapse` is found. Animation frames are advanced
by calling the :next() method by `love.update`.

Ani is an abstract class (or interface) that is required for AniSeq to call
either AniEnlarge OR AniMove the same way. All "Ani*" classes implements the
Ani interface. (But for now, only AniMove and AniEnlarge is required to
implement it.)

CLASS AniEntrance - a standalone animation by itself used for moving a cell
from the bottom to its new position for newly inserted cells. It is used
directly and advanced by `love.update`.

--]]

---@class AniCell A moving cell
local AniCell = {}

---@class AniCell
---@field target Cell Reference to Grid[coord.tr][coord.tc]. The cell to be modified
---@field dest Cell Destination Cell.row+col (AniCell does not change it,
--but it should be changed outside of AniCell during window resize!)
---@field delta {dr: integer, dc: integer} Added to o_r, o_c of `target`
---@field done boolean

---Create an AniCell instance using from and to coords.
-- NOTE: Not to be used directly! Use `AniMove:new` instead
---@param coord Coord Current position
---@param dest_coord Coord Destination position
function AniCell:new(coord, dest_coord)
    local dest = Grid[dest_coord.tr][dest_coord.tc]
    local target = Grid[coord.tr][coord.tc]
    local delta = {dr = 0, dc = 0}

    local mag = math.floor(TileWidth / 15)

    if dest.col ~= target.col then
        local diff = dest.col - target.col
        delta.dc = diff < 0 and -mag or mag
    end
    if dest.row ~= target.row then
        local diff = dest.row - target.row
        delta.dr = diff < 0 and -mag or mag
    end

    return setmetatable({
        target = target,
        dest = dest,
        delta = delta,
        done = false,
    }, { __index = AniCell })
end

---Update position of `self.target`, return whether this should be the last update.
-- NOTE: Note to be called directly! Use `AniMove:next` instead to update in batch.
---@return boolean ended Animation has ended
function AniCell:next()
    local dr, dc = self.delta.dr, self.delta.dc
    local new_or, new_oc = self.target.o_r + dr, self.target.o_c + dc
    local new_row, new_col = self.target.row + new_or, self.target.col + new_oc

    if dr > 0 and (new_row > self.dest.row) then
        return true
    end
    if dr < 0 and (new_row < self.dest.row) then
        return true
    end
    if dc > 0 and (new_col > self.dest.col) then
        return true
    end
    if dc < 0 and (new_col < self.dest.col) then
        return true
    end

    -- Apply new offset
    self.target.o_r, self.target.o_c = new_or, new_oc
    return false
end

---@class Ani
---@field active boolean
---@field next fun(self: Ani): boolean
---@field finish fun(self: Ani): any

---@type AniMove A merge-tile animation for collapses. SINGLETON
local AniMove = {}

---@class AniMove: Ani
---@field anim_cells AniCell[] Animation information
---@field final Cell The `Cell` which the `anim_cells` have merged into.
---@field new_tile Tile The tile to put into the `final` Cell after animation finishes
---@field active boolean Whether animation is running and should call `:next`

---@param sources Coord[]
---@param final Cell
---@param new_tile Tile
function AniMove:new(sources, final, new_tile)
    local dest_coord = {tr = final.tr, tc = final.tc}

    ---@type AniCell[]
    local anim_cells = {}
    for _, src_coord in ipairs(sources) do
        table.insert(anim_cells, AniCell:new(src_coord, dest_coord))
    end

    return setmetatable({
        anim_cells = anim_cells,
        final = final,
        new_tile = new_tile,
        active = true,
    }, { __index = AniMove })
end

---@return boolean done Whether this animation set is fully complete.
---The client should call `AniMove:finish` if this method returns true.
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
function AniMove:next()
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
---@return AniCell[] finished_cells
function AniMove:finish()
    self.final.tile = self.new_tile
    self.active = false
    local finished = {}
    local finished_keys = {}
    for k, ac in pairs(self.anim_cells) do
        if ac.done then
            ac.target.tile = Tile:new(0, {})
            ac.target.o_r = 0
            ac.target.o_c = 0
            table.insert(finished, ac)
            table.insert(finished_keys, k)
        end
    end
    for _, key in ipairs(finished_keys) do
        self.anim_cells[key] = nil
    end
    return finished
end

---@type AniEntrance
local AniEntrance = {}

---@class AniEntrance
---@field target Cell The actual cell (reference) that is moved
---@field active boolean

---Initialize the singleton.
function AniEntrance:new()
    return setmetatable({
        dest = nil,
        target = nil,
        active = false,
    }, { __index = AniEntrance })
end

---@param cell Cell To be inserted
function AniEntrance:init(cell)
    local target = cell
    -- Position of bottomost cell + half of tilewidth further bottom.
    target.o_r = Columns.bot - math.floor(TileWidth / 2) - target.row

    self.target = target
    self.active = true
    State = "animating"
end

---Client responsible for calling `:finish()` if done
---@return boolean done
function AniEntrance:next()
    local new_or = self.target.o_r - math.floor(TileWidth / 2)
    if new_or < 0 then
        return true
    end
    self.target.o_r = new_or
    return false
end

function AniEntrance:finish()
    self.active = false
    self.target.o_r = 0
    -- HACK: Not sensibly resetting to previous values
    State = "begin"
    Message = ""
end

---@type AniEnlarge
local AniEnlarge = {}

---@class AniEnlarge: Ani
---@field cell Cell
---@field active boolean
---@field delta number

---@param cell Cell
function AniEnlarge:new(cell)
    return setmetatable({
        cell = cell,
        active = true,
        delta = 1,
    }, { __index = AniEnlarge })
end

---@return boolean done
function AniEnlarge:next()
    self.cell.enlarge = self.cell.enlarge + self.delta
    if self.cell.enlarge > 4 then
        self.delta = - self.delta
    end
    if self.cell.enlarge < 0 then
        return true
    end
    return false
end

function AniEnlarge:finish()
    self.cell.enlarge = 0
    self.active = false
end

---@type AniSeq
local AniSeq = {}

---@class AniSeq: Ani
---@field active boolean
---@field seq Ani[] No two happen simultaneously
---@field data any

function AniSeq:new()
    return setmetatable({
        active = false,
        seq = {}
    }, { __index = AniSeq })
end

---Initialize the animation sequence of a vertical collapse
---@param up Cell
---@param this Cell
---@param new_tile Tile
function AniSeq:init_vert(up, this, new_tile, data)
    self.seq = {
        AniMove:new({{tr = this.tr, tc = this.tc}}, up, new_tile),
        AniEnlarge:new(up),
    }
    self.active = true
    self.data = data
end

---Initialize the animation sequence of a horizontal collapse from one side
---@param source Coord
---@param to Cell
---@param new_tile Tile
function AniSeq:init_horz_one(source, to, new_tile, data)
    self.seq = {
        AniMove:new({source}, to, new_tile),
        AniEnlarge:new(to),
    }
    -- Move whole column on the left/right up
    for tr = source.tr + 1, ROWS do
        local cell = Grid[tr][source.tc]
        local up = Grid[tr-1][source.tc]
        if cell.tile.value > 0 then
            table.insert(
                self.seq,
                AniMove:new({{tr = cell.tr, tc = cell.tc}}, up, cell.tile)
            )
        else
            break
        end
    end
    self.active = true
    self.data = data
end

---Initialize the animation sequence of a horizontal collapse from BOTH sides
---1. both left and right merges into the new cell
---2. new cell applies `new_tile`
---3. cells after both left and right files up (in sequence for now)
---@param left Cell
---@param to Cell
---@param right Cell
---@param new_tile Tile
---@param data any
function AniSeq:init_horz_both(left, to, right, new_tile, data)
    self.seq = {
        AniMove:new({left, right}, to, new_tile),
        AniEnlarge:new(to),
    }
    -- Move both columns up
    for tr = left.tr + 1, ROWS do
        local cell = Grid[tr][left.tc]
        local up = Grid[tr-1][left.tc]
        if cell.tile.value > 0 then
            table.insert(
                self.seq,
                AniMove:new({{tr = cell.tr, tc = cell.tc}}, up, cell.tile)
            )
        else
            break
        end
    end
    for tr = right.tr + 1, ROWS do
        local cell = Grid[tr][right.tc]
        local up = Grid[tr-1][right.tc]
        if cell.tile.value > 0 then
            table.insert(
                self.seq,
                AniMove:new({{tr = cell.tr, tc = cell.tc}}, up, cell.tile)
            )
        else
            break
        end
    end
    self.active = true
    self.data = data
end

---Initialize the animation sequence of a triangle collapse.
---1. the side and up cells all merge into the new cell
---2. the new cell applies `new_tile`
---3. the new cell moves upwards into `up`
---4. cells below `side` files up
---@param side Cell Any side
---@param to Cell
---@param up Cell
---@param new_tile Tile
function AniSeq:init_triangle(side, to, up, new_tile, data)
    self.seq = {
        AniMove:new({side, up}, to, new_tile),
        AniEnlarge:new(to),
    }
    -- Move left/right column up
    for tr = side.tr + 1, ROWS do
        local cell = Grid[tr][side.tc]
        local side_up = Grid[tr-1][side.tc]
        if cell.tile.value > 0 then
            table.insert(self.seq, AniMove:new(
                {{tr = cell.tr, tc = cell.tc}},
                side_up,
                cell.tile
            ))
        else
            break
        end
    end
    table.insert(
        self.seq,
        AniMove:new({{tr = to.tr, tc = to.tc}}, up, new_tile)
    )
    self.active = true
    self.data = data
end

---Initialize the animation sequence of a diamond collapse.
---1. up, left, and right all merge into the new cell
---2. the new cell applies the `new_tile`
---3. the new cell moves up (into up)
---4. cells below `left` files up
---5. cells below `right` files up
---@param left Cell
---@param up Cell
---@param right Cell
---@param to Cell
---@param new_tile Tile
---@param data any
function AniSeq:init_diamond(left, up, right, to, new_tile, data)
    self.seq = {
        AniMove:new({left, right, up}, to, new_tile),
        AniEnlarge:new(to),
    }
    -- Move left/right column up
    for tr = left.tr + 1, ROWS do
        local cell = Grid[tr][left.tc]
        local left_up = Grid[tr-1][left.tc]
        if cell.tile.value > 0 then
            table.insert(self.seq, AniMove:new(
                {{tr = cell.tr, tc = cell.tc}},
                left_up,
                cell.tile
            ))
        else
            break
        end
    end
    for tr = right.tr + 1, ROWS do
        local cell = Grid[tr][right.tc]
        local right_up = Grid[tr-1][right.tc]
        if cell.tile.value > 0 then
            table.insert(self.seq, AniMove:new(
                {{tr = cell.tr, tc = cell.tc}},
                right_up,
                cell.tile
            ))
        else
            break
        end
    end
    table.insert(
        self.seq,
        AniMove:new({{tr = to.tr, tc = to.tc}}, up, new_tile)
    )
    self.active = true
    self.data = data
end

---@return boolean done
function AniSeq:next()
    local done = false
    for _, ani in ipairs(self.seq) do
        done = not ani.active
        if ani.active then
            if ani:next() then
                ani:finish()
            else
                break
            end
        end
    end
    return done
end

function AniSeq:finish()
    self.active = false
end

----[[ LOVE ]] --------------------------------------------
--[[

M|TTTT|G|TTTT|G|TTTT|G|TTTT|G|TTTT|M
 
M|TTTT|G|TTTT|G|TTTT|G|TTTT|G|TTTT|M
 
M|TTTT|G|TTTT|G|TTTT|G|TTTT|G|TTTT|M
 
M|TTTT|G|TTTT|G|TTTT|G|TTTT|G|TTTT|M
 
M|TTTT|G|TTTT|G|TTTT|G|TTTT|G|TTTT|M
 
M|TTTT|G|TTTT|G|TTTT|G|TTTT|G|TTTT|M

Text text

--]]

function RecalculateDimensions()
    local _, _, fullW, fullH = love.window.getSafeArea()
    local minMargins = 5
    -- Maximum possible width to fit all cells
    local tile_max_width = math.floor((fullW - minMargins * 2 - (ROWS - 1) * TileGap) / ROWS)
    TileWidth = math.min(tile_max_width, 90)
    Margins = math.floor((fullW - (ROWS - 1) * TileGap - ROWS * TileWidth) / 2)

    Columns = {
        top = TileGap,
        bot = TileGap + ROWS * (TileGap + TileWidth),
        cols = {}
    }
    local col = Margins
    for y = 1, ROWS do
        Columns.cols[y] = {col, col + TileWidth}
        col = col + TileWidth + TileGap
    end

    if Grid then
        local row = TileGap
        for tr = 1, ROWS do
            col = Margins
            for tc = 1, ROWS do
                Grid[tr][tc].col = col
                Grid[tr][tc].row = row
                col = col + TileWidth + TileGap
            end
            row = row + TileWidth + TileGap
        end
    end
end

function love.load()
    Font = love.graphics.newFont("IBM_Plex_Sans/Regular.ttf", 20)
    FontHeight = Font:getHeight()

    TileFont = love.graphics.newFont("IBM_Plex_Sans/Medium.ttf", 26)
    TileFontHeight = TileFont:getHeight()

    love.graphics.setFont(Font)

    -- Game Params
    ROWS = 5
    TileGap = 10
    ---@type tileValue
    NextTileValue = 2
    ---@type tileValue
    MaxTileValue = 2

    RecalculateDimensions()

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
    for tr = 1, ROWS do
        GridTops[tr] = 1
    end

    --[[ Model ]]--
    -- Model. Structure of globals that might change.
    Md = {
        AniSeq = AniSeq:new(),
        AniEntrance = AniEntrance:new(),
        Next = 0,
    }

    ---Check for collapse at new insertion position. Newly inserted tile at `Grid[tr][tc]`.
    ---This will only check a single collapse at a time.
    ---
    ---**Checks**:
    ---1. Vertically up
    ---2. Horz left
    ---   `# %`
    ---3. Horz right
    ---   `% #`
    ---4. Horz both
    ---   `# % #`
    ---5. Triangle right
    ---```
    ---   #
    ---   % #
    ---```
    ---6. Triangle left
    ---```
    ---     #
    ---   # %
    ---```
    ---7. Diamond
    ---```
    ---     #
    ---   # % #
    ---```
    ---@param tc integer
    ---@param tr integer
    ---@return boolean has_collapse
    function Collapse(tc, tr)
        local this = Grid[tr][tc]

        --[[ 7: Diamond: top, left, right =>> this ]]--
        if tc > 1 and tc < ROWS and tr > 1 then
            local left = Grid[tr][tc-1]
            local right = Grid[tr][tc+1]
            local up = Grid[tr-1][tc]
            if all_eq({left, right, up, this}) then
                local new_tile = Tile.get(this.tile.value * 8)
                MaxTileValue = math.max(MaxTileValue, new_tile.value)
                GridTops[tc] = GridTops[tc] - 1
                GridTops[tc-1] = GridTops[tc-1] - 1
                GridTops[tc+1] = GridTops[tc+1] - 1
                Md.AniSeq:init_diamond(left, up, right, this, new_tile, up)
                return true
            end
        end
        --[[ 5: left-triangle  ]]--
        if tc > 1 and tr > 1 then
            local left = Grid[tr][tc-1]
            local up = Grid[tr-1][tc]
            if all_eq({left, up, this}) then
                local new_tile = Tile.get(this.tile.value * 4)
                MaxTileValue = math.max(MaxTileValue, new_tile.value)
                GridTops[tc] = GridTops[tc] - 1
                GridTops[tc-1] = GridTops[tc-1] - 1
                Md.AniSeq:init_triangle(left, this, up, new_tile, up)
                return true
            end
        end
        --[[ 6: right-triangle  ]]--
        if tc < ROWS and tr > 1 then
            local right = Grid[tr][tc+1]
            local up = Grid[tr-1][tc]
            if all_eq({right, up, this}) then
                local new_tile = Tile.get(this.tile.value * 4)
                MaxTileValue = math.max(MaxTileValue, new_tile.value)
                GridTops[tc] = GridTops[tc] - 1
                GridTops[tc+1] = GridTops[tc+1] - 1
                Md.AniSeq:init_triangle(right, this, up, new_tile, up)
                return true
            end
        end
        --[[ 4: Horz left -> this <- right ]]--
        if tc > 1 and tc < ROWS then
            local left = Grid[tr][tc-1]
            local right = Grid[tr][tc+1]
            if all_eq({left, right, this}) then
                local new_tile = Tile.get(this.tile.value * 4)
                MaxTileValue = math.max(MaxTileValue, new_tile.value)
                GridTops[tc+1] = GridTops[tc+1] - 1
                GridTops[tc-1] = GridTops[tc-1] - 1
                Md.AniSeq:init_horz_both(left, this, right, new_tile, this)
                return true
            end
        end
        --[[ 2: Horz left -> into this ]]--
        if tc > 1 then
            local left = Grid[tr][tc-1]
            if all_eq({left, this}) then
                local new_tile = Tile.get(this.tile.value * 2)
                MaxTileValue = math.max(MaxTileValue, new_tile.value)
                GridTops[tc-1] = GridTops[tc-1] - 1
                Md.AniSeq:init_horz_one({tr = left.tr, tc = left.tc}, this, new_tile, this)
                return true
            end
        end
        --[[ 3: Horz this <- right ]]--
        if tc < ROWS then
            local right = Grid[tr][tc+1]
            if all_eq({right, this}) then
                local new_tile = Tile.get(this.tile.value * 2)
                MaxTileValue = math.max(MaxTileValue, new_tile.value)
                GridTops[tc+1] = GridTops[tc+1] - 1
                Md.AniSeq:init_horz_one({tr = right.tr, tc = right.tc}, this, new_tile, this)
                return true
            end
        end
        --[[ 1: vertical ]]--
        if tr > 1 then
            local up = Grid[tr-1][tc]
            if all_eq({up, this}) then
                local new_tile = Tile.get(this.tile.value * 2)
                MaxTileValue = math.max(MaxTileValue, new_tile.value)
                GridTops[tc] = GridTops[tc] - 1

                Md.AniSeq:init_vert(up, this, new_tile, up)
                return true
            end
        end

        return false
    end

    function UpdateNext()
        ---@type tileValue
        local cap = NextMap[MaxTileValue] or NextMap.fallback
        ---@type tileValue
        NextTileValue = 2 ^ math.random(math.log(cap))
        -- INFO: Use this for quickly producing large tiles for debugging.
        -- Next = cap
    end

    ---@param tc integer
    function InsertTileAt(tc)
        if Md.AniEntrance.active or Md.AniSeq.active then
            Message = "Please wait for animation to finish"
            return
        end

        local tr = GridTops[tc]
        if tr <= ROWS then
            Grid[tr][tc].tile = Tile.get(NextTileValue)
            GridTops[tc] = tr + 1
            -- Defers collapsing & updating next to after animation finishes.
            -- See `love.update`.
            Md.AniEntrance:init(Grid[tr][tc])
            Message = ""
        else
            if Grid[ROWS][tc].tile.value == NextTileValue then
                Grid[ROWS][tc].tile = Tile.get(NextTileValue * 2)
                Collapse(tc, ROWS)
                Message = "Phew!"
            else
                Message = "Row is full and incollapsible!"
            end
        end
    end
end

function love.update(_)
    if Md.AniEntrance.active then
        local done = Md.AniEntrance:next()
        if done then
            Md.AniEntrance:finish()
            if not Collapse(Md.AniEntrance.target.tc, Md.AniEntrance.target.tr) then
                UpdateNext()
            end
        end
    end
    if Md.AniSeq.active then
        local done = Md.AniSeq:next()
        if done then
            Md.AniSeq:finish()
            if Md.AniSeq.data then
                local has_collapse = Collapse(Md.AniSeq.data.tc, Md.AniSeq.data.tr)
                -- for _, ac in ipairs(finished) do
                --     has_collapse = Collapse(ac.target.tc, ac.target.tr)
                -- end
                if not has_collapse then
                    UpdateNext()
                end
            end
        end
    end
end

---Draw a single tile with the correct background and text.
function Cell:draw()
    local tile = self.tile
    local width = TileWidth + 2 * self.enlarge
    local tile_padding_top = math.floor(TileWidth / 2 - TileFontHeight / 2)
    local text_row = self.row + self.o_r + tile_padding_top
    local radius = width / 8

    love.graphics.setColor(unpack(tile.bg))
    love.graphics.rectangle(
        "fill",
        self.col + self.o_c - self.enlarge,
        self.row + self.o_r - self.enlarge,
        width,
        width,
        radius
    )

    love.graphics.setColor(unpack(tile.fg))
    love.graphics.printf(
        tile.text,
        TileFont,
        self.col + self.o_c,
        text_row,
        TileWidth,
        "center"
    )
end

function love.draw()
    RecalculateDimensions()
    local column_radius = TileWidth / 8

    --[[ Columns ]]--

    love.graphics.setColor(unpack(ColumnColor.bg))
    for y = 1, ROWS do
        love.graphics.rectangle(
            'fill',
            Columns.cols[y][1],
            Columns.top,
            TileWidth,
            Columns.bot - Columns.top,
            column_radius
        )
    end

    --[[ Grid ]]--

    ---Number of occupied cells to determine whether game is over.
    -- TODO: Not actually true because some filled rows can still be collapsible
    Count = 0
    for tr = 1, ROWS do
        for tc = 1, ROWS do
            local cell = Grid[tr][tc]
            if cell.tile.value ~= 0 then
                Count = Count + 1
                Cell.draw(cell)
            end
        end
    end
    local row = (TileGap + TileWidth) * ROWS

    if Count == ROWS ^ 2 and State ~= "end" then
        State = "end"
        -- Avoids overwriting new messages on top
        Message = "GAME OVER"
    end

    --[[ Debug info ]]--

    row = row + FontHeight
    love.graphics.setColor(1, 1, 1)
    local col = Margins
    for x = 1, ROWS do
        love.graphics.printf(tostring(GridTops[x]), col, row, TileWidth, "center")
        col = col + TileWidth + TileGap
    end
    row = row + TileGap + FontHeight

    --[[ Next & messages ]]--

    love.graphics.setColor(1, 1, 1)
    row = row + FontHeight
    love.graphics.print("Next: " .. tostring(NextTileValue), Margins, row)
    row = row + FontHeight
    love.graphics.print(Message, Margins, row)
end

function love.keypressed(key)
    local col = tonumber(key)
    if col and col > 0 and col <= ROWS then
        InsertTileAt(col)
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
