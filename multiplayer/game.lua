-- Load dependencies
local Moat = require('https://raw.githubusercontent.com/revillo/castle-dungeon/master/moat.lua')

-- Render constants
local GAME_WIDTH = 192
local GAME_HEIGHT = 192
local RENDER_SCALE = 3

-- Game constants
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
local spawnX, spawnY

-- Assets
local playerImage
local objectsImage
local walkSounds
local jumpSound
local landSound
local gemSound

-- Define a unique ID for each type of entity
local ENTITY_TYPES = {
  Player = 0,
  Platform = 1,
  Gem = 2
}

-- Define some constants that configure the way Moat works
local MOAT_CONFIG = {
  TickInterval = 1.0 / 60.0,
  WorldSize = 192,
  ClientVisibility = 192
}

-- Create a new game using Moat, which allows for networked online play
local moat = Moat:new(ENTITY_TYPES, MOAT_CONFIG)

-- Initializes the game
function moat:clientLoad()
  -- Load assets
  playerImage = love.graphics.newImage('../img/player.png')
  objectsImage = love.graphics.newImage('../img/objects.png')
  playerImage:setFilter('nearest', 'nearest')
  objectsImage:setFilter('nearest', 'nearest')
  walkSounds = {
    love.audio.newSource('../sfx/walk1.wav', 'static'),
    love.audio.newSource('../sfx/walk2.wav', 'static')
  }
  jumpSound = love.audio.newSource('../sfx/jump.wav', 'static')
  landSound = love.audio.newSource('../sfx/land.wav', 'static')
  gemSound = love.audio.newSource('../sfx/gem.wav', 'static')
end
function moat:serverInitWorld(state)
  -- Create platforms and game objects from the level data
  for col = 1, LEVEL_NUM_COLUMNS do
    for row = 1, LEVEL_NUM_ROWS do
      local i = (LEVEL_NUM_ROWS + 1) * (row - 1) + col
      local x, y = 16 * (col - 1), 16 * (row - 1)
      local symbol = string.sub(LEVEL_DATA, i, i)
      if symbol == 'P' then
        -- Set the player spawn point for when a client connects
        spawnX, spawnY = x, y
      elseif symbol == 'X' then
        -- Create a platform
        moat:spawn(ENTITY_TYPES.Platform, x, y, 16, 16)
      elseif symbol == 'o' then
        -- Create a gem
        moat:spawn(ENTITY_TYPES.Gem, x, y, 16, 16)
      end
    end
  end
end
function moat:serverOnClientConnected(clientId)
  -- Create the player
  moat:serverSpawnPlayer(clientId, spawnX, spawnY, 16, 16, {
    vx = 0,
    vy = 0,
    isFacingLeft = false,
    isGrounded = false,
    landingTimer = 0.00,
    walkTimer = 0.00
  })
end

-- Updates the game state
function moat:clientUpdate(dt)
  moat:clientSetInput({
    left = love.keyboard.isDown('left'),
    right = love.keyboard.isDown('right'),
    jump = love.keyboard.isDown('space')
  })
end
function moat:playerUpdate(player, input, dt)
  player.landingTimer = math.max(0, player.landingTimer - dt)

  -- Figure out which direction the player is moving
  local moveX = (input.left and -1 or 0) + (input.right and 1 or 0)

  -- Keep track of the player's walk cycle
  if player.isGrounded then
    if player.walkTimer < 0.20 and player.walkTimer + dt >= 0.20 then
      -- love.audio.play(walkSounds[1]:clone())
    elseif player.walkTimer < 0.50 and player.walkTimer + dt >= 0.50 then
      -- love.audio.play(walkSounds[2]:clone())
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
  if player.isGrounded and input.jump then
    player.vy = -200
    -- love.audio.play(jumpSound:clone())
  end

  -- Accelerate downward (a la gravity)
  player.vy = player.vy + 480 * dt

  -- Apply the player's velocity to her position
  player.x = player.x + player.vx * dt
  player.y = player.y + player.vy * dt
  moat:moveEntity(player)

  -- Check for collisions with platforms
  local wasGrounded = player.isGrounded
  player.isGrounded = false
  moat:eachEntityOfType(ENTITY_TYPES.Platform, function(platform)
    local collisionDir = checkForCollision(player, platform)
    if collisionDir == 'top' then
      player.y = platform.y + platform.h
      player.vy = math.max(0, player.vy)
    elseif collisionDir == 'bottom' then
      player.y = platform.y - player.h
      player.vy = math.min(0, player.vy)
      player.isGrounded = true
      if not wasGrounded then
        player.landingTimer = 0.15
        -- love.audio.play(landSound:clone())
      end
    elseif collisionDir == 'left' then
      player.x = platform.x + platform.w
      player.vx = math.max(0, player.vx)
    elseif collisionDir == 'right' then
      player.x = platform.x - player.w
      player.vx = math.min(0, player.vx)
    end
    moat:moveEntity(player)
  end)

  -- Check for gem collection
  moat:eachOverlapping(player, function(entity)
    if entity.type == ENTITY_TYPES.Gem then
      moat:despawn(entity)
      -- love.audio.play(gemSound:clone())
    end
  end)

  -- Keep the player in bounds
  if player.x < 0 then
    player.x = 0
  elseif player.x > GAME_WIDTH - player.w then
    player.x = GAME_WIDTH - player.w
  end
  if player.y > GAME_HEIGHT + 50 then
    player.y = -10
  end

  -- Players bounce off of each other
  moat:eachOverlapping(player, function(entity)
    if entity.type == ENTITY_TYPES.Player and entity.y > player.y and not player.isGrounded and player.vy > 0 then
      player.vy = -200
      -- love.audio.play(jumpSound:clone())
    end
  end)
end

-- Renders the game
function moat:clientDraw()
  -- Scale and crop the screen
  love.graphics.setScissor(0, 0, RENDER_SCALE * GAME_WIDTH, RENDER_SCALE * GAME_HEIGHT)
  love.graphics.scale(RENDER_SCALE, RENDER_SCALE)
  love.graphics.clear(15 / 255, 217 / 255, 246 / 255)
  love.graphics.setColor(1, 1, 1, 1)

  -- Draw  the platforms
  moat:eachEntityOfType(ENTITY_TYPES.Platform, function(platform)
    drawSprite(objectsImage, 16, 16, 3, platform.x, platform.y)
  end)

  -- Draw the gems
  moat:eachEntityOfType(ENTITY_TYPES.Gem, function(gem)
    drawSprite(objectsImage, 16, 16, 4, gem.x, gem.y)
  end)

  -- Draw the players
  moat:eachEntityOfType(ENTITY_TYPES.Player, function(player)
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
    drawSprite(playerImage, 16, 16, sprite + 7 * (player.clientId % 7), player.x, player.y, player.isFacingLeft)
  end)
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

-- Checks to see if two entities are colliding, and if so from which side. This is
-- accomplished by checking the four quadrants of the axis-aligned bounding boxes
function checkForCollision(a, b)
  local indent = 3
  if rectsOverlapping(a.x + indent, a.y + a.h / 2, a.w - 2 * indent, a.h / 2, b.x, b.y, b.w, b.h) then
    return 'bottom'
  elseif rectsOverlapping(a.x + indent, a.y, a.w - 2 * indent, a.h / 2, b.x, b.y, b.w, b.h) then
    return 'top'
  elseif rectsOverlapping(a.x, a.y + indent, a.w / 2, a.h - 2 * indent, b.x, b.y, b.w, b.h) then
    return 'left'
  elseif rectsOverlapping(a.x + a.w / 2, a.y + indent, a.w / 2, a.h - 2 * indent, b.x, b.y, b.w, b.h) then
    return 'right'
  end
end

-- Run the game
moat:run()
