--[[
	Signal
	BindableEvent'e ihtiyac duymadan calisan hafif olay nesnesi.
	Instance uzerinden gecmedigi icin tablo/fonksiyon gibi degerleri
	referansini bozmadan tasiyabilir.
]]

local Signal = {}
Signal.__index = Signal

local Connection = {}
Connection.__index = Connection

function Connection:Disconnect()
	if self._connected then
		self._connected = false
		self._signal._handlers[self] = nil
	end
end

function Signal.new()
	return setmetatable({ _handlers = {} }, Signal)
end

function Signal:Connect(handler: (...any) -> ())
	local connection = setmetatable({ _signal = self, _handler = handler, _connected = true }, Connection)
	self._handlers[connection] = true
	return connection
end

function Signal:Once(handler: (...any) -> ())
	local connection
	connection = self:Connect(function(...)
		connection:Disconnect()
		handler(...)
	end)
	return connection
end

function Signal:Fire(...)
	for connection in self._handlers do
		if connection._connected then
			task.spawn(connection._handler, ...)
		end
	end
end

function Signal:Destroy()
	table.clear(self._handlers)
end

return Signal
