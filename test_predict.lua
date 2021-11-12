#!/usr/bin/env lua

require("predict")
require("balancer")

--load_matrix = {{1,2,3}, {4,5,6}}
--load_matrix = {{1, 2, 1, 3, 1, 2, 2, 10000},
--{4, 50, 53, 52, 57, 54, 53, 60},
--{30, 29, 30, 33, 31, 33, 33, 32},
--}

-- CURRENT_LOAD_FILE = "trace/50*173.txt"
CURRENT_LOAD_FILE = "trace/current"

PREDICT_DEPTH = 5
CLUSTER_SIZE = 10

--[[
TC_RED = "\033[1;31m"
TC_GREEN = "\033[1;32m"
TC_NULL = "\033[0m"
--]]
TC_RED = "\27[31m"
TC_GREEN = "\27[32m"
TC_NULL = "\27[0m"

function load_load_from_file(rows)
	load_matrix = {}
	fin = io.open(CURRENT_LOAD_FILE, "r")
	if not fin then return end
	if rows == nil then rows = math.huge end
	if type(rows) ~= "number" then return end

	-- First line: init matrix
	line = fin:read()
	if not line then return end
	for i, num in ipairs(line:split(", \n")) do
		load_matrix[i] = { num }
	end
	rows = rows - 1

	while rows > 0 do
		line = fin:read()
		if not line then break end

		-- print(line)
		for i, num in ipairs(line:split(", \n")) do
			array = load_matrix[i]
			array[#array+1] = num
		end

		rows = rows - 1
	end
	return load_matrix, fin
end

function simple_test()
	load_matrix, fin = load_load_from_file()
	predicted = predictfunc(load_matrix)
	predicted.show_array()
	fin:close()
end

function simulate_test()
	load_matrix, fin = load_load_from_file(PREDICT_DEPTH)
	analyzer = {["accurate"]=0, ["total"]=0}
	while true do
		line = fin:read()
		if not line then break end

		next_epoch_load = line:split(", \n")
		local acc = 0
		for _, v in pairs(next_epoch_load) do
			if v > 0 then acc = acc + 1 end
		end
		print(acc)

		predicted = predictfunc(load_matrix)
		--[[
		local s = ""
		for i, v in ipairs(predicted) do
			if v > 106 then
				s = s .. string.format("%s%d:%.2f,%s", v > 106 and TC_GREEN or "", i, v or 0, v > 0 and TC_NULL or "")
			end
		end
		print("Predicted: {" .. s .. "}")
		--]]
		exports, exporting = balancer.prep_rebalance(predicted, CLUSTER_SIZE)

		--[[
		-- Show migration
		for i, export_list in pairs(exports) do
			-- print(i .. ": ".. util.table_size(export_list) .. " {" .. table.concat(export_list, ",") .. "}")
			local s = ""
			for _, n in pairs(export_list) do
				nl = next_epoch_load[n]
				s = s .. string.format("%s%d:%d,%s", nl > 0 and TC_GREEN or "", n, nl or 0, nl > 0 and TC_NULL or "")
			end
			print(i .. ": ".. util.table_size(export_list) .. " {" .. s .. "}")
		end
		--]]
		
		is_balanced = balancer.check_balanced(CLUSTER_SIZE, exporting, next_epoch_load)
		analyzer.accurate = analyzer.accurate + (is_balanced and 1 or 0)
		analyzer.total = analyzer.total + 1
		-- io.write(string.format("%s%d / %d (%.2f%%)%s\n", is_balanced and TC_GREEN or TC_RED, analyzer.accurate, analyzer.total, 100 * analyzer.accurate / analyzer.total, TC_NULL))

		balancer.update_load_matrix(load_matrix, next_epoch_load)
		--break
	end
	fin:close()
end

-- simple_test()
simulate_test()
