// Swaps the knight sheet's tunic and plume colours so both players stay distinguishable.
// Source colours were measured from res://assets/sprites/knight.png (docs/ASSET_CATALOG.md).
shader_type canvas_item;

uniform vec4 source_tunic : source_color = vec4(0.0392, 0.4392, 0.1882, 1.0); // #0a7030
uniform vec4 target_tunic : source_color = vec4(0.0392, 0.4392, 0.1882, 1.0);
uniform vec4 source_plume : source_color = vec4(0.8235, 0.1255, 0.1725, 1.0); // #d2202c
uniform vec4 target_plume : source_color = vec4(0.8235, 0.1255, 0.1725, 1.0);

const float TOLERANCE = 0.02;

varying vec4 vertex_modulate;

void vertex() {
	vertex_modulate = COLOR;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec3 rgb = tex.rgb;
	if (distance(rgb, source_tunic.rgb) < TOLERANCE) {
		rgb = target_tunic.rgb;
	} else if (distance(rgb, source_plume.rgb) < TOLERANCE) {
		rgb = target_plume.rgb;
	}
	COLOR = vec4(rgb, tex.a) * vertex_modulate;
}
