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

  rhythmicDisplay = {   -- [1] = number of beats, then the rest is the subdivion in each beat
    {2, 5, 4, 2},
    {3, 1, 2, 3, 1},
    {4, 1, 2, 3, 4}
  }
  currentTrack = 1
  curXbeat=1
  curXdiv=1
  curXdeci = math.floor((1 / rhythmicDisplay[currentTrack][1]) * (1 / rhythmicDisplay[currentTrack][curXbeat + 1]))
  curXwidth = 128 * curXdeci
  curXdisp = 1
  curYPos = 0
  displayWidthBeat=1
  
  redraw()
end

function updateCursor() -- calculate the x position: beat + subdivision, and width of subdision
  if curXbeat == 0 then
    beatoffset = 0
    subdivoffset = 0
  else
    beatoffset = (curXbeat - 1) / rhythmicDisplay[currentTrack][1]
    subdivoffset = (1 / rhythmicDisplay[currentTrack][1]) * ((curXdiv - 1) / rhythmicDisplay[currentTrack][curXbeat + 1])
  end
  curXdisp = beatoffset + subdivoffset
  curXdisp = math.floor(curXdisp * 128)
  if curXbeat == 0 then
    curXwidth = 128 else
    curXwidth = math.floor(128 * (1 / rhythmicDisplay[currentTrack][1]) * (1 / rhythmicDisplay[currentTrack][curXbeat + 1]))
  end
end

function redraw()
  screen.clear()
  
    -- rectangle for cursor
  screen.level(1)
  screen.rect(curXdisp, curYPos, curXwidth, (64 / #rhythmicDisplay))
  screen.fill()
  
  -- for each track
  trackHeight = 64 / #rhythmicDisplay
  for i = 1, #rhythmicDisplay do                --for each track
    displayWidthBeat = math.floor( 128 / rhythmicDisplay[i][1] )
    for j = 1, rhythmicDisplay[i][1] do         -- for each beat (skip first index of rhythmicDisplay[currentTrack])
  		displayWidthSubdiv = math.floor(displayWidthBeat / rhythmicDisplay[i][j+1])
      for k = 1, rhythmicDisplay[i][j + 1] do     --for each subdivision
        nowPosition = displayWidthBeat * (j - 1) + displayWidthSubdiv * (k - 1)
        nowHeight = trackHeight * (i - 1)
        screen.level(4)
        if k == 1 then screen.level(15) end
        screen.rect(nowPosition, nowHeight, 1, trackHeight)
        screen.fill()
      end
    end
  end
  screen.update()
end

function enc(e, d)
  --move cursor between tracks
  if (e == 1) then
    currentTrack = util.clamp(currentTrack + d, 1, #rhythmicDisplay)
    curXbeat = 1
    curXdiv = 1
    updateCursor()
    curYPos = (currentTrack - 1) * (64 / #rhythmicDisplay)
    screenDirty = true
  end

  -- move cursor in time
  if (e == 2) then
    --in/decrement the position in the array
    curXdiv = curXdiv + d
    -- moving up to the next beat
    if curXbeat == 0 and curXdiv > 1 then
      curXbeat = 1
      curXdiv = 1 
      elseif curXbeat == 0 and curXdiv < 1 then 
        curXbeat = 0
        curXdiv = 1 else
      -- if we go over the beat div
      if curXdiv > rhythmicDisplay[currentTrack][curXbeat] then -- inc beat, reset div
        curXbeat = curXbeat + 1
        curXdiv = 1
        if curXbeat > rhythmicDisplay[currentTrack][1] then       -- check for over
          curXbeat = rhythmicDisplay[currentTrack][1]
          curXdiv = rhythmicDisplay[currentTrack][curXbeat + 1]
        end
      end
    end
    if curXbeat > 0 and curXdiv < 1 then curXbeat = curXbeat-1  -- if we bottom out
      if curXbeat == 0 then curXdiv = 1 else
      curXdiv = rhythmicDisplay[currentTrack][curXbeat] end
    end
    if curXbeat < 0 then curXbeat = 0
      curXdiv = 1 end

    updateCursor() -- update cursor
    
    screenDirty = true
  end

  --adjust beat/subdiv amount
  if (e == 3) then
    if curXbeat > 0 then        -- change subdiv
      rhythmicDisplay[currentTrack][curXbeat] = rhythmicDisplay[currentTrack][curXbeat] + d
      if rhythmicDisplay[currentTrack][curXbeat] < 1 then
        rhythmicDisplay[currentTrack][curXbeat] = 1 end
      if rhythmicDisplay[currentTrack][curXbeat] > 12 then
        rhythmicDisplay[currentTrack][curXbeat] = 12 end
      else                      -- change number of beats
      if d > 0 then             -- add beat
        table.insert(rhythmicDisplay[currentTrack], 1)
      else                      -- remove beat
        if rhythmicDisplay[currentTrack][1] > 1 then
        table.remove(rhythmicDisplay[currentTrack], rhythmicDisplay[currentTrack][1]) end
      end
    end
    screenDirty = true
  end

end

function cleanup() --------------- cleanup() is automatically called on script close
  clock.cancel(redraw_clock_id) -- melt our clock via the id we noted
  -- should we melt the ticker clock too?
end
