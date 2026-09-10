--!strict
--[[
	Types
	Sunucu ve client arasinda paylasilan veri sekilleri.
]]

export type Profile = {
	Version: number,
	Coins: number,
	Backpack: number,
	Rebirths: number,
	ToolIndex: number,
	BackpackIndex: number,
	TotalCollected: number,
	LastSeen: number,
}

-- Sunucunun client'a gonderdigi anlik durum. Ham profilin tamamini degil,
-- sadece arayuzun ihtiyaci olani gonderiyoruz.
export type Snapshot = {
	Coins: number,
	Backpack: number,
	Capacity: number,
	Rebirths: number,
	ToolIndex: number,
	BackpackIndex: number,
	Multiplier: number,
	RebirthCost: number,
	CanRebirth: boolean,
}

return {}
