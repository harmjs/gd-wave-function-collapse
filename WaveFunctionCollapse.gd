extends Node2D

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

var waves
var stack
var width

var height

#                0:RIGHT  1:DOWN  2:LEFT   3:UP
var directions = [[1, 0], [0, 1], [-1, 0], [0, -1]]
var observe_count = 0 
var collapsed_indices = []
var pixels = []
 
# TODO: Patterns which have no legal matches at runtime (void edge) need to be turned off

# TODO: Add rotation support...
# When there is a pattern, we also add all mirrored and rotated versions of that pattern...
# 

# How can we determine what is the ideal rotation of a piece?
# 1. first instance found...
# 2. Pattern properties.


func _ready():
	var source_image = Image.new()
	source_image.load("res://knot.png")
	source_image.lock()
	
	width = 100
	height = 100
	
	init_patterns(source_image)
	debug_patterns()
	
	init_propagator()
	init_waves()
	
	var file = File.new()
	file.open("res://debug.json", File.WRITE)
	file.store_line(to_json(propagator))
	file.close()

	run(10000000)
	
	for x in (width - N + 1): for y in (height - N + 1):
		for pattern_index in patterns.size():
			if waves[x][y][pattern_index]:
				observed[x][y] = pattern_index
				break
	
func run(limit):
	stack = []
	
	for l in limit:
		var min_entropy = find_min_entropy()
		if (min_entropy == null): break
		
		var wave_x = min_entropy[0]
		var wave_y = min_entropy[1]
		
		collapsed_indices.append(min_entropy)		
		
		var selected_pattern_index = observe(wave_x, wave_y)
		
		observe_count += 1;
		propagate(10000)
		
	render_output()
		
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
		
	print("observed x=" + str(wave_x) + " y=" + str(wave_y) + " selected pattern=" + str(selected_pattern_index))
	for pattern_index in wave.size():
		if pattern_index != selected_pattern_index && wave[pattern_index]:
			ban(wave_x, wave_y, pattern_index)
			
	return selected_pattern_index

func ban(wave_x, wave_y, pattern_index):
	print("banning x=" + str(wave_x) + " y=" + str(wave_y) + " banned_pattern=" + str(pattern_index))
	stack.append([wave_x, wave_y, pattern_index])
	
	waves[wave_x][wave_y][pattern_index] = false
	for direction_index in 4:
		compatible[wave_x][wave_y][pattern_index][direction_index] = 0
	counts[wave_x][wave_y] -= 1
	weight_sums[wave_x][wave_y] -= weights[pattern_index]
	weight_log_weight_sums[wave_x][wave_y] -= weight_log_weights[pattern_index]
	
	var weight_sum = weight_sums[wave_x][wave_y]
		
	entropies[wave_x][wave_y] = (log(weight_sum) 
		- weight_log_weight_sums[wave_x][wave_y] / weight_sum)
	
	
# When 5 is banned its wrongly banning two on the right side of it... have a look at the propagator and the constraints
	
func propagate(limit):
	var current = 0
	while current < limit and stack.size() > 0:
		var item = stack.pop_back()
		var wave_x = item[0]
		var wave_y = item[1]
		var removed_pat_index = item[2]
		var wave = waves[wave_x][wave_y]
		print("propagating x=" + str(wave_x) + " y=" + str(wave_y) + " removed pattern=" + str(removed_pat_index))
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
				if !neighbour[enabled_pat_index]: continue
				
				# for each enabled pattern we check it's enabler count:
				# if it's enable count is lowevered to 0 we kill the pattern
				
				compatible[neighbour_x][neighbour_y][enabled_pat_index][direction_index] -= 1
				var enablers = compatible[neighbour_x][neighbour_y][enabled_pat_index][direction_index]
				
				print("checking x=" + str(neighbour_x) + " y=" + str(neighbour_y) + " pattern=" + str(enabled_pat_index) + " in direction=" + str(direction_index) + " enablers=" + str(enablers))
				
				if compatible[neighbour_x][neighbour_y][enabled_pat_index][direction_index] <= 0:
					ban(neighbour_x, neighbour_y, enabled_pat_index)
		current += 1
		"""print("finished propatating x=" + str(wave_x) + " y=" + str(wave_y) + " banned_pattern=" + str(removed_pat_index))"""
	
func render_output():
	var output_image = Image.new()
	output_image.create(width, height, false, Image.FORMAT_RGBA4444)
	output_image.lock()
	
	pixels = [];
	for x in width: 
		pixels.append([])
		for y in height:
			pixels[x].append({})
	
	for wave_x in width - N + 1: for wave_y in height - N + 1:
		var wave = waves[wave_x][wave_y]
		for pattern_index in patterns.size():
			if wave[pattern_index] == true:
				for pattern_x in 3: for pattern_y in 3:
					
					var x = wave_x + pattern_x
					var y = wave_y + pattern_y
					
					var color = colors[patterns[pattern_index][pattern_x][pattern_y]]
					if not pixels[x][y].has(color):
						pixels[x][y][color] = 0
					pixels[x][y][color] += 1
					
	for x in width:
		for y in height:
			var pixel = pixels[x][y]
			
			if pixel.size() == 1:
				output_image.set_pixel(x, y, pixel.keys()[0])
			else:
				
				var total_count = 0
				var r = 0
				var g = 0
				var b = 0
				
				for color in pixel:
					var count = pixel[color]
					total_count += count
					
					r += color.r * count
					g += color.g * count
					b += color.b * count
				
				r = r / total_count
				g = g / total_count
				b = b / total_count
				
				var color = Color(r, g, b, 0.5)
				output_image.set_pixel(x, y, color)
				
	#output_image.save_png("res://output_image.png")
	output_image.unlock()
	
	var texture = ImageTexture.new()
	texture.create_from_image(output_image)
	texture.set_flags(0)
	
	var sprite = get_child(0)
	sprite.set_texture(texture)
	sprite.visible = true
	sprite.scale = Vector2(10, 10)
	sprite.centered = false
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
						propagator[pattern_index][(direction_index + 2) % 4].size())

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

func debug_patterns():
	var SCALE_FACTOR = 8
	
	var col_row_size = ceil(sqrt(float(patterns.size())))
	
	var size = col_row_size * (N+1) - 1
	
	var debug_image = Image.new()
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
