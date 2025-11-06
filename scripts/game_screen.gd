extends Control

const Square = preload("res://scripts/square.gd")
const BallScene = preload("res://ball.tscn")
const Character = preload("res://scripts/character.gd")

const COLOR_FAIRWAY = Color(0.5, 0.9, 0.5)
const COLOR_ROUGH = Color(0.1, 0.4, 0.1)
const COLOR_SAND = Color(0.9, 0.9, 0.6)
const COLOR_GREEN = Color(0.6, 0.9, 0.4)
const COLOR_HOLE = Color(0.1, 0.1, 0.1)
const COLOR_PLAYABLE = Color(0.6, 0.8, 1.0)
const COLOR_VARIANCE = Color(1.0, 0.7, 0.4)
const COLOR_TREE = Color(0.3, 0.4, 0.1)
const COLOR_TEEBOX = Color(0.8, 0.2, 0.2)

var player_clubs: Array[Club] = []
var player_character: Character = null # Character with D&D stats
var hole_grid: Dictionary = {} # Stores Square objects, keyed by Vector2(x, y)
var grid_width: int = 20
var grid_height: int = 20

var start_square: Square
var hole_square: Square
var current_ball_square: Square
var selected_club: Club = null
var selected_club_button: Button = null

var ball_instance: Node2D = null # Reference to the instantiated Ball scene
var square_buttons: Dictionary = {}
var is_animating_transition: bool = false

@onready var hex_grid_container = $HexGridContainer # Renamed to square_grid_container in scene
@onready var club_hand_container = $ClubHandContainer
@onready var flip_sound_player = AudioStreamPlayer.new()
@onready var reward_sound_player = AudioStreamPlayer.new()

func _ready():
    print("Game Screen Loaded!")
    if player_clubs:
        print("Player Clubs: ", player_clubs)

    # Setup audio players
    add_child(flip_sound_player)
    flip_sound_player.volume_db = -5  # Louder since we're only playing once per batch
    _generate_click_sound()

    add_child(reward_sound_player)
    reward_sound_player.volume_db = 0
    _generate_reward_sound()

    await _generate_hole()
    _display_clubs()

    # Instantiate Ball scene
    ball_instance = BallScene.instantiate()
    hex_grid_container.add_child(ball_instance)
    ball_instance.visible = true # Make the ball visible initially
    _update_ball_position_display()
    _create_legend()

func _generate_click_sound() -> void:
    # Generate a mechanical clack sound like a split-flap display
    var sample_rate = 44100.0
    var duration = 0.15 # Longer for more mechanical sound
    var frequency1 = 600.0 # Lower mechanical clack
    var frequency2 = 1200.0 # Higher mechanical component

    var audio_stream = AudioStreamWAV.new()
    audio_stream.mix_rate = int(sample_rate)
    audio_stream.format = AudioStreamWAV.FORMAT_16_BITS
    audio_stream.stereo = false

    var sample_count = int(sample_rate * duration)
    var data = PackedByteArray()

    for i in range(sample_count):
        var t = float(i) / sample_rate
        # Create a layered mechanical sound with very fast decay
        var envelope = exp(-t * 40.0) # Fast decay

        # Multiple frequency components for richer mechanical sound
        var sample = sin(2.0 * PI * frequency1 * t) * envelope * 0.5
        sample += sin(2.0 * PI * frequency2 * t) * envelope * 0.3

        # Add filtered noise burst for the mechanical impact
        var noise_envelope = exp(-t * 80.0) # Even faster decay for noise
        sample += (randf() * 2.0 - 1.0) * 0.4 * noise_envelope

        # Convert to 16-bit integer
        var sample_int = int(clamp(sample * 32767.0, -32768.0, 32767.0))
        # Pack as little-endian 16-bit
        data.append(sample_int & 0xFF)
        data.append((sample_int >> 8) & 0xFF)

    audio_stream.data = data
    flip_sound_player.stream = audio_stream

func _generate_reward_sound() -> void:
    # Generate a cheerful reward sound (ascending arpeggio)
    var sample_rate = 44100.0
    var duration = 0.3
    var frequencies = [523.25, 659.25, 783.99]  # C5, E5, G5 (C major chord)

    var audio_stream = AudioStreamWAV.new()
    audio_stream.mix_rate = int(sample_rate)
    audio_stream.format = AudioStreamWAV.FORMAT_16_BITS
    audio_stream.stereo = false

    var sample_count = int(sample_rate * duration)
    var data = PackedByteArray()

    for i in range(sample_count):
        var t = float(i) / sample_rate
        var envelope = exp(-t * 5.0)  # Gentle decay

        # Play notes in sequence (arpeggio)
        var note_duration = duration / 3.0
        var note_index = int(t / note_duration)
        if note_index >= 3:
            note_index = 2

        var freq = frequencies[note_index]
        var sample = sin(2.0 * PI * freq * t) * envelope * 0.3

        # Convert to 16-bit integer
        var sample_int = int(clamp(sample * 32767.0, -32768.0, 32767.0))
        data.append(sample_int & 0xFF)
        data.append((sample_int >> 8) & 0xFF)

    audio_stream.data = data
    reward_sound_player.stream = audio_stream

func set_player_clubs(clubs: Array[Club]) -> void:
    player_clubs = clubs

func set_character(character: Character) -> void:
    player_character = character
    print("Character loaded: %s" % character.get_summary())

func _calculate_terrain_penalty(terrain_type: Square.TerrainType, is_wood: bool) -> int:
    var base_penalty = 0

    match terrain_type:
        Square.TerrainType.ROUGH:
            base_penalty = 1
            if is_wood:
                base_penalty += 1
        Square.TerrainType.SAND:
            base_penalty = 1
            if is_wood:
                base_penalty += 2

    # Apply Wisdom bonus to reduce terrain penalties
    if player_character:
        var wisdom_reduction = player_character.get_terrain_penalty_reduction()
        base_penalty = max(0, base_penalty - wisdom_reduction)

    return base_penalty

func _generate_hole() -> void:
    hole_grid = {}
    square_buttons = {}

    # Create buttons first with a neutral starting color
    for y in range(grid_height):
        for x in range(grid_width):
            var square = Square.new(x, y, Square.TerrainType.ROUGH)
            hole_grid[Vector2(x, y)] = square

            var square_button = Button.new()
            square_buttons[Vector2(x,y)] = square_button
            var stylebox = StyleBoxFlat.new()
            stylebox.bg_color = COLOR_ROUGH # Start with rough color for initial flip
            stylebox.set_border_width_all(1)
            stylebox.set_border_color(Color(0.1, 0.1, 0.1, 0.2)) # Light border for grid effect
            square_button.add_theme_stylebox_override("normal", stylebox)
            square_button.set_flat(false) # Set to false to allow stylebox to show
            square_button.set_focus_mode(FOCUS_NONE)
            square_button.set_custom_minimum_size(Vector2(20, 20))
            square_button.connect("pressed", Callable(self, "_on_square_pressed").bind(x, y))
            square_button.connect("mouse_entered", Callable(self, "_on_square_mouse_entered").bind(x, y))
            square_button.connect("mouse_exited", Callable(self, "_on_square_mouse_exited").bind(x, y))
            hex_grid_container.add_child(square_button) # Still using hex_grid_container name for now

    # Define Tee Box
    var tee_box_center_x = randi() % (grid_width - 4) + 2 # Random x for tee box
    hole_grid[Vector2(tee_box_center_x, grid_height - 1)].terrain_type = Square.TerrainType.TEEBOX

    # Random Green position
    var green_center_x = randi() % (grid_width - 8) + 4
    var green_center_y = randi() % (grid_height / 2)
    var green_width = randi() % 3 + 3
    var green_height = randi() % 2 + 2

    for y in range(green_center_y, green_center_y + green_height):
        for x in range(green_center_x, green_center_x + green_width):
            if hole_grid.has(Vector2(x, y)):
                hole_grid[Vector2(x, y)].terrain_type = Square.TerrainType.GREEN

    # Random Fairway Path Generation (from tee box to green)
    var current_fairway_x = tee_box_center_x
    var current_fairway_y = grid_height - 3
    while current_fairway_y > green_center_y + green_height:
        # Randomly adjust fairway x, ensuring it stays within bounds
        var x_offset = randi() % 3 - 1 # -1, 0, or 1
        current_fairway_x = clamp(current_fairway_x + x_offset, 1, grid_width - 2)

        # Mark fairway squares (2 wide)
        for x_val in range(current_fairway_x - 1, current_fairway_x + 1):
            if hole_grid.has(Vector2(x_val, current_fairway_y)):
                hole_grid[Vector2(x_val, current_fairway_y)].terrain_type = Square.TerrainType.FAIRWAY
        current_fairway_y -= 1

    # Bunkers near green
    for y in range(green_center_y - 2, green_center_y + green_height + 2):
        for x in range(green_center_x - 2, green_center_x + green_width + 2):
            if hole_grid.has(Vector2(x, y)):
                var square = hole_grid[Vector2(x, y)]
                if square.terrain_type == Square.TerrainType.ROUGH and randf() < 0.4:
                    square.terrain_type = Square.TerrainType.SAND

    # Trees
    for y in range(grid_height):
        for x in range(grid_width):
            var square = hole_grid[Vector2(x, y)]
            if square.terrain_type == Square.TerrainType.ROUGH and randf() < 0.1:
                square.terrain_type = Square.TerrainType.TREE
            elif square.terrain_type == Square.TerrainType.FAIRWAY and randf() < 0.05:
                square.terrain_type = Square.TerrainType.TREE

    # Set start and hole positions
    start_square = hole_grid[Vector2(tee_box_center_x, grid_height - 1)] # Bottom-most square
    var hole_x = green_center_x + randi() % green_width
    var hole_y = green_center_y + randi() % green_height
    hole_square = hole_grid[Vector2(hole_x, hole_y)] # Random position on the green
    current_ball_square = start_square

    # NOW animate the transition with the split-flap effect
    await _animate_all_squares_transition(hole_grid)

    _update_ball_position_display()

func _update_ball_position_display() -> void:
    if is_instance_valid(current_ball_square):
        var square_button = square_buttons[Vector2(current_ball_square.x, current_ball_square.y)]
        var button_global_position = square_button.get_global_position()
        var button_center_global = button_global_position + square_button.size / 2
        if is_instance_valid(ball_instance):
            ball_instance.global_position = button_center_global

func _display_clubs() -> void:
    # Clear existing club buttons from the container
    for child in club_hand_container.get_children():
        if child is Button:
            child.queue_free()

    for i in range(player_clubs.size()):
        var club = player_clubs[i]
        var club_button = Button.new()
        club_button.name = "ClubButton" + str(i)
        club_button.text = club.emoji + " " + club.name + "\nDist: " + str(club.max_distance)
        # Find max deviation for display
        var max_dev = 0
        if club.accuracy.has(club.max_distance):
            var deviations = club.accuracy[club.max_distance]
            for dev in deviations:
                max_dev = max(max_dev, abs(dev))
        club_button.text += "\nAcc: +/-" + str(max_dev)

        club_button.set_custom_minimum_size(Vector2(100, 70))
        club_hand_container.add_child(club_button)
        club_button.connect("pressed", Callable(self, "_on_club_button_pressed").bind(club, club_button))

func _clear_highlights() -> void:
    for y in range(grid_height):
        for x in range(grid_width):
            var square = hole_grid[Vector2(x, y)]
            var square_button = square_buttons[Vector2(x,y)]
            var stylebox_normal = square_button.get_theme_stylebox("normal") as StyleBoxFlat

            # Explicitly restore hole color
            if square.x == hole_square.x and square.y == hole_square.y:
                stylebox_normal.bg_color = COLOR_HOLE
            # Skip the ball position
            elif square.x == current_ball_square.x and square.y == current_ball_square.y:
                pass # Ball position is handled by ball sprite
            # Restore terrain colors for all other squares
            else:
                match square.terrain_type:
                    Square.TerrainType.FAIRWAY:
                        stylebox_normal.bg_color = COLOR_FAIRWAY
                    Square.TerrainType.ROUGH:
                        stylebox_normal.bg_color = COLOR_ROUGH
                    Square.TerrainType.SAND:
                        stylebox_normal.bg_color = COLOR_SAND
                    Square.TerrainType.GREEN:
                        stylebox_normal.bg_color = COLOR_GREEN
                    Square.TerrainType.TREE:
                        stylebox_normal.bg_color = COLOR_TREE
                    Square.TerrainType.TEEBOX:
                        stylebox_normal.bg_color = COLOR_TEEBOX
    _update_ball_position_display() # Ensure ball and hole are correctly displayed

func _highlight_squares(club: Club) -> void:
    _clear_highlights() # Start with a clean slate

    var modified_max_distance = club.max_distance
    var is_wood = "Wood" in club.name or "Driver" in club.name

    # Apply terrain penalty with Wisdom modifier
    var terrain_penalty = _calculate_terrain_penalty(current_ball_square.terrain_type, is_wood)
    modified_max_distance -= terrain_penalty

    for y_iter in range(grid_height):
        for x_iter in range(grid_width):
            var square = _get_square_at_grid_coords(x_iter, y_iter)
            if square:
                if is_wood and is_line_of_sight_blocked(current_ball_square, square):
                    continue

                var distance = _get_distance(current_ball_square, square)
                if distance == modified_max_distance:
                    var square_button = square_buttons[Vector2(square.x, square.y)]
                    if square_button:
                        var stylebox_normal = square_button.get_theme_stylebox("normal") as StyleBoxFlat
                        stylebox_normal.bg_color = COLOR_PLAYABLE # Playable square
                elif distance == modified_max_distance + 1:
                    var square_button = square_buttons[Vector2(square.x, square.y)]
                    if square_button:
                        var stylebox_normal = square_button.get_theme_stylebox("normal") as StyleBoxFlat
                        stylebox_normal.bg_color = COLOR_PLAYABLE.lerp(COLOR_VARIANCE, 0.5) # Power shot square

func is_line_of_sight_blocked(from_square: Square, to_square: Square) -> bool:
    var x0 = from_square.x
    var y0 = from_square.y
    var x1 = to_square.x
    var y1 = to_square.y

    var dx = abs(x1 - x0)
    var dy = -abs(y1 - y0)
    var sx = 1 if x0 < x1 else -1
    var sy = 1 if y0 < y1 else -1
    var err = dx + dy

    while true:
        if x0 == x1 and y0 == y1:
            break
        
        var square = _get_square_at_grid_coords(x0, y0)
        if square and square.terrain_type == Square.TerrainType.TREE:
            return true

        var e2 = 2 * err
        if e2 >= dy:
            err += dy
            x0 += sx
        if e2 <= dx:
            err += dx
            y0 += sy
    return false

func _get_power_shot_accuracy_modifier() -> int:
    var accuracy_modifier = 0
    var is_wood = "Wood" in selected_club.name or "Driver" in selected_club.name
    match current_ball_square.terrain_type:
        Square.TerrainType.ROUGH:
            accuracy_modifier += 1
            if is_wood:
                accuracy_modifier += 1
        Square.TerrainType.SAND:
            accuracy_modifier += 2
            if is_wood:
                accuracy_modifier += 2
    
    var possible_deviations = selected_club.accuracy.get(selected_club.max_distance, [0])
    if possible_deviations == [0]:
        accuracy_modifier += 1
    else:
        var max_dev = 0
        if possible_deviations.size() > 0:
            max_dev = possible_deviations.max()
        accuracy_modifier += abs(max_dev)
    return accuracy_modifier

func _on_club_button_pressed(club: Club, button: Button) -> void:
    if is_animating_transition:
        return # Don't allow club selection during transition

    if selected_club == club:
        # Deselect club
        selected_club = null
        selected_club_button = null
        button.position.y += 20 # Slide down
        _clear_highlights()
    else:
        # Deselect previously selected club if any
        if selected_club_button:
            selected_club_button.position.y += 20 # Slide down

        # Select new club
        selected_club = club
        selected_club_button = button
        button.position.y -= 20 # Slide up
        _highlight_squares(selected_club)

func _get_square_at_grid_coords(x: int, y: int) -> Square:
    if hole_grid.has(Vector2(x, y)):
        return hole_grid[Vector2(x, y)]
    return null

func _get_distance(square1: Square, square2: Square) -> int:
    # Chebyshev distance for square grid (max of dx, dy)
    return max(abs(square1.x - square2.x), abs(square1.y - square2.y))

func _on_square_mouse_entered(x: int, y: int) -> void:
    if selected_club:
        _clear_highlights()
        _highlight_squares(selected_club)

        var hovered_square = _get_square_at_grid_coords(x, y)
        if not hovered_square: return

        var is_wood = "Wood" in selected_club.name or "Driver" in selected_club.name
        if is_wood and is_line_of_sight_blocked(current_ball_square, hovered_square):
            return

        var modified_max_distance = selected_club.max_distance

        # Apply terrain penalty with Wisdom modifier
        var terrain_penalty = _calculate_terrain_penalty(current_ball_square.terrain_type, is_wood)
        modified_max_distance -= terrain_penalty

        var distance_to_hovered = _get_distance(current_ball_square, hovered_square)
        var is_power_shot = distance_to_hovered == modified_max_distance + 1

        if is_power_shot:
            var accuracy_modifier = _get_power_shot_accuracy_modifier()
            var min_dev = -accuracy_modifier
            var max_dev = accuracy_modifier

            for dev in range(min_dev, max_dev + 1):
                var direction_vector = Vector2(hovered_square.x - current_ball_square.x, hovered_square.y - current_ball_square.y).normalized()
                var perpendicular_vector = Vector2(direction_vector.y, -direction_vector.x)
                var variance_x = round(hovered_square.x + perpendicular_vector.x * dev)
                var variance_y = round(hovered_square.y + perpendicular_vector.y * dev)

                if variance_x >= 0 and variance_x < grid_width and \
                   variance_y >= 0 and variance_y < grid_height:
                    var variance_square = _get_square_at_grid_coords(variance_x, variance_y)
                    if variance_square:
                        var variance_button = square_buttons[Vector2(variance_square.x, variance_square.y)]
                        if variance_button and not (variance_square.x == hovered_square.x and variance_square.y == hovered_square.y):
                            var stylebox_normal = variance_button.get_theme_stylebox("normal") as StyleBoxFlat
                            stylebox_normal.bg_color = COLOR_VARIANCE

func _on_square_mouse_exited(_x: int, _y: int) -> void:
    if selected_club:
        _clear_highlights() # Clear all highlights
        _highlight_squares(selected_club) # Re-apply general playable area highlights

func _on_square_pressed(x: int, y: int) -> void:
    if is_animating_transition:
        return # Don't allow shots during transition

    if selected_club:
        var pressed_square = _get_square_at_grid_coords(x, y)
        if not pressed_square: return

        var is_wood = "Wood" in selected_club.name or "Driver" in selected_club.name
        if is_wood and is_line_of_sight_blocked(current_ball_square, pressed_square):
            return

        var modified_max_distance = selected_club.max_distance

        # Apply terrain penalty with Wisdom modifier
        var terrain_penalty = _calculate_terrain_penalty(current_ball_square.terrain_type, is_wood)
        modified_max_distance -= terrain_penalty

        var distance_to_pressed = _get_distance(current_ball_square, pressed_square)
        var is_power_shot = distance_to_pressed == modified_max_distance + 1
        var is_normal_shot = distance_to_pressed == modified_max_distance

        if is_normal_shot or is_power_shot:
            var final_deviation = 0
            if is_power_shot:
                var accuracy_modifier = _get_power_shot_accuracy_modifier()
                final_deviation = (randi() % (2 * accuracy_modifier + 1)) - accuracy_modifier

            var direction_vector = Vector2(pressed_square.x - current_ball_square.x, pressed_square.y - current_ball_square.y).normalized()
            var perpendicular_vector = Vector2(direction_vector.y, -direction_vector.x)
            var final_x = round(pressed_square.x + perpendicular_vector.x * final_deviation)
            var final_y = round(pressed_square.y + perpendicular_vector.y * final_deviation)

            var landing_square = _get_square_at_grid_coords(final_x, final_y)
            if landing_square:
                var current_square_button = square_buttons[Vector2(current_ball_square.x, current_ball_square.y)]
                var start_position_global = current_square_button.get_global_position() + current_square_button.size / 2

                var target_square_button = square_buttons[Vector2(landing_square.x, landing_square.y)]
                var end_position_global = target_square_button.get_global_position() + target_square_button.size / 2

                await ball_instance.animate_shot(start_position_global, end_position_global)
                current_ball_square = landing_square
                _update_ball_position_display()
                print("Ball moved to: ", landing_square.x, ", ", landing_square.y)
                
                if current_ball_square == hole_square:
                    print("Ball in hole! Generating new hole...")
                    # Play reward sound
                    if reward_sound_player.stream:
                        reward_sound_player.play()
                    # Wait for reward sound to finish
                    await get_tree().create_timer(0.3).timeout
                    _generate_new_hole()
                    return
                
                # Remove used club from hand
                var club_index = player_clubs.find(selected_club)
                if club_index != -1:
                    player_clubs.remove_at(club_index)
                    var used_club_button = club_hand_container.get_child(club_index)
                    if used_club_button:
                        used_club_button.queue_free()
                
                # Deselect club and clear highlights
                selected_club = null
                _clear_highlights()

func _get_accuracy_array(accuracy: int) -> Array:
    var array = []
    for i in range(-accuracy, accuracy + 1):
        array.append(i)
    return array

func _generate_new_club_set() -> void:
    player_clubs.clear()
    # Woods
    player_clubs.append(Club.new("1-Wood", "⛳", 7, {7: _get_accuracy_array(3)}))
    player_clubs.append(Club.new("3-Wood", "⛳", 5, {5: _get_accuracy_array(3)}))
    player_clubs.append(Club.new("5-Wood", "⛳", 4, {4: _get_accuracy_array(2)}))
    # Irons
    player_clubs.append(Club.new("4-Iron", "⛳", 4, {4: _get_accuracy_array(2)}))
    player_clubs.append(Club.new("5-Iron", "⛳", 4, {4: _get_accuracy_array(1)}))
    player_clubs.append(Club.new("6-Iron", "⛳", 3, {3: _get_accuracy_array(1)}))
    # Wedge
    player_clubs.append(Club.new("Wedge", "⛳", 2, {2: _get_accuracy_array(1)}))
    # Putter
    player_clubs.append(Club.new("Putter", "⛳", 1, {1: _get_accuracy_array(1)}))

func _get_random_terrain_color() -> Color:
    # Removed COLOR_TEEBOX (red) as it's too bright for the flip effect
    var colors = [COLOR_FAIRWAY, COLOR_ROUGH, COLOR_SAND, COLOR_GREEN, COLOR_TREE]
    return colors[randi() % colors.size()]

func _animate_square_flip(square_button: Button, final_color: Color, delay: float, _play_sound: bool = true) -> void:
    # Wait for the staggered delay
    await get_tree().create_timer(delay).timeout

    var stylebox = square_button.get_theme_stylebox("normal") as StyleBoxFlat
    var flip_count = randi() % 10 + 15 # Random number of flips between 15-25
    var flip_duration = 0.05 # Time between flips

    # Flip through random colors
    for i in range(flip_count):
        stylebox.bg_color = _get_random_terrain_color()

        # Slight scale animation for flip effect
        var tween = create_tween()
        tween.tween_property(square_button, "scale", Vector2(0.9, 1.1), flip_duration / 2)
        tween.tween_property(square_button, "scale", Vector2(1.0, 1.0), flip_duration / 2)

        # Slow down the flips as we approach the final color
        var slowdown_factor = 1.0 + (float(i) / float(flip_count)) * 2.0
        await get_tree().create_timer(flip_duration * slowdown_factor).timeout

    # Final flip to the actual color
    stylebox.bg_color = final_color

    var final_tween = create_tween()
    final_tween.tween_property(square_button, "scale", Vector2(0.9, 1.1), 0.05)
    final_tween.tween_property(square_button, "scale", Vector2(1.0, 1.0), 0.05)
    await final_tween.finished

func _animate_all_squares_transition(new_grid: Dictionary) -> void:
    is_animating_transition = true

    # Group squares by distance from hole (radial animation)
    var squares_by_distance: Dictionary = {}
    var max_distance = 0

    for pos in new_grid.keys():
        var square = new_grid[pos]
        var distance = _get_distance(square, hole_square)

        if not squares_by_distance.has(distance):
            squares_by_distance[distance] = []
        squares_by_distance[distance].append(pos)
        max_distance = max(max_distance, distance)

    # Animate each ring outward from the hole
    var flip_time_per_ring = 0.15  # Faster rings

    for dist in range(max_distance + 1):
        if not squares_by_distance.has(dist):
            continue

        # Play sound for each ring
        if flip_sound_player.stream:
            flip_sound_player.play()

        # Animate all squares at this distance
        for pos in squares_by_distance[dist]:
            var square = new_grid[pos]
            var square_button = square_buttons[pos]

            # Determine final color based on terrain type
            var final_color: Color
            if square.x == hole_square.x and square.y == hole_square.y:
                final_color = COLOR_HOLE
            else:
                match square.terrain_type:
                    Square.TerrainType.FAIRWAY:
                        final_color = COLOR_FAIRWAY
                    Square.TerrainType.ROUGH:
                        final_color = COLOR_ROUGH
                    Square.TerrainType.SAND:
                        final_color = COLOR_SAND
                    Square.TerrainType.GREEN:
                        final_color = COLOR_GREEN
                    Square.TerrainType.TREE:
                        final_color = COLOR_TREE
                    Square.TerrainType.TEEBOX:
                        final_color = COLOR_TEEBOX
                    _:
                        final_color = COLOR_ROUGH

            # No delay for radial effect
            _animate_square_flip(square_button, final_color, 0.0, false)

        # Wait for this ring to complete before starting the next
        await get_tree().create_timer(flip_time_per_ring).timeout

    # Small buffer to ensure all animations complete
    await get_tree().create_timer(0.3).timeout

    is_animating_transition = false

func _generate_new_hole() -> void:
    # Generate new grid data WITHOUT updating the display
    var new_grid = {}

    # Initialize grid with rough
    for y in range(grid_height):
        for x in range(grid_width):
            var square = Square.new(x, y, Square.TerrainType.ROUGH)
            new_grid[Vector2(x, y)] = square

    # Define Tee Box
    var tee_box_center_x = randi() % (grid_width - 4) + 2
    new_grid[Vector2(tee_box_center_x, grid_height - 1)].terrain_type = Square.TerrainType.TEEBOX

    # Random Green position
    var green_center_x = randi() % (grid_width - 8) + 4
    var green_center_y = randi() % (grid_height / 2)
    var green_width = randi() % 3 + 3
    var green_height = randi() % 2 + 2

    for y in range(green_center_y, green_center_y + green_height):
        for x in range(green_center_x, green_center_x + green_width):
            if new_grid.has(Vector2(x, y)):
                new_grid[Vector2(x, y)].terrain_type = Square.TerrainType.GREEN

    # Random Fairway Path Generation (from tee box to green)
    var current_fairway_x = tee_box_center_x
    var current_fairway_y = grid_height - 3
    while current_fairway_y > green_center_y + green_height:
        var x_offset = randi() % 3 - 1
        current_fairway_x = clamp(current_fairway_x + x_offset, 1, grid_width - 2)

        for x_val in range(current_fairway_x - 1, current_fairway_x + 1):
            if new_grid.has(Vector2(x_val, current_fairway_y)):
                new_grid[Vector2(x_val, current_fairway_y)].terrain_type = Square.TerrainType.FAIRWAY
        current_fairway_y -= 1

    # Bunkers near green
    for y in range(green_center_y - 2, green_center_y + green_height + 2):
        for x in range(green_center_x - 2, green_center_x + green_width + 2):
            if new_grid.has(Vector2(x, y)):
                var square = new_grid[Vector2(x, y)]
                if square.terrain_type == Square.TerrainType.ROUGH and randf() < 0.4:
                    square.terrain_type = Square.TerrainType.SAND

    # Trees
    for y in range(grid_height):
        for x in range(grid_width):
            var square = new_grid[Vector2(x, y)]
            if square.terrain_type == Square.TerrainType.ROUGH and randf() < 0.1:
                square.terrain_type = Square.TerrainType.TREE
            elif square.terrain_type == Square.TerrainType.FAIRWAY and randf() < 0.05:
                square.terrain_type = Square.TerrainType.TREE

    # Set start and hole positions
    start_square = new_grid[Vector2(tee_box_center_x, grid_height - 1)]
    var hole_x = green_center_x + randi() % green_width
    var hole_y = green_center_y + randi() % green_height
    hole_square = new_grid[Vector2(hole_x, hole_y)]

    # NOW animate the transition with the split-flap effect
    await _animate_all_squares_transition(new_grid)

    # After animation, update the actual hole_grid
    hole_grid = new_grid
    current_ball_square = start_square

    # Generate a new hand of clubs
    _generate_new_club_set()

    # Re-display clubs
    _display_clubs()

    # Ensure ball is positioned correctly at the new start square
    _update_ball_position_display()

    # Deselect any selected club
    if selected_club:
        var prev_button = club_hand_container.find_child("ClubButton" + str(player_clubs.find(selected_club)))
        if prev_button:
            prev_button.position.y += 20 # Slide down
        selected_club = null
    _clear_highlights() # Clear any lingering highlights

func _create_legend() -> void:
    var legend_container = VBoxContainer.new()
    legend_container.name = "Legend"
    legend_container.position = Vector2(1100, 50)
    add_child(legend_container)

    legend_container.add_child(create_legend_item(COLOR_FAIRWAY, "Fairway"))
    legend_container.add_child(create_legend_item(COLOR_ROUGH, "Rough"))
    legend_container.add_child(create_legend_item(COLOR_SAND, "Sand"))
    legend_container.add_child(create_legend_item(COLOR_GREEN, "Green"))
    legend_container.add_child(create_legend_item(COLOR_TREE, "Tree"))
    legend_container.add_child(create_legend_item(COLOR_TEEBOX, "Tee Box"))
    legend_container.add_child(create_legend_item(COLOR_HOLE, "Hole"))
    legend_container.add_child(create_legend_item(COLOR_PLAYABLE, "Playable"))
    legend_container.add_child(create_legend_item(COLOR_PLAYABLE.lerp(COLOR_VARIANCE, 0.5), "Power Shot"))
    legend_container.add_child(create_legend_item(COLOR_VARIANCE, "Variance"))

    var explanation = Label.new()
    explanation.text = "\nWoods can't be hit over trees."
    legend_container.add_child(explanation)

func create_legend_item(color: Color, text: String) -> HBoxContainer:
    var item = HBoxContainer.new()
    var color_rect = ColorRect.new()
    color_rect.color = color
    color_rect.custom_minimum_size = Vector2(20, 20)
    item.add_child(color_rect)

    var label = Label.new()
    label.text = " " + text
    item.add_child(label)

    return item
