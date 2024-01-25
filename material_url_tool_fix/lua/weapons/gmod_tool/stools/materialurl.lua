--   __  __          _                 _          _     _   _   ___   _      _  _____ _ 
--  |  \/  |  __ _  | |_   ___   _ _  (_)  __ _  | |   | | | | | _ \ | |    |_)|_  | |_|
--  | |\/| | / _` | |  _| / -_) | '_| | | / _` | | |   | |_| | |   / | |__  |_)|__ | | |
--  |_|  |_| \__,_|  \__| \___| |_|   |_| \__,_| |_|    \___/  |_|_\ |____|
--                                                                              by Some1else{} aka Hλdrien

TOOL.Category = "Render"
TOOL.Name = "#tool.materialurl.name"
TOOL.Command = nil
TOOL.ConfigName = ""

TOOL.ClientConVar["url"] = ""
TOOL.ClientConVar["name"] = ""
TOOL.ClientConVar["material"] = ""

TOOL.ClientConVar["submaterial_index"] = 0

TOOL.ClientConVar["parameter_noclamp"] = 1
TOOL.ClientConVar["parameter_transparent"] = 0
TOOL.ClientConVar["parameter_envmap"] = 0
TOOL.ClientConVar["parameter_reflectivity"] = 0
TOOL.ClientConVar["parameter_scalex"] = 1
TOOL.ClientConVar["parameter_scaley"] = 1
TOOL.ClientConVar["parameter_rotation"] = 0
TOOL.ClientConVar["parameter_translatex"] = 0
TOOL.ClientConVar["parameter_translatey"] = 0

MatURL = MatURL or {}
MatURL.tool = MatURL.tool or {}
MatURL.version = "v0.8.3"

local materials_directory = "materialurl_materials"
local uploaded_materials = {}
local reported_urls = {}

local print_prefix = "[Material URL] "

local no_char = {
    ["/"] = true,
    ["."] = true,
    [","] = true,
    ["\\"] = true,
    [":"] = true,
    ["!"] = true,
    ["?"] = true,
    ["#"] = true
}

local function IsExtensionValid(body,headers)
    local contenttype = headers["Content-Type"]
    local isPNG = string.lower(string.sub(body,2,4)) == "png" or contenttype == "image/png"
    local isJPEG = string.lower(string.sub(body,7,10)) == "jfif" or string.lower(string.sub(body,7,10)) == "exif" or contenttype == "image/jpeg"
    return (isPNG and "png") or (isJPEG and "jpg")
end

----- CONVARS -----

local cvar_adminonly = CreateConVar("sv_materialurl_adminonly",0,{FCVAR_ARCHIVE,FCVAR_REPLICATED})
local cvar_deletedisconnected = CreateConVar("sv_materialurl_deletedisconnected",1,{FCVAR_ARCHIVE,FCVAR_REPLICATED})
local cvar_whitelist = CreateConVar("sv_materialurl_whitelist",1,{FCVAR_ARCHIVE,FCVAR_REPLICATED})
local cvar_reportingenabled = CreateConVar("sv_materialurl_reportingenabled",0,{FCVAR_ARCHIVE,FCVAR_REPLICATED})
local cvar_limitedsize = CreateConVar("sv_materialurl_limitedsize",0,{FCVAR_ARCHIVE,FCVAR_REPLICATED})
local cvar_sizelimit = CreateConVar("sv_materialurl_filesizelimit",1000,{FCVAR_ARCHIVE,FCVAR_REPLICATED}) --kilobytes
local cvar_limitedmaterials = CreateConVar("sv_materialurl_limitedmaterials",1,{FCVAR_ARCHIVE,FCVAR_REPLICATED})
local cvar_materiallimit = CreateConVar("sv_materialurl_materiallimit",5,{FCVAR_ARCHIVE,FCVAR_REPLICATED},"",1) --per player
local cvar_cooldown = CreateConVar("sv_materialurl_cooldown",10,{FCVAR_ARCHIVE,FCVAR_REPLICATED},"",2)

if SERVER then ----- SERVER -----
    util.AddNetworkString("materialurl_load")
    util.AddNetworkString("materialurl_materials")
    util.AddNetworkString("materialurl_requestmaterials")
    util.AddNetworkString("materialurl_removematerial")
    util.AddNetworkString("materialurl_report")
    util.AddNetworkString("materialurl_notify")

    local function Notify(ply,text,type,uploading)
        net.Start("materialurl_notify")
        net.WriteString(text)
        net.WriteUInt(type,3)
        net.WriteBool(uploading or false)
        net.Send(ply)
    end

    local function SendMaterials(ply)
        if not ply then
            timer.Stop("delay")
        end
        timer.Create("delay",0.35,1,function()
            net.Start("materialurl_materials")
            net.WriteTable(uploaded_materials)
            net.Send(ply != nil and ply or player.GetHumans()) --Yes, I think bots have no real use for custom materials. If they do, let me know.
        end)
    end

    local function GetMatCount(ply)
        local count = 0
        local steamid64 = ply:SteamID64()
        for _,v in ipairs(uploaded_materials) do
            local explode = string.Explode("_",v.name)
            if explode[#explode] == steamid64 then
                count = count+1
            end
        end
        return count
    end

    function AlreadyExists(name,url)
        for _,v in ipairs(uploaded_materials) do
            if v.url == url or v.name == name then
                return true
            end
        end
        return false
    end

    function AddMaterial(name,url,ply,parameters,duping)
        if not ply:IsValid() and ply != Entity(0) then return end
        if url == "" or url == nil then return end
        if not tobool(ply:GetInfoNum("cl_materialurl_enabled",0)) then return false,"You have disabled Material URL" end

        if AlreadyExists(name,url) then
            return false,(duping and nil or "This material was already uploaded (name or URL already used)")
        end
        
        if not ply:IsAdmin() then
            if cvar_adminonly:GetBool() then return false,"Admin mode is enabled on this server" end
            
            if cvar_limitedmaterials:GetBool() and GetMatCount(ply) >= cvar_materiallimit:GetInt() then return false,"You have reached your maximum material amount ("..cvar_materiallimit:GetInt()..")" end
            
            if not MatURL.checkURL(url) and cvar_whitelist:GetBool() then 
                ServerLog(print_prefix..ply:Nick().."<"..ply:SteamID().."> tried to create a material from a non-whitelisted URL: '"..url.."'\n")
                return false,"The URL you requested isn't whitelisted or is invalid!"
            end
            
            local cooldown = ply:GetVar("materialurl_cooldown") or 0

            if not duping then
                if cooldown > CurTime() then
                    return false,"Material URL is on cooldown, please wait "..math.ceil(cooldown-CurTime()).." second(s)"
                else
                    ply:SetVar("materialurl_cooldown",CurTime()+cvar_cooldown:GetInt())
                    ply:SetVar("materialurl_dupeuploads",0)
                end
            end
        end

        Notify(ply,"",0,true)

        http.Fetch(url,function(body,size,headers)
            size = size*0.001

            local extension = IsExtensionValid(body,headers)
            if not extension then
                Notify(ply,"Failed to create material, error: the file isn't PNG or JPEG",1)
                return
            end
            
            local sizelimit = cvar_sizelimit:GetInt()
            if size > sizelimit and cvar_limitedsize:GetBool() then
                Notify(ply,"Material size too big ("..size.." kb), exceeding the server's limit ("..sizelimit.." kb)",1)
                return
            end
            
            local tbl = {
                url = url,
                name = "!"..name,
                extension = extension,
                owner = ply,
                parameters = parameters,
                path = ""
            }
            table.insert(uploaded_materials,tbl)
            SendMaterials()

            if duping then
                local dupeuploads = (ply:GetVar("materialurl_dupeuploads") or 0) + 1
                ply:SetVar("materialurl_dupeuploads",dupeuploads)
                ply:SetVar("materialurl_cooldown",CurTime()+cvar_cooldown:GetInt()*dupeuploads)
            end

            Notify(ply,"Successfully added your Material URL \"!"..name.."\"",0)
            ServerLog(print_prefix..ply:Nick().."<"..ply:SteamID().."> created a material from '"..url.."' with a size of "..(size).." kb\n")
            return
        end,function(err)
            Notify(ply,"Failed to create material, error: "..err,1)
            return
        end)

        return true
    end

    hook.Add("PlayerDisconnected","DeleteDisconnectedMaterials",function(ply)
        if not cvar_deletedisconnected:GetBool() then return end
        if ply:IsValid() then
            for k,v in ipairs(uploaded_materials) do
                if v.owner == ply then
                    table.remove(uploaded_materials,k)
                end
            end

            SendMaterials()
        end
    end)

    hook.Add("PlayerInitialSpawn","SetOwner",function()
        for _,v in ipairs(uploaded_materials) do
            if not v.owner:IsValid() then
                local exp = string.Explode("_",v.name)
                local owner = player.GetBySteamID64(exp[#exp])
                if owner then
                    v.owner = owner
                end
            end
        end

        SendMaterials()
    end)

    cvars.AddChangeCallback(cvar_cooldown:GetName(),function(_,_,num)
        num = tonumber(num)
        for _,v in ipairs(player.GetHumans()) do
            local cooldown = v:GetVar("materialurl_cooldown") or 0
            v:SetVar("materialurl_cooldown",cooldown > num and num or cooldown)
        end
    end)

    net.Receive("materialurl_load",function(_,ply)
        if not ply:IsValid() then return end
        local url = net.ReadString()

        local raw_name = string.sub(string.Replace(net.ReadString()," ","_"),1,32)
        for k,v in pairs(no_char) do
            raw_name = string.Replace(raw_name,k,"")
        end
        local name = "maturl_"..raw_name.."_"..tostring(ply:SteamID64())
        local parameters = net.ReadTable()

        local success,msg = AddMaterial(name,url,ply,parameters,false)
        if msg then Notify(ply,msg,success and 0 or 1) end
    end)

    net.Receive("materialurl_requestmaterials",function(_,ply)
        if not ply:IsValid() then return end
        SendMaterials(ply)
    end)

    net.Receive("materialurl_removematerial",function(_,ply)
        if not ply:IsValid() then return end
        local material = net.ReadString()

        for k,v in ipairs(uploaded_materials) do
            if v.name == material then
                local exp = string.Explode("_",material)
                local material_owner = player.GetBySteamID64(exp[#exp])
                local material_count = GetMatCount(material_owner)

                if not ply:IsAdmin() and ply != material_owner then return end

                table.remove(uploaded_materials,k)
                SendMaterials()

                Notify(ply,"Removed "..(ply == material_owner and "your material: \"" or (material_owner:Nick() or "[disconnected player]").."'s\"")..material..'"',0)
                ServerLog(print_prefix..ply:Nick().."<"..ply:SteamID().."> removed '"..material.."'\n")

                for _,ent in ipairs(ents.GetAll()) do
                    if ent:GetMaterial() == material then
                        ent:SetMaterial("")
                    end
                end
                return
            end
        end
    end)

    net.Receive("materialurl_report",function(_,ply)
        if not ply:IsValid() then return end
        if cvar_reportingenabled:GetBool() then
            for _,v in ipairs(player.GetHumans()) do
                if v:IsAdmin() then
                    v:ChatPrint(print_prefix..ply:Nick().." reported "..net.ReadString())
                end
            end
        else
            Notify(ply,"Material reporting is disabled on this server",1)
        end
    end)

    -----

    duplicator.RegisterEntityModifier("materialurl",function(ply,ent,data)
        ent:SetMaterial(data.name)
        AddMaterial(string.sub(data.name,2),data.url,player.GetBySteamID64(data.steamid64) or Entity(0),data.parameters,true)
    end)

    duplicator.RegisterEntityModifier("materialurl_submaterial",function(ply,ent,data)
        for i = 0,#ent:GetMaterials()-1 do
            local sub = data.materials[i]
            if sub then
                ent:SetSubMaterial(i,sub.name)
                AddMaterial(string.sub(sub.name,2),sub.url,player.GetBySteamID64(data.steamid64) or Entity(0),sub.parameters,true)
            end
        end
    end)

    function SetMaterialURL(ent,data)
        ent:SetMaterial(data.name)

        duplicator.StoreEntityModifier(ent,"materialurl",{
            name = data.name,
            url = data.url,
            steamid64 = data.owner and data.owner:SteamID64() or nil,
            parameters = data.parameters
        })
    end

    function SetSubMaterialURL(ent,data,index)
        ent:SetSubMaterial(index,data.name)
        
        ent:SetVar("materialurl_submaterial_"..index,data.name and {
            name = data.name,
            url = data.url,
            parameters = data.parameters
        } or nil)

        local submaterials = {}
        for i = 0,#ent:GetMaterials()-1 do
            local sub = ent:GetVar("materialurl_submaterial_"..i)
            if sub then
                table.insert(submaterials,i,{
                    name = sub.name,
                    url = sub.url,
                    parameters = sub.parameters
                })
            end
        end

        local data = {
            steamid64 = data.owner and data.owner:SteamID64() or nil,
            materials = submaterials
        }
        duplicator.StoreEntityModifier(ent,"materialurl_submaterial",data)
    end
else ----- CLIENT -----
    local favorites_file = "materialurl_favorites.txt"
    if not file.Exists(favorites_file,"DATA") then
        file.Write(favorites_file,"")
    end

    local favorites = util.JSONToTable(file.Read(favorites_file,"DATA")) or {}

    local function SaveFavorites()
        file.Write(favorites_file,util.TableToJSON(favorites,true))
    end

    function RequestMaterials()
        net.Start("materialurl_requestmaterials")
        net.SendToServer()
    end

    local function WipeFiles()
        local PNGfiles = file.Find(materials_directory.."/*.png","DATA")
        local JPEGfiles = file.Find(materials_directory.."/*.jpg","DATA")
        local files = table.Add(PNGfiles,JPEGfiles)

        for _,v in ipairs(files) do
            file.Delete(materials_directory.."/"..v)
        end
        
        if #files > 0 then
            MsgN(print_prefix.."Deleted "..#files.." file(s) from the 'materialurl_materials/' folder")
        end
    end

    -----

    local cvar_enabled = CreateClientConVar("cl_materialurl_enabled",1,true,true)
    local cvar_keepfiles = CreateClientConVar("cl_materialurl_keepfiles",0,true)
    local cvar_preview = CreateClientConVar("cl_materialurl_preview",1,true)
    local cvar_showmine = CreateClientConVar("cl_materialurl_showmine",0,true)

    MatURL.enabled = cvar_enabled:GetBool()
    MatURL.tool.selected = ""
    MatURL.tool.submaterial_index = 0

    net.Receive("materialurl_notify",function()
        local text = net.ReadString()
        local type = net.ReadUInt(3)

        if net.ReadBool() then
            notification.AddProgress("materialurl_uploading","Uploading material...")
            surface.PlaySound("buttons/button14.wav")

            timer.Stop("materialurl_uploadingtimeout")
            timer.Create("materialurl_uploadingtimeout",10,1,function()
                notification.Kill("materialurl_uploading")
            end)
        else
            notification.AddLegacy(text,type,3)
            surface.PlaySound("buttons/button"..(type+9)..".wav")
            notification.Kill("materialurl_uploading")
        end
    end)

    function CheckURL(url,func)
        local URLIsValid
        http.Fetch(url,function(body,size,headers)
            URLIsValid = IsExtensionValid(body,headers)
            func(URLIsValid,size*0.001,0)
            return URLIsValid
        end,
        function(err)
            func(false,0,err)
            return false
        end)
    end

    function RefreshMaterialList()
        if not MatURL.tool.MatListview or not MatURL.enabled then return end
        MatURL.tool.MatListview:Clear()

        for _,v in ipairs(uploaded_materials) do
            AddMaterial(v)
        end
    end

    function AddMaterial(material)
        if not MatURL.tool.MatListview or not MatURL.enabled then return end
        local showpreview = cvar_preview:GetBool()
        local showmine = cvar_showmine:GetBool()

        if showmine and material.owner != LocalPlayer() then return end

        for k,line in pairs(MatURL.tool.MatListview:GetLines()) do
            if line:GetValue(1) == material.name then return end
        end

        local exp = string.Explode("_",material.name)
        local matname = table.concat(exp,"_",2,#exp-1)
        local ply = material.owner or Entity(0)
        local plyname = ply:IsValid() and ply:Nick() or "[Unknown]"

        local MatPreview = vgui.Create("DImage")
        MatPreview:SetKeepAspect(true)
        MatPreview:SetMaterial(Material(material.name))
        MatPreview:FixVertexLitMaterial()
        MatPreview:SetVisible(showpreview)
        MatPreview:SetEnabled(showpreview)

        local ActionPanel = vgui.Create("DPanel")
        ActionPanel:SetPaintBackground(false)

        local CopyButton = ActionPanel:Add("DImageButton")
        CopyButton:Dock(showpreview and TOP or LEFT)
        CopyButton:DockPadding(0,0,0,0)
        CopyButton:DockMargin(1,1,1,1)
        CopyButton:SetImage("icon16/page_link.png")
        CopyButton:SetSize(16,16)
        CopyButton:SetWide(16)
        CopyButton:SetKeepAspect(true)
        CopyButton:SizeToContents(true)
        CopyButton:SetStretchToFit(false)
        CopyButton:SetToolTip("Copy URL")
        CopyButton.DoClick = function()
            SetClipboardText(material.url)
        end

        local FavoriteButton = ActionPanel:Add("DImageButton")
        FavoriteButton:Dock(showpreview and TOP or LEFT)
        FavoriteButton:DockPadding(0,0,0,0)
        FavoriteButton:DockMargin(1,1,1,1)
        FavoriteButton:SetImage("icon16/star.png")
        FavoriteButton:SetSize(16,16)
        FavoriteButton:SetWide(16)
        FavoriteButton:SetKeepAspect(true)
        FavoriteButton:SetStretchToFit(false)
        FavoriteButton:SetToolTip("Add URL to favorites")
        FavoriteButton.DoClick = function()
            if favorites[material.url] then
                notification.AddLegacy("This material is already in your favorites",NOTIFY_HINT,3)
                surface.PlaySound("ambient/water/drip2.wav")
            else
                favorites[material.url] = matname
                SaveFavorites()
                RefreshFavorites()
            end
        end

        if LocalPlayer():IsAdmin() or LocalPlayer() == ply then
            local DelButton = ActionPanel:Add("DImageButton")
            DelButton:Dock(showpreview and TOP or LEFT)
            DelButton:DockPadding(0,0,0,0)
            DelButton:DockMargin(1,1,1,1)
            DelButton:SetImage("icon16/delete.png")
            DelButton:SetSize(16,16)
            DelButton:SetWide(16)
            DelButton:SetKeepAspect(true)
            DelButton:SetStretchToFit(false)
            DelButton:SetToolTip("Delete material")
            DelButton.DoClick = function()
                net.Start("materialurl_removematerial")
                net.WriteString(material.name)
                net.SendToServer()
            end
        end

        if not reported_urls[material.url] and not ply == LocalPlayer() and not ply:IsAdmin() then
            local ReportButton = ActionPanel:Add("DImageButton")
            ReportButton:Dock(showpreview and TOP or LEFT)
            ReportButton:DockPadding(0,0,0,0)
            ReportButton:DockMargin(1,1,1,1)
            ReportButton:SetImage("icon16/exclamation.png")
            ReportButton:SetSize(16,16)
            ReportButton:SetWide(16)
            ReportButton:SetKeepAspect(true)
            ReportButton:SetStretchToFit(false)
            ReportButton:SetToolTip("Report material")
            ReportButton.DoClick = function(self)
                net.Start("materialurl_report")
                net.WriteString(string.sub(material.name,2))
                net.SendToServer()

                reported_urls[material.url] = true
                self:Remove()
            end
        end

        local line = MatURL.tool.MatListview:AddLine(material.name,matname,plyname,MatPreview,ActionPanel)
        selected = (material.name == MatURL.tool.selected) or selected
        line:SetSelected(material.name == MatURL.tool.selected)
        line.OnRightClick = function()
            local Menu = DermaMenu()
            Menu:Open()
            Menu:AddOption("Copy material",function()
                SetClipboardText(material.name)
            end):SetIcon("icon16/page_copy.png")
        end

        MatURL.tool.MatListview:InvalidateLayout(true)
    end

    function CreateMaterialFromURL(n)
        local mat = uploaded_materials[n]

        local name = string.sub(mat.name,2)
        local url = mat.url
        local parameters = mat.parameters
        http.Fetch(url,function(body,_,headers)
            if not uploaded_materials[n] then return end --because this is async, things can happen while it's loading

            local extension = IsExtensionValid(body,headers)
            if extension then
                local material_path = materials_directory.."/"..name.."."..extension
                file.Write(material_path,body)

                -- BACKWARD COMPATIBILITY WITH PARAMETERS
                parameters.noclamp = parameters.noclamp or 1
                parameters.transparent = parameters.transparent or 0
                parameters.envmap = parameters.envmap or 0
                parameters.reflectivity = parameters.reflectivity or 0
                parameters.scale = parameters.scale or "1 1"
                parameters.rotation = parameters.rotation or 0
                parameters.translate = parameters.translate or "0 0"

                local path = "data/"..material_path
                
                local vmt = {
                    ["$basetexture"] = path,
                    ["$basetexturetransform"] = "center .5 .5 scale "..parameters.scale.." rotate "..parameters.rotation.." translate "..parameters.translate,
                    ["$surfaceprop"] = "gravel",
                    ["$model"] = 1,
                    ["$translucent"] = parameters.transparent,
                    ["$vertexalpha"] = parameters.transparent,
                    ["$vertexcolor"] = 1,
                    ["$envmap"] = tobool(parameters.envmap) and "env_cubemap" or "",
                    ["$reflectivity"] = "["..parameters.reflectivity.." "..parameters.reflectivity.." "..parameters.reflectivity.."]"
                }
                
                if uploaded_materials[n] then
                    uploaded_materials[n].path = path
                end

                local material = CreateMaterial(name,"VertexLitGeneric",vmt)

                material:SetTexture("$basetexture",Material(path,(tobool(parameters.noclamp) and " noclamp" or "")):GetName())
                material:SetInt("$flags",(32+2097152)*parameters.transparent)

                AddMaterial(mat)

                if n-#uploaded_materials == 0 then
                    ReapplyMaterials()

                    if not MatURL.tool.MatListview then return end
                    for k,line in ipairs(MatURL.tool.MatListview:GetLines()) do
                        local found = false
                        local val = line:GetValue(1)
                        for _,v in ipairs(uploaded_materials) do
                            if val == v.name then
                                found = true
                                break
                            end
                        end

                        if not found then
                            MatURL.tool.MatListview:RemoveLine(k)
                            MatURL.tool.selected = MatURL.tool.selected == val and "" or MatURL.tool.selected
                        end
                    end
                end
            end
        end)
    end

    function SendMaterial(url,name,parameters)
        net.Start("materialurl_load")
        net.WriteString(url)
        net.WriteString(name)
        net.WriteTable(parameters)
        net.SendToServer()
    end

    function ReapplyMaterials()
        for _,v in ipairs(ents.GetAll()) do
            if not v:IsValid() then continue end
            local material = v:GetMaterial()

            v:SetMaterial(material)
        end
    end

    function UpdateToolgun()
        local mat = MatURL.tool.selected
        if not MatURL.tool or not mat then return end

        for _,v in ipairs(uploaded_materials) do
            if mat == v.name then
                MatURL.tool.nick = v.owner:Nick() or "[Unknown]"

                local exp = string.Explode("_",string.sub(mat,2))
                MatURL.tool.name = table.concat(exp,"_",2,#exp-1) or ""

                MatURL.tool.mat = Material(v.path,"ignorez")

                MatURL.tool.noclamp = v.parameters.noclamp
                MatURL.tool.transparent = v.parameters.transparent
                MatURL.tool.envmap = v.parameters.envmap
                MatURL.tool.reflectivity = v.parameters.reflectivity
                MatURL.tool.scale = v.parameters.scale
                MatURL.tool.rotation = v.parameters.rotation
                MatURL.tool.translate = v.parameters.translate
                return
            end
        end
    end

    hook.Add("InitPostEntity","GetMaterials",RequestMaterials)

    -----

    net.Receive("materialurl_materials",function()
        if MatURL.enabled then
            uploaded_materials = net.ReadTable() or {}

            for k = 1,#uploaded_materials do
                CreateMaterialFromURL(k)
            end

            if #uploaded_materials == 0 then
                timer.Simple(0.1,function()
                    RefreshMaterialList()
                    ReapplyMaterials()
                end)
                MatURL.tool.selected = ""
            end
        end
    end)

    cvars.AddChangeCallback(cvar_enabled:GetName(),function(_,_,on)
        on = tobool(on)
        MatURL.enabled = on
        if on then
            RequestMaterials()
        else
            for _,v in ipairs(ents.GetAll()) do
                local material = v:GetMaterial()
                if string.Explode("_",material)[1] == "!maturl" then
                    v:SetMaterial("")
                end
            end
        end

        if not MatURL.tool.SendButton then return end
        MatURL.tool.SendButton:SetToolTip(on and "Send the material to the server and allow everyone to use it" or "You have disabled Material URL")
        MatURL.tool.SendButton:SetEnabled(on)
    end)

    cvars.AddChangeCallback(cvar_preview:GetName(),function(_,_,on)
        on = tobool(on)
        if not MatURL.tool.PreviewColumn then return end

        MatURL.tool.PreviewColumn:SetFixedWidth(on and MatURL.tool.PreviewSize or 0)
        MatURL.tool.MatListview:SetDataHeight(on and MatURL.tool.PreviewSize or 20)
        MatURL.tool.ActionsColumn:SetFixedWidth(on and 25 or 75)

        MatURL.tool.MatListview:InvalidateLayout()
        RefreshMaterialList()
    end)

    if not file.Exists(materials_directory,"") then
        file.CreateDir(materials_directory)
    end

    language.Add("tool.materialurl.name","Material URL")
    language.Add("tool.materialurl.desc","Use custom materials with an URL")

    language.Add("tool.materialurl.left","Apply selected Material URL")
    language.Add("tool.materialurl.right","Copy the entity's Material URL")
    language.Add("tool.materialurl.reload","Reset the material")
    language.Add("tool.materialurl.reload_use","Switch to SubMaterial mode")

    language.Add("tool.materialurl.1","Use the scrollwheel while looking at an entity to iterate over its submaterials")
    language.Add("tool.materialurl.left_1","Apply submaterial")
    language.Add("tool.materialurl.right_1","Copy submaterial")
    language.Add("tool.materialurl.reload_1","Reset submaterial")
    language.Add("tool.materialurl.reload_use_1","Switch to normal mode")

    language.Add("materialurl.category","Material URL Settings")
    language.Add("materialurl.cl_options","Client")
    language.Add("materialurl.sv_options","Server")

    TOOL.Information = {
        { name = info, stage = 0 },
        { name = "left", stage = 0 },
        { name = "right", stage = 0 },
        { name = "reload", stage = 0 },
        { name = "reload_use", stage = 0, icon = "gui/r.png", icon2 = "gui/e.png" },

        { name = "info", stage = 1 },
        { name = "left_1", stage = 1 },
        { name = "right_1", stage = 1 },
        { name = "reload_1", stage = 1 },
        { name = "reload_use_1", stage = 1, icon = "gui/r.png", icon2 = "gui/e.png" }
    }

    hook.Add("AddToolMenuCategories","Material URL Category",function()
	    spawnmenu.AddToolCategory("Utilities","Material URL","#materialurl.category")
    end)

    hook.Add("PopulateToolMenu","CustomMenuSettings",function()
        spawnmenu.AddToolMenuOption("Utilities","Material URL","Material_URL_Client","#materialurl.cl_options","","",function(panel)
            panel:ClearControls()
            
            local Header = vgui.Create("DLabel")
            panel:AddPanel(Header)
            Header:Dock(FILL)
            Header:SetDark(true)
            Header:SetText("Material URL client settings")
            
            local OnCheckbox = vgui.Create("DCheckBoxLabel")
            panel:AddPanel(OnCheckbox)
            OnCheckbox:SetDark(true)
            OnCheckbox:SetText("Enable Material URL")
            OnCheckbox:SetConVar(cvar_enabled:GetName())

            local KeepFilesCheckbox = vgui.Create("DCheckBoxLabel")
            panel:AddPanel(KeepFilesCheckbox)
            KeepFilesCheckbox:SetDark(true)
            KeepFilesCheckbox:SetText("Keep the PNGs/JPEGs\n(in the 'data/materialurl_materials/' folder)")
            KeepFilesCheckbox:SetToolTip("Enable if you want to keep the images when you log off.")
            KeepFilesCheckbox:SetConVar(cvar_keepfiles:GetName())

            local PreviewCheckbox = vgui.Create("DCheckBoxLabel")
            panel:AddPanel(PreviewCheckbox)
            PreviewCheckbox:SetDark(true)
            PreviewCheckbox:SetText("Show a preview of each material in the list")
            PreviewCheckbox:SetConVar(cvar_preview:GetName())

            local CleanFilesButton = vgui.Create("DButton")
            panel:AddPanel(CleanFilesButton)
            CleanFilesButton:SetText("Clean PNGs and JPEGs")
            CleanFilesButton:SetToolTip("This will remove every .png/.jpg/.jpeg files from the /materialurl_materials/ folder")
            CleanFilesButton.DoClick = WipeFiles
        end)

        spawnmenu.AddToolMenuOption("Utilities","Material URL","Material_URL_Server","#materialurl.sv_options","","",function(panel)
            panel:ClearControls()
            
            local Header = vgui.Create("DLabel")
            panel:AddPanel(Header)
            Header:Dock(FILL)
            Header:SetDark(true)
            Header:SetText("Material URL server settings")
            
            local AdminOnlyCheckbox = vgui.Create("DCheckBoxLabel")
            panel:AddPanel(AdminOnlyCheckbox)
            AdminOnlyCheckbox:SetDark(true)
            AdminOnlyCheckbox:SetText("Admin only mode")
            AdminOnlyCheckbox:SetConVar(cvar_adminonly:GetName())

            local DeleteDisconnectedCheckbox = vgui.Create("DCheckBoxLabel")
            panel:AddPanel(DeleteDisconnectedCheckbox)
            DeleteDisconnectedCheckbox:SetDark(true)
            DeleteDisconnectedCheckbox:SetText("Delete disconnect players' materials")
            DeleteDisconnectedCheckbox:SetConVar(cvar_deletedisconnected:GetName())

            local WhitelistCheckbox = vgui.Create("DCheckBoxLabel")
            panel:AddPanel(WhitelistCheckbox)
            WhitelistCheckbox:SetDark(true)
            WhitelistCheckbox:SetText("Enable the URL whitelist")
            WhitelistCheckbox:SetConVar(cvar_whitelist:GetName())

            local ReportCheckbox = vgui.Create("DCheckBoxLabel")
            panel:AddPanel(ReportCheckbox)
            ReportCheckbox:SetDark(true)
            ReportCheckbox:SetText("Enable material reporting")
            ReportCheckbox:SetConVar(cvar_reportingenabled:GetName())

            local Spacer1 = vgui.Create("DPanel")
            panel:AddPanel(Spacer1)
            Spacer1:SetMouseInputEnabled(false)
	        Spacer1:SetPaintBackgroundEnabled(false)
	        Spacer1:SetPaintBorderEnabled(false)
            Spacer1:DockMargin(0,0,0,0)
            Spacer1:DockPadding(0,0,0,0)
            Spacer1:SetPaintBackground(0,0,0,0)
            Spacer1:SetHeight(5)

            local LimitSizeCheckbox = vgui.Create("DCheckBoxLabel")
            panel:AddPanel(LimitSizeCheckbox)
            LimitSizeCheckbox:SetDark(true)
            LimitSizeCheckbox:SetText("Limit material file size")
            LimitSizeCheckbox:SetConVar(cvar_limitedsize:GetName())

            local FileSizeSlider = vgui.Create("DNumSlider")
            panel:AddPanel(FileSizeSlider)
            FileSizeSlider:SetMinMax(100,10000)
            FileSizeSlider:SetDecimals(0)
            FileSizeSlider:SetDark(true)
            FileSizeSlider:SetText("Maximum material file\nsize (in kilobytes)")
            FileSizeSlider:SetValue(cvar_sizelimit:GetInt())
            FileSizeSlider:SetConVar(cvar_sizelimit:GetName())

            local Spacer2 = vgui.Create("DPanel")
            panel:AddPanel(Spacer2)
            Spacer2:SetMouseInputEnabled(false)
	        Spacer2:SetPaintBackgroundEnabled(false)
	        Spacer2:SetPaintBorderEnabled(false)
            Spacer2:DockMargin(0,0,0,0)
            Spacer2:DockPadding(0,0,0,0)
            Spacer2:SetPaintBackground(0,0,0,0)
            Spacer2:SetHeight(5)

            local LimitMaterials = vgui.Create("DCheckBoxLabel")
            panel:AddPanel(LimitMaterials)
            LimitMaterials:SetDark(true)
            LimitMaterials:SetText("Limit material amount for each player")
            LimitMaterials:SetConVar(cvar_limitedmaterials:GetName())

            local MaterialLimitSlider = vgui.Create("DNumSlider")
            panel:AddPanel(MaterialLimitSlider)
            MaterialLimitSlider:SetMinMax(1,100)
            MaterialLimitSlider:SetDecimals(0)
            MaterialLimitSlider:SetDark(true)
            MaterialLimitSlider:SetText("Material limit for\neach player")
            MaterialLimitSlider:SetConVar(cvar_materiallimit:GetName())

            local Spacer3 = vgui.Create("DPanel")
            panel:AddPanel(Spacer3)
            Spacer3:SetMouseInputEnabled(false)
	        Spacer3:SetPaintBackgroundEnabled(false)
	        Spacer3:SetPaintBorderEnabled(false)
            Spacer3:DockMargin(0,0,0,0)
            Spacer3:DockPadding(0,0,0,0)
            Spacer3:SetPaintBackground(0,0,0,0)
            Spacer3:SetHeight(5)

            local CooldownSlider = vgui.Create("DNumSlider")
            panel:AddPanel(CooldownSlider)
            CooldownSlider:SetMinMax(2,300)
            CooldownSlider:SetDecimals(0)
            CooldownSlider:SetDark(true)
            CooldownSlider:SetText("Cooldown between\neach client upload")
            CooldownSlider:SetConVar(cvar_cooldown:GetName())

        end)
    end)

    function RefreshFavorites()
        if not MatURL.tool.FavoritesListview then return end
        MatURL.tool.FavoritesListview:Clear()

        for k,v in pairs(favorites) do
            local ActionPanel = vgui.Create("DPanel")
            ActionPanel:SetPaintBackground(false)

            local UploadButton = ActionPanel:Add("DImageButton")
            UploadButton:Dock(LEFT)
            UploadButton:Dock(LEFT)
            UploadButton:DockPadding(0,0,0,0)
            UploadButton:DockMargin(1,1,1,1)
            UploadButton:SetImage("icon16/picture_go.png")
            UploadButton:SetWide(16)
            UploadButton:SetStretchToFit(false)
            UploadButton:SetToolTip("Upload material")
            UploadButton.DoClick = function()
                SendMaterial(k,v,{
                    noclamp = GetConVar("materialurl_parameter_noclamp"):GetInt(),
                    transparent = GetConVar("materialurl_parameter_transparent"):GetInt(),
                    envmap = GetConVar("materialurl_parameter_envmap"):GetInt(),
                    reflectivity = math.Round(GetConVar("materialurl_parameter_reflectivity"):GetFloat(),1),
                    scale = math.Round(GetConVar("materialurl_parameter_scalex"):GetFloat(),1).." "..math.Round(GetConVar("materialurl_parameter_scaley"):GetFloat(),1),
                    rotation = GetConVar("materialurl_parameter_rotation"):GetInt(),
                    translate = math.Round(GetConVar("materialurl_parameter_translatex"):GetFloat(),1).." "..math.Round(GetConVar("materialurl_parameter_translatey"):GetFloat(),1)
                })
            end

            local CopyButton = ActionPanel:Add("DImageButton")
            CopyButton:Dock(LEFT)
            CopyButton:DockPadding(0,0,0,0)
            CopyButton:DockMargin(1,1,1,1)
            CopyButton:SetImage("icon16/page_link.png")
            CopyButton:SetWide(16)
            CopyButton:SetStretchToFit(false)
            CopyButton:SetToolTip("Copy URL")
            CopyButton.DoClick = function()
                SetClipboardText(k)
            end

            local DelButton = ActionPanel:Add("DImageButton")
            DelButton:Dock(LEFT)
            DelButton:DockPadding(0,0,0,0)
            DelButton:DockMargin(1,1,1,1)
            DelButton:SetImage("icon16/award_star_delete.png")
            DelButton:SetWide(16)
            DelButton:SetStretchToFit(false)
            DelButton:SetToolTip("Remove favorite")
            DelButton.DoClick = function()
                favorites[k] = nil
                SaveFavorites()
                RefreshFavorites()
            end
            local line = MatURL.tool.FavoritesListview:AddLine(v,k,ActionPanel)
        end
    end

    function ToolObject()
        local wep = LocalPlayer():GetActiveWeapon()
        if not IsValid(wep) or wep:GetClass() != "gmod_tool" or wep.Mode != "materialurl" then return end

        return wep:GetToolObject("materialurl")
    end

    function FixMaterial(material,shader)
        local name = material:GetName()
        local mat = CreateMaterial(name.."_fixed",shader or "UnlitGeneric",{
            ["$basetexture"] = material:GetString("$basetexture"),
            ["$vertexcolor"] = 1,
            ["$vertexalpha"] = 1,
            ["$ignorez"] = 1
        })
        return mat
    end

    MatURL.tool.nomaterial = FixMaterial(Material("models/wireframe"),"Wireframe_DX9") --it won't work otherwise

    function UpdateSubToolgun(ent)
        timer.Simple(RealFrameTime(),function()
            if not ent:IsValid() or #ent:GetMaterials() == 0 then
                LocalPlayer():ConCommand("materialurl_submaterial_index 0")
                MatURL.tool.submaterial_mat = nil
                MatURL.tool.submaterial_index = 0
            else
                local submat = ent:GetSubMaterial(MatURL.tool.submaterial_index) or ""
                local mat = ent:GetMaterials()[MatURL.tool.submaterial_index + 1] or ""
                local material = Material(submat) or Material(mat)
                MatURL.tool.submaterial_mat = FixMaterial(material)
                MatURL.tool.submaterial_index_old = MatURL.tool.submaterial_index
            end
        end)
    end

    function TOOL:Deploy()
        LocalPlayer():ConCommand("materialurl_submaterial_index 0")
        MatURL.tool.submaterial_index = 0
    end

    function TOOL:Think()
        local ent = LocalPlayer():GetEyeTrace().Entity

        if ent != MatURL.tool.submaterial_ent or MatURL.tool.submaterial_index_old != MatURL.tool.submaterial_index or LocalPlayer():KeyPressed(IN_ATTACK) or LocalPlayer():KeyPressed(IN_RELOAD) then
            UpdateSubToolgun(ent)
        end

        MatURL.tool.submaterial_ent = ent
    end

    hook.Add("ShutDown","Wipe",function()
        if not cvar_keepfiles:GetBool() then
            WipeFiles()
            SaveFavorites()
        end
    end)

    hook.Add("PlayerBindPress","ScrollSelectIndex",function(ply,inp,pressing)
        if not pressing or not ToolObject() then return end
        if ToolObject():GetStage() == 1 and (inp == "invprev" or inp == "invnext") then
            local ent = LocalPlayer():GetEyeTrace().Entity
            if not ent:IsValid() then return end

            local matnum = #ent:GetMaterials()
            local index = MatURL.tool.submaterial_index
            local newindex = 0
            if inp == "invprev" then
                newindex = index > 0 and index - 1 or index
            elseif inp == "invnext" then
                newindex = index < matnum - 1 and index + 1 or index
            end
            LocalPlayer():ConCommand("materialurl_submaterial_index "..newindex)
            MatURL.tool.submaterial_index = newindex
            UpdateSubToolgun(ent)
            return true
        end
    end)
end

function TOOL:LeftClick(trace)
    local stage = self:GetStage()
    local owner = self:GetOwner()

    local ent = trace.Entity
    if not ent:IsValid() then return false end

    local index = owner:GetInfoNum("materialurl_submaterial_index",-1)

    if CLIENT then
        if not GetConVar("cl_materialurl_enabled"):GetBool() and util.TimerCycle() > 500 then
            notification.AddLegacy("You have disabled Material URL",NOTIFY_HINT,3)
            surface.PlaySound("ambient/water/drip2.wav") 
        end
        return true
    end
    if not tobool(owner:GetInfoNum("cl_materialurl_enabled",0)) then return false end

    local material = self:GetClientInfo("material")

    for _,v in ipairs(uploaded_materials) do
        if material == v.name then
            if stage == 0 then
                SetMaterialURL(ent,v)
            else
                SetSubMaterialURL(ent,v,owner:GetInfoNum("materialurl_submaterial_index",-1))
            end
            return true
        end
    end

    return false
end

function TOOL:RightClick(trace)
    local stage = self:GetStage()
    local owner = self:GetOwner()

    local ent = trace.Entity
    if not ent:IsValid() then return false end

    if stage == 1 then
        if SERVER then
            owner:ConCommand("materialurl_material "..ent:GetSubMaterial(owner:GetInfoNum("materialurl_submaterial_index",-1)))
        else
            MatURL.tool.selected = ent:GetSubMaterial(MatURL.tool.submaterial_index)
            UpdateToolgun()
        end
        return true
    end

    if string.Explode("_",ent:GetMaterial())[1] != "!maturl" then return false end

    if CLIENT then
        if not GetConVar("cl_materialurl_enabled"):GetBool() and util.TimerCycle() > 500 then
            notification.AddLegacy("You have disabled Material URL",NOTIFY_HINT,3)
            surface.PlaySound("ambient/water/drip2.wav") 
        end
        MatURL.tool.selected = ent:GetMaterial()
        UpdateToolgun()
        return true
    end
    if not tobool(owner:GetInfoNum("cl_materialurl_enabled",0)) then return false end

    owner:ConCommand("materialurl_material "..ent:GetMaterial())
    return true
end

function TOOL:Reload(trace)
    local stage = self:GetStage()
    local owner = self:GetOwner()

    if owner:KeyDown(IN_USE) then
        self:SetStage(stage == 0 and 1 or 0)
        return false
    end

    local ent = trace.Entity
    if not ent:IsValid() then return false end
    if CLIENT then return true end

    if stage == 1 then
        SetSubMaterialURL(ent,{
            name = ""
        },owner:GetInfoNum("materialurl_submaterial_index",-1))
        return true
    end

    if string.Explode("_",ent:GetMaterial())[1] != "!maturl" then return false end

    SetMaterialURL(ent,{
        name = ""
    })
    return true
end

function TOOL:DrawToolScreen(w,h)
    if not MatURL.tool then return end

    cam.Start2D()
        surface.SetDrawColor(30,30,30,255)
        surface.DrawRect(0,0,w,h)

        draw.DrawText("Material URL","CloseCaption_Normal",5,5,Color(100,100,255,255),TEXT_ALIGN_LEFT)
        draw.DrawText("Beta","Trebuchet24",128,3,Color(255,0,0,255),TEXT_ALIGN_LEFT)

        draw.DrawText(MatURL.version,"CloseCaption_Normal",180,5,Color(255,200,0,255),TEXT_ALIGN_LEFT)

        if not MatURL.enabled then
            draw.DrawText("Material URL\nis disabled","CloseCaption_Bold",w/2,h/2-20,Color(255,0,0,255),TEXT_ALIGN_CENTER)
        elseif MatURL.tool.mat and MatURL.tool.selected != "" and self:GetStage() == 0 then
            -- Name, Uploader, Params
            local name = #MatURL.tool.name > 13 and string.sub(MatURL.tool.name,1,11).."..." or MatURL.tool.name
            local nick = #MatURL.tool.nick > 15 and string.sub(MatURL.tool.nick,1,13).."..." or MatURL.tool.nick
            draw.DrawText("Name: "..name,"CloseCaption_Bold",10,40,Color(255,255,255,255),TEXT_ALIGN_LEFT)
            draw.DrawText("Owner: "..nick,"CloseCaption_Normal",10,65,Color(255,255,255,255),TEXT_ALIGN_LEFT)

            draw.DrawText("Params:","CloseCaption_Normal",10,85,Color(255,70,70,255),TEXT_ALIGN_LEFT)
            draw.DrawText("nclp: "..MatURL.tool.noclamp,"CloseCaption_Normal",10,105,Color(255,70,70,255),TEXT_ALIGN_LEFT)
            draw.DrawText("trsp: "..MatURL.tool.transparent,"CloseCaption_Normal",10,125,Color(255,70,70,255),TEXT_ALIGN_LEFT)
            draw.DrawText("env: "..MatURL.tool.envmap,"CloseCaption_Normal",10,145,Color(255,70,70,255),TEXT_ALIGN_LEFT)
            draw.DrawText("refl: "..MatURL.tool.reflectivity,"CloseCaption_Normal",10,165,Color(255,70,70,255),TEXT_ALIGN_LEFT)
            draw.DrawText("s: "..MatURL.tool.scale,"CloseCaption_Normal",10,185,Color(255,70,70,255),TEXT_ALIGN_LEFT)
            draw.DrawText("rot: "..MatURL.tool.rotation,"CloseCaption_Normal",10,205,Color(255,70,70,255),TEXT_ALIGN_LEFT)
            draw.DrawText("tl: "..MatURL.tool.translate,"CloseCaption_Normal",10,225,Color(255,70,70,255),TEXT_ALIGN_LEFT)

            -- Preview
            surface.SetDrawColor(255,255,255,255) -- White background
            surface.DrawRect(100,100,w-110,h-110)
            surface.SetMaterial(MatURL.tool.mat)
            surface.DrawTexturedRect(105,105,w-120,h-120)
        elseif self:GetStage() == 1 then
            draw.DrawText("SubMaterial Mode","CloseCaption_Bold",10,40,Color(80,150,255,255),TEXT_ALIGN_LEFT)

            surface.SetDrawColor(255,255,255,255)
            if MatURL.tool.submaterial_mat and MatURL.tool.submaterial_ent:IsValid() then
                draw.DrawText("Index: "..(MatURL.tool.submaterial_index+1).."/"..#MatURL.tool.submaterial_ent:GetMaterials(),"CloseCaption_Normal",10,90,Color(255,255,255,255),TEXT_ALIGN_LEFT)
                surface.DrawRect(10,h/2-2,114,114)
                surface.SetMaterial(MatURL.tool.submaterial_mat)
            else
                draw.DrawText("look at\nan entity","CloseCaption_Normal",w/2-60,h/2+25,Color(200,200,255,255),TEXT_ALIGN_CENTER)
                surface.SetMaterial(MatURL.tool.nomaterial)
            end
            surface.DrawTexturedRect(12,h/2,110,110)
            
            if MatURL.tool.selected != "" then
                local name = #MatURL.tool.name > 9 and string.sub(MatURL.tool.name,1,7).."..." or MatURL.tool.name
                draw.DrawText(name,"CloseCaption_Bold",130,90,Color(255,255,255,255),TEXT_ALIGN_LEFT)

                surface.SetDrawColor(255,255,255,255)
                surface.DrawRect(w-124,h/2-2,114,114)
                surface.SetMaterial(MatURL.tool.mat)
            else
                draw.DrawText("none\nselected","CloseCaption_Normal",w/2+60,h/2+25,Color(200,200,255,255),TEXT_ALIGN_CENTER)
                surface.SetMaterial(MatURL.tool.nomaterial)
            end
            surface.DrawTexturedRect(w-122,h/2,110,110)
        else
            draw.DrawText("[none selected]","CloseCaption_Bold",w/2,h/2-10,Color(255,255,255,255),TEXT_ALIGN_CENTER)
        end
    cam.End2D()
end

function TOOL.BuildCPanel(CPanel)
    CPanel:AddControl("Header",{
        Description = "Allows you to apply custom materials coming from the internet. Only the PNG and JPEG formats are supported."
    })

    local panel = vgui.Create("DPanel")
    panel:SetPaintBackground(false)
    CPanel:AddPanel(panel)

    local URLLabel = panel:Add("DLabel")
    URLLabel:SetText("Material URL: ")
	URLLabel:SetDark(true)
	URLLabel:SizeToContents()
	URLLabel:Dock(LEFT)

    local URLEntry = panel:Add("DTextEntry")
    URLEntry:Dock(FILL)
    URLEntry:DockMargin(5,2,0,2)
    URLEntry:SetConVar("materialurl_url")
    URLEntry:SetUpdateOnType(false)
    URLEntry:SetPlaceholderText("Enter your material's direct link here")

    local CheckIcon = panel:Add("DImageButton")
    CheckIcon:SetImage("icon16/information.png")
    CheckIcon:SetWide(20)
	CheckIcon:Dock(RIGHT)
	CheckIcon:SetStretchToFit(false)
	CheckIcon:DockMargin(0,0,0,0)
    CheckIcon:SetToolTip("No URL")

    local HelpLabel = vgui.Create("DLabel")
    CPanel:AddPanel(HelpLabel)
    HelpLabel:SetWrap(true)
    HelpLabel:SetAutoStretchVertical(true)
    HelpLabel:SetContentAlignment(5)
    HelpLabel:DockMargin(16,0,16,8)
    HelpLabel:SetTextInset(0,0)
    HelpLabel:SetText("Make sure your file is PNG or JPEG. It is recommended to use square images (1:1 ratio), otherwise they might get cropped/stretched.")
    HelpLabel:SetTextColor(Color(51,148,240))
    
    local NameEntry = vgui.Create("DTextEntry")
    CPanel:AddPanel(NameEntry)
    NameEntry:SetConVar("materialurl_name")
    NameEntry:SetUpdateOnType(true)
    NameEntry:SetValue(GetConVar("materialurl_url"):GetString())
    NameEntry:SetAllowNonAsciiCharacters(false)
    NameEntry:SetPlaceholderText("Material name (only ASCII characters)")

    local CharnumIndicator = NameEntry:Add("DLabel")
    CharnumIndicator:Dock(RIGHT)
    CharnumIndicator:SetContentAlignment(5)
    CharnumIndicator:SetTextInset(30,0)
    CharnumIndicator:SetDark(true)
    CharnumIndicator:SetText("")
    NameEntry.OnValueChange = function(self,text)
        local num = #text
        CharnumIndicator:SetText(num > 0 and num.."/32" or "")
        if num > 32 then
            local name = string.sub(text,1,32)
            self:SetValue(name)
            LocalPlayer():ConCommand("materialurl_name "..name)
        end
    end
    NameEntry.AllowInput = function(self,char)
        return #self:GetValue() >= 32 or no_char[char]
    end

    local NameNoticeLabel = vgui.Create("DLabel")
    CPanel:AddPanel(NameNoticeLabel)
    NameNoticeLabel:SetWrap(true)
    NameNoticeLabel:SetAutoStretchVertical(true)
    NameNoticeLabel:SetTextColor(Color(255,10,10,255))
    NameNoticeLabel:SetText("NOTICE: The actual material name will be this name preceded by '!maturl' and followed by your SteamID64. All spaces in the name will be replaced by '_'.")

    local DetailLabel = vgui.Create("DLabel")
    CPanel:AddPanel(DetailLabel)
    DetailLabel:SetDark(true)
    DetailLabel:SetWrap(true)
    DetailLabel:SetAutoStretchVertical(true)
    DetailLabel:SetText("In order to use your custom material, press the button below to send it to the server and other players.")

    local SendButton = vgui.Create("DButton")
    MatURL.tool.SendButton = SendButton
    CPanel:AddPanel(SendButton)
    SendButton:SetText("Upload to the server")
    SendButton:SetColor(Color(10,255,10,255))
    SendButton:SetSize(80,20)
    local enabled = MatURL.enabled
    SendButton:SetToolTip(enabled and "Send the material to the server and allow everyone to use it" or "You have disabled Material URL")
    SendButton:SetEnabled(enabled)

    local ShowMineCheckbox = vgui.Create("DCheckBoxLabel")
    CPanel:AddPanel(ShowMineCheckbox)
    ShowMineCheckbox:SetDark(true)
    ShowMineCheckbox:SetText("Only show my materials")
    ShowMineCheckbox:SetConVar("cl_materialurl_showmine")
    ShowMineCheckbox.OnChange = function()
        MatURL.tool.MatListview:Clear()
        RequestMaterials()
    end

    local panel2 = vgui.Create("DPanel")
    CPanel:AddPanel(panel2)
    panel2:SetPaintBackground(false)
    panel2:SetSize(100,300)

    MatURL.tool.PreviewSize = 75
    local showpreview = GetConVar("cl_materialurl_preview"):GetBool()
    local MatListview = panel2:Add("DListView")
    MatURL.tool.MatListview = MatListview
    MatListview:Dock(FILL)
    MatListview:SetMultiSelect(false)
    MatListview:SetSortable(false)
    MatListview:SetDataHeight(showpreview and MatURL.tool.PreviewSize or 20)

    local NameColumn = MatListview:AddColumn("MatRealName"):SetFixedWidth(0)
    local PrintNameColumn = MatListview:AddColumn("Name"):SetMinWidth(50)
    local UploaderColumn = MatListview:AddColumn("Uploader"):SetMinWidth(50)
    MatURL.tool.PreviewColumn = MatListview:AddColumn("Preview")
    MatURL.tool.PreviewColumn:SetFixedWidth(showpreview and MatURL.tool.PreviewSize or 0)
    MatURL.tool.ActionsColumn = MatListview:AddColumn("Actions")
    MatURL.tool.ActionsColumn:SetFixedWidth(showpreview and 25 or 75)

    function MatListview:OnRowSelected(_,r)
        local mat = r:GetValue(1)
        MatURL.tool.selected = mat
        UpdateToolgun()
        LocalPlayer():ConCommand("materialurl_material "..mat)
    end

    local RefreshButton = panel2:Add("DButton")
    RefreshButton:Dock(BOTTOM)
    RefreshButton:SetText("Refresh")
    RefreshButton.DoClick = function()
        MatURL.tool.MatListview:Clear()
        RequestMaterials()
    end

    SendButton.DoClick = function()
        local url = GetConVar("materialurl_url"):GetString()
        local name = GetConVar("materialurl_name"):GetString()
        SendMaterial(url,#name > 0 and name or "material",{
            noclamp = GetConVar("materialurl_parameter_noclamp"):GetInt(),
            transparent = GetConVar("materialurl_parameter_transparent"):GetInt(),
            envmap = GetConVar("materialurl_parameter_envmap"):GetInt(),
            reflectivity = math.Round(GetConVar("materialurl_parameter_reflectivity"):GetFloat(),1),
            scale = math.Round(GetConVar("materialurl_parameter_scalex"):GetFloat(),1).." "..math.Round(GetConVar("materialurl_parameter_scaley"):GetFloat(),1),
            rotation = GetConVar("materialurl_parameter_rotation"):GetInt(),
            translate = math.Round(GetConVar("materialurl_parameter_translatex"):GetFloat(),1).." "..math.Round(GetConVar("materialurl_parameter_translatey"):GetFloat(),1)
        })

        URLEntry:SetValue("")
        NameEntry:SetValue("")
        CheckIcon:SetImage("icon16/information.png")
        CheckIcon:SetToolTip("No URL")
    end

    local function URLCheck()
        local str = URLEntry:GetValue()
        if str != "" and str != nil and MatURL != nil then
            if MatURL.checkURL(str) or not GetConVar("sv_materialurl_whitelist"):GetBool() then
                CheckIcon:SetImage("icon16/arrow_refresh.png")
                CheckIcon:SetToolTip("Checking URL...")
                
                CheckURL(str,function(success,size,code)
                    str = URLEntry:GetValue()
                    if str != "" and str != nil then
                        CheckIcon:SetImage(success and "icon16/accept.png" or "icon16/cross.png")
                        CheckIcon:SetToolTip(success and "Valid URL, file size: "..size.." kb" or (code != 0 and "Error code: "..code or "Invalid PNG/JPEG file"))
                    end
                end)
            else
                CheckIcon:SetImage("icon16/error.png")
                CheckIcon:SetToolTip("URL not whitelisted!")
            end
        else
            CheckIcon:SetImage("icon16/information.png")
            CheckIcon:SetToolTip("No URL")
        end
    end
    URLCheck()
    RefreshMaterialList()

    CheckIcon.DoClick = URLCheck
    function URLEntry:OnValueChange(text)
        GetConVar("materialurl_url"):SetString(text)
        URLCheck()
    end

    local ExperimentalLabel = vgui.Create("DLabel")
    CPanel:AddPanel(ExperimentalLabel)
    ExperimentalLabel:SetDark(true)
    ExperimentalLabel:SetText("\nThe following parameters are experimental. They may be changed or removed in future updates.")
    ExperimentalLabel:SetWrap(true)
    ExperimentalLabel:SetAutoStretchVertical(true)

    local WarningLabel = vgui.Create("DLabel")
    CPanel:AddPanel(WarningLabel)
    WarningLabel:SetTextColor(Color(255,10,10,255))
    WarningLabel:SetText("Some parameters won't work if a material with the same name has already been uploaded!")
    WarningLabel:SetWrap(true)
    WarningLabel:SetAutoStretchVertical(true)

    local NoclampCheckbox = vgui.Create("DCheckBoxLabel")
    CPanel:AddPanel(NoclampCheckbox)
    NoclampCheckbox:SetDark(true)
    NoclampCheckbox:SetText("No clamping: when enabled the texture loops,\notherwise its edges stretch")
    NoclampCheckbox:SetConVar("materialurl_parameter_noclamp")

    local TransparentCheckbox = vgui.Create("DCheckBoxLabel")
    CPanel:AddPanel(TransparentCheckbox)
    TransparentCheckbox:SetDark(true)
    TransparentCheckbox:SetText("Transparent texture")
    TransparentCheckbox:SetToolTip("Enable this only if your texture has transparency")
    TransparentCheckbox:SetConVar("materialurl_parameter_transparent")

    local EnvmapCheckbox = vgui.Create("DCheckBoxLabel")
    CPanel:AddPanel(EnvmapCheckbox)
    EnvmapCheckbox:SetDark(true)
    EnvmapCheckbox:SetText("Specular texture")
    EnvmapCheckbox:SetToolTip("Will reflect the map's env_cubemaps (only visible when mat_specular is on)")
    EnvmapCheckbox:SetConVar("materialurl_parameter_envmap")

    local ReflectivitySlider = vgui.Create("DNumSlider")
    CPanel:AddPanel(ReflectivitySlider)
    ReflectivitySlider:SetDecimals(1)
    ReflectivitySlider:SetMinMax(0,1)
    ReflectivitySlider:SetDark(true)
    ReflectivitySlider:SetText("Reflectivity")
    ReflectivitySlider:SetToolTip("How much the material will reflect light")
    ReflectivitySlider:SetConVar("materialurl_parameter_reflectivity")

    local ScaleXSlider = vgui.Create("DNumSlider")
    CPanel:AddPanel(ScaleXSlider)
    ScaleXSlider:SetDecimals(1)
    ScaleXSlider:SetMinMax(0.1,10)
    ScaleXSlider:SetDark(true)
    ScaleXSlider:SetText("Scale X")
    ScaleXSlider:SetConVar("materialurl_parameter_scalex")

    local ScaleYSlider = vgui.Create("DNumSlider")
    CPanel:AddPanel(ScaleYSlider)
    ScaleYSlider:SetDecimals(1)
    ScaleYSlider:SetMinMax(0.1,10)
    ScaleYSlider:SetDark(true)
    ScaleYSlider:SetText("Scale Y")
    ScaleYSlider:SetConVar("materialurl_parameter_scaley")

    local RotationSlider = vgui.Create("DNumSlider")
    CPanel:AddPanel(RotationSlider)
    RotationSlider:SetDecimals(0)
    RotationSlider:SetMinMax(0,360)
    RotationSlider:SetDark(true)
    RotationSlider:SetText("Rotation (in degrees)")
    RotationSlider:SetToolTip("Rotate the material counter-clockwise")
    RotationSlider:SetConVar("materialurl_parameter_rotation")

    local TranslateXSlider = vgui.Create("DNumSlider")
    CPanel:AddPanel(TranslateXSlider)
    TranslateXSlider:SetDecimals(1)
    TranslateXSlider:SetMinMax(0,1)
    TranslateXSlider:SetDark(true)
    TranslateXSlider:SetText("X Offset")
    TranslateXSlider:SetConVar("materialurl_parameter_translatex")

    local TranslateYSlider = vgui.Create("DNumSlider")
    CPanel:AddPanel(TranslateYSlider)
    TranslateYSlider:SetDecimals(1)
    TranslateYSlider:SetMinMax(0,1)
    TranslateYSlider:SetDark(true)
    TranslateYSlider:SetText("Y Offset")
    TranslateYSlider:SetConVar("materialurl_parameter_translatey")

    local ResetButton = vgui.Create("DButton")
    CPanel:AddPanel(ResetButton)
    ResetButton:SetText("Reset parameters")
    ResetButton:Dock(BOTTOM)
    ResetButton.DoClick = function()
        LocalPlayer():ConCommand("materialurl_parameter_noclamp 1")
        LocalPlayer():ConCommand("materialurl_parameter_transparent 0")
        LocalPlayer():ConCommand("materialurl_parameter_envmap 0")
        LocalPlayer():ConCommand("materialurl_parameter_reflectivity 0.0")
        LocalPlayer():ConCommand("materialurl_parameter_scalex 1.0;materialurl_parameter_scaley 1.0")
        LocalPlayer():ConCommand("materialurl_parameter_rotation 0")
        LocalPlayer():ConCommand("materialurl_parameter_translatex 0.0;materialurl_parameter_translatey 0.0")
    end

    -----

    local FavoritesLabel = vgui.Create("DLabel")
    CPanel:AddPanel(FavoritesLabel)
    FavoritesLabel:SetDark(true)
    FavoritesLabel:SetText("\nThis is your favorite list. The materials you favorited are stored here.")
    FavoritesLabel:SetWrap(true)
    FavoritesLabel:SetAutoStretchVertical(true)

    local panel3 = vgui.Create("DPanel")
    CPanel:AddPanel(panel3)
    panel3:SetPaintBackground(false)
    panel3:SetSize(100,200)

    local FavoritesListview = panel3:Add("DListView")
    MatURL.tool.FavoritesListview = FavoritesListview
    FavoritesListview:Dock(FILL)
    FavoritesListview:SetMultiSelect(false)
    FavoritesListview:SetSortable(false)
    FavoritesListview:SetDataHeight(20)
    local FNameColumn = FavoritesListview:AddColumn("Name"):SetMinWidth(50)
    local FUrlColumn = FavoritesListview:AddColumn("URL"):SetMinWidth(50)
    local FActionColumn = FavoritesListview:AddColumn("Actions"):SetFixedWidth(60)

    local VersionLabel = vgui.Create("DLabel")
    CPanel:AddPanel(VersionLabel)
    VersionLabel:SetTextColor(Color(100,100,255,255))
    VersionLabel:SetText("Material URL "..MatURL.version.."\nby Some1else{}")
    VersionLabel:SetWrap(true)
    VersionLabel:SetAutoStretchVertical(true)

    RefreshFavorites()
end