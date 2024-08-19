
hook.Add("EntityTakeDamage", "edshot_css_bhit_helmet", function(target, dmg)
	if target:IsPlayer() and dmg:IsBulletDamage() then
		if (target:LastHitGroup() == HITGROUP_HEAD) then
			target:EmitSound("player/bhit_helmet-1.wav")
		end
	end
end)
