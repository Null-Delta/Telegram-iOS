//
//  liquid-ass.metal
//  liquid-ass
//
//  Created by Rustam Khakhuk on 05.12.2025.
//

#include <metal_stdlib>
using namespace metal;

struct VertexIn {
    float2 position [[attribute(0)]];
    float2 texCoord [[attribute(1)]];
};

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
};

struct GlassUniforms {
    float radius;
    float aspectRatio;
    float2 uvOffset;
    float2 uvScale;
    float p;
    float height;
    float max_edge_blur;
};

struct PixelInfo {
    float2 refraction_vector;
};

vertex VertexOut glass_vertex(VertexIn in [[stage_in]]) {
    VertexOut out;
    out.position = float4(in.position, 0.0, 1.0);
    out.texCoord = in.texCoord;
    return out;
}

float refraction_value(float alpha) {
    float k = 1;
    if (alpha == 700) {
        return 2.0 * k;
    }

    if (alpha == 546.1) {
        return 1.8 * k;
    }

    if (alpha == 435.8) {
        return 1.6 * k;
    }

    return 1;
}

float angle_betweeen_lines(float2 line1, float2 line2) {
    return acos((line1.x * line2.x + line1.y * line2.y) / (length(line1) * length(line2)));
}

float glass_shape(float t) {
    if (t <= 0) { return 0; }
    return pow(1 - pow(1 - t, 4), float(1.0 / 4.0));
}

float shape_differ(float t) {
    if (t <= 0) { return 100; }

    return pow(1 - t, 3) / pow(1 - pow(1 - t, 4), float(3.0 / 4.0));
}

float refraction_offset(float t, float p, float height, float alpha) {
    float2 normal = normalize(float2(-shape_differ(t), 1));
    float angle = angle_betweeen_lines(float2(0, 1), normal);
    float refraction_k = refraction_value(alpha);
    float refraction_angle = asin(sin(angle) / refraction_k);

    float2 direction = normal * float2x2(
        cos(refraction_angle), sin(refraction_angle),
        -sin(refraction_angle), cos(refraction_angle)
    );

    if (direction.y == 0) {
        return 0;
    }

    return (direction.x * ((glass_shape(t) * p + height) / -direction.y));
}

PixelInfo normal_map_2(float2 position, float2 center, float radius, float p, float height, float alpha) {
    float2 newCenter = center + normalize(position - center) * (radius * (1 - p));
    float d = distance(position, center) / radius;

    float d2 = distance(position, newCenter) / (radius * p);
    float2 norm = -normalize(position - newCenter);


    PixelInfo info = PixelInfo();
    info.refraction_vector = (d > (1 - p)) ? norm * (refraction_offset(1 - d2, radius * p, height, alpha)) : 0;
    return info;
}

PixelInfo normal_map(float2 position, float aspectRatio, float radius, float p, float height, float alpha) {
    position *= float2(1, aspectRatio);
    int part_x = position.x < radius ? -1 : position.x > 1 - radius ? 1 : 0;
    int part_y = position.y < radius ? -1 : position.y > aspectRatio - radius ? 1 : 0;

    float2 center_position;
    center_position.x = part_x == -1 ? radius : part_x == 1 ? 1 - radius : position.x;
    center_position.y = part_y == -1 ? radius : part_y == 1 ? aspectRatio - radius : position.y;

    if ((part_x == 0 && part_y == 0) || p == 0) {
        PixelInfo info = PixelInfo();
        info.refraction_vector = 0;
        return info;
    }

    return normal_map_2(position, center_position, radius, p, height, alpha);
}

float gaussian(float x, float sigma) {
    return exp(-(x * x) / (2.0 * sigma * sigma));
}

fragment float4 glass_effect(VertexOut in [[stage_in]],
                            texture2d<float> backgroundTexture [[texture(0)]],
                            constant GlassUniforms &uniforms [[buffer(0)]]) {

    float2 uv = float2(in.texCoord);

    float radius = uniforms.radius;
    float aspectRatio = uniforms.aspectRatio;

    float red_alpha = 700;
    float green_alpha = 546.1;
    float blue_alpha = 435.8;

    float height = uniforms.height;
    float p = uniforms.p;
    float scale = 1;

    PixelInfo red_info = normal_map(uv, aspectRatio, radius, p, height, red_alpha);
    PixelInfo green_info = normal_map(uv, aspectRatio, radius, p, height, green_alpha);
    PixelInfo blue_info = normal_map(uv, aspectRatio, radius, p, height, blue_alpha);

    float2 red_normal = red_info.refraction_vector / float2(1, aspectRatio);
    float2 green_normal = green_info.refraction_vector / float2(1, aspectRatio);
    float2 blue_normal = blue_info.refraction_vector / float2(1, aspectRatio);

//    return float4((blue_normal.x + 1) / 2.0, (blue_normal.y + 1) / 2.0, 0, 1);

    constexpr sampler textureSampler(mag_filter::bicubic, min_filter::bicubic);

    float sigma = min(uniforms.max_edge_blur, length(red_normal) * 25);

    if (sigma < 0.00001) {
        PixelInfo red_info = normal_map(uv, aspectRatio, radius, p, height, red_alpha);
        PixelInfo green_info = normal_map(uv, aspectRatio, radius, p, height, green_alpha);
        PixelInfo blue_info = normal_map(uv, aspectRatio, radius, p, height, blue_alpha);

        float2 red_normal = red_info.refraction_vector * scale / float2(1, aspectRatio);
        float2 green_normal = green_info.refraction_vector * scale / float2(1, aspectRatio);
        float2 blue_normal = blue_info.refraction_vector * scale / float2(1, aspectRatio);

        float2 fixed_uv = uniforms.uvOffset + uv * uniforms.uvScale;

        float2 red_textureUV = fixed_uv + red_normal * uniforms.uvScale;
        float2 green_textureUV = fixed_uv + green_normal * uniforms.uvScale;
        float2 blue_textureUV = fixed_uv + blue_normal * uniforms.uvScale;

        return float4(
                      backgroundTexture.sample(textureSampler, red_textureUV).r,
                      backgroundTexture.sample(textureSampler, green_textureUV).g,
                      backgroundTexture.sample(textureSampler, blue_textureUV).b,
                      (backgroundTexture.sample(textureSampler, red_textureUV).a + backgroundTexture.sample(textureSampler, green_textureUV).a + backgroundTexture.sample(textureSampler, blue_textureUV).a) / 3.0
                      );
    }

    float2 texel_size = 1.0 / float2(backgroundTexture.get_width(), backgroundTexture.get_height());
    float4 color = float4(0);
    float total_weight = 0;

    int blur_radius = int(ceil(sigma * 3.0));
    int step = ceil(blur_radius / 1.5);
    int zero_index = (2 * blur_radius + 2) * blur_radius;
    int initial_value = zero_index % step;

    for (int index = initial_value; index < pow(2.0 * blur_radius + 1, 2.0); index += step) {
        int x = index % (2 * blur_radius + 1) - blur_radius;
        int y = index / (2 * blur_radius + 1) - blur_radius;

        float dist = length(float2(x, y));
        float weight = gaussian(dist, sigma);
        float2 offset = float2(x, y) * texel_size;

        PixelInfo red_info = normal_map(uv + offset, aspectRatio, radius, p, height, red_alpha);
        PixelInfo green_info = normal_map(uv + offset, aspectRatio, radius, p, height, green_alpha);
        PixelInfo blue_info = normal_map(uv + offset, aspectRatio, radius, p, height, blue_alpha);

        float2 red_normal = red_info.refraction_vector * scale / float2(1, aspectRatio);
        float2 green_normal = green_info.refraction_vector * scale / float2(1, aspectRatio);
        float2 blue_normal = blue_info.refraction_vector * scale / float2(1, aspectRatio);

        float2 fixed_uv = uniforms.uvOffset + (uv + offset) * uniforms.uvScale;

        float2 red_textureUV = fixed_uv + red_normal * uniforms.uvScale;
        float2 green_textureUV = fixed_uv + green_normal * uniforms.uvScale;
        float2 blue_textureUV = fixed_uv + blue_normal * uniforms.uvScale;

        color.r += backgroundTexture.sample(textureSampler, red_textureUV).r * weight;
        color.g += backgroundTexture.sample(textureSampler, green_textureUV).g * weight;
        color.b += backgroundTexture.sample(textureSampler, blue_textureUV).b * weight;
        color.a += (backgroundTexture.sample(textureSampler, red_textureUV).a + backgroundTexture.sample(textureSampler, green_textureUV).a + backgroundTexture.sample(textureSampler, blue_textureUV).a) / 3.0 * weight;
        total_weight += weight;
    }

    return color / total_weight;
}
