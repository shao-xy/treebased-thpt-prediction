util = {}

function util.show_array(array)
	if type(array) ~= 'table' then return end
	for _, v in ipairs(array) do
		io.write(tostring(v) .. ' ')
	end
	io.write('\n')
end
