#!/usr/bin/env lua

require("stats")
require("util")

local function calc_decayedload(load_array)
	local decayfactor = 2
	local sum = 0
	for i = #load_array, 1, -1 do
		sum = (sum + load_array[i]) / decayfactor
		if sum < 1 then sum = 0 end
	end
	return sum
end

local function predictfunc_average(load_matrix)
	prediction = {}
	for entry, entry_load_list in ipairs(load_matrix) do
		prediction[entry] = stats.average(entry_load_list)
	end
	return prediction
end

local function predictfunc_decay(load_matrix)
	prediction = {}
	for entry, entry_load_list in ipairs(load_matrix) do
		prediction[entry] = calc_decayedload(entry_load_list)
	end
	return prediction
end

-- Use pulse-based function to predict.
-- Flunctuations above average are treated as spatial load,
-- and are distributed among all entries
local function predictfunc_above_average(load_matrix)
	prediction = {}
	spatial_load = 0
	for entry, entry_load_list in ipairs(load_matrix) do
		average = #entry_load_list > 0 and stats.mean(entry_load_list) or 0
		sd = stats.standardDeviation(entry_load_list)
		-- print(string.format("%2d: average is %.2f, standard deviation is %.2f.", entry, average, sd))
		local my_spatial_load_total = 0
		for epoch, load_value in ipairs(entry_load_list) do
			delta = load_value - average
			-- delta must be positive
			if delta > 0 then
				my_spatial_load_total = my_spatial_load_total + math.abs(delta)
				-- print(string.format("%2d %2d: delta %d > 0", entry, epoch, delta))
			end
		end
		spatial_load = spatial_load + my_spatial_load_total / #entry_load_list
		prediction[entry] = average
	end
	-- print("Spatial load is " .. spatial_load)
	for i = 1,#prediction do
		prediction[i] = prediction[i] + spatial_load / #prediction
	end
	return prediction
end

local function predictfunc_kmeans2(load_matrix)
	if #load_matrix < 10 then
		return predictfunc_decay(load_matrix)
	end

	local kmeans2 = function (vallist)
		-- initialize
		cluster = {{["vals"]={}}, {["vals"]={}}}
		for i = 1, #vallist do
			idx = i > (#vallist / 2) and 2 or 1
			target_vals = cluster[idx].vals
			target_vals[#target_vals+1] = vallist[i]
		end

		-- -- DEBUG
		-- print("Before cluster")
		-- for i = 1, 2 do
		-- 	io.write(string.format("cluster[%d]=", i))
		-- 	util.show_array(cluster[i].vals)
		-- end
		-- print("Start cluster")

		-- cluster
		while true do
			-- initialize average first
			for i = 1, 2 do
				cluster[i].avg = stats.mean(cluster[i].vals)
				if cluster[i].avg == nil then
					return stats.mean(vallist), 0
					-- print("Cluster length = "..#cluster[i].vals)
					-- print("The other cluster length = " .. #cluster[3-i].vals)
				end
			end
			local cluster_stop = true
			local new_cluster = {{["vals"]={}}, {["vals"]={}}}
			-- do swap
			for i = 1, 2 do
				local vals = cluster[i].vals
				for j = 1, #vals do
					local val = vals[j]
					local target = 
						(math.abs(val-cluster[1].avg) < math.abs(val-cluster[2].avg))
						and 1 or 2
					new_cluster[target].vals[#new_cluster[target].vals + 1] = val
					if i ~= target then
						cluster_stop = false
					end
				end
			end
			if cluster_stop then break end

			-- real swap: old data is dropped
			cluster = new_cluster

			-- -- DEBUG: show array
			-- for i = 1, 2 do
			-- 	io.write(string.format("cluster[%d]=", i))
			-- 	util.show_array(cluster[i].vals)
			-- end
		end
		-- -- DEBUG
		-- print("End cluster")

		-- final average
		for i = 1, 2 do
			cluster[i].avg = stats.mean(cluster[i].vals)
		end

		-- which is which
		local temporal_idx = cluster[1].avg < cluster[2].avg and 1 or 2
		local spatial_idx = 3 - temporal_idx
		local temporal_loads = cluster[temporal_idx]
		local spatial_loads = cluster[spatial_idx]
		-- -- DEBUG: show array
		-- io.write("temporal_loads=")
		-- util.show_array(temporal_loads.vals)
		-- io.write("spatial_loads=")
		-- util.show_array(spatial_loads.vals)
		
		-- check if they are close?
		if spatial_loads.avg < 1.1 * temporal_loads.avg or #spatial_loads.vals > #temporal_loads.vals then
			return stats.mean(vallist), 0
		end

		-- groups are far from each other: spatial load equals (spatial_average - temporal_average)
		return temporal_loads.avg, 
			spatial_loads.avg - temporal_loads.avg
	end

	prediction = {}
	spatial_load = 0

	for entry, entry_load_list in ipairs(load_matrix) do
		temporal, spatial = kmeans2(entry_load_list)
		-- print(string.format("temporal = %.2f, spatial = %.2f", temporal, spatial))
		prediction[entry] = temporal
		spatial_load = spatial_load + spatial
	end
	-- print("Spatial load is " .. spatial_load)
	for i = 1,#prediction do
		prediction[i] = prediction[i] + spatial_load / #prediction
	end
	return prediction
end

-- A reference to real predict function.
-- Each possible prediction function should be defined with:
--   Parameters:
--     load_matrix: an M*N matrix representing load
--             with M as directory entries
--                  N as recent epochs
--                  load_matrix[i][j] representing dentry i has
--                      that much load in epoch j
--
--   Returns:
--     an array: an length-M array (i.e. M*1 matrix) representing
--               a prediction of load in the next epoch
-- predictfunc = predictfunc_above_average
predictfunc = predictfunc_kmeans2
--predictfunc = predictfunc_decay
--predictfunc = nil
