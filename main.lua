-- ESC to exit game
-- HOME to enter idle mode or idle for 10 seconds after spinning
-- LEFT CLICK to spin

function love.load()

  defaultFrameRate = 60
  showPrizeTimeout = 10
  showPriceFade = .6
  debugMode = false
  display = 1
  defaultBgMusicVolume = 1.0
  dimmedBgMusicVolume  = .4
  spinLockTimeout = 1.5

  gameState = 1
  gameStateTimeout = 10.0
  justSpun = false
  spinLockTimer = 0
  showPrizeTimer = 0
  showPrize = false
  prizeKey = ''
  lastClickedWedge = 0
  deltaTime = 0

  love.window.setMode( love.graphics.getWidth(), love.graphics.getHeight(), {fullscreen=true,display=display} )
  love.window.setTitle( 'Happily Wheel of Fortune' )

  require('./wheel')
  require('./prizes')

  if debugMode then
    -- wheel.speedDecay = .5
  end

  -- graphics
  bg = {}
  table.insert(bg, love.graphics.newImage('sprites/shadow.png'))
  table.insert(bg, love.graphics.newImage('sprites/cover.png'))
  table.insert(bg, love.graphics.newImage('sprites/wheel-hub.png'))

  sprites = {}
  sprites.wheel = love.graphics.newImage('sprites/wheel.png')

  -- sounds
  sounds = {}
  sounds.clicks = loadClickingSound()
  bgMusic = love.audio.newSource( 'sounds/soundtrack.mp3', 'stream' )
  bgMusic:setLooping( true )
  bgMusic:play()
  
end

function love.update(dt)
  deltaTime = dt

  -- clicking sound
  makeClickingSound()

  -- gradualy increase volume in idle state
  if gameState == 1 then
    local curentBgVolume = bgMusic:getVolume()
    if curentBgVolume < defaultBgMusicVolume then
      bgMusic:setVolume(curentBgVolume + .005)
    end
  end

  -- update rotation calculation
  if wheel.rotation > (math.pi*2) then
    wheel.rotation = math.fmod(wheel.rotation, (math.pi*2)) -- modulus operation
  end
  wheel.rotation = wheel.rotation + ((dt * defaultFrameRate) * wheel.speed)

  -- if game is in session
  if gameState == 2 then
    if love.mouse.isDown(1) and (spinLockTimer < spinLockTimeout) then
      spinLockTimer = 0
      if wheel.speed <= wheel.addJumpStartSpeed then
        wheel.speed = math.random(3,5)/10
        justSpun = true
      end
      if wheel.speed < wheel.maxSpeed then
        wheel.acceleration = wheel.acceleration * 1.00025
      else
        wheel.acceleration = wheel.acceleration * 1.00000000025
      end
      wheel.speed = wheel.speed * wheel.acceleration
    else
      spinLockTimer = spinLockTimer + dt
      wheel.acceleration = wheel.defaultAcceleration
      if wheel.speed > wheel.cutOffSpeed then
        local decayRate = 0
        if wheel.speed > wheel.maxSpeed then
          decayRate = wheel.speedDecayFast
        else
          decayRate = wheel.speedDecay
        end
        wheel.speed = wheel.speed - ((dt * defaultFrameRate) * (wheel.speed * decayRate))
      else
        wheel.speed = wheel.defaultSpeed
        if justSpun then
          gameState = 3
        end
      end
    end
  -- if game is in show prize state
  elseif gameState == 3 then
    showPrizeTimer = showPrizeTimer + dt
    if justSpun then
      determinePrize(radToDeg(wheel.rotation))
      if not (prizeKey == '') then
        if not (prizes[prizeKey].sound == nil) then
          prizes[prizeKey].sound:play()
        end
      end
      showPrize = true
      justSpun = false
    elseif showPrizeTimer >= showPrizeTimeout then
      enterIdleState()
    end
  -- if game is idle
  else
    wheel.speed = wheel.idleSpeed
  end
  
end -- end love.update

function love.draw()
  love.graphics.draw(bg[1], 0, 0, (3*math.pi)/2, love.graphics.getWidth()/bg[1]:getHeight(), nil, bg[1]:getWidth(), nil) -- shadow
  love.graphics.draw(sprites.wheel, wheel.x, wheel.y, wheel.rotation, love.graphics.getWidth()/sprites.wheel:getHeight(), nil, (sprites.wheel:getWidth()/2)+wheel.centerOffsetX, sprites.wheel:getWidth()/2) -- wheel
  love.graphics.draw(bg[2], 0, 0, (3*math.pi)/2, love.graphics.getWidth()/bg[2]:getHeight(), nil, bg[2]:getWidth(), nil) -- background
  love.graphics.draw(bg[3], 0, love.graphics.getHeight(), (3*math.pi)/2, love.graphics.getWidth()/sprites.wheel:getWidth(), nil) -- wheel hub

  -- show price state
  if gameState == 3 then
    love.graphics.setColor(0,0,0,showPriceFade)
    love.graphics.rectangle('fill', 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
    love.graphics.setColor(255,255,255,1)
    if not (prizeKey == '') then
      if not (prizes[prizeKey].sprite == nil) then
        love.graphics.draw(prizes[prizeKey].sprite, love.graphics.getWidth()/2, love.graphics.getHeight()/2, (3*math.pi)/2, (love.graphics.getHeight()*.8)/prizes[prizeKey].sprite:getWidth(), nil, prizes[prizeKey].sprite:getWidth()/2, prizes[prizeKey].sprite:getHeight()/2) -- prize
      end
    end
  end

  -- debug messages
  if debugMode then
    love.graphics.print('Speed: ' ..wheel.speed)
    love.graphics.print('Rotation: ' ..wheel.rotation, 0, 20)
    love.graphics.print('Acc: ' ..wheel.acceleration, 0, 40)
    love.graphics.print('Spin Lock Timer: ' ..spinLockTimer, 0, 60)
    love.graphics.print('Prize: ' ..prizeKey, 300, 0)
    love.graphics.print('Show prize timer: ' ..showPrizeTimer, 600, 0)
    love.graphics.print('DT: ' ..deltaTime, 600, 20)
  end
end

function love.keypressed(k)
  if k == 'escape' then
     love.event.quit()
  elseif k == 'home' and gameState == 2 then
    enterIdleState()
  end
end

function love.mousepressed( x, y, button, istouch, presses )
  if (button == 1) and ((gameState == 1) or (gameState == 3)) then
    startGame()
  end
end

function radToDeg(rad)
  return rad * (180/math.pi)
end

function determinePrize(deg)
  lastPrizeDeg = 0
  for i, w in ipairs(wheel.wedges) do
    if deg > lastPrizeDeg and deg <= w.stop then
      prizeKey = w.prizeKey
      break
    end
    lastPrizeDeg = w.stop
  end
end

function resetState()
  wheel.speed = 0
  showPrizeTimer = 0
  showPrize = false
  prizeKey = ''
  spinLockTimer = 0
end

function startGame()
  gameState = 2
  bgMusic:setVolume(dimmedBgMusicVolume)
  resetState()
end

function enterIdleState()
  gameState = 1
  resetState()
end

function loadClickingSound()
  local clicks = {}
  table.insert(clicks, love.audio.newSource("sounds/click.wav", "static"))
  for i = 1, 30, 1 do
    table.insert(clicks, clicks[1]:clone())
  end
  return clicks
end

function makeClickingSound()
  if (wheel.speed > 0) and (wheel.speed < 0.2) then
    local deg = radToDeg(wheel.rotation)
    local lastPrizeDeg = 0
    for i, w in ipairs(wheel.wedges) do
      if deg > lastPrizeDeg and deg <= w.stop then
        if not (i == lastClickedWedge) then
          for i, s in ipairs(sounds.clicks) do
            if not s:isPlaying() then
              s:play()
              break
            end
          end
          lastClickedWedge = i
        end
        break
      end
      lastPrizeDeg = w.stop
    end
  end
end