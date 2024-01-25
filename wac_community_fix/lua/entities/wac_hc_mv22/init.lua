
include("shared.lua")
AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

function ENT:SpawnFunction(ply, tr)
	if (!tr.Hit) then return end
	local ent=ents.Create(ClassName)
	ent:SetPos(tr.HitPos+tr.HitNormal*10)
	ent:Spawn()
	ent:Activate()
	ent.Owner=ply
	return ent
end

ENT.Wheels={
	{
		mdl="models/BF2/helicopters/Mil Mi-28/mi28_w1.mdl",
		pos=Vector(-98,-66,5),
		friction=100,
		mass=250,
	},
	{
		mdl="models/BF2/helicopters/Mil Mi-28/mi28_w1.mdl",
		pos=Vector(-98,-79,5),
		friction=100,
		mass=250
	},
	{
		mdl="models/BF2/helicopters/Mil Mi-28/mi28_w1.mdl",
		pos=Vector(-98,66,5),
		friction=100,
		mass=250,
	},
	{
		mdl="models/BF2/helicopters/Mil Mi-28/mi28_w1.mdl",
		pos=Vector(-98,79,5),
		friction=100,
		mass=250
	},
	{
		mdl="models/BF2/helicopters/Mil Mi-28/mi28_w1.mdl",
		pos=Vector(225,-6,5),
		friction=100,
		mass=250
	},
	{
		mdl="models/BF2/helicopters/Mil Mi-28/mi28_w1.mdl",
		pos=Vector(225,6,5),
		friction=100,
		mass=250
	},
}

function ENT:addRotors()
	self:base("wac_hc_base").addRotors(self)
	self.topRotor2 = self:addEntity("prop_physics")
	self.topRotor2:SetModel("models/props_junk/sawblade001a.mdl")
	self.topRotor2:SetPos(self:LocalToWorld(self.TopRotor2.pos))
	self.topRotor2:SetAngles(self:LocalToWorldAngles(self.TopRotor2.angles))
	self.topRotor2:SetOwner(self.Owner)
	self.topRotor2:SetNotSolid(true)
	self.topRotor2:Spawn()
	self.topRotor2.Phys = self.topRotor2:GetPhysicsObject()
	self.topRotor2.Phys:EnableGravity(false)
	self.topRotor2.Phys:SetMass(5)
	self.topRotor2.Phys:EnableDrag(false)
	self.topRotor2:SetNoDraw(true)
	self.topRotor2.fHealth = 100
	self.topRotor2.wac_ignore = true
	if self.TopRotor2.model then
		local e = self:addEntity("wac_hitdetector")
		self:SetNWEntity("wac_air_rotor_main", e)
		e:SetModel(self.TopRotor2.model)
		e:SetPos(self.topRotor2:GetPos())
		e:SetAngles(self.topRotor2:GetAngles())
		e:Spawn()
		e:SetNotSolid(true)
		e:SetParent(self.topRotor2)
		e.wac_ignore = true
		local obb = e:OBBMaxs()
		self.RotorWidth2 = (obb.x>obb.y and obb.x or obb.y)
		self.RotorHeight2 = obb.z
		self.topRotor2.vis = e
	end
	constraint.Axis(self.Entity, self.topRotor2, 0, 0, self.TopRotor2.pos, Vector(0,0,1), 0,0,0,1)
	self:AddOnRemove(self.topRotor2)
end

function ENT:PhysicsUpdate(ph)
	self:base("wac_hc_base").PhysicsUpdate(self,ph)		
		
	local vel = ph:GetVelocity()	
	local pos = self:GetPos()
	local ri = self:GetRight()
	local up = self:GetUp()
	local fwd = self:GetForward()
	local ang = self:GetAngles()
	local dvel = vel:Length()
	local lvel = self:WorldToLocal(pos+vel)
	local pilot = self.passengers[1]
	local hover = self:calcHover(ph,pos,vel,ang)
	
	local rotateX = (self.controls.roll*1.5+hover.r)*self.rotorRpm
	local rotateY = (self.controls.pitch+hover.p)*self.rotorRpm
	local rotateZ = self.controls.yaw*1.5*self.rotorRpm
	
	--local phm = (wac.aircraft.cvars.doubleTick:GetBool() and 2 or 1)
	local phm = FrameTime()*66
	if self.UsePhysRotor then
		if self.topRotor2 and self.topRotor2.Phys and self.topRotor2.Phys:IsValid() then
			if self.RotorBlurModel then
				self.topRotor2.vis:SetColor(Color(255,255,255,math.Clamp(1.3-self.rotorRpm,0.1,1)*255))
			end
			-- top rotor physics
			local rotor = {}
			rotor.phys = self.topRotor2.Phys
			rotor.angVel = rotor.phys:GetAngleVelocity()
			rotor.upvel = self.topRotor2:WorldToLocal(self.topRotor2:GetVelocity()+self.topRotor2:GetPos()).z
			rotor.brake =
				math.Clamp(math.abs(rotor.angVel.z) - 2950, 0, 100)/10 -- RPM cap
				+ math.pow(math.Clamp(1500 - math.abs(rotor.angVel.z), 0, 1500)/900, 3)
				+ math.abs(rotor.angVel.z/10000)
				- (rotor.upvel - self.rotorRpm)*self.controls.throttle/1000
			rotor.targetAngVel =
				Vector(0, 0, math.pow(self.engineRpm,2)*self.TopRotor2.dir*10)
				- rotor.angVel*rotor.brake/200
			rotor.phys:AddAngleVelocity(rotor.targetAngVel)
		end
	end
	self.LastPhys = CurTime()
end