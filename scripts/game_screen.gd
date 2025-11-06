extends Control

const Square = preload("res://scripts/square.gd")
const BallScene = preload("res://ball.tscn")

const COLOR_FAIRWAY = Color(0.4, 0.8, 0.4)
const COLOR_ROUGH = Color(0.2, 0.6, 0.2)
const COLOR_SAND = Color(0.9, 0.9, 0.6)
const COLOR_GREEN = Color(0.3, 0.7, 0.3)
const COLOR_HOLE = Color(0.1, 0.1, 0.1)
const COLOR_PLAYABLE = Color(0.6, 0.8, 1.0)
const COLOR_VARIANCE = Color(1.0, 0.7, 0.4)

var player_clubs: Array
var hole_grid: Dictionary # Stores Square objects, keyed by Vector2(x, y)
var grid_width: int = 20
var grid_height: int = 20

var start_square: Square
var hole_square: Square
var current_ball_square: Square
var selected_club: Club = null
var selected_club_button: Button = null

var ball_instance: Node2D # Reference to the instantiated Ball scene
var square_buttons: Dictionary = {}

@onready var hex_grid_container = $HexGridContainer # Renamed to square_grid_container in scene
@onready var club_hand_container = $ClubHandContainer

func _ready():
    print("Game Screen Loaded!")
    if player_clubs:
        print("Player Clubs: ", player_clubs)
    _generate_hole()
    _display_clubs()

    # Instantiate Ball scene
    ball_instance = BallScene.instantiate()
    hex_grid_container.add_child(ball_instance)
    ball_instance.visible = true # Make the ball visible initially
    print("Ball scene instantiated and added. ball_instance: ", ball_instance)

    _update_ball_position_display()

func set_player_clubs(clubs: Array):
    player_clubs = clubs

func _generate_hole():
    hole_grid = {}
    square_buttons = {}
    # Initialize grid with rough and create buttons
    for y in range(grid_height):
        for x in range(grid_width):
            var square = Square.new(x, y, Square.TerrainType.ROUGH)
            hole_grid[Vector2(x, y)] = square

            var square_button = Button.new()
            square_buttons[Vector2(x,y)] = square_button
            var stylebox = StyleBoxFlat.new()
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

    # Define Tee Box (last 2 rows)
    var tee_box_center_x = randi() % (grid_width - 4) + 2 # Random x for tee box
    for y in range(grid_height - 2, grid_height): # Last two rows
        for x_val in range(tee_box_center_x - 2, tee_box_center_x + 3):
            if hole_grid.has(Vector2(x_val, y)):
                hole_grid[Vector2(x_val, y)].terrain_type = Square.TerrainType.FAIRWAY # Tee box is part of fairway

    # Random Fairway Path Generation (from bottom to top)
    var current_fairway_x = tee_box_center_x # Start fairway from tee box center
    for y in range(grid_height - 3, 1, -1): # Iterate from bottom-ish to top-ish
        # Randomly adjust fairway x, ensuring it stays within bounds
        var x_offset = randi() % 3 - 1 # -1, 0, or 1
        current_fairway_x = clamp(current_fairway_x + x_offset, 1, grid_width - 2)

        # Mark fairway squares (3 wide)
        for x_val in range(current_fairway_x - 1, current_fairway_x + 2):
            if hole_grid.has(Vector2(x_val, y)):
                hole_grid[Vector2(x_val, y)].terrain_type = Square.TerrainType.FAIRWAY

    # Add sand around the fairway
    for y in range(grid_height):
        for x in range(grid_width):
            var square = hole_grid[Vector2(x, y)]
            if square.terrain_type == Square.TerrainType.ROUGH:
                # Check if adjacent to fairway
                var is_adjacent_to_fairway = false
                for dy in range(-1, 2):
                    for dx in range(-1, 2):
                        if dx == 0 and dy == 0: continue
                        var neighbor_pos = Vector2(x + dx, y + dy)
                        if hole_grid.has(neighbor_pos):
                            var neighbor_square = hole_grid[neighbor_pos]
                            if neighbor_square.terrain_type == Square.TerrainType.FAIRWAY:
                                is_adjacent_to_fairway = true
                                break
                    if is_adjacent_to_fairway: break
                
                if is_adjacent_to_fairway and randf() < 0.3: # 30% chance to become sand
                    square.terrain_type = Square.TerrainType.SAND

    # Create green at the top of the screen (first 3 rows)
    var green_center_x = current_fairway_x # Use the last fairway x as green center
    for y in range(3): # First three rows
        for x_val in range(green_center_x - 2, green_center_x + 3):
            if hole_grid.has(Vector2(x_val, y)):
                hole_grid[Vector2(x_val, y)].terrain_type = Square.TerrainType.GREEN

    # Set start and hole positions
    start_square = hole_grid[Vector2(tee_box_center_x, grid_height - 1)] # Bottom-most square
    hole_square = hole_grid[Vector2(green_center_x, 0)] # Top-most square
    current_ball_square = start_square

    # Update button colors based on terrain
    for y in range(grid_height):
        for x in range(grid_width):
            var square = hole_grid[Vector2(x, y)]
            var square_button = square_buttons[Vector2(x,y)]
            var stylebox_normal = square_button.get_theme_stylebox("normal") as StyleBoxFlat
            match square.terrain_type:
                Square.TerrainType.FAIRWAY:
                    stylebox_normal.bg_color = COLOR_FAIRWAY
                Square.TerrainType.ROUGH:
                    stylebox_normal.bg_color = COLOR_ROUGH
                Square.TerrainType.SAND:
                    stylebox_normal.bg_color = COLOR_SAND
                Square.TerrainType.GREEN:
                    stylebox_normal.bg_color = COLOR_GREEN

    # Mark hole position with a different color
    var hole_button = square_buttons[Vector2(hole_square.x, hole_square.y)]
    var hole_stylebox = hole_button.get_theme_stylebox("normal") as StyleBoxFlat
    hole_stylebox.bg_color = COLOR_HOLE

    _update_ball_position_display()

func _update_ball_position_display():
    if is_instance_valid(current_ball_square):
        var square_button = square_buttons[Vector2(current_ball_square.x, current_ball_square.y)]
        var button_global_position = square_button.get_global_position()
        var button_center_global = button_global_position + square_button.size / 2
        if is_instance_valid(ball_instance):
            ball_instance.global_position = button_center_global

func _display_clubs():
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

func _clear_highlights():
    for y in range(grid_height):
        for x in range(grid_width):
            var square = hole_grid[Vector2(x, y)]
            var square_button = square_buttons[Vector2(x,y)]
            var stylebox_normal = square_button.get_theme_stylebox("normal") as StyleBoxFlat
            # Only revert if it's not the ball or the hole
            if not (square.x == current_ball_square.x and square.y == current_ball_square.y) and \
               not (square.x == hole_square.x and square.y == hole_square.y):
                match square.terrain_type:
                    Square.TerrainType.FAIRWAY:
                        stylebox_normal.bg_color = COLOR_FAIRWAY
                    Square.TerrainType.ROUGH:
                        stylebox_normal.bg_color = COLOR_ROUGH
                    Square.TerrainType.SAND:
                        stylebox_normal.bg_color = COLOR_SAND
                    Square.TerrainType.GREEN:
                        stylebox_normal.bg_color = COLOR_GREEN
    _update_ball_position_display() # Ensure ball and hole are correctly displayed

func _highlight_squares(club: Club):
    _clear_highlights() # Start with a clean slate

    var modified_max_distance = club.max_distance
    var is_wood = "Wood" in club.name or "Driver" in club.name

    match current_ball_square.terrain_type:
        Square.TerrainType.ROUGH:
            modified_max_distance -= 1
            if is_wood:
                modified_max_distance -= 1
        Square.TerrainType.SAND:
            modified_max_distance -= 1
            if is_wood:
                modified_max_distance -= 2

    for y_iter in range(grid_height):
        for x_iter in range(grid_width):
            var square = _get_square_at_grid_coords(x_iter, y_iter)
            if square:
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

func _get_power_shot_accuracy_modifier():
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

func _on_club_button_pressed(club: Club, button: Button):
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

func _on_square_mouse_entered(x: int, y: int):
    if selected_club:
        _clear_highlights()
        _highlight_squares(selected_club)

        var hovered_square = _get_square_at_grid_coords(x, y)
        if not hovered_square: return

        var modified_max_distance = selected_club.max_distance
        var is_wood = "Wood" in selected_club.name or "Driver" in selected_club.name

        match current_ball_square.terrain_type:
            Square.TerrainType.ROUGH:
                modified_max_distance -= 1
                if is_wood:
                    modified_max_distance -= 1
            Square.TerrainType.SAND:
                modified_max_distance -= 1
                if is_wood:
                    modified_max_distance -= 2

        var distance_to_hovered = _get_distance(current_ball_square, hovered_square)
        var is_power_shot = distance_to_hovered == modified_max_distance + 1

        if is_power_shot:
            var accuracy_modifier = _get_power_shot_accuracy_modifier()
            var min_dev = -accuracy_modifier
            var max_dev = accuracy_modifier

            for dev_x in range(min_dev, max_dev + 1):
                var variance_x = hovered_square.x + dev_x
                var variance_y = hovered_square.y # Assuming deviation is only horizontal for now

                if variance_x >= 0 and variance_x < grid_width and \
                   variance_y >= 0 and variance_y < grid_height:
                    var variance_square = _get_square_at_grid_coords(variance_x, variance_y)
                    if variance_square:
                        var variance_button = square_buttons[Vector2(variance_square.x, variance_square.y)]
                        if variance_button and not (variance_square.x == hovered_square.x and variance_square.y == hovered_square.y):
                            var stylebox_normal = variance_button.get_theme_stylebox("normal") as StyleBoxFlat
                            stylebox_normal.bg_color = COLOR_VARIANCE

func _on_square_mouse_exited(x: int, y: int):

    if selected_club:

        _clear_highlights() # Clear all highlights

        _highlight_squares(selected_club) # Re-apply general playable area highlights

func _on_square_pressed(x: int, y: int):
    if selected_club:
        var pressed_square = _get_square_at_grid_coords(x, y)
        if not pressed_square: return

        var modified_max_distance = selected_club.max_distance
        var is_wood = "Wood" in selected_club.name or "Driver" in selected_club.name

        match current_ball_square.terrain_type:
            Square.TerrainType.ROUGH:
                modified_max_distance -= 1
                if is_wood:
                    modified_max_distance -= 1
            Square.TerrainType.SAND:
                modified_max_distance -= 1
                if is_wood:
                    modified_max_distance -= 2

        var distance_to_pressed = _get_distance(current_ball_square, pressed_square)
        var is_power_shot = distance_to_pressed == modified_max_distance + 1
        var is_normal_shot = distance_to_pressed == modified_max_distance

        if is_normal_shot or is_power_shot:
            var final_deviation = 0
            if is_power_shot:
                var accuracy_modifier = _get_power_shot_accuracy_modifier()
                final_deviation = (randi() % (2 * accuracy_modifier + 1)) - accuracy_modifier

            var final_x = clamp(pressed_square.x + final_deviation, 0, grid_width - 1)
            var final_y = pressed_square.y # For now, deviation is only horizontal

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

func _generate_new_club_set():
    player_clubs.clear()
    player_clubs.append(Club.new("Driver", "⛳", 5, {5: [-2, -1, 0, 1, 2]}))
    player_clubs.append(Club.new("3-Wood", "⛳", 4, {4: [-1, 0, 1]}))
    player_clubs.append(Club.new("5-Wood", "⛳", 3, {3: [-1, 0, 1]}))
    player_clubs.append(Club.new("4-Iron", "⛳", 3, {3: [0]}))
    player_clubs.append(Club.new("5-Iron", "⛳", 2, {2: [0]}))
    player_clubs.append(Club.new("6-Iron", "⛳", 2, {2: [0]}))
    player_clubs.append(Club.new("7-Iron", "⛳", 2, {2: [-1, 0, 1]}))
    player_clubs.append(Club.new("8-Iron", "⛳", 1, {1: [0]}))
    player_clubs.append(Club.new("9-Iron", "⛳", 1, {1: [0]}))
    player_clubs.append(Club.new("Putter", "⛳", 1, {1: [0]}))

func _generate_new_hole():
    # Clear existing grid buttons from the container
    for child in hex_grid_container.get_children():
        if child is Button:
            child.queue_free()
    
    # Club buttons are cleared in _display_clubs()

    # Generate a new hand of clubs (placeholder for actual game logic)
    _generate_new_club_set()
    
    # Regenerate the hole
    _generate_hole()

    hex_grid_container.move_child(ball_instance, -1)
    
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
