//Auto Reconnect by Extra Mental

AddCSLuaFile()
if SERVER then return end

local function Message(Msg)
    print("[Auto Reconnect] "..Msg)
end
Message("Loaded.")

RunConsoleCommand("cl_timeout","300")

surface.CreateFont( "ARFontTitle",{
    font = "Trebuchet",
    size = ScrH()/1.5/18
})

surface.CreateFont( "ARFontBody",{
    font = "Trebuchet",
    size = ScrH()/1.5/15
})

surface.CreateFont( "ARFontButton",{
    font = "Trebuchet",
    size = ScrH()/1.5/12
})

local API = "http://api.steampowered.com/ISteamApps/GetServersAtAddress/v0001?addr="

local Menu
local WaitMsg = ""
local Cancelled = false
local IP = game.GetIPAddress()
local MenuOpen = false
local IsTimingOut = false
local LastPing = RealTime()
local CountDown = 30
local LastDec = 0
local CountDownActive = false

//Check if the server is online, then start the countdown.
local function PingServer()
    if Cancelled or not IsTimingOut then return end
    Message("Pinging Server")
    http.Fetch(API .. IP, function(JSON)
        //Message(JSON)
        Data = util.JSONToTable(JSON)
        local ServerCount = #Data["response"]["servers"]
        if ServerCount >= 1 then
            CountDownActive = true
            CountDown = 30
            LastDec = RealTime()
        else
            PingServer()
        end
    end, function() PingServer() end)
end

//Safely close the menu without error.
local function CloseMenu()
    if MenuOpen then
        MenuOpen = false
        CountDownActive = false
        Menu:Close()
    end
end

//Open the menu
local function OpenMenu()
    if MenuOpen or   Cancelled then return end//Dont want to open more than 1 or when cancelled

    Message("Opening menu")
    MenuOpen = true
    WaitMsg = "Waiting for server response..."
    PingServer()

    Menu = vgui.Create("DFrame")
    Menu:SetSize(ScrW()/2.5,ScrH()/5)
    Menu:SetTitle("")
    Menu:CenterHorizontal(0.5)
    Menu:CenterVertical(0)
    Menu:ShowCloseButton(false)
    Menu:MakePopup()

    Menu.Paint = function(self, W, H)
        draw.RoundedBox(0, 0, 0, W, H, Color(50,50,50,255))//Background
        draw.RoundedBox(0, 0, 0, W, H/4.8, Color(255,0,0,255))//TitleBar

        draw.SimpleText("Connection Lost D:", "ARFontTitle", W/2, 0, Color(255, 255, 255), TEXT_ALIGN_CENTER)
        draw.SimpleText(WaitMsg, "ARFontBody", W/2, H/3.3, Color(255, 255, 255), TEXT_ALIGN_CENTER)
    end

    local CancelBtn = vgui.Create("DButton")
    CancelBtn:SetParent(Menu)
    CancelBtn:SetText("")
    CancelBtn:SetSize(Menu:GetWide()/2,Menu:GetTall()/3)
    CancelBtn:SetPos(0,Menu:GetTall()-(Menu:GetTall()/3))
    CancelBtn.Paint = function( self, W, H )
        draw.RoundedBox(0, W*0.02/2, H*0.08/2, W/1.02, H/1.08, Color(255,255,255,255))
        draw.DrawText("Cancel", "ARFontButton", W/2, 2, Color(0,0,0,255), TEXT_ALIGN_CENTER)
    end

    local DiscBtn = vgui.Create("DButton")
    DiscBtn:SetParent(Menu)
    DiscBtn:SetText("")
    DiscBtn:SetSize(Menu:GetWide()/2,Menu:GetTall()/3)
    DiscBtn:SetPos(Menu:GetWide()/2,Menu:GetTall()-(Menu:GetTall()/3))
    DiscBtn.Paint = function( self, W, H )
        draw.RoundedBox(0, W*0.02/2, H*0.08/2, W/1.02, H/1.08, Color(255,255,255,255))
        draw.DrawText("Disconnect", "ARFontButton", W/2, 2, Color(0,0,0,255), TEXT_ALIGN_CENTER)
    end

    CancelBtn.DoClick = function()
        Cancelled = true
        CountDownActive = false
        CloseMenu()
    end
    DiscBtn.DoClick = function()
        RunConsoleCommand("disconnect")
    end

end
//OpenMenu()

//Ticks over while the client is connected
timer.Create("ARConnected",0.5,0,function()
    LastPing = RealTime()
    IsTimingOut = false
    Cancelled = false
    CloseMenu()
end)

local LastFrame = RealTime()

hook.Add( "Think", "ARCheck1.1", function()

  if RealTime() - LastFrame > 0.5 then//check if the client locked up, MUST BE BEFORE RETRY CODE TO PREVENT RETRY
    Message("Client recovered from lockup (".. math.Round(RealTime() - LastFrame, 2) .."s). Resetting timer.")
    LastPing = RealTime()
    IsTimingOut = false
    Cancelled = false
    LastDec = RealTime()
    CloseMenu()
  end
  LastFrame = RealTime()

    local Diff = RealTime() - LastPing
    if Diff > 5 and not IsTimingOut then
        IsTimingOut = true
        OpenMenu()
    end

    if CountDownActive and RealTime() - LastDec > 1 and IsTimingOut then
        if CountDown <= 0 then
            Message("Commencing Auto Reconnect.")
	   	   	  LocalPlayer():ConCommand("retry")
        end
        LastDec = RealTime()
        CountDown = CountDown - 1
        Message("Countdown: " .. CountDown)
        WaitMsg = "Auto reconnecting in " .. CountDown .. " seconds."
    end

end)

hook.Add("ShutDown", "ARSHUTDOWN", function()
	Message("SHUTDOWN")
end )
