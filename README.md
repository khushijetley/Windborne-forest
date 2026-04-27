# Windborne Forest
### Probabilistic Forest Fire Cellular Automaton · Real-Time GLSL Shader

![Stable forest state](screenshots/preview.png)
*Stable forest regime — high density, rare ignition*

![Fire propagation](screenshots/burning.png)
*Active fire front — directional spread under wind bias*

![Post-fire recovery](screenshots/sparse.png)
*Sparse recovery regime — regrowth competing with ignition*

[**View Live on Shadertoy →**](https://www.shadertoy.com/view/tXGyzK)

---

## Overview

Windborne Forest is a real-time probabilistic cellular automaton simulating emergent forest fire dynamics, built entirely in GLSL on Shadertoy. Each cell exists in one of three discrete states — empty, tree, or burning — and the system evolves according to local probabilistic rules modulated by global wind direction and spatially varying terrain properties.

The result is a complex system capable of producing qualitatively distinct long-term behavioral regimes from small parameter changes: stable forests, cyclic growth-burn-regrowth patterns, coherent traveling fire fronts, and full extinction scenarios. This sensitivity to initial conditions and parameters is a direct instance of **self-organized criticality** — a phenomenon studied in complexity science, emergent AI behavior research, and systems that sit at the edge of order and chaos.

---

## Why This Matters Beyond Visuals

This project is fundamentally a study in **emergent behavior in complex adaptive systems**. The same questions it raises — how do local rules produce global structure? how does a system tip between stable and catastrophic regimes? how does directional bias (wind) propagate through a network? — are structurally identical to questions in AI alignment research about mesa-optimization, behavioral drift, and the emergence of unintended system-level behaviors from individually simple components.

Building and tuning this system required developing strong intuitions about feedback loops, phase transitions, and the relationship between local rules and global outcomes. Those intuitions transfer directly to thinking about how AI systems behave at scale.

---

## Technical Architecture

### Buffer Structure
| Buffer | Role |
|--------|------|
| **Buffer A** | Cellular automata state feedback buffer |
| **Image** | Rendering pass — color mapping and glow |

### Cell State Encoding (RED channel)
| Value | State |
|-------|-------|
| `0.0` | Empty / ash |
| `0.5` | Tree |
| `1.0` | Burning |

### Interaction
- **Mouse click** — ignites nearby trees, allowing user-triggered fire events
- **Mouse position** — controls global wind direction, biasing directional fire spread in real time

---

## Key Parameters

| Parameter | Effect |
|-----------|--------|
| `pGrow` | Probability of tree regrowth on empty cells |
| `pLightning` | Probability of spontaneous ignition |
| `spreadBase` | Base fire-spread probability between neighbours |
| `windStrength` | Magnitude of directional wind bias |
| `terrainScale` | Size of terrain feature regions |
| `dampnessPower` | How strongly terrain moisture suppresses ignition |

Small changes to these parameters can shift the system dramatically between behavioral regimes — a direct demonstration of bifurcation and phase transition in complex systems.

---

## System Behavior & Emergent Regimes

Over long time scales the system exhibits several distinct dynamical regimes:

- **Stable forest** — rare fires, high dampness, slow lightning
- **Cyclic growth-burn-regrowth** — periodic oscillation between dense and sparse states
- **Traveling fire fronts** — coherent directional spread under strong wind
- **Extinction** — parameter regimes where regrowth cannot outpace burning

The transition between these regimes is often abrupt and sensitive to small parameter changes, consistent with the Drossel-Schwabl model of self-organized criticality.

---

## Conceptual Foundation

This work is grounded in the classic **Drossel-Schwabl (1992)** forest fire model, a foundational model in complexity science for studying emergent behavior and self-organized criticality. All GLSL code was written independently. LLM tools (ChatGPT, Gemini) were used for debugging and refinement.

> Drossel, B., & Schwabl, F. (1992). Self-organized critical forest-fire model. *Physical Review Letters, 69*(11), 1629–1632. https://doi.org/10.1103/PhysRevLett.69.1629

---

## Future Extensions

- Second buffer encoding fuel, moisture, or tree age
- Time-varying wind and storm events
- Mobile ember particles for spot fires
- Multiple vegetation species with distinct burn characteristics
- Reaction-diffusion coupling for smoke and heat propagation

---

## Stack
`GLSL` `Shadertoy` `Cellular Automata` `Real-Time Simulation` `Complexity Science`

---

*Part of an ongoing series of real-time shader simulations exploring emergent behavior in complex adaptive systems.*
