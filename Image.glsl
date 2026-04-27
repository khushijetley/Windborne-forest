/*  Image — Renderer for "Windborne Forest"
     Title: Windborne Forest: A Terrain- and Wind-Driven Forest Fire CA

    Inputs:
    - iChannel0: Buffer A (simulation state)

    Rendering:
    - empty/ash: dark
    - trees: green-ish
    - burning: bright with simple glow based on nearby burning pixels
*/

#ifdef GL_ES
precision highp float;
#endif

/*
    decodeState:
    Same encoding as Buffer A:
    0.0 empty, 0.5 tree, 1.0 burning
*/
int decodeState(float r) {
    if (r < 0.25) return 0;
    if (r < 0.75) return 1;
    return 2;
}

int sampleState(ivec2 ip) {
    ivec2 size = ivec2(iResolution.xy);
    ip = ivec2((ip.x % size.x + size.x) % size.x, (ip.y % size.y + size.y) % size.y);

    vec2 uv = (vec2(ip) + 0.5) / iResolution.xy;
    return decodeState(texture(iChannel0, uv).r);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    ivec2 ip = ivec2(fragCoord);

    int s = sampleState(ip);

    // Base colors
    vec3 col;

    if (s == 0) col = vec3(0.03, 0.03, 0.04);        // ash/empty
    if (s == 1) col = vec3(0.08, 0.22, 0.10);        // trees
    if (s == 2) col = vec3(0.95, 0.35, 0.05);        // fire

    // Simple glow: look for burning neighbors and add brightness.
    float glow = 0.0;

    ivec2 offs[8];
    offs[0] = ivec2(-1, -1);
    offs[1] = ivec2( 0, -1);
    offs[2] = ivec2( 1, -1);
    offs[3] = ivec2(-1,  0);
    offs[4] = ivec2( 1,  0);
    offs[5] = ivec2(-1,  1);
    offs[6] = ivec2( 0,  1);
    offs[7] = ivec2( 1,  1);

    for (int i = 0; i < 8; i++) {
        int ns = sampleState(ip + offs[i]);
        if (ns == 2) glow += 0.12; 
    }

    // Fire itself glows more.
    if (s == 2) glow += 0.35;

    col += glow;

    // Vignette
    vec2 uv = (fragCoord + 0.5) / iResolution.xy;
    float v = smoothstep(0.95, 0.25, distance(uv, vec2(0.5)));
    col *= mix(0.85, 1.05, v);

    fragColor = vec4(col, 1.0);
}
