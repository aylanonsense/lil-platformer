-- Game constants
local GAME_WIDTH = 192
local GAME_HEIGHT = 192
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

-- Game variables
local player
local platforms
local gems

-- Assets
local playerImage
local objectsImage
local walkSounds
local jumpSound
local landSound
local gemSound

-- Initializes the game
function love.load()
  -- Load assets
  love.graphics.setDefaultFilter('nearest', 'nearest')
  playerImage = love.graphics.newImage('img/player.png')
  objectsImage = love.graphics.newImage('img/objects.png')
  walkSounds = {
    love.audio.newSource('sfx/walk1.wav', 'static'),
    love.audio.newSource('sfx/walk2.wav', 'static')
  }
  jumpSound = love.audio.newSource('sfx/jump.wav', 'static')
  landSound = love.audio.newSource('sfx/land.wav', 'static')
  gemSound = love.audio.newSource('sfx/gem.wav', 'static')

  -- Create platforms and game objects from the level data
  platforms = {}
  gems = {}
  for col = 1, LEVEL_NUM_COLUMNS do
    for row = 1, LEVEL_NUM_ROWS do
      local i = (LEVEL_NUM_ROWS + 1) * (row - 1) + col
      local x, y = 16 * (col - 1), 16 * (row - 1)
      local symbol = string.sub(LEVEL_DATA, i, i)
      if symbol == 'P' then
        -- Create the player
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
      elseif symbol == 'X' then
        -- Create a platform
        table.insert(platforms, {
          x = x,
          y = y,
          width = 16,
          height = 16
        })
      elseif symbol == 'o' then
        -- Create a gem
        table.insert(gems, {
          x = x,
          y = y,
          width = 16,
          height = 16,
          isCollected = false
        })
      end
    end
  end
end

-- Updates the game state
function love.update(dt)
  player.landingTimer = math.max(0, player.landingTimer - dt)

  -- Figure out which direction the player is moving
  local moveX = (love.keyboard.isDown('left') and -1 or 0) + (love.keyboard.isDown('right') and 1 or 0)

  -- Keep track of the player's walk cycle
  if player.isGrounded then
    if player.walkTimer < 0.20 and player.walkTimer + dt >= 0.20 then
      love.audio.play(walkSounds[1]:clone())
    elseif player.walkTimer < 0.50 and player.walkTimer + dt >= 0.50 then
      love.audio.play(walkSounds[2]:clone())
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

  -- Accelerate downward (a la gravity)
  player.vy = player.vy + 480 * dt

  -- Apply the player's velocity to her position
  player.x = player.x + player.vx * dt
  player.y = player.y + player.vy * dt

  -- Check for collisions with platforms
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
    if not gem.isCollected and entitiesOverlapping(player, gem) then
      gem.isCollected = true
      love.audio.play(gemSound:clone())
    end
  end

  -- Keep the player in bounds
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
  -- Clear the screen
  love.graphics.clear(251 / 255, 134 / 255, 199 / 255)
  love.graphics.setColor(1, 1, 1)

  -- Draw  the platforms
  for _, platform in ipairs(platforms) do
    drawSprite(objectsImage, 16, 16, 1, platform.x, platform.y)
  end

  -- Draw the gems
  for _, gem in ipairs(gems) do
    if not gem.isCollected then
      drawSprite(objectsImage, 16, 16, 2, gem.x, gem.y)
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
  drawSprite(playerImage, 16, 16, sprite, player.x, player.y, player.isFacingLeft)
end

-- Draws a sprite from a sprite sheet, spriteNum=1 is the upper-leftmost sprite
function drawSprite(spriteSheetImage, spriteWidth, spriteHeight, sprite, x, y, flipHorizontal, flipVertical, rotation)
  local width, height = spriteSheetImage:getDimensions()
  local numColumns = math.floor(width / spriteWidth)
  local col, row = (sprite - 1) % numColumns, math.floor((sprite - 1) / numColumns)
  love.graphics.draw(spriteSheetImage,
    love.graphics.newQuad(spriteWidth * col, spriteHeight * row, spriteWidth, spriteHeight, width, height),
    x + spriteWidth / 2, y + spriteHeight / 2,
    rotation or 0,
    flipHorizontal and -1 or 1, flipVertical and -1 or 1,
    spriteWidth / 2, spriteHeight / 2)
end

-- Determine whether two rectangles are overlapping
function rectsOverlapping(x1, y1, w1, h1, x2, y2, w2, h2)
  return x1 + w1 > x2 and x2 + w2 > x1 and y1 + h1 > y2 and y2 + h2 > y1
end

-- Returns true if two entities are overlapping, by checking their bounding boxes
function entitiesOverlapping(a, b)
  return rectsOverlapping(a.x, a.y, a.width, a.height, b.x, b.y, b.width, b.height)
end

-- Checks to see if two entities are colliding, and if so from which side. This is
-- accomplished by checking the four quadrants of the axis-aligned bounding boxes
function checkForCollision(a, b)
  local indent = 3
  if rectsOverlapping(a.x + indent, a.y + a.height / 2, a.width - 2 * indent, a.height / 2, b.x, b.y, b.width, b.height) then
    return 'bottom'
  elseif rectsOverlapping(a.x + indent, a.y, a.width - 2 * indent, a.height / 2, b.x, b.y, b.width, b.height) then
    return 'top'
  elseif rectsOverlapping(a.x, a.y + indent, a.width / 2, a.height - 2 * indent, b.x, b.y, b.width, b.height) then
    return 'left'
  elseif rectsOverlapping(a.x + a.width / 2, a.y + indent, a.width / 2, a.height - 2 * indent, b.x, b.y, b.width, b.height) then
    return 'right'
  end
end
