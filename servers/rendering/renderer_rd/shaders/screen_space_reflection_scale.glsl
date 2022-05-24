#[compute]

#version 450

#VERSION_DEFINES

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(set = 0, binding = 0) uniform sampler2D source_ssr;
layout(set = 1, binding = 0) uniform sampler2D source_depth;
layout(set = 1, binding = 1) uniform sampler2D source_normal;
layout(rgba16f, set = 2, binding = 0) uniform restrict writeonly image2D dest_ssr;
layout(r32f, set = 3, binding = 0) uniform restrict writeonly image2D dest_depth;
layout(rgba8, set = 3, binding = 1) uniform restrict writeonly image2D dest_normal;

layout(push_constant, std430) uniform Params {
	ivec2 screen_size;
	float camera_z_near;
	float camera_z_far;

	bool orthogonal;
	bool filtered;
	uint pad[2];
}
params;

void main() {
	// Pixel being shaded
	ivec2 ssC = ivec2(gl_GlobalInvocationID.xy);

	if (any(greaterThanEqual(ssC, params.screen_size))) { //too large, do nothing
		return;
	}
	//do not filter, SSR will generate arctifacts if this is done

	float divisor = 0.0;
	vec4 color;
	float depth;
	vec4 normal;

	if (params.filtered) {
		color = vec4(0.0);
		depth = 0.0;
		normal = vec4(0.0);

		for (int i = 0; i < 4; i++) {
			ivec2 ofs = ssC << 1;
			if (bool(i & 1)) {
				ofs.x += 1;
			}
			if (bool(i & 2)) {
				ofs.y += 1;
			}
			color += texelFetch(source_ssr, ofs, 0);
			float d = texelFetch(source_depth, ofs, 0).r;
			vec4 nr = texelFetch(source_normal, ofs, 0);
			normal.xyz += nr.xyz * 2.0 - 1.0;
			normal.w += nr.w;

			d = d * 2.0 - 1.0;
			if (params.orthogonal) {
				d = ((d + (params.camera_z_far + params.camera_z_near) / (params.camera_z_far - params.camera_z_near)) * (params.camera_z_far - params.camera_z_near)) / 2.0;
			} else {
				d = 2.0 * params.camera_z_near * params.camera_z_far / (params.camera_z_far + params.camera_z_near - d * (params.camera_z_far - params.camera_z_near));
			}
			depth += -d;
		}

		color /= 4.0;
		depth /= 4.0;
		normal.xyz = normalize(normal.xyz / 4.0) * 0.5 + 0.5;
		normal.w /= 4.0;
	} else {
		color = texelFetch(source_ssr, ssC << 1, 0);
		depth = texelFetch(source_depth, ssC << 1, 0).r;
		normal = texelFetch(source_normal, ssC << 1, 0);

		depth = depth * 2.0 - 1.0;
		if (params.orthogonal) {
			depth = ((depth + (params.camera_z_far + params.camera_z_near) / (params.camera_z_far - params.camera_z_near)) * (params.camera_z_far - params.camera_z_near)) / 2.0;
		} else {
			depth = 2.0 * params.camera_z_near * params.camera_z_far / (params.camera_z_far + params.camera_z_near - depth * (params.camera_z_far - params.camera_z_near));
		}
		depth = -depth;
	}

	imageStore(dest_ssr, ssC, color);
	imageStore(dest_depth, ssC, vec4(depth));
	imageStore(dest_normal, ssC, normal);
}