#!/usr/bin/env lua

require("util")
require("stats")

balancer = {}

-- Here we ignore parameter "have" since we don't descend into subtrees
function balancer.find_exports(load_array, amount, exports, already_exporting, target)
	local need = amount
	local needmax = need * 1.2
	local needmin = need * 0.8
	local midchunk = need * 0.3
	local smaller = {}
	local bigger = {}
	for i = 1, #load_array do
	repeat -- for continue
		pop = load_array[i]
		if already_exporting[i] then
			-- print("Already exporting " .. i)
			break
		end -- continue

		-- lucky find?
		if pop > needmin and pop < needmax then
			exports[#exports+1] = i
			already_exporting[i] = target
			return
		end

		if pop > need then
			bigger[#bigger+1] = i
		else
			smaller[#smaller+1] = {pop, i}
		end
	until true
		-- ::continue:: -- This doesn't work in Lua 5.1
	end
	--[[
	local exporting_contents = ""
	for i, _ in pairs(already_exporting) do
		exporting_contents = exporting_contents .. i .. ","
	end
	local smaller_contents = ""
	for _, v in ipairs(smaller) do
		smaller_contents = smaller_contents .. v[2] .. ","
	end
	print("exporting size: " .. util.table_size(already_exporting) .. " {" .. exporting_contents .. "}")
	print("smaller size: " .. util.table_size(smaller) .. " {" .. smaller_contents .. "}")
	print("bigger size: " .. util.table_size(bigger) .. " {" .. table.concat(bigger, ",") .. "}")
	--]]

	local have = 0

	-- Sort smaller dirs
	table.sort(smaller, function (a, b)
		return a[1] > b[1] -- or a[1] == b[1] and a[2] < b[2]
	end)

	small_pos = 1
	while small_pos < #smaller do
		if smaller[small_pos][1] < midchunk then break end
		-- print("  taking smaller " .. smaller[small_pos][1] .. "" ..smaller[small_pos][2])
		exports[#exports+1] = smaller[small_pos][2]
		already_exporting[smaller[small_pos][2]] = target
		have = have + smaller[small_pos][1]

		--[[ increase actually should be placed before break
		but Ceph's implementation doesn't care about this
		--]]
		small_pos = small_pos + 1

		if have > needmin then break end
	end
	
	-- We have to skip bigger set here: we couldn't descend
	
	while small_pos < #smaller do
		-- print("  taking (much) smaller " .. smaller[small_pos][1] .. "" ..smaller[small_pos][2])
		exports[#exports+1] = smaller[small_pos][2]
		already_exporting[smaller[small_pos][2]] = target
		have = have + smaller[small_pos][1]
		small_pos = small_pos + 1
		if have > need then break end
	end

	-- return have
end

-- Returns an table of (entry_index, target_mds)
function balancer.prep_rebalance(load_array, cluster_size)
	local amount = stats.sum(load_array) / cluster_size

	local exports = {}
	local already_exporting = {}
	for i = 2, cluster_size do
		exports[i] = {}
		balancer.find_exports(load_array, amount, exports[i], already_exporting, i)
	end

	return exports, already_exporting
end

function balancer.check_balanced(cluster_size, exporting, next_epoch_load)
	mds_load = {}
	for i = 1, cluster_size do
		mds_load[i] = 0
	end

	for entry, l in ipairs(next_epoch_load) do
		target = exporting[entry] and exporting[entry] or 1
		mds_load[target] = mds_load[target] + l
	end
	cv = stats.coefficientOfVariation(mds_load)
	cv = cv or 0
	ncv = cv / math.sqrt(cluster_size)
	-- io.write("\r\27[0K")
	--[[
	io.write(string.format("%.4f ", ncv))
	util.show_array(mds_load)
	--]]
	return ncv < 0.15
end

function balancer.update_load_matrix(load_matrix, next_epoch_load)
	for entry, load_list in pairs(load_matrix) do
		table.remove(load_list, 1)
		table.insert(load_list, next_epoch_load[entry] or 0)
	end
end
