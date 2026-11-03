ENT.Type = "brush"
ENT.Base = "base_trigger_brush"
ENT.Spawnable = false
DEFINE_BASECLASS(ENT.Base)

ENT.CargoPlayer = NULL
ENT.CargoEntity = NULL
ENT.Vehicle = NULL
ENT.IgnoreEntity = NULL
ENT.IgnoreDuration = 0

ENT.DoesCustomOutput = true

-- Approx size of the hold
local vecMins = Vector( -8.0, -6.0, 0 )
local vecMaxs = Vector( 8.0, 6.0, 4.0 )

function ENT:Initialize()
	self:SetKeyValue("spawnflags", SF_TRIGGER_ALLOW_PHYSICS)
	self:SetCollisionBounds(vecMins, vecMaxs)

	self:SetTrigger(true)
	self:SetSolid(SOLID_OBB)

	-- we are hijacking an engine ent; so when engine sets us up on a jalopy, we have our parent & owner (both set to vehicle) setup already
	local vehicle = self:GetParent()
	if vehicle:IsValid() and vehicle:IsVehicle() and vehicle:IsValidVehicle() then
		self.Vehicle = vehicle
	end

	BaseClass.Initialize(self)
end

function ENT:Think()
	local ent = self.CargoEntity
	local vehicle = self.Vehicle

	if ent and ent:IsValid() and vehicle and vehicle:IsValid() then
		-- stop colliding with things
		ent:PhysicsDestroy()
		ent:SetSolidFlags(FSOLID_NOT_SOLID)
		ent:SetMoveType(MOVETYPE_NONE)

		-- parent the object to our owner
		ent:SetParent(vehicle)

		-- the car now owns the entity
		do --pJeep->AddPropToCargoHold( pProp )
			local cargoProp = vehicle:GetInternalVariable("m_hCargoProp")
			if not cargoProp:IsValid() then
				vehicle:SetSaveValue("m_hCargoProp", ent)
				--vehicle:SetSaveValue("m_flCargoStartTime", CurTime())
				--vehicle:SetSaveValue("m_bAddingCargo", true)

				-- for some reason i cannot force the engine animation to smoothly place the item in the cargo hold
				-- so i'll just snap it into place :(
				local qa = Angle( 0, 90, 0 )

				--local ply = self.CargoPlayer
				--if ply and ply:IsValid() then
				--	--local carryAng = ply:GetPreferredCarryAngles(ent)
				--	--qa:Add(carryAng)
				--end

				local attachmentID = vehicle:LookupAttachment("cargo")
				local attachment = vehicle:GetAttachment(attachmentID)
				local vecTarget = vehicle:WorldToLocal(attachment.Pos)

				ent:SetLocalPos(vecTarget)
				ent:SetLocalAngles(qa)
			end
		end
	end

	return true
end

function ENT:OnStartTouch(ent, was_empty)
	-- cannot be ignoring touches
	if ent == self.IgnoreEntity and CurTime() <= self.IgnoreDuration then return end

	-- make sure that this object is being held by the player
	local phys = ent:GetPhysicsObject()
	if not (IsValid(phys) and phys:HasGameFlag(FVPHYSICS_PLAYER_HELD)) then return end

	local classname = ent:GetClass()
	if classname == "weapon_striderbuster" and ent:GetInternalVariable("m_nAttachedFlechettes") > 0 then return end

	self:AddCargo(ent)
end

function ENT:OnEndTouch(ent, is_empty)
	if ent == self.IgnoreEntity then
		self.IgnoreEntity = NULL
	end
end

function ENT:AddCargo(ent)
	local phys = ent:GetPhysicsObject()
	if not IsValid(phys) then return end

	local jeep = self.Vehicle
	if not (jeep and jeep:IsValid()) then return end

	local addingPlayer = ent.oc_plyholding

	ent:ForcePlayerDrop()

	self.CargoEntity = ent
	self.CargoPlayer = addingPlayer
	-- now goto Think() to handle the rest
	self.Enabled = false

	self:NextThink(CurTime())
end

function ENT:IgnoreTouches(ent)
	self.IgnoreEntity = ent
	self.IgnoreDuration = CurTime() + 0.5
end
