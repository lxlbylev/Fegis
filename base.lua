local round = function(num, idp)
  local mult = (10^(idp or 0))
  return math.floor(num * mult + 0.5) *(1/ mult)
end
-- local moneyPath = system.pathForFile( "money.json", system.DocumentsDirectory )
local scoresPath = system.pathForFile( "scores.json", system.DocumentsDirectory )
local accountPath = system.pathForFile( "account.json", system.DocumentsDirectory )
-- local taskPath = system.pathForFile( "stats.json", system.DocumentsDirectory )
local settingsPath = system.pathForFile( "settings.json", system.DocumentsDirectory )


local json = require( "json" )


-- for k,v in pairs(EMshipfire) do
--   print(k,v)
-- end
 
local function CL(code)
  code = code:lower()
  code = code and string.gsub( code , "#", "") or "FFFFFFFF"
  code = string.gsub( code , " ", "")
  local colors = {1,1,1,1}
  while code:len() < 8 do
    code = code .. "F"
  end
  local r = tonumber( "0X" .. string.sub( code, 1, 2 ) )
  local g = tonumber( "0X" .. string.sub( code, 3, 4 ) )
  local b = tonumber( "0X" .. string.sub( code, 5, 6 ) )
  local a = tonumber( "0X" .. string.sub( code, 7, 8 ) )
  local colors = { r/255, g/255, b/255, a/255 }
  return colors
end

local events = {list={},groups={}}
local timers = {tags={},groups={}}


local function onTimer(tag)
  -- print("IN",tag,timers[tag].time, timers[tag].func, timers[tag].cycle)
  timers[tag].link = timer.performWithDelay( timers[tag].time, timers[tag].func, timers[tag].cycle )
  -- print("LINK",timers[tag].link)
end


local function openFile(dir)
  local file = io.open( dir, "r" )
 
  local data
  if file then
    local contents = file:read( "*a" )
    io.close( file )
    data = json.decode( contents )
  end
  return data
end

local function saveFile(data,dir)
  local file = io.open( dir, "w" )
 
  if file then
    file:write( json.encode( data ) )
    io.close( file )
  end
end


local star = {
  function() 
    local star = display.newImageRect(starsGroup, "emitters/simple.png", c, c)
    return star
    end,
  function() 
    local star = display.newCircle(starsGroup, 0, 0, c )
    return star
  end,
  function()
    local star = display.newRect(starsGroup, 0, 0, c, c) star.alpha=.5
    return star
  end,
}


local function printTable(val, name, skipnewlines, depth)
  skipnewlines = skipnewlines or false
  depth = depth or 0

  local tmp = string.rep(" ", depth)

  if name then
   if type(name)=="string" then name = '"'..name..'"' end
    tmp = tmp .. "[".. name .. "] = "
  end

  if type(val) == "table" then
      tmp = tmp .. "{" .. (not skipnewlines and "\n" or "")

      for k, v in pairs(val) do
          tmp =  tmp .. printTable(v, k, skipnewlines, depth + 1) .. "," .. (not skipnewlines and "\n" or "")
      end

      tmp = tmp .. string.rep(" ", depth) .. "}"
  elseif type(val) == "number" then
      tmp = tmp .. tostring(val)
  elseif type(val) == "string" then
      tmp = tmp .. string.format("%q", val)
  elseif type(val) == "boolean" then
      tmp = tmp .. (val and "true" or "false")
  else
      tmp = tmp .. "\"[inserializeable datatype:" .. type(val) .. "]\""
  end

  return tmp
end

local isDevice = (system.getInfo("environment") == "device")
local cx = round(display.contentCenterX)
local cy = round(display.contentCenterY)
local fullw  = round(display.actualContentWidth)
local fullh  = round(display.actualContentHeight)

local orig = {
  settings={
    -- joy={x=fullw - (210 + 60), y=fullh - 170 - 70, radius = 150 },
    volume={all = 50, music = 0, sfx = 100},
    style = 0,
  }
}

local function cheker(nowSet, orig, isChanged)
  nowSet = type(nowSet)=="table" and nowSet or {}
  isChanged = isChanged or false

  for k, v in pairs(orig) do
    if nowSet[k]==nil then
      -- print(k,"is nil set to",v)
      isChanged = true
      nowSet[k] = v
    elseif type(nowSet[k])=="table" then
      -- print(k,"is table in check now")
      nowSet[k], inIsChange = cheker(nowSet[k], orig[k])
      isChanged = isChanged or inIsChange
    else
      -- print(k,"already exsist")
    end
  end
  
  for k, v in pairs(nowSet) do
    if orig[k]==nil then
      nowSet[k] = nil
    end
  end
  -- print("=========")
  return nowSet, isChanged
end
local colors = {
  black = CL"323235",
  neon = CL"36d8d4",
  gold = CL"d6a938",
  violet = CL"ab38d6",
  red = CL"dd2a49",
}
local tri_shape = {0,-80, 40,0, -40,0}
local base = {
  createPlayer = function(parent, x, y)
    local group = display.newGroup()
    if parent then parent:insert( group ) end
    group.x = x or 0
    group.y = y or 0
    group.myName = "player"
    local cube = display.newRect( group, 0, 0-28*.55, 80*.55, 80*.55 )
    cube.fill = colors.black
    local line = display.newRect( group, 0, 0-28*.55, 80*.55, 20*.55 )
    local tri = display.newPolygon( group, 0, (40+40*(21/27)-28)*.55, tri_shape )
    tri.fill = colors.black
    tri.xScale = .55
    tri.yScale = (21/27)*.55
    tri.rotation = 180

    cube.alpha = 0
    tri.alpha = 0
    line.alpha = 0
    local img = display.newImageRect( group, "img/player.png", 80*.55, 80*.55 )

    group.myBody = {cube,line,tri,img}
    
    return group
  end,
  cx = cx,
  cy = cy,
  fullw = fullw,
  fullh = fullh,
  trim = function(s)
    return (s:gsub("^%s*(.-)%s*$", "%1"))
  end,
  utf8len = function(s)
    return #(s:gsub('[\128-\191]',''))
  end,

  graphicsOpt = graphicsOpt,
  options = options,
  printTable = printTable,

  CL = CL,
  div = function(num, hz)
    return num*(1/hz)-(num%hz)*(1/hz)
  end,
  getAngle = function(sx, sy, ax, ay)
    return (((math.atan2(sy - ay, sx - ax) *(1/ (math.pi *(1/ 180))) + 270) % 360))
  end,
  getSpeed = function(hypotenuse, r)
    local angle = math.abs(r*math.pi/180)
    local x = math.abs(hypotenuse*(math.sin(angle)))
    local y = math.abs(hypotenuse*(math.sin(90*math.pi/180-angle)))

    r=math.abs((r+180)%360)
    if r>180 then x= -x end
    if r>270 or r<90 then y= -y end
    return x, y
  end,
  getCathetsLenght = function(hypotenuse, angle)
    angle = math.abs(angle*math.pi/180)
    local firstL = math.abs(hypotenuse*(math.sin(angle)))
    local secondL = math.abs(hypotenuse*(math.sin(90*math.pi/180-angle)))
    return firstL, secondL
  end,
  getCathetsLenghtNoAbs = function(hypotenuse, angle)
    angle = math.abs(angle*math.pi/180)
    local firstL = hypotenuse*(math.sin(angle))
    local secondL = hypotenuse*(math.sin(90*math.pi/180-angle))
    return firstL, secondL
  end,
  getHypLenght = function(a, b)
    return (math.sqrt(a*a+b*b))
  end,
  saveSettings = function(settings)
    saveFile(settings, settingsPath)
  end,
  loadSettings = function()
    local settings = openFile(settingsPath)
    local settings, isChanged = cheker(settings, orig.settings)
    if isChanged then 
      print("Settings changed!")
      saveFile(settings, settingsPath)
    end
    return settings
  end,

  saveAccount = function(account)
    saveFile(account, accountPath)
  end,
  loadAccount = function()
    local account = openFile(accountPath)
    return account
  end,

  findBest = function(scoresTable)
    local best = 0
    for j=1, #graphicsOpt+1 do
      for i = 1, 3 do
        best = best<scoresTable[j][i] and scoresTable[j][i] or best
      end
    end
    return best
  end,
  saveScores = function(scoresTable)
    saveFile(scoresTable, scoresPath)
  end,
  loadScores = function()
    local scoresTable = openFile( scoresPath )

    if ( scoresTable == nil ) then
      scoresTable = {0}
      saveFile(scoresTable, scoresPath)
    end
    return scoresTable
  end,

  event = {
    add = function(name, butt, funcc)
    	events.list[#events.list+1]=name
    	events[name]={eventOn=false, but=butt, func=funcc}
    end,
    off = function(name, enable)
      if name==true then
        for i=1, #events.list do
          local event = events[events.list[i]]
          if event.eventOn==true then
            event.but:removeEventListener("tap", event.func)
          end
        end
      else
      	local event = events[name]
      	event.eventOn = enable or false
      	event.but:removeEventListener("tap", event.func)
      end
    end,
    on = function(name, enable)
      if name==true then
        for i=1, #events.list do
          local event = events[events.list[i]]
          if event.eventOn==true then
            event.but:addEventListener("tap", event.func)
          end
        end
      else
      	local event = events[name]
      	events.eventOn = enable or true
      	event.but:addEventListener("tap", event.func)
      end
    end,
    group = { 
      add = function(groupName,mas)
        if events[groupName]==nil then
          events.groups[#events.groups+1]=groupName
        end
        if type(mas)=="string" then
          if events[groupName]~=nil then
            events[groupName][#events[groupName]+1]=mas
          else
            events[groupName]={mas}
          end
        else
          events[groupName]=mas
        end
      end,
      on = function(groupName, enable)
        for i=1, #events[groupName] do
          local name = events[groupName][i]
          local event = events[name]
          events.eventOn = enable or true
          print(a.."#group "..groupName.." enable "..name)
          event.but:addEventListener("tap", event.func)
        end
      end,
      off = function(groupName, enable)
        for i=1, #events[groupName] do
          local name = events[groupName][i]
          local event = events[name]
          event.eventOn = enable or false
          event.but:removeEventListener("tap", event.func)
        end
      end,
    }
  },

  timer = {
    add = function(tag, time, func, cycle)
      timers.tags[#timers.tags+1]=tag
      timers[tag] = {enabled=true, func=func, time=time, cycle = cycle or 1, link = nil}
    end,
    isEnabled = function(tag)
      -- print(tag,"is",timers[tag].enabled)

      return timers[tag] and timers[tag].enabled or nil
    end,
    change = function(tag,param)
      local timer = timers[tag]
      for k,v in pairs(param) do
        timer[k] = v
      end
    end,
    restart = function(tag, sec)
      if timers[tag].link then --[[print("CANCELING",timers[tag].link)]] timer.cancel( timers[tag].link ) end
      if sec then
        timers[tag].time=sec
      end
      -- print("restarted", tag)
      onTimer(tag)
    end,
    remove = function(tag)
      timer.cancel(timers[tag].link)
      timers[tag]=nil
      for i=1, #timers.tags do
        if timers.tags[i]==tag then
          table.remove(timers.tags, i)
          break
        end
      end
    end,
    off = function(tag, enable)
      if tag==true then
        for i=1, #timers.tags do
          local tag = timers.tags[i]
          if timers[tag].enabled==true then
            timer.cancel( timers[tag].link )
          end
        end
      else
        if timers[tag].link then timer.cancel( timers[tag].link ) end
        timers[tag].enabled = enable or false
      end
    end,
    on = function(tag, enable)
      if tag==true then
        for i=1, #timers.tags do
          local tag = timers.tags[i]
          if timers[tag].enabled==true then
            onTimer(tag)
          end
        end
      else
        timers[tag].enabled = enable or true
        onTimer(tag)
      end
    end,
    group = { 
      add = function(groupName,mas)
        if timers[groupName]==nil then
          timers.groups[#timers.groups+1]=groupName
        end
        if type(mas)=="string" then
          if timers[groupName]~=nil then
            timers[groupName][#timers[groupName]+1]=mas
          else
            timers[groupName]={mas}
          end
        else
          timers[groupName]=mas
        end
      end,
      removeElement = function(groupName,name)
        if name==nil then error( "expected parameter #2 for timer.group.removeElement" ) end
        for i=1, #timers[groupName] do
          if timers[groupName][i] == name then
            -- print("REMOVED",name,"FROM",groupName)
            table.remove(timers[groupName], i)
            break
          end
        end
      end,
      on = function(groupName, enable)
        -- print("=====================")
        -- print("TIMER GROUP ON "..groupName)
        for i=1, #timers[groupName] do
          local tag = timers[groupName][i]
          -- print("\n")
          -- print(i.."# enable "..tag)
          timers[tag].enabled = enable or true
          onTimer(tag)
        end
        -- print("--------------------------")
      end,
      off = function(groupName, enable)
        -- print("=====================")
        -- print("TIMER GROUP OFF "..groupName)
        for i=1, #timers[groupName] do
          local tag = timers[groupName][i]
          -- print(i.."# disable "..tag)
          if timers[tag].link then
            -- print("DELINKED:",timers[tag].link)
            timer.cancel( timers[tag].link )
          end
          -- print("\n")
          timers[tag].enabled = enable or false
        end
        -- print("--------------------------")
      end,
      remove = function(groupName, enable)
        -- print("=====================")
        -- print("!TIMER GROUP REMOVE "..groupName)
        for i=1, #timers[groupName] do
          local tag = timers[groupName][i]
          -- print(i.."# disable "..tag)
          if timers[tag].link then
            -- print("DELINKED:",timers[tag].link)
            timer.cancel( timers[tag].link )
          end
          -- print("\n")
          timers[tag] = nil
        end

        for k, v in pairs(timers) do
          if k == groupName then
            timers[k] = nil
            -- print("TIMER GROUP REMOVED:",k )
            break
          end
        end
        -- print("--------------------------")
      end,
    }
  },
  round = round,
  emitters = {laserShip = EMshipLfire}
  }
return base
