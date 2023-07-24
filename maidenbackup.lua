util = require "util"

function redraw_clock() ----- a clock that draws space
  while true do ------------- "while true do" means "do this forever"
    clock.sleep(1/15) ------- pause for a fifteenth of a second (aka 15fps)
    if screenDirty then ---- only if something changed
      redraw() -------------- redraw space
      screen_dirty = false -- and everything is clean again
    end
  end
end

function init()
  redraw_clock_id = clock.run(redraw_clock) --add these for other clocks so we can kill them at the end

  currentTrack = 1
  curXpos=1
  curXbeat=1
  curXdiv=1
  curXwidth=1
  curXdisp = 1
  maxXpos=1
  displayWidthBeat=1

  rhythmicDisplay = {
    {2, 5, 4, 1},
    {4},
    {1, 1, 1, 3}
  }
  redraw()
end

function redraw()
  
  screen.clear()
  -- for each track
  trackHeight = 64 / #rhythmicDisplay
  for i = 1, #rhythmicDisplay do
    displayWidthBeat = math.floor( 128 / #rhythmicDisplay[i] )
    -- for each beat
    for j = 1, #rhythmicDisplay[i] do
  		displayWidthSubdiv = math.floor(displayWidthBeat / rhythmicDisplay[i][j])
      --for each subdivision
      for k = 1, rhythmicDisplay[i][j] do
        nowPosition = displayWidthBeat * (j - 1) + displayWidthSubdiv * (k - 1)
        nowHeight = trackHeight * (i - 1)
        screen.level(4)
        if k == 1 then
          screen.level(15)
        end
        screen.rect(nowPosition, nowHeight, 1, trackHeight)
        screen.fill()
      end
    end
  end
  
  -- rectangle for cursor
  screen.level(1)
  
  --calc y pos
  curYPos = (currentTrack - 1) * (64 / #rhythmicDisplay)
  
  screen.rect(curXdisp, curYPos, curXwidth, (64 / #rhythmicDisplay))
  screen.fill()
  
  screen.update()
end

function enc(e, d)
  --move cursor between tracks
  if (e == 1) then
    currentTrack = util.clamp(currentTrack + d, 1, #rhythmicDisplay)
    curXpos = 1
    -- calculate the cursor width
    maxXpos = 0
    for i=1, #rhythmicDisplay[currentTrack] do
      maxXpos = maxXpos + rhythmicDisplay[currentTrack][i]
    end
    print('maxXpos is ' .. maxXpos)
    --calculate the width of the cursor
    for i=1, #rhythmicDisplay[currentTrack] do
      if curXpos < rhythmicDisplay[currentTrack][i] then
        curXwidth = math.floor( 128 / (#rhythmicDisplay[currentTrack] * rhythmicDisplay[currentTrack][i]))
        print('curXwidth is ' .. curXwidth)
        break
      end
    end
    screenDirty = true
  end

  -- move cursor in time
  if (e == 2) then
    --in/decrement the position in the array
    curXdiv = curXpos + d
    if curXdiv > rhythmicDisplay[currentTrack][curXbeat] then
      curXbeat = curXbeat+1
      curXdiv = 1
    end
    if curXdiv < 1 then curXbeat = curXbeat-1 end
    if curXbeat < 1 then curXbeat = 1 end
    if curXbeat > #rhythmicDisplay[currentTrack] then curXbeat = #rhythmicDisplay[currentTrack] end
    -- calculate the x position: beat + subdivision
    -- offset by beat
    curXdisp = (128 / curXbeat)
    
    screenDirty = true
  end

  --adjust segment Length
  if (e == 3) then

    screenDirty = true
  end

end

function cleanup() --------------- cleanup() is automatically called on script close
  clock.cancel(redraw_clock_id) -- melt our clock via the id we noted
  -- should we melt the ticker clock too?
end
