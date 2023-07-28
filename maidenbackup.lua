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

--tick along, play events
function ticker()
  while isPlaying do
    if (clockPosition >= 1) then clockPosition = 0 end  --loop clock
--[[    for i, data in ipairs(trackEvents) do     --check if it's time for an event
      if (data[4] ~=nil) then --if there's an event to check
        local localTick = clockPosition - trackTiming[data[3]+1]  --offset track playhead position by track offset
        if localTick > totalBeats then localTick = 0 - trackTiming[data[3]+1]   --check we're not out of bounds
        else if localTick < 0 then localTick = totalBeats - trackTiming[data[3]+1] end
        end
        if (localTick == math.floor(totalBeats * (data[1]))) then  --finally, play an event?
          softcut.position(data[3]+1,data[3]+1) -- put the voice playhead in the right place
          softcut.level(data[3]+1,data[4])  --set dynamic level
          softcut.play(data[3]+1,1) -- play
        end
      end
    end
    if clockPosition % 16 == 0 then screenDirty = true end -- redraw screen every x ticks --]]
    clockPosition = clockPosition + tick -- move to next clock position
    clock.sync(1/192) -- and wait
  end
end

function init()
  redraw_clock_id = clock.run(redraw_clock) --add these for other clocks so we can kill them at the end

  -- screen variables
  screenWidth = 128
  screenHeight = 64
  
  rhythmicDisplay = {    -- [1] = number of beats, then the rest is the subdivion in each beat
    {4, 1, 1, 1, 1},
    {4, 1, 1, 1, 1},
    {4, 1, 1, 1, 1},
    {4, 1, 1, 1, 1}
  }
  
  noteEvents = {           -- pairs. [track][decimal time of note]

  }

  -- declare init cursor variables
  currentTrack,curXbeat,curXdiv,curXdisp,displayWidthBeat,curYPos=1,1,1,1,1,0
  tick = 1 / 192
  isPlaying = false
  -- calculate some other init cursor values
  -- 1 / number of beat * 1 / number of subdivs in current beat
  curXwidth = (1 / rhythmicDisplay[currentTrack][1]) * (1 / rhythmicDisplay[currentTrack][curXbeat + 1])
  
  updateCursor()
  redraw()
end

function updateCursor() -- calculate the x position: beat + subdivision, and width of subdision
  if curXbeat == 0 then
    beatoffset = 0
    subdivoffset = 0
    curXwidth = screenWidth
  else
    beatoffset = (curXbeat - 1) / rhythmicDisplay[currentTrack][1]
    subdivoffset = (1 / rhythmicDisplay[currentTrack][1]) * ((curXdiv - 1) / rhythmicDisplay[currentTrack][curXbeat + 1])
    curXwidth = math.floor(screenWidth * (1 / rhythmicDisplay[currentTrack][1]) * (1 / rhythmicDisplay[currentTrack][curXbeat + 1]))
  end
  curXdisp = math.floor((beatoffset + subdivoffset) * screenWidth)
end

function redraw()
  screen.clear()
  screen.line_width(1)
  
    -- rectangle for cursor background
  screen.level(1)
  screen.rect(curXdisp, curYPos, curXwidth, (screenHeight / #rhythmicDisplay))
  screen.fill()

  --DON'T TOUCH -- THIS IS WORKING
  -- lines for each beat and subdivision
  -- rectangles for notes
  -- for each track
  trackHeight = 1 / #rhythmicDisplay
  for i = 1, #rhythmicDisplay do                --for each track
    displayWidthBeat = 1 / rhythmicDisplay[i][1]
    for j = 1, rhythmicDisplay[i][1]  do         -- for each beat (skip first index of rhythmicDisplay[currentTrack])
  		displayWidthSubdiv = displayWidthBeat / rhythmicDisplay[i][j+1]
      for k = 1, rhythmicDisplay[i][j + 1] do     --for each subdivision
        --calculate the position and height of each line
        nowPosition = displayWidthBeat * (j - 1) + displayWidthSubdiv * (k - 1)
        nowPixel = math.floor(nowPosition * screenWidth)
        nowHeight = math.floor(trackHeight * (i - 1) * screenHeight)
        -- draw notes
        for l=1, #noteEvents do
          if i == noteEvents[l][1] and nowPosition == noteEvents[l][2] then
            screen.level(2)
            screen.rect(nowPixel, nowHeight, math.floor(128 * displayWidthSubdiv), screenHeight / #rhythmicDisplay)
            screen.fill()
          end
        end
        --draw the lines and cursor
        screen.level(5)
        if k == 1 then screen.level(15) end
        if clockPosition >= nowPosition and clockPosition < nowPosition + displayWidthSubdiv then
            screen.level(2)
            screen.rect(nowPixel, nowHeight, math.floor(128 * displayWidthSubdiv), screenHeight / #rhythmicDisplay)
            screen.fill()
        else
          screen.move(nowPixel, nowHeight)
          screen.line_rel(1, screenHeight / #rhythmicDisplay)
          screen.stroke()
        end
      end
    end
  end
  --DON"T TOUCH
  
  -- rectangle for cursor outside
  screen.level(4)
  screen.rect(curXdisp + 2, curYPos + 1, curXwidth - 1, (screenHeight / #rhythmicDisplay) - 2)
  screen.stroke()
  
  screen.update()
end

function enc(e, d)
  --move cursor between tracks
  if (e == 1) then
    currentTrack = util.clamp(currentTrack + d, 1, #rhythmicDisplay)
    curXbeat = 1
    curXdiv = 1
    updateCursor()
    curYPos = math.floor((currentTrack - 1) * (screenHeight / #rhythmicDisplay))
    screenDirty = true
  end

  -- move cursor in time
  if (e == 2) then
    --in/decrement the position in the array
    curXdiv = curXdiv + d
                                    --going up
    if curXdiv > rhythmicDisplay[currentTrack][curXbeat + 1] then
      curXbeat = curXbeat + 1
      if curXbeat > rhythmicDisplay[currentTrack][1] then 
        curXbeat = rhythmicDisplay[currentTrack][1]
        curXdiv = rhythmicDisplay[currentTrack][curXbeat + 1]
        else curXdiv = 1
      end
    end
    if curXdiv < 1 then             --going down
      curXbeat = curXbeat - 1
      if curXbeat < 1 then curXbeat, curXdiv = 0, 1 else
      curXdiv = rhythmicDisplay[currentTrack][curXbeat + 1] end
    end

    updateCursor() -- update cursor
    
    screenDirty = true
  end

  --adjust beat/subdiv amount
  if (e == 3) then       -- change subdiv
    -- if we're changing beats
    if curXbeat == 0 then
      if d > 0 then
        if rhythmicDisplay[currentTrack][1] < 12 then
        table.insert(rhythmicDisplay[currentTrack], 1)
        rhythmicDisplay[currentTrack][1] = rhythmicDisplay[currentTrack][1] + 1 end
      else rhythmicDisplay[currentTrack][1] = util.clamp(rhythmicDisplay[currentTrack][1] - 1, 1, 12)
      end
    -- if we're not on beats, just change the subdiv
    else 
      rhythmicDisplay[currentTrack][curXbeat + 1] = util.clamp(rhythmicDisplay[currentTrack][curXbeat + 1] + d, 1, 12) end
    
    if curXdiv > rhythmicDisplay[currentTrack][curXbeat + 1] then
      curXdiv = rhythmicDisplay[currentTrack][curXbeat + 1] end
    updateCursor()
    screenDirty = true
  end

end

function key(k, z)
  --add/remove notes
  if k==3 and z==1 then
    local foundOne = false
    local displayWidthBeat = 1 / rhythmicDisplay[currentTrack][1]
    local displayWidthSubdiv = displayWidthBeat / rhythmicDisplay[currentTrack][curXbeat + 1]
    local nowPosition = displayWidthBeat * (curXbeat - 1) + displayWidthSubdiv * (curXdiv - 1)
    print('cursor at: '..nowPosition)

    if #noteEvents > 0 then --if we've got any notes at all
      for i=1, #noteEvents do
        if currentTrack == noteEvents[i][1] and nowPosition == noteEvents[i][2] then
          --remove this note
          table.remove(noteEvents[i])
          foundOne = true
          screenDirty = true
        end
      end
    end 
    if (not foundOne) then -- if we didn't delete
      table.insert(noteEvents, 1, {currentTrack, nowPosition}) -- insert a new note
      screenDirty = true
    end
  end

  if (k == 2 and z == 1) then
    if isPlaying then
      isPlaying = false
      clockPosition = 0
    else
      isPlaying = true
      clock.run(ticker) -- need to call this every time? hmm
    end
  end  
end

function cleanup() --------------- cleanup() is automatically called on script close
  clock.cancel(redraw_clock_id) -- melt our clock via the id we noted
  -- should we melt the ticker clock too?
end
