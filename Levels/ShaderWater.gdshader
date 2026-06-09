shader_type canvas_item;

// Uniforms allow you to control these values from the Godot Inspector
uniform float wave_speed : hint_range(0.5, 5.0) = 4.0;
uniform float wave_amplitude : hint_range(1.0, 20.0) = 1.0;
uniform float wave_frequency : hint_range(0.01, 0.1) = 0.02;

void vertex() {
	// Calculate the wave displacement using a sine function
	// VERTEX.x adds a wave offset across the screen so it looks like a moving wave
	float wave = sin(TIME * wave_speed + VERTEX.x * wave_frequency) * wave_amplitude;
	
	// Apply the displacement to the Y axis (up and down)
	VERTEX.y += wave;
}