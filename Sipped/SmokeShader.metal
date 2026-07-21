#include <metal_stdlib>
using namespace metal;

// The first eight vectors are u_colors; the remaining seven preserve the
// packed u_scene/u_shape/u_surface/u_finish/u_transform/u_space/u_cursor API.
struct SmokeUniforms {
    float4 colors[8];
    float4 scene;
    float4 shape;
    float4 surface;
    float4 finish;
    float4 transform;
    float4 space;
    float4 cursor;
};

struct SmokeVertexOut {
    float4 position [[position]];
};

vertex SmokeVertexOut sippedSmokeVertex(uint vertexID [[vertex_id]]) {
    const float2 positions[3] = {
        float2(-1.0, -1.0),
        float2(3.0, -1.0),
        float2(-1.0, 3.0)
    };
    SmokeVertexOut out;
    out.position = float4(positions[vertexID], 0.0, 1.0);
    return out;
}

#define u_resolution uniforms.scene.xy
#define u_time uniforms.scene.z
#define u_colorCount uniforms.scene.w
#define u_scale uniforms.shape.x
#define u_intensity uniforms.shape.y
#define u_paramA uniforms.shape.z
#define u_warp uniforms.shape.w
#define u_detail uniforms.surface.x
#define u_contrast uniforms.surface.y
#define u_brightness uniforms.surface.z
#define u_saturation uniforms.surface.w
#define u_hue uniforms.finish.x
#define u_vignette uniforms.finish.y
#define u_blur uniforms.finish.z
#define u_grain uniforms.finish.w
#define u_seed uniforms.transform.x
#define u_rotate uniforms.transform.y
#define u_drift uniforms.transform.z
#define u_oklab uniforms.transform.w
#define u_offset uniforms.space.xy
#define u_mouse uniforms.space.zw
#define u_cursorPresence uniforms.cursor.x
#define u_cursorEffect uniforms.cursor.y
#define u_cursorStrength uniforms.cursor.z
#define u_cursorRadius uniforms.cursor.w

float hash21(float2 p) {
    p = fract(p * float2(234.34, 435.345));
    p += dot(p, p + 34.23);
    return fract(p.x * p.y);
}

float grainHash(float2 p) {
    float3 p3 = fract(float3(p.x, p.y, p.x) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

float2 hash22(float2 p) {
    float n = sin(dot(p, float2(41.0, 289.0)));
    return fract(float2(15731.743, 7892.321) * n);
}

float noise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    float2 u = f * f * (3.0 - 2.0 * f);
    return mix(
        mix(hash21(i), hash21(i + float2(1.0, 0.0)), u.x),
        mix(hash21(i + float2(0.0, 1.0)), hash21(i + float2(1.0, 1.0)), u.x),
        u.y
    );
}

float fbm(float2 p) {
    float value = 0.0;
    float amplitude = 0.5;
    for (int i = 0; i < 5; i++) {
        value += amplitude * noise(p);
        p = p * 2.03 + float2(17.0, 9.2);
        amplitude *= 0.5;
    }
    return value;
}

float3 srgbToLinear(float3 color) {
    return select(
        color / 12.92,
        pow((color + 0.055) / 1.055, float3(2.4)),
        color >= 0.04045
    );
}

float3 linearToSrgb(float3 color) {
    return select(
        color * 12.92,
        1.055 * pow(max(color, float3(0.0)), float3(1.0 / 2.4)) - 0.055,
        color >= 0.0031308
    );
}

float3 linToOklab(float3 color) {
    float l = 0.4122214708 * color.r + 0.5363325363 * color.g + 0.0514459929 * color.b;
    float m = 0.2119034982 * color.r + 0.6806995451 * color.g + 0.1073969566 * color.b;
    float s = 0.0883024619 * color.r + 0.2817188376 * color.g + 0.6299787005 * color.b;
    l = pow(max(l, 0.0), 1.0 / 3.0);
    m = pow(max(m, 0.0), 1.0 / 3.0);
    s = pow(max(s, 0.0), 1.0 / 3.0);
    return float3(
        0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
        1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
        0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s
    );
}

float3 oklabToLin(float3 color) {
    float l = color.x + 0.3963377774 * color.y + 0.2158037573 * color.z;
    float m = color.x - 0.1055613458 * color.y - 0.0638541728 * color.z;
    float s = color.x - 0.0894841775 * color.y - 1.2914855480 * color.z;
    l = l * l * l;
    m = m * m * m;
    s = s * s * s;
    return float3(
        4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
        -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
        -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s
    );
}

float3 mixColour(float3 a, float3 b, float t, constant SmokeUniforms& uniforms) {
    if (u_oklab > 0.5) {
        float3 la = linToOklab(srgbToLinear(a));
        float3 lb = linToOklab(srgbToLinear(b));
        return clamp(linearToSrgb(oklabToLin(mix(la, lb, t))), 0.0, 1.0);
    }
    return mix(a, b, t);
}

float3 palette(float x, constant SmokeUniforms& uniforms) {
    float n = max(u_colorCount - 1.0, 1.0);
    float f = clamp(x, 0.0, 1.0) * n;
    float3 color = uniforms.colors[0].xyz;
    for (int i = 0; i < 7; i++) {
        if (float(i) < n) {
            color = mixColour(
                color,
                uniforms.colors[i + 1].xyz,
                smoothstep(0.0, 1.0, clamp(f - float(i), 0.0, 1.0)),
                uniforms
            );
        }
    }
    return color;
}

float3 hueRotate(float3 color, float angle) {
    const float3x3 toYIQ = float3x3(
        float3(0.299, 0.596, 0.211),
        float3(0.587, -0.274, -0.523),
        float3(0.114, -0.322, 0.312)
    );
    const float3x3 toRGB = float3x3(
        float3(1.0, 1.0, 1.0),
        float3(0.956, -0.272, -1.106),
        float3(0.621, -0.647, 1.703)
    );
    float3 yiq = toYIQ * color;
    float cosine = cos(angle);
    float sine = sin(angle);
    yiq = float3(
        yiq.x,
        yiq.y * cosine - yiq.z * sine,
        yiq.y * sine + yiq.z * cosine
    );
    return toRGB * yiq;
}

float3 shade(float2 uv, float2 p, float time, constant SmokeUniforms& uniforms) {
    float warp = 2.0 + u_intensity * 4.0;
    float2 q = float2(
        fbm(p + time * 0.08),
        fbm(p + float2(5.2, 1.3) - time * 0.06)
    );
    float2 r = float2(
        fbm(p + warp * q + float2(1.7, 9.2)),
        fbm(p + warp * q + float2(8.3, 2.8))
    );
    return palette(fbm(p + 3.0 * r + u_seed), uniforms);
}

fragment float4 sippedSmokeFragment(
    SmokeVertexOut in [[stage_in]],
    constant SmokeUniforms& uniforms [[buffer(0)]]
) {
    // WebGL gl_FragCoord has a bottom-left origin; Metal's fragment position
    // is top-left, so flip Y before applying the original shader math.
    float2 fragmentCoordinate = float2(in.position.x, u_resolution.y - in.position.y);
    float2 uv = fragmentCoordinate / u_resolution;
    float2 screenUv = uv;
    float2 p = (fragmentCoordinate - 0.5 * u_resolution)
        / min(u_resolution.x, u_resolution.y);
    float cursorMask = 0.0;

    if (u_cursorPresence > 0.001) {
        float2 cursorPosition = (0.5 * u_mouse * u_resolution)
            / min(u_resolution.x, u_resolution.y);
        float2 cursorDelta = p - cursorPosition;
        if (u_cursorEffect < 0.5) {
            p += cursorPosition * u_cursorPresence * u_cursorStrength * 0.55;
        } else {
            float cursorDistance = length(cursorDelta);
            float2 cursorDirection = cursorDelta / max(cursorDistance, 0.0001);
            cursorMask = u_cursorPresence
                * (1.0 - smoothstep(0.0, u_cursorRadius, cursorDistance));
            if (u_cursorEffect < 1.5) {
                p -= cursorDirection * cursorMask * u_cursorStrength * 0.24;
            } else if (u_cursorEffect < 2.5) {
                float cursorAngle = cursorMask * u_cursorStrength * 2.2;
                float cc = cos(cursorAngle);
                float cs = sin(cursorAngle);
                p = cursorPosition + float2x2(cc, -cs, cs, cc) * cursorDelta;
            } else if (u_cursorEffect < 3.5) {
                float ripple = sin(
                    cursorDistance / max(u_cursorRadius, 0.001) * 18.0 - u_time * 5.0
                );
                p -= cursorDirection * ripple * cursorMask * u_cursorStrength * 0.07;
            }
        }
    }

    uv = p * min(u_resolution.x, u_resolution.y) / u_resolution + 0.5;
    p *= u_scale;
    if (abs(u_rotate) > 0.0001) {
        float cr = cos(u_rotate);
        float sr = sin(u_rotate);
        p = float2x2(cr, -sr, sr, cr) * p;
    }
    p += u_offset;
    if (u_drift > 0.0001) {
        p += u_drift * float2(sin(u_time * 0.31), cos(u_time * 0.23));
    }
    if (u_warp > 0.0) {
        p += u_warp * (
            float2(
                fbm(p * u_detail + u_seed),
                fbm(p * u_detail + float2(5.2, 1.3))
            ) - 0.5
        );
    }

    float3 color;
    if (u_blur > 0.0) {
        float edge = u_blur;
        float positionEdge = edge * u_scale;
        float2 uvEdge = float2(edge) * min(u_resolution.x, u_resolution.y) / u_resolution;
        color = shade(uv, p, u_time, uniforms) * 0.36;
        color += shade(uv + float2(uvEdge.x, 0.0), p + float2(positionEdge, 0.0), u_time, uniforms) * 0.16;
        color += shade(uv - float2(uvEdge.x, 0.0), p - float2(positionEdge, 0.0), u_time, uniforms) * 0.16;
        color += shade(uv + float2(0.0, uvEdge.y), p + float2(0.0, positionEdge), u_time, uniforms) * 0.16;
        color += shade(uv - float2(0.0, uvEdge.y), p - float2(0.0, positionEdge), u_time, uniforms) * 0.16;
    } else {
        color = shade(uv, p, u_time, uniforms);
    }

    if (abs(u_contrast - 1.0) > 0.0001) {
        color = (color - 0.5) * u_contrast + 0.5;
    }
    if (abs(u_saturation - 1.0) > 0.0001) {
        float luma = dot(color, float3(0.299, 0.587, 0.114));
        color = mix(float3(luma), color, u_saturation);
    }
    if (abs(u_hue) > 0.0001) {
        color = hueRotate(color, u_hue);
    }
    if (abs(u_brightness) > 0.0001) {
        color += u_brightness;
    }
    if (u_vignette > 0.0001) {
        float vignetteDistance = length(screenUv - 0.5) * 1.41421356;
        color *= 1.0 - u_vignette * smoothstep(0.35, 1.0, vignetteDistance);
    }
    if (u_cursorPresence > 0.001 && u_cursorEffect > 3.5) {
        color += (float3(0.18) + color * 0.12) * cursorMask * u_cursorStrength;
    }
    if (u_grain > 0.0001) {
        color += (
            grainHash(fragmentCoordinate + float2(u_seed * 17.0, u_seed * 31.0)) - 0.5
        ) * u_grain;
    }
    return float4(clamp(color, 0.0, 1.0), 1.0);
}
