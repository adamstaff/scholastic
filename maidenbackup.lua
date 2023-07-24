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
  curXpos=0
  curXwidth=0

  rhythmicDisplay = {
    {5, 3, 2, 4},
    {4, 3},
    {2, 2},
    {1, 1, 1, 1, 1, 6}
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
  screen.level(2)
  
  curYPos = (currentTrack - 1) * (64 / #rhythmicDisplay)
  screen.rect(0, 0, 10, (64 / #rhythmicDisplay))
  screen.fill()
  
  screen.update()
end

function enc(e, d)
  --move cursor between tracks
  if (e == 1) then
    currentTrack = util.clamp(currentTrack + d, 1, #rhythmicDisplay)
    curXpos = 0
    for i=1, #rhythmicDisplay do
    
    end
    maxXpos = totalBeats
    screenDirty = true
  end

  -- move cursor in time
  if (e == 2) then
    curXpos = curXpos + d
    displayWidthBeat = math.floor( 128 / #rhythmicDisplay[currentTrack] )
    displayWidthSubdiv = math.floor(displayWidthBeat / rhythmicDisplay[i][j])
    nowPosition = displayWidthBeat * (j - 1) + displayWidthSubdiv * (k - 1)
    curXwidth = dispayWidthBeat
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
