-- Constants
local GAME_WIDTH = 192
local GAME_HEIGHT = 192
local RENDER_SCALE = 3
local LEVEL_NUM_COLUMNS = 12
local LEVEL_NUM_ROWS = 12
local LEVEL_DATA = [[
............
............
............
............
............
............
............
........XXX.
............
..X.........
..XXXXXXX...
............
]]
local TILE_TYPES = {
  -- Platforms
  ['X'] = { sprite = 1 }
}

-- Game objects
local player
local platforms

-- Images
local playerImage
local tilesImage

-- Initializes the game
function love.load()
  -- Load images
  playerImage = loadImage('img/player.png')
  tilesImage = loadImage('img/tiles.png')

  -- Create the player character
  createPlayer()
end

-- Renders the game
function love.draw()
  -- Set some drawing filters
  love.graphics.setDefaultFilter('nearest', 'nearest')
  love.graphics.scale(RENDER_SCALE, RENDER_SCALE)

  -- Black out the screen
  love.graphics.setColor(0, 0, 0, 1)
  love.graphics.rectangle('fill', 0, 0, GAME_WIDTH, GAME_HEIGHT)
  love.graphics.setColor(1, 1, 1, 1)

  -- Draw the player
  drawImage(playerImage, 1, player.isFacingLeft, player.x, player.y)
end

-- Creates the player
function createPlayer()
  player = {
    x = 60,
    y = 60,
    isFacingLeft = false
  }
end

-- Loads a pixelated image
function loadImage(filePath)
  local image = love.graphics.newImage(filePath)
  image:setFilter('nearest', 'nearest')
  return image
end

-- Draws a 16x16 sprite from an image, spriteNum=1 is the upper-leftmost sprite
function drawImage(image, spriteNum, flipHorizontally, x, y)
  local columns = math.floor(image:getWidth() / 16)
  local col = (spriteNum - 1) % columns
  local row = math.floor((spriteNum - 1) / columns)
  local quad = love.graphics.newQuad(16 * col, 16 * row, 16, 16, image:getDimensions())
  love.graphics.draw(image, quad, x + (flipHorizontally and 16 or 0), y, 0, flipHorizontally and -1 or 1, 1)
end
