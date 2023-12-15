function AddTextEntry(key, value)
	Citizen.InvokeNative(GetHashKey("ADD_TEXT_ENTRY"), key, value)
end

Citizen.CreateThread(function()
	AddTextEntry("0x00000000 =", "")
	AddTextEntry("0xEEA97E66", "Roof Rack")
end)