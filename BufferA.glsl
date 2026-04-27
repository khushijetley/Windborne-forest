/*

Buffer A - Forest Fire + Wind + Terrrain Simulation

Title: Windborne Forest: A Terrain- and Wind-Driven Forest Fire CA

BUFFERS

- Buffer A: Cellular automata simulation state (feedback buffer).
  The RED channel encodes cell state:
    0.0  = empty / ash
    0.5  = tree
    1.0  = burning
- Image: Rendering pass that visualizes the simulation with color and glow.

INTERACTIONS AND GLOBAL PARAMETERS
- Mouse click ignites nearby trees, allowing the user to intentionally start fires.
- Mouse position controls global wind direction, biasing how fire spreads.
- Several parameters can be modified in the code to explore different behaviours:
    • pGrow: probability of tree growth
    • pLightning: probability of spontaneous ignition
    • spreadBase: base fire-spread probability
    • windStrength: strength of directional wind bias
    • terrainScale: size of terrain regions
    • dampnessPower: how strongly terrain dampness suppresses fire
Resetting the simulation or adjusting parameters can result in very different
long-term behaviours.

SYSTEM IDEA & BEHAVIOUR
This project implements a probabilistic forest fire cellular automaton in which
local fire spread is influenced by both global wind direction and spatially
varying terrain properties. Each cell exists in one of three discrete states:
empty, tree, or burning. Burning cells turn into empty cells, trees may ignite
either from neighbouring fires or from spontaneous lightning events, and empty
cells may regrow trees probabilistically over time.

Terrain introduces spatial non-homogeneity by modulating growth and burn
probabilities: fertile, damp regions promote regrowth and resist fire, while dry
regions burn more easily and recover more slowly. Wind introduces directional
bias, causing fire fronts to travel across the lattice in coherent patterns.

Over long time scales, the system exhibits several distinct regimes, including:
stable forests with rare fires, cyclic growth–burn–regrowth behaviour, traveling
fire fronts under strong wind, and extinction scenarios where the forest fails
to recover. Small parameter changes can shift the system dramatically between
these regimes.

SOURCES & INSPIRATION
The conceptual foundation of this work is inspired by the classic Forest Fire 
(Drossel & Schwabl, 1992) probabilistic cellular automaton, a well-known model 
used in complexity science to study emergent behaviour and self-organized criticality. 
The basic three-state structure (empty, tree, burning) follows this traditional 
framework.

Additional inspiration comes from course material. No external code was copied. 
All GLSL code was written independently for this assignment. LLM tools such as ChatGPT
and Gemini were applied to debug and refine the code.

CITATION
Drossel, B., & Schwabl, F. (1992). Self-organized critical forest-fire model. 
Physical Review Letters, 69(11), 1629–1632. https://doi.org/10.1103/PhysRevLett.69.1629

FUTURE EXTENSIONS
Possible future extensions of this project include:
- Introducing a second buffer to store fuel, moisture, or tree age
- Time-varying wind or storm events (temporal non-homogeneity)
- Mobile ember particles to create spot fires (mobile CA)
- Multiple vegetation species with different burn characteristics
- Coupling the system to a reaction–diffusion field for smoke or heat

*/

#ifdef GL_ES
precision highp float;
#endif

// Tunable parameters (play!)

// Probability that an EMPTY cell becomes a TREE per frame (before terrain bias).
const float pGrow = 0.012;

// Probability that a TREE ignites spontaneously (before terrain bias).
const float pLightning = 0.00006;

// Base probability a TREE catches from a single BURNING neighbour (before biases).
const float spreadBase = 0.28;

// Extra spread when a burning neighbour is aligned with wind direction.
const float windStrength = 0.65;

// Terrain scale: higher = smaller patches; lower = larger patches.
const float terrainScale = 4.0;

// Dampness curve: higher makes wet areas MUCH more fire-resistant.
const float dampnessPower = 2.2;

// Mouse ignition radius (in pixels).
const float igniteRadiusPx = 18.0;

// State encoding helpers

/*
    decodeState:
    Reads encoded RED value and returns a discrete state:
    0 = empty, 1 = tree, 2 = burning
*/
int decodeState(float r) {
    // WHY: storing as 0.0/0.5/1.0 avoids precision issues of exact integers.
    if (r < 0.25) return 0;
    if (r < 0.75) return 1;
    return 2;
}

/*
    encodeState:
    Takes a discrete state and returns RED channel encoding:
    0 -> 0.0, 1 -> 0.5, 2 -> 1.0
*/
float encodeState(int s) {
    if (s == 0) return 0.0;
    if (s == 1) return 0.5;
    return 1.0;
}

// Random + terrain (procedural)

/*
    hash21:
    Small deterministic hash from a 2D point -> [0,1).
    Args: p (any vec2)
    Returns: pseudo-random float in [0,1)
*/
float hash21(vec2 p) {
    // WHY: simple and fast; good enough for stochastic CA decisions.
    p = fract(p * vec2(123.34, 345.45));
    p += dot(p, p + 34.345);
    return fract(p.x * p.y);
}

/*
    valueNoise:
    Cheap value noise from a 2D position (no textures).
    Args: p (continuous coords)
    Returns: smooth-ish noise in [0,1)
*/

float valueNoise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);

    // Four corners
    float a = hash21(i + vec2(0.0, 0.0));
    float b = hash21(i + vec2(1.0, 0.0));
    float c = hash21(i + vec2(0.0, 1.0));
    float d = hash21(i + vec2(1.0, 1.0));

    // Smoothstep interpolation
    vec2 u = f * f * (3.0 - 2.0 * f);

    // Bilinear blend
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

/*
    terrain01:
    Returns terrain value in [0,1] where:
    - higher means more fertile AND more damp (more growth, less burning)
    Args: uv (0..1)
*/
float terrain01(vec2 uv) {
    // WHY: multi-octave-ish by mixing two scales; still cheap.
    float n1 = valueNoise(uv * terrainScale);
    float n2 = valueNoise(uv * (terrainScale * 2.3) + 17.2);
    return clamp(0.65 * n1 + 0.35 * n2, 0.0, 1.0);
}

// Buffer sampling

/*
    readStateAt:
    Samples previous simulation (iChannel0) at integer pixel coordinate.
    Args: ip (pixel coordinate, integer-ish)
    Returns: discrete state 0/1/2
*/
int readStateAt(ivec2 ip) {
    // Wrap around edges to avoid dead borders.
    ivec2 size = ivec2(iResolution.xy);
    ip = ivec2((ip.x % size.x + size.x) % size.x, (ip.y % size.y + size.y) % size.y);

    vec2 uv = (vec2(ip) + 0.5) / iResolution.xy;
    float r = texture(iChannel0, uv).r;
    return decodeState(r);
}

// Wind / interaction helpers

/*
    computeWindDir:
    Wind direction points from screen center toward mouse position.
    If mouse hasn't moved/available, defaults to right.
*/
vec2 computeWindDir() {
    vec2 center = 0.5 * iResolution.xy;

    // If iMouse.z <= 0, mouse isn't actively pressed; still use iMouse.xy if present.
    vec2 m = iMouse.xy;
    // Some setups return (0,0) if no mouse use; handle that.
    bool hasMouse = (m.x > 1.0 || m.y > 1.0);

    vec2 dir = hasMouse ? (m - center) : vec2(1.0, 0.0);

    // Avoid zero-length normalize.
    float len2 = dot(dir, dir);
    if (len2 < 1e-4) dir = vec2(1.0, 0.0);

    return normalize(dir);
}

/*
    isMouseIgnitingHere:
    Returns true if mouse is down and the pixel is close enough to ignite.
*/
bool isMouseIgnitingHere(vec2 fragCoord) {
    // WHY: simple user interaction that creates controllable "storms" of fire.
    bool mouseDown = (iMouse.z > 0.0);
    if (!mouseDown) return false;

    float d = length(fragCoord - iMouse.xy);
    return d < igniteRadiusPx;
}

// Main simulation

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    ivec2 ip = ivec2(fragCoord);
    vec2 uv = (fragCoord + 0.5) / iResolution.xy;

    // Initialization 
    if (iFrame < 5) {
        float t = terrain01(uv);

        // Fertile areas start denser with trees.
        float forestDensity = mix(0.65, 0.92, t);

        // Random seed per pixel (frame-independent for stable initial condition).
        float r = hash21(vec2(ip) * 0.73 + 12.34);

        int s = 0; // empty by default
        if (r < forestDensity) s = 1;

        // Add rare initial fire sparks (more likely in dry areas).
        float spark = hash21(vec2(ip) * 1.91 + 98.76);
        float dry = 1.0 - t;
        if (s == 1 && spark < (0.0008 + 0.002 * dry)) s = 2;

        fragColor = vec4(encodeState(s), 0.0, 0.0, 1.0);
        return;
    }

    // -------- Read current state --------
    int state = readStateAt(ip);

    // Terrain: high = fertile + damp. Dryness is 1 - dampness.
    float damp = terrain01(uv);
    float dry = 1.0 - damp;

    // Wind direction from mouse.
    vec2 windDir = computeWindDir();

    // -------- Apply CA rules --------
    int nextState = state;

    // 1) Burning -> Empty
    if (state == 2) {
        nextState = 0;
    }

    // 2) Tree -> Burning (spread or lightning or mouse ignite)
    if (state == 1) {

        // Mouse ignite overrides: user can start fires intentionally.
        if (isMouseIgnitingHere(fragCoord)) {
            nextState = 2;
        } else {
            // Compute probability of catching fire from neighbours (wind-biased).
            float catchProb = 0.0;

            // 8-neighbourhood offsets
            ivec2 offs[8];
            offs[0] = ivec2(-1, -1);
            offs[1] = ivec2( 0, -1);
            offs[2] = ivec2( 1, -1);
            offs[3] = ivec2(-1,  0);
            offs[4] = ivec2( 1,  0);
            offs[5] = ivec2(-1,  1);
            offs[6] = ivec2( 0,  1);
            offs[7] = ivec2( 1,  1);

            // Accumulate spread chance from each burning neighbour.
            for (int i = 0; i < 8; i++) {
                ivec2 no = offs[i];
                int ns = readStateAt(ip + no);

                if (ns == 2) {
                    // Alignment with wind:
                    // If neighbour is "upwind" relative to this cell, boost spread.
                    vec2 off = normalize(vec2(no));
                    float alignment = max(0.0, dot(off, windDir));

                    // Base spread + wind boost
                    float p = spreadBase + windStrength * alignment;

                    // Dampness reduces spread (strongly in wet zones).
                    float dampFactor = pow(dry, dampnessPower);
                    p *= mix(0.35, 1.0, dampFactor);

                    // Combine multiple neighbour chances without exceeding 1:
                    // P_total = 1 - Π(1 - p_i)
                    catchProb = 1.0 - (1.0 - catchProb) * (1.0 - clamp(p, 0.0, 1.0));
                }
            }

            // Lightning chance (more likely in dry areas).
            float lightning = pLightning * mix(0.6, 2.0, pow(dry, 1.6));

            // Single random decision for this cell this frame.
            float rnd = hash21(vec2(ip) + vec2(17.0, 31.0) * float(iFrame));

            // Decide whether tree ignites.
            if (rnd < (catchProb + lightning)) {
                nextState = 2;
            } else {
                nextState = 1;
            }
        }
    }

    // 3) Empty -> Tree (growth, terrain-biased)
    if (state == 0) {
        // Fertile (damp) zones grow faster.
        float grow = pGrow * mix(0.35, 2.2, damp);

        float rnd = hash21(vec2(ip) + vec2(91.0, 53.0) * float(iFrame));
        if (rnd < grow) {
            nextState = 1;
        } else {
            nextState = 0;
        }
    }

    fragColor = vec4(encodeState(nextState), 0.0, 0.0, 1.0);
}
