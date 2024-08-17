
surface.CreateFont("ScoreboardPlayer", {
    font = "Verdana_Bold",
    size = 14,
    weight = 800
})

surface.CreateFont("ScoreboardTitle", {
    font = "Verdana_Bold",
    size = 20,
    weight = 800
})

local PLAYER_LINE_TITLE = {
    Init = function(self)
        self.Players = self:Add("DLabel")
        self.Players:SetFont("ScoreboardPlayer")
        self.Players:SetTextColor(Color(255, 215, 0))
        self.Players:SetPos(10, 5)
        self.Players:SetWidth(300)

        self.Score = self:Add("DLabel")
        self.Score:SetFont("ScoreboardPlayer")
        self.Score:SetTextColor(Color(255, 215, 0))
        self.Score:SetText("Score")
        self.Score:SetPos(350, 5)
        self.Score:SetWidth(100)

        self.Deaths = self:Add("DLabel")
        self.Deaths:SetFont("ScoreboardPlayer")
        self.Deaths:SetTextColor(Color(255, 215, 0))
        self.Deaths:SetText("Deaths")
        self.Deaths:SetPos(450, 5)
        self.Deaths:SetWidth(100)

        self.Ping = self:Add("DLabel")
        self.Ping:SetFont("ScoreboardPlayer")
        self.Ping:SetTextColor(Color(255, 215, 0))
        self.Ping:SetText("Ping")
        self.Ping:SetPos(550, 5)
        self.Ping:SetWidth(100)

        self.SteamID = self:Add("DLabel")
        self.SteamID:SetFont("ScoreboardPlayer")
        self.SteamID:SetTextColor(Color(255, 215, 0))
        self.SteamID:SetText("SteamID")
        self.SteamID:SetPos(650, 5)
        self.SteamID:SetWidth(200)

        self:Dock(TOP)
        self:DockPadding(3, 3, 3, 3)
        self:SetHeight(38)
        self:DockMargin(10, 0, 10, 2)
        self:SetZPos(-8000)
    end,

    Paint = function(self, w, h)
        surface.SetDrawColor(255, 215, 0, 255)
        surface.DrawLine(0, h + 2, w, h + 2)
        surface.DrawLine(0, h - 2, w, h - 2)
    end
}

PLAYER_LINE_TITLE = vgui.RegisterTable(PLAYER_LINE_TITLE, "DPanel")

local PLAYER_LINE = {
    Init = function(self)
        self.Name = self:Add("DLabel")
        self.Name:SetFont("ScoreboardPlayer")
        self.Name:SetTextColor(Color(255, 215, 0))
        self.Name:SetPos(10, 5)
        self.Name:SetWidth(300)

        self.Score = self:Add("DLabel")
        self.Score:SetFont("ScoreboardPlayer")
        self.Score:SetTextColor(Color(255, 215, 0))
        self.Score:SetPos(350, 5)
        self.Score:SetWidth(100)

        self.Deaths = self:Add("DLabel")
        self.Deaths:SetFont("ScoreboardPlayer")
        self.Deaths:SetTextColor(Color(255, 215, 0))
        self.Deaths:SetPos(450, 5)
        self.Deaths:SetWidth(100)

        self.Ping = self:Add("DLabel")
        self.Ping:SetFont("ScoreboardPlayer")
        self.Ping:SetTextColor(Color(255, 215, 0))
        self.Ping:SetPos(550, 5)
        self.Ping:SetWidth(100)

        self.SteamID = self:Add("DLabel")
        self.SteamID:SetFont("ScoreboardPlayer")
        self.SteamID:SetTextColor(Color(255, 215, 0))
        self.SteamID:SetPos(650, 5)
        self.SteamID:SetWidth(200)

        self:Dock(TOP)
        self:SetHeight(38)
        self:DockMargin(10, 0, 10, 2)
    end,

    Setup = function(self, pl)
        self.Player = pl
        self:Think()
    end,

    Think = function(self)
        if not IsValid(self.Player) then
            self:SetZPos(9999)
            self:Remove()
            return
        end

        local name = self.Player:Nick()
        if #name > 12 then
            name = string.sub(name, 1, 12) .. "..."
        end

        self.Name:SetText(name)
        self.Score:SetText(self.Player:Frags())
        self.Deaths:SetText(self.Player:Deaths())
        self.Ping:SetText(self.Player:Ping())
        self.SteamID:SetText(self.Player:SteamID())
    end,

    Paint = function(self, w, h)
        if not IsValid(self.Player) then return end
        if self.Player == LocalPlayer() then
            draw.RoundedBox(0, -5, 0, w + 10, h - 8, Color(150, 150, 50, 100))
        end
    end
}

PLAYER_LINE = vgui.RegisterTable(PLAYER_LINE, "DPanel")

local SCORE_BOARD = {
    Init = function(self)
        self.Header = self:Add("Panel")
        self.Header:Dock(TOP)
        self.Header:SetHeight(50)

        self.Name = self.Header:Add("DLabel")
        self.Name:SetFont("ScoreboardTitle")
        self.Name:SetTextColor(Color(255, 215, 0))
        self.Name:Dock(TOP)
        self.Name:SetHeight(50)
        self.Name:SetContentAlignment(4)
        self.Name:DockMargin(50, 0, 0, 0)

        self.Scores = self:Add("DScrollPanel")
        self.Scores:Dock(FILL)
        self.Scores:DockMargin(0, 0, 0, 0)

        self.Title = self.Scores:Add(PLAYER_LINE_TITLE)
    end,

    PerformLayout = function(self)
        self:SetSize(900, ScrH() - 400)
        self:SetPos(ScrW() / 2 - 450, 150)
    end,

    Paint = function(self, w, h)
        draw.RoundedBox(0, 0, 0, w, h, Color(10, 10, 10, 240))
        surface.SetDrawColor(255, 215, 0, 255)
        surface.DrawOutlinedRect(0, 0, w, h)
    end,

    Think = function(self)
        self.Name:SetText(GetHostName())
        self.Title.Players:SetText("Players (" .. #player.GetAll() .. ")")

        for id, pl in pairs(player.GetAll()) do
            if IsValid(pl.ScoreEntry) then continue end

            pl.ScoreEntry = vgui.CreateFromTable(PLAYER_LINE, pl.ScoreEntry)
            pl.ScoreEntry:Setup(pl)
            self.Scores:AddItem(pl.ScoreEntry)
        end
    end
}

SCORE_BOARD = vgui.RegisterTable(SCORE_BOARD, "EditablePanel")

hook.Add("ScoreboardShow", "CustomScoreboardShow", function()
    if not IsValid(Scoreboard) then
        Scoreboard = vgui.CreateFromTable(SCORE_BOARD)
    end

    if IsValid(Scoreboard) then
        Scoreboard:Show()
        Scoreboard:MakePopup()
        Scoreboard:SetKeyboardInputEnabled(false)
    end

    return false
end)

hook.Add("ScoreboardHide", "CustomScoreboardHide", function()
    if IsValid(Scoreboard) then
        Scoreboard:Hide()
    end

    return false
end)
