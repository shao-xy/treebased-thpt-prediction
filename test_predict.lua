#!/usr/bin/env lua

require("predict")

--load_matrix = {{1,2,3}, {4,5,6}}
load_matrix = {{1, 2, 1, 3, 1, 2, 2, 10000},
{4, 50, 53, 52, 57, 54, 53, 60},
{30, 29, 30, 33, 31, 33, 33, 32},
}
predicted = predictfunc(load_matrix)
util.show_array(predicted)
