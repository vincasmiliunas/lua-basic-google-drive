local M = {}
M.__index = M

function M.new()
	return setmetatable({}, M)
end

function M:formatHttpCodeError(x)
	return string.format('Bad http response code: %d.', x)
end

function M:generateBoundary()
	math.randomseed(os.time())
	local rnd = function() return string.sub(math.random(), 3) end
	local result = {}
	for i = 1,5 do table.insert(result, rnd()) end
	return table.concat(result)
end

function M:buildMultipartRelated(parts)
	local boundary = self:generateBoundary()
	local result = {}
	for _,part in pairs(parts) do
		-- delimiter
		table.insert(result, '--' .. boundary)
		-- encapsulation
		table.insert(result, '\r\n')
		table.insert(result, 'Content-Type: ' .. part.type .. '\r\n')
		table.insert(result, '\r\n')
		table.insert(result, part.data)
		table.insert(result, '\r\n')
	end
	-- close-delimiter
	table.insert(result, '--' .. boundary .. '--' .. '\r\n')
	return table.concat(result), 'multipart/related; boundary=' .. boundary
end

function M:streamMultipartRelated(parts)
	local boundary = self:generateBoundary()
	local worker = coroutine.create(function()
		for _,part in pairs(parts) do
			coroutine.yield(
				'--' .. boundary .. '\r\n' ..
				'Content-Type: ' .. part.type .. '\r\n' ..
				'\r\n'
			)
			if type(part.data) == 'string' then
				coroutine.yield(part.data)
			elseif type(part.data) == 'function' then
				while true do
					local ret = part.data()
					if not ret or #ret == 0 then break end
					coroutine.yield(ret)
				end
			elseif type(part.data) == 'thread' then
				while true do
					local ok, ret = coroutine.resume(part.data)
					if not ok then error(ret) end
					if not ret or #ret == 0 then break end
					coroutine.yield(ret)
				end
			else
				error(string.format('Invalid data format %s', type(part.data)))
			end
			coroutine.yield('\r\n')
		end
		coroutine.yield('--' .. boundary .. '--' .. '\r\n')
	end)
	return worker, 'multipart/related; boundary=' .. boundary
end

return M
