# Exhibit 2 · Between Bounces

**Can we predict how much plasma escapes without computing every bounce?** A trapped ion returns to the same places many times before collisions appreciably change the population on its orbit. A passing ion can reach a wall in one trip. At the bead stand, visitors can slow the trapped orbits and predict when the counters at the wall will change. [Thesis derivation](<../../PhD-thesis-latex/Chapter POA Toy Models/tex-files/algorithm.tex>) · [Rosen, Francisquez and Hammett](https://arxiv.org/abs/2604.00121)

## The walk from the atrium

The room is **20 m deep × 10 m wide**, with a 4 m doorway and 5 m ceiling. Viewed from the atrium, the four freestanding sculptures run along the visitor’s **right**. The bead stand carries its phase controls on the right side of the inclined display.

Beyond the bead stand, the reading area extends across the room so both thesis prints and their captions can be viewed straight on. The sketch shows the original 16 m sculpture layout.

![Scale plan of the sculpture layout with the river and whirlpool side by side and a four-metre ruler.](sketches/room.svg)

| Centre from doorway | Station | Length along aisle × width × height, including its sign |
| --- | --- | --- |
| 2.2 m | Twin pendulums | 2.60 × 1.20 × 2.40 m |
| 5.8 m | Dye river | 3.20 × 1.65 × 1.93 m |
| 9.4 m | Dye whirlpool | 2.70 × 1.84 × 2.22 m |
| 13.35 m | Bead rings and two open paths | 3.95 × 2.20 × 2.24 m |

Place the centres 2.7 m off the right wall. Even the widest base leaves 1.6 m behind it. Keep a continuous 3 m viewing aisle and floor landings within the 4 m teleport range. The bead tracks rise from 0.80 to 1.80 m on a 28° slope facing the aisle. Face each question toward the arriving visitor, with white lettering on matte black. [Gallery layout](../SETTING.md) · [Reach and controls](../CONTROLS.md)

## The blackboards

Each board hangs directly across from its sculpture on the left wall, centred 1.57 m above the floor. At the pendulums, one bounce of period $T_b$ samples a local source $S$ with the time-weighted average $\langle S\rangle_b=T_b^{-1}\oint S\,dt$. When many bounces fit within a collision time $\tau_c$, their precise timing matters little to the slow evolution of the trapped population.

The dye river illustrates the long, orbit-averaged phase. For the ion distribution $f$, the algorithm advances

$$
\frac{\partial f}{\partial t}
= H_{\rm orbit}\left[\alpha\{\mathcal H,f\}+C(f)+S\right].
$$

On a closed orbit the mask $H_{\rm orbit}=1$. The factor $0<\alpha<1$ scales Hamiltonian motion along the orbit. Collisions $C(f)$ and the source keep their physical rates. A slowed bounce can still sample the orbit when $T_b/\alpha\ll\tau_c$. This relaxes the time-step limit from orbital motion and lets larger steps follow collisional evolution. On a passing path $H_{\rm orbit}=0$, so its distribution holds at the last full-speed value.

The whirlpool board compares the concentration around one lap of each water sculpture at the instant of release, divided by that lap’s mean. The river has a peak downstream of its localized dye tap. The whirlpool trace stays level at one.

At the bead rings, the short full-dynamics phase restores $\partial_t f=\{\mathcal H,f\}+C(f)+S$ throughout phase space. Small steps resolve a few transit times, so ions on open paths can scatter and reach the walls before the next orbit-averaged phase. [Thesis derivation](<../../PhD-thesis-latex/Chapter POA Toy Models/tex-files/algorithm.tex>) · [Rosen, Francisquez and Hammett](https://arxiv.org/abs/2604.00121)

## Twin pendulums · Which pendulum settles first?

> Follow the gold dot and the mint ring as each bob writes its angle on the graph. At six seconds the bobs point in opposite directions. How far is each from straight down? After sixteen seconds one has made sixteen swings and the other four. Their common swing limit has fallen from 10° to 3.68°, and both traces approach the same resting angle of 0°.

![Animated pendulums with sixteen and four swings and a shared angular envelope.](sketches/pendulums.svg)

The dashed curves mark the swing limits above and below the zero line. The two rulers on the lectern each span one exhibit second. Give each swing eight time steps and the full-rate ruler needs eight steps of 0.125 s. The quarter-rate ruler covers the same second with two steps of 0.5 s.

Place this next graphic **beside the two swing scales**, so visitors can look from bob to mirror without turning around. A return trip between two magnetic turning points plays the role of one swing. The swing amplitude represents a slowly evolving quantity. In a plasma that quantity is the distribution on a trapped orbit, which feeding and scattering can increase or decrease. Shortening the calculation by slowing the bounce makes sense while the reduced bounce time is still short compared with the time over which that distribution changes.

![A shared swing envelope beside an idealized ion bouncing between two turning points and a passing ion reaching the wall.](sketches/pendulum-key.svg)

## Dye river · Why hold the open stream?

> Watch the sluice mouth when the loop slows. Which water holds its colour, and which bank keeps getting redder?

At 4 s the loop switches from 2 to 20 s per lap and the sluice and receiving stream hold their colour and ripples together. Dye keeps entering the loop. At 12 s the rivers resume full dynamics. Follow the stronger patch around the bends and watch its contrast fall before the 28 s cycle repeats. H and L mark the banks downstream of the feed and drain. The left graph shows the whole loop, including the instantaneous difference between its strongest and weakest dye concentrations.

> Now follow the white ring in the straight river nearest you. How far does a parcel carry its dye when it moves at half speed?

Clean water enters this separate 3 m river and reaches a dye tap halfway along, level with the sluice mouth in the neighbouring stream. The right graph follows the whole river, with the tap at 0 m and the outlet 1.5 m downstream. Halving the current doubles the settled concentration at the tap, halves the downstream decay length and makes the gradient just downstream of the tap four times steeper. The white ring on the graph travels with the ring on the water. On both graphs the solid curve shows the current water and the dashed curve gives the equilibrium at the slower speed. [Dye transport equations and checks](model-notes.md#river-with-gradual-exchange)

The earlier plan-view studies show the original gradual slowdown and a straight reach with a fixed feed and zero downstream decay. [Loop motion study](sketches/river.mp4) · [Straight-channel sketch](sketches/river-open.svg)

## Dye whirlpool · Do opposite sides match?

> Find A and B on opposite sides of the same spinning disk. When the exhaust freezes, does one probe turn redder than the other?

The red feed surrounds the central opening. Dye diffuses outward across the disks. Water from every angle along the rim enters a widening spiral channel, turns into the tapered exhaust and flows out through the nozzle. With the river beside it, watch what happens at 4 exhibit seconds. The open water holds its colour and reflections. The disks keep turning at one tenth speed while dye continues to diffuse. Both probes change together. At 12 s the exhaust picks up where it stopped. [Dye field, phase clocks and reference values](model-notes.md#the-dye-whirlpool)

## Bead rings · When do beads reach the wall?

Follow the bead with the white halo. Each closed ring represents a different trapped orbit in phase space. Going around it once represents a round trip between mirror turning points. A collision can change which orbit a bead occupies. Look for a bead turning white as it crosses a gap. Both inward and outward hops occur around the circumference.

![The inner ring is crowded, the outer ring is sparse and a halo follows one bead onto two semicircular passing paths.](sketches/transport.webp)

New, equal-weight beads enter the inner ring. At the edge, a collision anywhere along the adjoining half-turn can take a bead onto blue. Passing beads can scatter between blue and orange while the paths run alongside each other. The two straights lead to separate collectors. The board counts the actual beads on each ring and the arrivals at each wall. [Play or scrub the 36-second study](sketches/transport.mp4)

| Exhibit clock | What to watch |
| --- | --- |
| 0–8 s · Full dynamics | A lap takes 5 s. The halo moves from the middle ring to the outer one, then crosses to blue and orange. |
| 8–26 s · Orbit-averaged phase | A lap takes 15 s. The source and trapped collisions keep their rates. The open paths hold their samples. Beads scattered out of the trapped region increment a separate loss count. |
| 26–36 s · Full dynamics resumes | Both paths move from their held positions. The halo reaches Wall 2 at 29.34 s. The wall counts record actual arrivals. |

The solver can use larger steps during the middle phase because trapped circulation has slowed and passing motion is held. The full phase restores the physical rate for resolving escape. The rings illustrate this split with a stochastic teaching model. Four exhibit seconds represent one model second. Use **Pause** and **Next phase** on the stand to inspect either side of a switch. [Source model and checks](model-notes.md#distributed-scattering-on-the-bead-stand)
