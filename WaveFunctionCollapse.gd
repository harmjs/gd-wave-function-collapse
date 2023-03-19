extends Node2D

#var texture_path = "res://flowers.png"
#var texture = load(texture_path)

var source_image = load("res://simple_case.png")

var N = 3
var N2 = Vector2(N, N)

var NOISE_FACTOR = 0.01;

var colors
var patterns
var weights
var observed

var constraint_index

var propagator
var compatible

var weight_sums
var weight_log_weight_sums
var starting_entropy

var counts
var weight_log_weights
var entropies

#var n_overlaps
#var xyn_overlaps
#var xyn_overlaps_size

var waves
var stack
var width

var height

var directions = [[1, 0], [0, 1], [-1, 0], [0, -1]]
var observe_count = 0 
var collapsed_indices = []
var rendered = []

# Called when the node enters the scene tree for the first time.

func _ready():
	
	var source_image = Image.new()
	source_image.load("res://flowers.png")
	source_image.lock()
	
	width = 5
	height = 5
	
	init_patterns(source_image)
	debug_patterns()
	
	init_propagator()
	init_waves()
	
	run(10)
	
	for x in (width - N + 1): for y in (height - N + 1):
		for pattern_index in patterns.size():
			if waves[x][y][pattern_index]:
				observed[x][y] = pattern_index
				break
				
	print(observed)
	print(observe_count)
	
func run(limit):
	stack = []
	
	for l in limit:
		var min_entropy = find_min_entropy()
		if (min_entropy == null): break
		
		var wave_x = min_entropy[0]
		var wave_y = min_entropy[1]
		
		collapsed_indices.append(min_entropy)		
		
		observe(wave_x, wave_y)
		propagate()
		

		
func observe(wave_x, wave_y):
	var wave = waves[wave_x][wave_y]

	var weight_sum = weight_sums[wave_x][wave_y]
	var random_target = randf() * weight_sum

	var min_weight = 0
	var max_weight = 0

	var selected_pattern_index = -1

	for pattern_index in wave.size():
		if not wave[pattern_index]: continue
		var weight = weights[pattern_index]
		max_weight += weight
		if random_target > min_weight && random_target <= max_weight: 
			selected_pattern_index = pattern_index
			break
		min_weight = max_weight
	for pattern_index in wave.size():
		if pattern_index != selected_pattern_index && wave[pattern_index]:
			ban(wave_x, wave_y, pattern_index)
	return selected_pattern_index

func ban(wave_x, wave_y, pattern_index):
	waves[wave_x][wave_y][pattern_index] = false	
	for direction_index in 4:
		compatible[wave_x][wave_y][pattern_index][direction_index] = 0
	counts[wave_x][wave_y] -= 1
	weight_sums[wave_x][wave_y] -= weights[pattern_index]
	weight_log_weight_sums[wave_x][wave_y] -= weight_log_weights[pattern_index]
	var weight_sum = weight_sums[wave_x][wave_y]
	entropies[wave_x][wave_y] = (log(weight_sum) 
		- weight_log_weight_sums[wave_x][wave_y] / weight_sum)
	stack.append([wave_x, wave_y, pattern_index])
	
func draw_pattern():
	rendered = []
	
	for wave_x in width - N + 1:
		for wave_y in height - N + 1:
			for pattern_index in waves[wave_x][wave_y]:
				pass
	
func propagate():
	while stack.size() > 0:
		var item = stack.pop_back()
		var wave_x = item[0]
		var wave_y = item[1]
		var removed_pat_index = item[2]
		var wave = waves[wave_x][wave_y]
		for direction_index in 4:	
			var direction_x = directions[direction_index][0]
			var direction_y = directions[direction_index][1]
			var neighbour_x = wave_x + direction_x
			var neighbour_y = wave_y + direction_y
			if neighbour_x < 0 or neighbour_x >= (width - N + 1): continue
			if neighbour_y < 0 or neighbour_y >= (height - N + 1): continue
			var neighbour = waves[neighbour_x][neighbour_y]
			var enabled_pat_indices = propagator[removed_pat_index][direction_index]
			for enabled_pat_index in enabled_pat_indices:
				# for each enabled pattern we check it's enabler count:
				# if it's enable count is lowevered to 0 we kill the pattern
				compatible[neighbour_x][neighbour_y][enabled_pat_index][direction_index] -= 1;
				
				if compatible[neighbour_x][neighbour_y][enabled_pat_index][direction_index] == 0:
					ban(neighbour_x, neighbour_y, enabled_pat_index)
					
		#print("finished propatating x=" + str(wave_x) + " y=" + str(wave_y) + " banned_pattern=" + str(removed_pat_index))
	
func render_output():
	var output_image = Image.new()
	output_image.create(width, height, false, Image.FORMAT_RGBA4444)
	output_image.lock()
	
func init_waves():
	stack = []
	weight_log_weights = []
	var weight_sum = 0
	var weight_log_weight_sum = 0
	for weight in weights:
		var weight_log_weight = weight * log(weight)
		weight_sum += weight
		weight_log_weight_sum += weight_log_weight
		weight_log_weights.append(weight_log_weight)
	starting_entropy = log(weight_sum) - weight_log_weight_sum / weight_sum
	waves = []
	counts = []
	weight_sums = []
	weight_log_weight_sums = []
	entropies = []
	compatible = []
	observed = []
	for x in (width - N + 1):
		waves.append([])
		counts.append([])
		weight_sums.append([])
		weight_log_weight_sums.append([]);
		entropies.append([])
		compatible.append([])
		observed.append([])
		for y in (height - N + 1):
			waves[x].append([])
			compatible[x].append([])
			counts[x].append(patterns.size())
			weight_sums[x].append(weight_sum)
			weight_log_weight_sums[x].append(weight_log_weight_sum)
			entropies[x].append(starting_entropy)
			observed[x].append(-1)
			for pattern_index in patterns.size():
				waves[x][y].append(true)
				compatible[x][y].append([])
				for direction_index in 4:
					compatible[x][y][pattern_index].append(
						propagator[pattern_index][direction_index].size()) 

func are_patterns_equal(pattern_a, pattern_b):
	for x in N: for y in N: if pattern_a[x][y] != pattern_b[x][y]: return false
	return true

func find_pattern(pattern_to_find, patterns):
	for index in patterns.size():
		var pattern = patterns[index]
		if are_patterns_equal(pattern, pattern_to_find): return index
	return -1

func find_min_entropy():
	var min_entropy = INF
	var min_entropy_plus_noise = INF
	var min_entropy_index = null
	for x in (width - N + 1): for y in (height - N + 1):
		var entropy = entropies[x][y]
		var count = counts[x][y]
		if count > 1 && entropy <= min_entropy:
			var entropy_plus_noise = entropy + randf() * NOISE_FACTOR
			if entropy_plus_noise < min_entropy_plus_noise:
				min_entropy = entropy
				min_entropy_plus_noise = entropy_plus_noise
				min_entropy_index = [x, y]
	return min_entropy_index
	
func init_propagator():
	var intersections = [];
	for direction_index in directions.size(): 
		var direction = directions[direction_index]
		intersections.append([])
		var dx = direction[0]
		var dy = direction[1]
		for nx in N: 
			var x = nx + dx
			if x < 0: continue
			if x >= N: break
			for ny in N: 
				var y = ny + dy 
				if y < 0: continue
				if y >= N: break
				intersections[direction_index].append([x, y])
	propagator = []
	for pattern_index in patterns.size():
		propagator.append([])
		for direction_index in 4:
			propagator[pattern_index].append([])
	for pattern_index_a in range(patterns.size() - 1): for pattern_index_b in range(pattern_index_a, patterns.size()):
		var pattern_a = patterns[pattern_index_a]
		var pattern_b = patterns[pattern_index_b]
		for direction_index_a in 4:
			var direction_index_b = (direction_index_a + 2) % 4
			var intersection_a = intersections[direction_index_a]
			var intersection_b = intersections[direction_index_b]
			var pattern_overlap_match = true
			for offset_index in 6:
				var offset_a = intersection_a[offset_index]
				var offset_b = intersection_b[offset_index]
				var symbol_a = pattern_a[offset_a[0]][offset_a[1]]
				var symbol_b = pattern_b[offset_b[0]][offset_b[1]]
				if symbol_a != symbol_b:
					pattern_overlap_match = false
					break
			if pattern_overlap_match:
				propagator[pattern_index_a][direction_index_a].append(pattern_index_b)
				if pattern_index_a == pattern_index_b: continue
				propagator[pattern_index_b][direction_index_b].append(pattern_index_a)
func init_patterns(image:Image):
	var width = image.get_width()
	var height = image.get_height()
	
	colors = []
	var symbols = []
	
	for x in range(width): 
		symbols.append([])
		for y in range(height):
			var color = image.get_pixel(x, y)
			var symbol = colors.find(color)
			
			if symbol == -1: symbol = colors.size()
			colors.append(color)
			symbols[x].append(symbol)
	patterns = []
	weights = []
	for x in (width - N + 1): for y in (height - N + 1):
		var pattern = []
		for xn in N: 
			pattern.append([])
			for yn in N:
				pattern[xn].append(symbols[x + xn][y + yn])
		var index = find_pattern(pattern, patterns)
		if index == -1:
			#print(str(x) + ", " + str(y))
			patterns.append(pattern)
			weights.append(1)
		else:
			weights[index] +=1
"""
func create_xyn_overlaps():
	n_overlaps = []
	for n in range((N*2)-1):
		var n_offsets = []
		for n_offset in range(-N + n, n): if abs(n_offset) < (N-1):
			n_offsets.append(n_offset)	
		n_overlaps.append(n_offsets)
	
	var n_overlaps_size = n_overlaps.size()
	
	var xyn_overlaps = []
	for xn_overlap_index in n_overlaps_size:
		var xn_overlap = n_overlaps[xn_overlap_index]
		
		xyn_overlaps.append([])
		
		for yn_overlap_index in n_overlaps_size:
			var yn_overlap = n_overlaps[yn_overlap_index]
			
			var xyn_offsets = []
			
			for xn_offset in xn_overlap: for yn_offset in yn_overlap:
				xyn_offsets.append([xn_offset + 1, yn_offset + 1])
				
			xyn_overlaps[xn_overlap_index].append(xyn_offsets)
	return xyn_overlaps
	
func init_constriant_index():
	xyn_overlaps = create_xyn_overlaps()
	xyn_overlaps_size = xyn_overlaps.size()

	constraint_index = []
	for pattern_index in patterns.size():
		constraint_index.append([])
		for xn_overlap_index in xyn_overlaps_size: 
			constraint_index[pattern_index].append([])
			for yn_overlap_index in xyn_overlaps_size:	
				constraint_index[pattern_index][xn_overlap_index].append([])
		
	for pattern_index_a in range(patterns.size() - 1): for pattern_index_b in range(pattern_index_a, patterns.size()):
		var pattern_a = patterns[pattern_index_a]
		var pattern_b = patterns[pattern_index_b]
		
		for xn_overlap_index_a in xyn_overlaps_size:
			var xn_overlap_index_b = xyn_overlaps_size - 1 - xn_overlap_index_a
			for yn_overlap_index_a in xyn_overlaps_size:
				if xn_overlap_index_a == 2 && yn_overlap_index_a == 2: continue
				
				var yn_overlap_index_b = xyn_overlaps_size - 1 - yn_overlap_index_a
				
				var xyn_offsets_a = xyn_overlaps[xn_overlap_index_a][yn_overlap_index_a]
				var xyn_offsets_b = xyn_overlaps[xn_overlap_index_b][yn_overlap_index_a]
				
				var pattern_overlap_match = true;
				
				for xyn_offset_index in xyn_offsets_a.size():
					var xyn_offset_a = xyn_offsets_a[xyn_offset_index]
					var xyn_offset_b = xyn_offsets_b[xyn_offset_index]
					
					var symbol_a = pattern_a[xyn_offset_a[0]][xyn_offset_a[1]]
					var symbol_b = pattern_b[xyn_offset_b[0]][xyn_offset_b[1]]
					
					if symbol_a != symbol_b:
						pattern_overlap_match = false;
						break;
					
				if pattern_overlap_match:
					constraint_index[pattern_index_a][xn_overlap_index_a][yn_overlap_index_a].append(pattern_index_b)
					
					if (pattern_index_a == pattern_index_b): continue
					
					constraint_index[pattern_index_b][xn_overlap_index_b][yn_overlap_index_b].append(pattern_index_a)
"""


func debug_patterns():
	var debug_image = Image.new()
	
	var SCALE_FACTOR = 4
	
	var col_row_size = ceil(sqrt(float(patterns.size())))
	
	var size = col_row_size * (N+1) - 1
	
	debug_image.create(size, size, false, Image.FORMAT_RGBA4444)
	debug_image.lock()
	
	for row in col_row_size: for col in col_row_size:
		var index = row + (col * col_row_size)
		
		if index < patterns.size(): for x in N: for y in N:
			var pattern = patterns[index]
			
			var x_pixel = x + row*(N+1)
			var y_pixel = y + col*(N+1)

			debug_image.set_pixel(x_pixel, y_pixel, colors[pattern[x][y]])
			
	debug_image.save_png("res://debug_image.png")
