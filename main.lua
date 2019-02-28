-- Constants
local GAME_WIDTH = 192
local GAME_HEIGHT = 192
local RENDER_SCALE = 3
local LEVEL_NUM_COLUMNS = 12
local LEVEL_NUM_ROWS = 12
local LEVEL_DATA = [[
............
............
......ooooo.
X....XXXXXXX
XX..........
.XX.......o.
..XXXXX...o.
..........o.
X........XXX
X....oo.....
X.P..XXX....
XXXXXX......
]]
local LEVEL_OBJECT_TYPES = {
  ['P'] = { object = 'player' },
  ['X'] = { object = 'platform' },
  ['o'] = { object = 'gem' }
}

-- Game objects
local player
local platforms
local gems

-- Images
local playerImage
local objectsImage

-- Sound effects
local walkSound1
local walkSound2
local jumpSound
local landSound
local gemSound

-- Initializes the game
function love.load()
  -- Load images
  playerImage = loadImage('img/player.png')
  objectsImage = loadImage('img/objects.png')

  -- Load sound effects
  walkSound1 = love.audio.newSource('sfx/walk1.wav', 'static')
  walkSound2 = love.audio.newSource('sfx/walk2.wav', 'static')
  jumpSound = love.audio.newSource('sfx/jump.wav', 'static')
  landSound = love.audio.newSource('sfx/land.wav', 'static')
  gemSound = love.audio.newSource('sfx/gem.wav', 'static')

  -- Create platforms and game objects from the level data
  platforms = {}
  gems = {}
  loadLevel()
end

-- Updates the game state
function love.update(dt)
  local moveX = (love.keyboard.isDown('left') and -1 or 0) + (love.keyboard.isDown('right') and 1 or 0)
  player.landingTimer = math.max(0, player.landingTimer - dt)

  -- Walk animation timing
  if player.isGrounded then
    if player.walkTimer < 0.20 and player.walkTimer + dt >= 0.20 then
      love.audio.play(walkSound1:clone())
    elseif player.walkTimer < 0.50 and player.walkTimer + dt >= 0.50 then
      love.audio.play(walkSound2:clone())
    end
  end
  player.walkTimer = moveX == 0 and 0.00 or ((player.walkTimer + dt) % 0.60)

  -- Move the player left / right
  player.vx = 62 * moveX
  if moveX < 0 then
    player.isFacingLeft = true
  elseif moveX > 0 then
    player.isFacingLeft = false
  end

  -- Jump when space is pressed
  if player.isGrounded and love.keyboard.isDown('space') then
    player.vy = -200
    love.audio.play(jumpSound:clone())
  end

  -- Accelerate downward (due to gravity)
  player.vy = player.vy + 8

  -- Apply the player's velocity to her position
  player.x = player.x + player.vx * dt
  player.y = player.y + player.vy * dt

  -- Check for collisions with any platforms
  local wasGrounded = player.isGrounded
  player.isGrounded = false
  for _, platform in ipairs(platforms) do
    local collisionDir = checkForCollision(player, platform)
    if collisionDir == 'top' then
      player.y = platform.y + platform.height
      player.vy = math.max(0, player.vy)
    elseif collisionDir == 'bottom' then
      player.y = platform.y - player.height
      player.vy = math.min(0, player.vy)
      player.isGrounded = true
      if not wasGrounded then
        player.landingTimer = 0.15
        love.audio.play(landSound:clone())
      end
    elseif collisionDir == 'left' then
      player.x = platform.x + platform.width
      player.vx = math.max(0, player.vx)
    elseif collisionDir == 'right' then
      player.x = platform.x - player.width
      player.vx = math.min(0, player.vx)
    end
  end

  -- Check for gem collection
  for _, gem in ipairs(gems) do
    if not gem.isCollected and checkForHit(player, gem) then
      gem.isCollected = true
      love.audio.play(gemSound:clone())
    end
  end

  -- Keep the player on stage
  if player.x < 0 then
    player.x = 0
  elseif player.x > GAME_WIDTH - player.width then
    player.x = GAME_WIDTH - player.width
  end
  if player.y > GAME_HEIGHT + 50 then
    player.y = -10
  end
end

-- Renders the game
function love.draw()
  -- Set some drawing filters
  love.graphics.setDefaultFilter('nearest', 'nearest')
  love.graphics.scale(RENDER_SCALE, RENDER_SCALE)

  -- Clear the screen
  love.graphics.setColor(251 / 255, 134 / 255, 199 / 255, 1)
  love.graphics.rectangle('fill', 0, 0, GAME_WIDTH, GAME_HEIGHT)
  love.graphics.setColor(1, 1, 1, 1)

  -- Draw all of the platforms
  for _, platform in ipairs(platforms) do
    drawImage(objectsImage, 1, false, platform.x, platform.y)
  end

  -- Draw all of the gems
  for _, gem in ipairs(gems) do
    if not gem.isCollected then
      drawImage(objectsImage, 2, false, gem.x, gem.y)
    end
  end

  -- Draw the player
  local sprite
  if player.isGrounded then
    -- When standing
    if player.vx == 0 then
      if player.landingTimer > 0.00 then
        sprite = 7
      else
        sprite = 1
      end
    -- When running
    elseif player.walkTimer < 0.2 then
      sprite = 2
    elseif player.walkTimer < 0.3 then
      sprite = 3
    elseif player.walkTimer < 0.5 then
      sprite = 4
    else
      sprite = 3
    end
  -- When jumping
  elseif player.vy > 0 then
    sprite = 6
  else
    sprite = 5
  end
  drawImage(playerImage, sprite, player.isFacingLeft, player.x, player.y)
end

-- Create a 2D grid of tiles
function loadLevel()
  for col = 1, LEVEL_NUM_COLUMNS do
    for row = 1, LEVEL_NUM_ROWS do
      local i = (LEVEL_NUM_ROWS + 1) * (row - 1) + col
      local symbol = string.sub(LEVEL_DATA, i, i)
      local tileData = LEVEL_OBJECT_TYPES[symbol]
      if tileData then
        local x = 16 * (col - 1)
        local y = 16 * (row - 1)
        if tileData.object == 'player' then
          createPlayer(x, y)
        elseif tileData.object == 'platform' then
          createPlatform(x, y)
        elseif tileData.object == 'gem' then
          createGem(x, y)
        end
      end
    end
  end
end

-- Creates the player
function createPlayer(x, y)
  player = {
    x = x,
    y = y,
    vx = 0,
    vy = 0,
    width = 16,
    height = 16,
    isFacingLeft = false,
    isGrounded = false,
    landingTimer = 0.00,
    walkTimer = 0.00
  }
end

-- Creates a platform
function createPlatform(x, y)
  table.insert(platforms, {
    x = x,
    y = y,
    width = 16,
    height = 16
  })
end

-- Creates a platform
function createGem(x, y)
  table.insert(gems, {
    x = x,
    y = y,
    width = 16,
    height = 16,
    isCollected = false
  })
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

-- Determine whether two rectangles are overlapping
function rectsOverlapping(x1, y1, w1, h1, x2, y2, w2, h2)
  return x1 + w1 > x2 and x2 + w2 > x1 and y1 + h1 > y2 and y2 + h2 > y1
end

-- Checks to see if obj1 is overlapping ob2, by checking axis-aligned bounding boxes
function checkForHit(obj1, obj2)
  return rectsOverlapping(obj1.x, obj1.y, obj1.width, obj1.height, obj2.x, obj2.y, obj2.width, obj2.height)
end

-- Checks to see if obj1 is colliding with obj2, and if so from which side
--  This is accomplished by checking the four quadrants of the axis-aligned bounding boxes
function checkForCollision(obj1, obj2)
  local indent = 3
  if rectsOverlapping(obj1.x + indent, obj1.y + obj1.height / 2, obj1.width - 2 * indent, obj1.height / 2, obj2.x, obj2.y, obj2.width, obj2.height) then
    return 'bottom'
  elseif rectsOverlapping(obj1.x + indent, obj1.y, obj1.width - 2 * indent, obj1.height / 2, obj2.x, obj2.y, obj2.width, obj2.height) then
    return 'top'
  elseif rectsOverlapping(obj1.x, obj1.y + indent, obj1.width / 2, obj1.height - 2 * indent, obj2.x, obj2.y, obj2.width, obj2.height) then
    return 'left'
  elseif rectsOverlapping(obj1.x + obj1.width / 2, obj1.y + indent, obj1.width / 2, obj1.height - 2 * indent, obj2.x, obj2.y, obj2.width, obj2.height) then
    return 'right'
  end
end
