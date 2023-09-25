-- # scholastic
-- A norns script that borrows
-- ideas from Modalics's Beat 
-- Scholar:
-- https://www.modalics.com/
-- beatscholar
-- 
-- E1: Select track
-- - Scroll to track 0 to change 
--   number of tracks with E3
-- E2: Select position
-- - Scroll to beat 0 to change 
--   number of beats with E3
-- E3 - -+ tracks/beat/division
-- K1 + E1: Transpose
-- K1 + E2: Engine Release
-- K1 + E3: Engine PWidth
-- 
-- K2: Play/Stop
-- K3: Insert / remove a note
-- K1 + K3: Edit Velocity

util = require "util"
MusicUtil = require "musicutil"
nb= require "scholastic/lib/nb"
engine.name = 'PolyPerc'

local grid = util.file_exists(_path.code.."midigrid") and include "midigrid/lib/mg_128" or grid
g = grid.connect()

function redraw_clock() ----- a clock that draws space
  while true do ------------- "while true do" means "do this forever"
    clock.sleep(1/15) ------- pause for a fifteenth of a second (aka 15fps)
    if screenDirty or isPlaying or heldKeys[1] then ---- only if something changed
      redraw() -------------- redraw space
      if hudTime < 0 then
        screenDirty = false -- and everything is clean again
      end
    end
    if gridDirty then
      redrawGrid()
      gridDirty = false
    end
  end
end

--tick along, play events
function ticker()
  while isPlaying do
    for i = 1, #noteEvents do                           -- play notes
      if noteEvents[i][4] and noteEvents[i][1] <= tracksAmount then
        if math.floor(util.round(clockPosition*192,0.0001)) == math.floor(util.round(noteEvents[i][2] * 192 * (4 * clock_div), 0.0001)) then
          local track = noteEvents[i][1]
					-- if we want to play a note:
					if note_output == 1 then 
					  engine.amp(noteEvents[i][4]/128)
					  engine.hz(MusicUtil.note_num_to_freq(rhythmicDisplay[noteEvents[i][1]]['n'])) 
					end
					if note_output == 2 then
          	local player = params:lookup_param("voice_id"):get_player()
            player:play_note(rhythmicDisplay[noteEvents[i][1]]['n'], noteEvents[i][4]/128, noteEvents[i][3])
          end
					if note_output == 3 then
					  play_midi_note(rhythmicDisplay[track]['n'], noteEvents[i][3], noteEvents[i][4])
					end
        end
      end
    end
    clockPosition = clockPosition + tick           -- move to next clock position
    if (clockPosition >= 4 * clock_div) then clockPosition = 0 end  --loop clock
    clock.sync(1/192)                               -- and wait
  end
end

function init()
  nb:init()
  redraw_clock_id = clock.run(redraw_clock) --add these for other clocks so we can kill them at the end
  ticker_clock_id = clock.run(ticker)
  --note_clock_id = clock.run(play_midi_note)
  clockPosition = 0
  screenDirty = true
  gridDirty = true
	velocity_mode = false
  screen.line_width(1)

  --playing notes stuff
	note_destinations = {"engine", "nb voice", "midi out"}
	note_output = 1
  function play_midi_note(note, duration, velocity)  
    midi_device[midi_target]:note_on(note, velocity)
    local note_time = clock.get_beat_sec() * duration * 4 - 0.01
    clock.run(
      function()
        clock.sleep(note_time)
        midi_device[midi_target]:note_off(note, 0)
      end
    )
  end

  --engine stuff
  engine.amp(1)
  engine.release(0.2)

  -- screen variables
  screenWidth = 128
  screenHeight = 64
  curFlashTime = 0
  function curFlash()
    local level = 0
    curFlashTime = curFlashTime + 1
    if curFlashTime > 8 then curFlashTime = 0 end
    if curFlashTime > 4 then level=15 else level = 10 end
    return screen.level(level)
  end
  hudTime = 0						-- times HUD popups when changing params
  velHudTime = 0						-- times HUD popups when changing velocities
  
  rhythmicDisplay = {    -- [1] = number of beats, then the rest is the subdivion in each beat, 'f'=h z for engine
  }
  for i=1, 8 do
    rhythmicDisplay[i] = {4,1,1,1,1}
  end
  
  noteEvents = {}           -- [track][decimal time of note][decimal length]

  -- declare init cursor variables
  currentTrack,curXbeat,curXdiv,curXdisp,displayWidthBeat,curYPos=1,1,1,1,1,0
  tick = 1 / 192
  clock_div = 1
  isPlaying = false
  -- calculate some other init cursor values
  -- 1 / number of beat * 1 / number of subdivs in current beat
  curXwidth = (1 / rhythmicDisplay[currentTrack][1]) * (1 / rhythmicDisplay[currentTrack][curXbeat + 1])
  
  heldKeys = {false, false, false}
  for i =1 , 3 do
    norns.enc.sens(i, 4)
  end
  changedBeat = {}

  --params
  params:add_separator("-Scholastic Global-")
  params:add_number("tracksAmount", "Number of Tracks", 1, 8, 4)
  params:set_action("tracksAmount", function(x) tracksAmount = x end)
  params:add_number("clock_div", "Clock Divide", 1, 4, 1)
  params:set_action("clock_div", function(x) clock_div = x end)
	params:add{type="option", id="note_output", name="Output", options=note_destinations, default=1, action=function(x) note_output=x
	  if x==1 then params:show('Pulse Width')
	    params:show('Release')
	    else params:hide('Release') 
	      params:hide('Pulse Width') 
	  end
	  if x==3 then params:show('midi target') else params:hide('midi target') end
	  if x==2 then params:show('voice_id') else params:hide('voice_id') end
	  _menu.rebuild_params()
	end}
	nb:add_param("voice_id", "nb voice") -- adds a voice selector param to your script.
  nb:add_player_params() -- Adds the parameters for the selected voices to your script.

		--MIDI--
	midi_device = {} -- container for connected midi devices
  midi_device_names = {}
  midi_target = 1
  for i = 1,#midi.vports do -- query all ports
    midi_device[i] = midi.connect(i) -- connect each device
    table.insert(midi_device_names, i..": "..util.trim_string_to_width(midi_device[i].name,80) -- value to insert
    )
  end
  params:add_option("midi target", "MIDI Device",midi_device_names,1)
  params:set_action("midi target", function(x) midi_target = x end)
	--END MIDI--
  params:add{type="control",id="Release",controlspec=controlspec.new(0,10,'lin',0,0.5,''),
    action=function(x) engine.release(x) end}
  params:add{type="control",id="Pulse Width",controlspec=controlspec.new(0,1,'lin',0,0.5,''),
    action=function(x) engine.pw(x) end}
  --set notes for each track
  params:add_separator("Output Notes")
  params:add_group("output notes", "output notes", 8)
  for i=1, 8 do
    rhythmicDisplay[i]['n'] = 36+i*2
    params:add_number("track"..i.."note", "Track "..i.." Note:", 1, 127, 36+i*2)
    params:set_action("track"..i.."note", function(x)
      rhythmicDisplay[i]['n'] = x
    end)
  end

    -- here, we set our PSET callbacks for save / load:
  params.action_write = function(filename,name,number)
    os.execute("mkdir -p "..norns.state.data.."/"..number.."/")
    tab.save(rhythmicDisplay,norns.state.data.."/"..number.."/display.data")
    tab.save(noteEvents,norns.state.data.."/"..number.."/notes.data")
  end
  params.action_read = function(filename,silent,number)
    midi_device[midi_target]:cc(123,0,1) -- all notes off
    print("finished reading '"..filename.."'", number)
    note_data = tab.load(norns.state.data.."/"..number.."/display.data")
    rhythmicDisplay = note_data -- send this restored table to the sequins
    note_data = tab.load(norns.state.data.."/"..number.."/notes.data")
    noteEvents = note_data -- send this restored table to the sequins
    updateCursor()
    curYPos = math.floor((currentTrack - 1) * (screenHeight / tracksAmount))
  end
  params.action_delete = function(filename,name,number)
    print("finished deleting '"..filename, number)
    norns.system_cmd("rm -r "..norns.state.data.."/"..number.."/")
  end
  params:bang()
  --end params
  
  params:default()
  
  updateCursor()
  redraw()
end

function updateCursor() -- calculate the x position: beat + subdivision, and width of subdision
  if curXbeat == 0 or currentTrack == 0 then
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

function change_velocity(d)
  local displayWidthBeat = 1 / rhythmicDisplay[currentTrack][1]
  local displayWidthSubdiv = displayWidthBeat / rhythmicDisplay[currentTrack][curXbeat + 1]
  if #noteEvents > 0 then --if we've got any notes at all
    for i=1, #noteEvents do
      if noteEvents[i][4] then
        local noteX = math.floor(noteEvents[i][2] * 128) / 128
        local curX = curXdisp / screenWidth
        if (currentTrack == noteEvents[i][1] and curX >= noteX and curX < noteX + noteEvents[i][3] ) or (currentTrack == noteEvents[i][1] and curX + displayWidthSubdiv > noteX and curX + displayWidthSubdiv <= noteEvents[i][2] + noteEvents[i][3]) then
            noteEvents[i][4] = util.clamp(noteEvents[i][4] + d, 1, 127)
            screenDirty = true
        end
      end
    end
  end
end

function redraw()
  screen.clear()

	-- draw note events
	if velocity_mode then screen.level(1) else screen.level(3) end
  for i=1, #noteEvents do
    if noteEvents[i][4] then
      screen.rect(
        noteEvents[i][2] * 128, 
        (noteEvents[i][1] - 1) * (screenHeight / tracksAmount),
        noteEvents[i][3] * 128, 
        screenHeight / tracksAmount)
      screen.fill()
    end
  end

--DON'T TOUCH -- THIS IS WORKING
  -- lines for each beat and subdivision
  trackHeight = 1 / tracksAmount
	--for each track:
  for i = 1, tracksAmount do
    displayWidthBeat = 1 / rhythmicDisplay[i][1] -- calc track beat width
		-- for each beat in track:
    for j = 1, rhythmicDisplay[i][1]  do
  		displayWidthSubdiv = displayWidthBeat / rhythmicDisplay[i][j+1] -- calc subdivision width in each beat
			--for each subdivision:
      for k = 1, rhythmicDisplay[i][j + 1] do
        --calculate the x, y position and height of each line
        nowPosition = displayWidthBeat * (j - 1) + displayWidthSubdiv * (k - 1) -- get x pos 0-1
        nowPixel = math.floor(nowPosition * screenWidth) -- covert to pixel
        nowHeight = math.floor(trackHeight * (i - 1) * screenHeight) -- get y pos pixel
        --draw squares, flashing if playing back
        if isPlaying and clockPosition/(4 * clock_div) >= nowPosition  and clockPosition/(4 * clock_div) < nowPosition + displayWidthSubdiv then
          --flash squares, or don't
          local level = 1 + math.floor(10 * (nowPosition + displayWidthSubdiv - clockPosition / (4 * clock_div)))
          if velocity_mode then screen.level(2) else screen.level(level) end
          screen.rect(nowPixel, nowHeight, math.floor(128 * displayWidthSubdiv), screenHeight / tracksAmount)
          screen.fill()
          for m=1, #noteEvents do
            if noteEvents[m][3] then
              if i == noteEvents[m][1] and clockPosition/(4 * clock_div) >= noteEvents[m][2] and clockPosition/(4*clock_div) < noteEvents[m][2] + noteEvents[m][3] then
                local level = 8 + math.floor(25 * (nowPosition + displayWidthSubdiv - clockPosition/(4*clock_div)))
                screen.level(level)
                screen.rect(noteEvents[m][2] * 128, nowHeight, math.floor(screenWidth * noteEvents[m][3]), screenHeight / tracksAmount)
                screen.fill()
              end
            end
          end
        end
        --draw the lines
        local gridlevel = 5
        screen.level(6)
        if k == 1 then screen.level(15)
          gridlevel = 15 end
        if velocity_mode then screen.level(4) end
        if velocity_mode and k == 1 then screen.level(8) end
        screen.move(nowPixel, nowHeight)
        screen.line_rel(0, screenHeight / tracksAmount)
        screen.stroke()
      end
    end
  end
  --DON"T TOUCH
  -- add a highlight line to each note
  for m=1, #noteEvents do
    if noteEvents[m][4] then
      screen.level(4)
      screen.move(math.floor(noteEvents[m][2] * screenWidth), (noteEvents[m][1] - 1) * (screenHeight / tracksAmount))
      screen.line_rel(0, screenHeight / tracksAmount)
      screen.stroke()
    end
  end
  
  -- rectangle for cursor outside
  if currentTrack == 0 then
    curFlash()
    screen.rect(1, 1, screenWidth-1, screenHeight-1)
    screen.stroke()
    screen.level(1)
    screen.rect(2, 2, screenWidth - 3, screenHeight -3)
    screen.stroke()
  else
    curFlash()
    y,l = curYPos, screenHeight / tracksAmount
    if velocity_mode then y,l = 0, screenHeight end
    screen.rect(curXdisp+1, y + 1, math.max(curXwidth - 2, 1), l - 1)
    screen.stroke()
    screen.level(1)
    screen.rect(curXdisp+2, y + 2, math.max(curXwidth - 4, 0), l - 3)
    screen.stroke()
  end
  --HUD for values
  if heldKeys[1] then
    if note_output == 1 then
      screen.level(2)
      screen.rect(0,57,51,12) --release
      screen.rect(92,57,42, 21) --width
      screen.fill()
      screen.level(1)
      screen.rect(0,57,51,12) --r
      screen.rect(92,57,42, 21) --w
      screen.stroke()
      screen.level(15)
      screen.move(1,63)
      screen.text("release: "..params:get("Release"))
      screen.move(127, 63)
      screen.text_right("pw: "..params:get("Pulse Width"))
    end
    if note_output == 3 then
      screen.rect(92,57,42, 21) --w
      screen.stroke()
      screen.level(15)
      screen.move(127, 63)
      screen.text_right("MIDI device "..midi_device_names[midi_target])
    end
    for i=1, tracksAmount do
      screen.level(2)
      screen.rect(58,((screenHeight / tracksAmount) / 2) + (i - 1) * (screenHeight / tracksAmount) - 4,12,8) --note
      screen.fill()
      screen.level(15)
      screen.move(64,((screenHeight / tracksAmount) / 2) + (i - 1) * (screenHeight / tracksAmount) + 2)
      screen.text_center(MusicUtil.note_num_to_name(params:get('track'..i..'note'), true))
    end
    screen.fill()
  end
  
  --HUD for beat changes
  if #changedBeat > 0 then
    hudTime = hudTime - 1
    if changedBeat[1] == -1 then
      screen.level(1)
      screen.rect(59,28,10,8)
      screen.fill()
      screen.level(15)
      screen.move(64,34)
      screen.text_center(tracksAmount)
    else if hudTime < 0 then changedBeat = {}
      else
        if curXbeat > 0 then
          local xpos = (changedBeat[2] - 1) * (screenWidth / rhythmicDisplay[currentTrack][1]) + ((screenWidth / rhythmicDisplay[currentTrack][1]) / 2)
          screen.level(1)
          screen.rect(xpos - 5,(currentTrack - 1) * screenHeight / tracksAmount + screenHeight / (tracksAmount * 2) -4,11,8)
          screen.fill()
          screen.level(15)
          screen.move(xpos, 
            changedBeat[1] * (screenHeight /tracksAmount) - ((screenHeight /tracksAmount) / 2) + 2)
            screen.text_center(changedBeat[3])
        else -- we changed beat
          screen.level(1)
          screen.rect(59,(currentTrack - 1) * screenHeight / tracksAmount + screenHeight / (tracksAmount * 2) -4,11,8)
          screen.fill()
          screen.level(15)
          screen.move(64,(currentTrack - 1) * screenHeight / tracksAmount + screenHeight / (tracksAmount * 2) + 2)
          screen.text_center(rhythmicDisplay[currentTrack][1])
        end
      end
    end
  end
  
  --HUD for velocity
  if velocity_mode then
    velHudTime = velHudTime - 1
    if #noteEvents > 0 then
      for i=1, #noteEvents do
        if noteEvents[i][4] and noteEvents[i][1] == currentTrack then
          local x = (noteEvents[i][2] + noteEvents[i][3]/2) * screenWidth
          local y = 63 - (noteEvents[i][4] / 2)
          --bottom line
          screen.level(15)
          screen.move(x,y+1)
          screen.line(x,64)
          --horiz line
          screen.move(noteEvents[i][2]* screenWidth,y+1)
          screen.line((noteEvents[i][2] + noteEvents[i][3])* screenWidth,y+1)
          screen.stroke()
          --text
          if velHudTime > 0 and curXdisp == noteEvents[i][2]*128 then
            screen.level(1)
            screen.rect(x-5,y-5,11,7)
            screen.fill()
            screen.level(15)
            local ty = 0
            if y < 5 then ty = 5 else ty = y end
            screen.move(x,ty)
            screen.text_center(noteEvents[i][4])
            screen.stroke()
          end
          if velHudTime < 0 then velHudTime = 0 end
          --[[top line
          screen.move(x,0)
          screen.level(2)
          screen.line(x,y)
          screen.stroke()]]--
        end
      end
    end
  end
  
  screen.update()

end

function redrawGrid()
--[[  print('drawing grid')
  local grid_h = g.rows
  print()
  g:all(0)
  -- draw grid
--  if grid_h == 16 then
    for r=1, 16 do
      for i=1, tracksAmount do -- for each track
        for j=1, rhythmicDisplay[i][1] do --for each beat
          local beatpos = 1 + math.floor(j / rhythmicDisplay[i][1])
          for k=1, rhythmicDisplay[i][j+1] do
            divpos = math.floor(k / rhythmicDisplay[i][j])
            print('checking at '..16 * beatpos * divpos)
            if r == 16 * beatpos * divpos then
              local glevel = 3 else glevel = 0 
            end
            print('drawing a light at '..r..', '..k)
            g.level(r,k,glevel)
          end
        end
      end
--    end
  end
  g:refresh()--]]
end

function enc(e, d) --START ENCODERS
  
  if e == 1 or e==2 then changedBeat = {} end

	--E1:
  if e==1 and heldKeys[1] then 	-- transpose
    if currentTrack == 0 then		--transpose all
      for i = 1, tracksAmount do
        local nownote = params:get("track"..i.."note")
        params:set("track"..i.."note", nownote + d)
      end
    else local nownote = params:get("track"..currentTrack.."note")
      params:set("track"..currentTrack.."note", nownote + d)
    end
  elseif (e == 1 and not velocity_mode) then	--change track
    local foundit = false
    curXdisp = curXdisp / 128
    if currentTrack > 0 then
      displayWidthBeat = 1 / rhythmicDisplay[currentTrack][1]
      dws = displayWidthBeat / rhythmicDisplay[currentTrack][curXbeat+1]
      xcenter = curXdisp + dws * 0.5
    else
      displayWidthBeat = 1
      dws = 1
      xcenter = 0
    end
    currentTrack = util.clamp(currentTrack + d, 0, tracksAmount)  --change track
    -- how wide is a beat, decimal
    if currentTrack > 0 then displayWidthBeat = 1 / rhythmicDisplay[currentTrack][1] end
    -- for each beat
    if currentTrack > 0 then
      for i=1, rhythmicDisplay[currentTrack][1] do
        --how wide is subdiv in this beat
        dws = displayWidthBeat / rhythmicDisplay[currentTrack][i+1]
        dwb = displayWidthBeat * (i - 1)
        for j=1, rhythmicDisplay[currentTrack][i + 1] do
          -- if cursor pos is within this subdiv
          if xcenter >= dwb + dws * (j - 1) and xcenter < dwb + dws * (j) then
            curXbeat = i
            curXdiv = j
            foundit = true
            break
          end
          if foundit then break end
        end
        if foundit then break end
      end
    end
    updateCursor()
    curYPos = math.floor((currentTrack - 1) * (screenHeight / tracksAmount))
    screenDirty = true
    gridDirty= true
  end

	--	E2:
  if heldKeys[1] and e==2 then	-- engine release
    local release = params:get("Release")
    params:set("Release", release + d * 0.1)
  elseif heldKeys[1] == false and (e == 2)  and currentTrack > 0 then -- 	move cursor in time
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
    gridDirty= true
  end

	-- E3:
  if heldKeys[1] and e==3 and not velocity_mode then	-- engine PW
    local release = params:get("Pulse Width")
    params:set("Pulse Width", util.clamp(release + d * 0.01, 0.01, 0.99))
  elseif (e == 3 and not velocity_mode) then 	--adjust beat/subdiv amount
    -- if we're changing beats
    if currentTrack > 0 then
      if curXbeat == 0 then
        if d > 0 then
          if rhythmicDisplay[currentTrack][1] < 12 then
          table.insert(rhythmicDisplay[currentTrack], 1)
          rhythmicDisplay[currentTrack][1] = rhythmicDisplay[currentTrack][1] + 1 end
        else rhythmicDisplay[currentTrack][1] = util.clamp(rhythmicDisplay[currentTrack][1] - 1, 1, 12)
        end
      else	-- if we're not on beats, just change the subdiv
        rhythmicDisplay[currentTrack][curXbeat + 1] = util.clamp(rhythmicDisplay[currentTrack][curXbeat + 1] + d, 1, 12) end
    else params:set("tracksAmount", util.clamp(tracksAmount + d, 1, 8))  --change number of tracks
      redraw()
    end
    if currentTrack > 0 and curXdiv > rhythmicDisplay[currentTrack][curXbeat + 1] then
      curXdiv = rhythmicDisplay[currentTrack][curXbeat + 1] end
    if currentTrack > 0 then changedBeat = {currentTrack,curXbeat,rhythmicDisplay[currentTrack][curXbeat + 1]} 
      else changedBeat = {-1,-1,-1}
    end
    updateCursor()
    screenDirty = true
    gridDirty= true
    hudTime = 15
  elseif e==3 and velocity_mode then	-- adjust note velocity
    change_velocity(d)
    velHudTime = 15
  end

end -- END OF ENCODERS

-- START OF BUTTONS
function key(k, z)
  
  heldKeys[k] = z == 1
  if k==1 then screenDirty = true end
  
  --add/remove notes
  if k==3 and z==1 and not heldKeys[1] then
    local foundOne = false
    local displayWidthBeat = 1 / rhythmicDisplay[currentTrack][1]
    local displayWidthSubdiv = displayWidthBeat / rhythmicDisplay[currentTrack][curXbeat + 1]
    local nowPosition = util.round(displayWidthBeat * (curXbeat - 1) + displayWidthSubdiv * (curXdiv - 1), 1/128)

    if #noteEvents > 0 then --if we've got any notes at all
      for i=1, #noteEvents do
        if noteEvents[i][3] then
          if (currentTrack == noteEvents[i][1] and nowPosition >= noteEvents[i][2] and nowPosition < util.round(noteEvents[i][2] + noteEvents[i][3], 0.0001) ) or (currentTrack == noteEvents[i][1] and nowPosition + displayWidthSubdiv > noteEvents[i][2] and nowPosition + displayWidthSubdiv <= noteEvents[i][2] + noteEvents[i][3]) then
            --remove this note
            table.remove(noteEvents[i])
            foundOne = true
            screenDirty = true
            gridDirty= true
          end
        end
      end
    end 
    if (not foundOne) then -- if we didn't delete
			-- insert a new note
      table.insert(noteEvents, 1, {currentTrack, nowPosition, util.round(displayWidthSubdiv, 1/128), 100})
      screenDirty = true
      gridDirty= true
    end
  end

  if (k == 2 and z == 1) then
    if heldKeys[1] then
      if isPlaying then
        isPlaying = false
        midi_device[midi_target]:cc(123,0,1) -- all notes off
      else
        isPlaying = true end
    else
      if isPlaying then
      isPlaying = false
      clockPosition = 0
      midi_device[midi_target]:cc(123,0,1) -- all notes off
    else
      isPlaying = true
      clock.run(ticker) -- need to call this every time? hmm
    end
    end
    screenDirty,gridDirty = true, true
  end

	-- toggle velocity mode
	if k==3 and z==1 and heldKeys[1] then
		if velocity_mode then velocity_mode = false else velocity_mode = true end
	end
end -- END OF BUTTONS

function cleanup() --------------- cleanup() is automatically called on script close
  midi_device[midi_target]:cc(123,0,1) -- all notes off
  clock.cancel(redraw_clock_id) -- melt our clock via the id we noted
  -- should we melt the ticker clock too?
  clock.cancel(ticker_clock_id)
end
