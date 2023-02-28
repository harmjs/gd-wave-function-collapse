extends Node2D

var texture_path = "res://flowers.png"
var texture = load(texture_path)

var N = 3
var N2 = Vector2(N, N)

var NOISE_FACTOR = 0.00001;

var colors
var patterns
var weights

var constraints

var weight_sum
var weight_log_weight_sum
var starting_entropy

var counts
var weight_log_weights
var entropies

var waves
	
func find_min_entropy():
	var min_entropy = INF
	var min_entropy_plus_noise = INF
	var min_entropy_index = null
			
	for x in patterns.size(): for y in patterns.size():
		var entropy = entropies[x][y]
		var count = counts[x][y]
			
		if count > 1 && entropy <= min_entropy:
			var entropy_plus_noise = entropy + randf() * NOISE_FACTOR
			if entropy_plus_noise < min_entropy_plus_noise:
				min_entropy = entropy
				min_entropy_plus_noise = entropy_plus_noise
				min_entropy_index = [x, y]
				
	return min_entropy_index

# Called when the node enters the scene tree for the first time.
func _ready():
	var source_image = texture.get_data()
	source_image.load("res://flowers.png")	
	source_image.lock()
	
	init_patterns(source_image)
	
	print(patterns.size())
	
	debug_patterns()
	init_constriants() 
	init_waves(10, 10)
	
func run(limit):
	for l in limit:
		var min_entropy_index = find_min_entropy()
		if (min_entropy_index == null): break
		
		observe(min_entropy_index)
		
func observe(wave_index):
	var wave = waves[wave_index[0]][wave_index[1]]
	
	var random_target = randf() * weight_sum[wave_index]
	
	var min_weight = 0
	var max_weight = 0
	
	var selected_pattern_index = -1
	
	for pattern_index in wave:
		if not wave[pattern_index]: continue
		var weight =  weights[pattern_index]
				
		max_weight += weight
		
		if random_target > min_weight && random_target <= max_weight: 
			selected_pattern_index = pattern_index
			break;
			
		min_weight = max_weight
		
	
func ban(wave_index, pattern_index):
	waves[wave_index][pattern_index] = false
	
	counts[wave_index] -= 1
	
	# write this later :)
	
func init_waves(width, height):

	weight_log_weights = []
	
	var weight_sum = 0
	var weight_log_weight_sum = 0
	

	for weight in weights:
		var weight_log_weight = weight * log(weight)
		
		weight_sum += weight
		weight_log_weight_sum += weight_log_weight
		weight_log_weights.append(weight_log_weight)
	
	starting_entropy = log(weight_sum) - weight_log_weight_sum / weight_sum
	
	var waves = []
	var counts = []
	var weight_sums = []
	var weight_log_weight_sums = []
	var entropies = []
	
	for x in width - N + 1:
		waves.append([])
		counts.append([])
		weight_sums.append([])
		weight_log_weight_sums.append([]);
		entropies.append([])
		
		for y in height - N + 1:
			for index in patterns.size(): waves[x].append(true)
			counts.append(patterns.size())
			weight_sums.append(weight_sum)
			weight_log_weight_sums.append(weight_log_weight_sum)
			entropies.append(starting_entropy)

func create_xyn_overlaps():
	var n_overlaps = []
	for n in range((N*2)-1):
		if n == (N - 2): continue
		var n_offsets = []
		for n_offset in range(-N + n, n): if abs(n_offset) < (N-1): 
			n_offsets.append(n_offset)
		n_overlaps.append(n_offsets)
	
	var xyn_overlaps = []
	for xn_offsets in n_overlaps: for yn_offsets in n_overlaps:
		var xyn_offsets_ab = []
		for xn_offset in xn_offsets: for yn_offset in yn_offsets:
			var xyn_offset_a = [xn_offset + 1, yn_offset + 1]
			var xyn_offset_b = [-xn_offset + 1, -yn_offset + 1]
			
			xyn_offsets_ab.append([xyn_offset_a, xyn_offset_b])
		xyn_overlaps.append(xyn_offsets_ab)
	return xyn_overlaps

func init_constriants():
	var xyn_overlaps = create_xyn_overlaps()
	var xyn_overlaps_size = xyn_overlaps.size()

	constraints = []
	for index in patterns.size():
		var constraint = []
		for xyn_overlap_index in range(xyn_overlaps_size): 
			constraint.append([])
		constraints.append(constraint)

	for pattern_index_a in range(0, patterns.size() - 1): for pattern_index_b in range(1, patterns.size()):
		var pattern_a = patterns[pattern_index_a]
		var pattern_b = patterns[pattern_index_b]
	
		for xyn_overlap_index_a in range(xyn_overlaps_size): 
			var xyn_overlap_index_b = xyn_overlaps_size - xyn_overlap_index_a - 1
			var xyn_offsets_ab = xyn_overlaps[xyn_overlap_index_a]
			
			var pattern_overlap_match = true
			
			for xyn_offset_ab in xyn_offsets_ab:
				var xyn_offset_a = xyn_offset_ab[0];
				var xyn_offset_b = xyn_offset_ab[1];
				
				var symbol_a = pattern_a[xyn_offset_a[0]][xyn_offset_a[1]]
				var symbol_b = pattern_b[xyn_offset_b[0]][xyn_offset_b[1]]
				
				if symbol_a != symbol_b:
					pattern_overlap_match = false
					break
				
			if pattern_overlap_match:
				constraints[pattern_index_a][xyn_overlap_index_a].append(pattern_index_b)
				constraints[pattern_index_b][xyn_overlap_index_b].append(pattern_index_a)
				
func debug_patterns():
	var debug_image = Image.new()
	
	var SCALE_FACTOR = 4
	
	var col_row_size = ceil(sqrt(float(patterns.size())))
	
	print(col_row_size)
	
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
	
func are_patterns_equal(pattern_a, pattern_b):
	for x in N: for y in N: if pattern_a[x][y] != pattern_b[x][y]: return false
	return true

func find_pattern(pattern_to_find, patterns):
	for index in patterns.size():
		var pattern = patterns[index]
		if are_patterns_equal(pattern, pattern_to_find): return index
	
	return -1
	
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
			print(str(x) + ", " + str(y))
			patterns.append(pattern)
			weights.append(1)
		else:
			weights[index] +=1 
			
	print(weights)
