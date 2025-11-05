extends Node2D

@onready var ball_sprite: ColorRect = $BallSprite
@onready var ball_shadow: ColorRect = $BallShadow
@onready var dust_particles: CPUParticles2D = $DustParticles
@onready var grass_particles: CPUParticles2D = $GrassParticles

func _ready():
	pass # All nodes are @onready, so no need for manual assignment here

func animate_shot(start_pos: Vector2, end_pos: Vector2):
	# Set initial ball and shadow positions
	global_position = start_pos
	ball_sprite.position = Vector2.ZERO # Relative to Ball Node
	ball_shadow.position = Vector2(2, 2) # Relative to Ball Node
	ball_sprite.scale = Vector2(1, 1)
	ball_shadow.scale = Vector2(1, 1)

	# Emit dust particles at the start
	dust_particles.global_position = start_pos
	dust_particles.emitting = true

	var tween = create_tween().set_parallel()
	var travel_time = 0.5
	var half_time = travel_time / 2

	# Animate ball position (arc)
	var peak_height = 50 # How high the ball goes
	var mid_pos = (start_pos + end_pos) / 2
	var peak_pos = mid_pos - Vector2(0, peak_height)

	# Position
	tween.tween_property(self, "global_position", peak_pos, half_time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(self, "global_position", end_pos, half_time).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD).set_delay(half_time)

	# Ball scale
	tween.tween_property(ball_sprite, "scale", Vector2(1.5, 1.5), half_time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(ball_sprite, "scale", Vector2(1, 1), half_time).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD).set_delay(half_time)

	# Shadow scale
	tween.tween_property(ball_shadow, "scale", Vector2(1.5, 1.5), half_time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(ball_shadow, "scale", Vector2(1, 1), half_time).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD).set_delay(half_time)

	# Shadow position
	tween.tween_property(ball_shadow, "position", Vector2(10, 10), half_time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(ball_shadow, "position", Vector2(2, 2), half_time).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD).set_delay(half_time)

	await tween.finished

	# Emit grass particles at the end
	grass_particles.global_position = end_pos
	grass_particles.emitting = true
