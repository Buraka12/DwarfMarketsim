shader_type canvas_item; // ARTIK SPATIAL (3D) DEĞİL, EKRAN FİLTRESİ (2D)

// filter_nearest PSX pikselleri için zorunludur
uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform float pixel_size : hint_range(0.0, 16.0, 1.0) = 2.0;
uniform float levels : hint_range(0.0, 100.0, 1.0) = 24.0;
uniform vec2 gamma = vec2(1.0, 1.0);

void fragment() {
	vec2 tex_size = vec2(textureSize(screen_texture, 0));
	
	// Piksel boyutunu güvenli hale getir
	float p_size = max(pixel_size * 2.0, 1.0);
	vec2 pixel_count = tex_size / p_size;
	vec2 pixelated_uv = floor(SCREEN_UV * pixel_count) / pixel_count; 
	
	// Ekrandaki o anki renkleri (Glow dahil her şeyi) al
	vec4 color = texture(screen_texture, pixelated_uv);
	
	// --- HDR (BLOOM) KORUMASI ---
	float max_color = max(color.r, max(color.g, color.b));
	
	// Lamba gibi ışık saçan (Emission) objelere dokunmuyoruz.
	if (max_color <= 1.0) {
		color.rgb = pow(color.rgb, vec3(gamma.x));
		
		float grayscale = max_color; 
		
		if (grayscale > 0.0001) {
			float lower = floor(grayscale * levels) / levels;
			float higher = ceil(grayscale * levels) / levels;
			
			float lower_diff = abs(lower - grayscale);
			float higher_diff = abs(higher - grayscale);
			
			float level = lower_diff < higher_diff ? lower : higher;
			float adjustment = level / grayscale;
			
			color.rgb *= adjustment;
		}
		
		color.rgb = pow(color.rgb, vec3(gamma.y));
	}
	
	// Final rengi ekrana bas
	COLOR = color;
}