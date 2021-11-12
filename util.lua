util = {}

function util.show_array(array)
	if type(array) ~= 'table' then return end
	io.write(table.concat(array, ' ')..'\n')
	-- for _, v in ipairs(array) do
	-- 	io.write(tostring(v) .. ' ')
	-- end
	-- io.write('\n')
end

function util.table_size(t)
	if type(t) ~= 'table' then return end

	local acc = 0
	for _ in pairs(t) do
		acc = acc + 1
	end
	return acc
end

function string:split(delim)
	local delim, fields = delim or " \t\n", {}
	local pattern = string.format("([^%s]+)", delim)
	self:gsub(pattern,
		function (c)
			numval = tonumber(c)
			fields[#fields+1] = (numval ~= nil) and numval or c
		end)
	return fields
end
