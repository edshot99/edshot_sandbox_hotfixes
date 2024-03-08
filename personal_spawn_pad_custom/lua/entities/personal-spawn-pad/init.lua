AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

local PSPHealth = CreateConVar( "personal_spawn_pad_hp", 75, { FCVAR_ARCHIVE, FCVAR_NOTIFY }, "Set the default health ammount for Personal Spawn Pads" )
local PSPTeamDmg = CreateConVar( "personal_spawn_pad_team_dmg", 1, { FCVAR_ARCHIVE, FCVAR_NOTIFY }, "Allow players on the same team to damage Personal Spawn Pads",0,1 ) 
local PSPPickup = CreateConVar( "personal_spawn_pad_allow_owner_pickup", 1, { FCVAR_ARCHIVE, FCVAR_NOTIFY }, "Allow Spawn Pad owners to pick up their Pads with E",0,1 )
local PSPPhysics = CreateConVar( "personal_spawn_pad_enable_physics", 0, { FCVAR_ARCHIVE, FCVAR_NOTIFY }, "Do you want the Spawn Pads to spawn like props?",0,1 ) 

--not added (yet)
-- local PSPBeamType = CreateConVar( "personal_spawn_pad_beam_type", 1, { FCVAR_ARCHIVE, FCVAR_NOTIFY }, "Change Spawn Pad beam type(0=off, 1=plasma, 2=rift)",0,2 ) --feature creeping. removed. see cl_init.lua
	
function ENT:SpawnFunction(ply, tr)
	if (!tr.Hit) then  
		return
	end

	local SpawnPos = tr.HitPos + tr.HitNormal * 16

	local ent = ents.Create("personal-spawn-pad")
	ent:SetPos(SpawnPos)
	ent:Spawn()
	ent:Activate()
	ent:GetOwner(self.SpawnPadOwner)
	return ent
end

function ENT:Initialize()
	self.Entity:SetModel("models/maxofs2d/hover_plate.mdl")
	self.Entity:PhysicsInit(SOLID_VPHYSICS)
	if (GetConVar( "personal_spawn_pad_enable_physics" ):GetInt() == 1) then
		self.Entity:SetMoveType(MOVETYPE_VPHYSICS)
	else
		self.Entity:SetMoveType(MOVETYPE_NONE)
	end
	self.Entity:SetSolid(SOLID_VPHYSICS)
	self.Entity:SetCollisionGroup(COLLISION_GROUP_WEAPON)
	self.Entity:DrawShadow(false)
	self.Entity:SetMaxHealth(5)
	self.Entity:SetHealth(5)
	self.Entity:SetOwner(game.GetWorld())
	self.HealthAmnt = GetConVar( "personal_spawn_pad_hp" ):GetInt()
	
	local phys = self.Entity:GetPhysicsObject()

	if (phys:IsValid()) then
		phys:Wake()
	end
	self.Hit = false

	self:SetDTFloat(0, math.Rand(0.5, 1.3))
	self:SetDTFloat(1, math.Rand(0.3, 1.2))
end

function ENT:SetupDataTables()
	self:DTVar("Float", 0, "RotationSeed1")
	self:DTVar("Float", 1, "RotationSeed2")
end

local zapsound = Sound("npc/assassin/ball_zap1.wav")
local pickupsound = Sound("buttons/lever7.wav")

function ENT:OnTakeDamage(dmg)
	local DoWeTakeTeamDmg = GetConVar( "personal_spawn_pad_team_dmg" ):GetBool()
	if(DoWeTakeTeamDmg == false) then
		if !dmg:GetAttacker():IsNPC() then --ignore the following if the attacker is npc (let npcs dmg spawn pad)
			if dmg:GetAttacker():Team() == self.SpawnPadOwner:Team() then return true end --thanks |KB| >KEKSQUAD
		end
	end
	
	self:TakePhysicsDamage(dmg)

	if (self.HealthAmnt <= 0) then
		return
	end

	self.HealthAmnt = self.HealthAmnt - dmg:GetDamage()

	if (self.HealthAmnt <= 0) then
		local effect = EffectData()
		effect:SetStart(self:GetPos())
		effect:SetOrigin(self:GetPos())
		util.Effect("cball_explode", effect, true, true)
		sound.Play(zapsound, self:GetPos(), 100, 100)
		self:Remove()
	end
end

function ENT:Use(activator, caller)	
	timer.Simple(0.2,function() 
		local AllowPickupNow = GetConVar( "personal_spawn_pad_allow_owner_pickup" ):GetBool()
		if(AllowPickupNow == true and activator == self.SpawnPadOwner and !activator:KeyDown(IN_USE) and !activator:KeyDown(IN_ATTACK)) then
			activator:Give("personal-spawn-pad-swep")
			sound.Play(pickupsound, self:GetPos(), 100, math.random( 120, 150 ))
			self:Remove()
		end
	end)
end

function ENT:Think()
end
