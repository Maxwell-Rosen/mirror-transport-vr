# Exhibit 1 · The Magnetic Mirror

**Which particles turn back, and which escape through the ends?** At the pedestal, follow particle **6 (+171.4 km/s)**. Leave the speed spread, magnetic moment and potential at their opening settings. Set the mirror ratio to 1 and watch the particle cross the right-hand ring. Return the slider to the thesis mark at 31.41. The particle turns before the ring, crosses the midplane and turns at the other end. Its launch speed and magnetic moment are the same in both trials.

Show two copper-coloured throat rings in profile, eight field lines and five particles per line with short fading trails. Give each line’s particles a colour and a matching numbered point on the loss-cone plot. Colour the field line for its current launch outcome. Bright blue marks confined particles, dark blue-grey marks escaping particles and pale grey marks a launch at rest or on the boundary. The central sign identifies the **idealized particle trajectories** with charge $q=+e$ and the deuterium mass. A particle turns where its motion along the field stops and reverses. It escapes the central cell when it crosses a throat moving outward. [Gallery layout](SETTING.md)

## Double-Lorentzian field

Use physical axial position $Z$ in metres, with the midplane at zero. The two Lorentzians are centred at $\pm a$, with $a=0.98\,\mathrm{m}$. In the thesis reference geometry their width is $\gamma_*=0.124904\,\mathrm{m}$ and their amplitude parameter is $\mathcal B=6.51292\,\mathrm{T\,m}$. The reference flux is $\psi(r,Z)=r^2 F_*(Z)/2$, where

$$
L_\gamma(Z)=\frac{1}{1+[(Z-a)/\gamma]^2}+\frac{1}{1+[(Z+a)/\gamma]^2},
\qquad F_*(Z)=\frac{\mathcal B}{\pi\gamma_*}L_{\gamma_*}(Z).
$$

Set $B_0=F_*(0)=0.53062\,\mathrm{T}$. The positive peak is at $Z_t=0.97997\,\mathrm{m}$, where the field reaches $16.6649\,\mathrm{T}$. Mark the default slider position **Thesis geometry (nominal R32)** with a live ratio readout of **31.41**. Show the midplane and throat strengths in tesla beside the slider. [Thesis geometry construction](<../PhD-thesis-latex/Chapter Gkeyll Foundations/tex-files/mirror-geometry.tex>) · [Published flux model, Eq. 1](https://arxiv.org/pdf/2305.06372)

Keep $B_0$ fixed as the visitor changes the ratio $R_m=B_t/B_0$. From 3 to 50, narrow the two Lorentzians as the ratio rises, following the thesis geometry scan. For each requested ratio, solve for $\gamma$ by bisection on $[0.09,0.46]\,\mathrm{m}$, using the positive peak $Z_t=\arg\max_{Z\ge0}L_\gamma(Z)$.

$$
R_m=\frac{L_\gamma(Z_t)}{L_\gamma(0)},\qquad
F(Z)=B_0\frac{L_\gamma(Z)}{L_\gamma(0)},
\qquad \psi(r,Z)=\tfrac12 r^2 F(Z).
$$

For $1\le R_m<3$, blend the ratio-three profile $F_3$ with a uniform field using $F=B_0+(R_m-1)(F_3-B_0)/2$. This exhibit extension gives exactly straight lines at one and joins the double-Lorentzian scan continuously at three. Place the exits at the current peaks, keeping the ratio-three positions for the blend. Follow both expanders to the run boundaries at $Z=\pm2.5\,\mathrm{m}$, about 1.52 physical metres beyond each throat. The configuration-space limits and the mirror-grid limits in the input deck agree with the first and last saved physical nodes. [Run input](../gkylmax/a-thesis-simulations/1x-beams/sim.c) · [Double-Lorentzian scan inputs](../gkyl-paper-inp/2026_PRE_hts_mirror_equilibria/generate_efit/write_efit_double_lorentzian.py)

All eight lines lie on the flux surface through $r_0=0.10\,\mathrm{m}$ at the midplane, spaced at $45^\circ$ in azimuth. Compute the line radius, local field strength and arc length from the same flux. Primes denote derivatives with respect to $Z$.

$$
r(Z)=r_0\sqrt{B_0/F(Z)},\qquad
B_Z=F(Z),\qquad B_r=-\tfrac12 r F'(Z),\qquad
B(Z)=\sqrt{B_Z^2+B_r^2},\qquad \frac{ds}{dZ}=\sqrt{1+[r'(Z)]^2}.
$$

At either throat $r_t=r_0/\sqrt{R_m}$, about 1.78 cm at the default. The rings need enough clearance for the straight-field setting. Draw the model at **1.44× axial scale and 5.4× radial scale**. The display is 7.2 m tip to tip, with 2.82 m between the rings and a 54 cm midplane radius. Each flared expander extends another 2.19 m in the gallery. Label the relative radial enlargement **3.75×**. Apply the scale to finished positions, after computing physical lengths, speeds and forces.

## Launch controls and plots

| Pedestal control | Proposed range | Opening setting |
| --- | --- | --- |
| Mirror ratio $R_m$ (dimensionless) | 1–50, with a detent at the thesis geometry | 31.40658 |
| Parallel speed spread $V$ | 0–1,400 km/s | 400 km/s |
| Magnetic moment $\mu$ | 0–1.00 keV/T | 1.00 keV/T |
| Midplane potential relative to the throats $\Delta\phi$ | −5 to +5 kV, with zero at the centre | 0.0 kV |

Launch from $Z=0$ with $v_{\parallel0,i}=(2i-7)V/7$ for $i=0,\ldots,7$. At the default the four speed magnitudes are approximately 57.1, 171.4, 285.7 and 400 km/s, each launched in both directions. All five particles on a line share that line’s launch velocity and the common $\mu$. Stagger the five releases across a full bounce or a trip to the expander tip and relaunch. Round the interval to the nearest 1/60 exhibit second and cap it at 1.5 exhibit seconds so a slow trial fills promptly. Dragging changes just the selected control. The geometry, plots, launch points and trails update at each particle’s existing launch age while the gallery clock runs. **Reset** restores all four opening settings, selects particle 6 and restarts the staggered midplane releases with clear trails. Keep an escaping marker visible through the entire expander, where the model potential stays at zero. At the tip, fade it over 0.16 exhibit seconds and relaunch it at the midplane with a fresh trail. [VR and desktop bindings](CONTROLS.md)

Keep the loss-cone and potential graphs on fixed physical axes. Place the energy plot on a low floor stand to the left of the launch controls. Angle it toward the open floor in front of the mirror so the graph and the bouncing ion share one view. The speed and magnetic-moment sliders also show the corresponding midplane kinetic energies.

- **Where will each particle go?** Plot signed *launch parallel velocity* $v_{\parallel0}$ (−1,400 to +1,400 km/s) horizontally and *magnetic moment* $\mu$ (0 to 1 keV/T) vertically. Draw the boundary derived below and label the regions **turns back** and **escapes**. Plot the eight launch points on the selected $\mu$ row. At $V=0$ they coincide. Label the point **8 launches at rest along the field**.
- **What accelerates the particle?** Plot the prescribed potential $\phi(Z)=\Delta\phi[1-(Z/Z_t)^2]$ between the two rings. Label *axial position* $Z$ (m) and *electric potential* $\phi$ (kV), with a fixed −5 to +5 kV vertical scale. Both throats are at zero. Continue the curve at zero to each expander tip. A particle with charge $+e$ gains kinetic energy from the positive midplane potential as it moves outward. A negative one raises the energy needed to escape. Label this **model ambipolar potential**.

**How is the ion’s energy divided?** Select a numbered point on the loss-cone plot to trace the first marker on that line. A soft white glow falls off with distance from the coloured marker and fades with it at the expander tip. Plot parallel kinetic energy $K_\parallel=H-\mu B-q\phi$ and perpendicular kinetic energy $K_\perp=\mu B$ over the last 10 µs of physical particle time. Use eV for sub-keV trials and keV for higher energies. Show both current energies, the signed guiding-centre position and time since launch. Start a fresh trace on selection, control edits, reset or relaunch, and end each passing trace at the physical expander tip. The trace pauses with the apparatus.

## Orbit dynamics and the loss cone

Use collisionless guiding centres on the prescribed lines. Take the run’s deuterium model, $q=+e$ and $m=2.014m_p$. Compute in SI, converting keV/T to J/T, kV to V and km/s to m/s at input. For fixed controls the magnetic moment $\mu=mv_\perp^2/(2B)$ and total energy $H$ are conserved. With $s$ increasing toward positive $Z$,

$$
U(s)=\mu B(s)+q\phi(s),\qquad H=\tfrac12 m v_\parallel^2+U(s),\qquad
\dot s=v_\parallel,\qquad m\dot v_\parallel=-\mu\frac{dB}{ds}-q\frac{d\phi}{ds}.
$$

As a particle enters stronger field, its perpendicular kinetic energy $\mu B$ increases. With the potential set to zero this gain comes entirely from parallel motion. For display, advance each of the eight distinct launches once and sample its orbit at the five release times. Bracket the first reachable $H=U$, integrate the time of flight to that point, and reflect the orbit there by symmetry. A particle launched with zero parallel speed stays at the symmetric midplane. [Thesis orbit classification](<../PhD-thesis-latex/Chapter Gkeyll Foundations/tex-files/orbit-average-phase-implementation.tex>)

For each plotted $\mu$, find the highest effective potential **on the path from the midplane to the exit**. The two exits are symmetric. The two branches of the boundary are

$$
\Delta U(\mu)=\max_{0\le Z\le Z_t}\,[U(Z)-U(0)],\qquad
v_{\parallel0}=\pm\sqrt{2\Delta U(\mu)/m}.
$$

Refine interior maxima and include both endpoints. For a moving launch, a speed magnitude above the threshold escapes and one below it turns. Mark equality as **on the boundary** for a nonzero launch. The orbit and the plot must use the same field and potential. For positive $\Delta\phi$, a range of magnetic moments can have $\Delta U=0$. Every moving launch in that range escapes. Draw the two branches from the first magnetic moment with a finite barrier, leaving the zero-speed axis below their tip clear. At zero potential, $\Delta U=\mu B_0(R_m-1)$. For $R_m>1$ the boundary on this plot is the parabola $\mu=m v_{\parallel0}^2/[2 B_0(R_m-1)]$. In velocity space the same boundary is a cone about each axial direction, with half-angle $\sin^{-1}(1/\sqrt{R_m})$. At $R_m=1$ the general rule still works, including purely electrostatic trapping. At $\mu=0$ the gyro-radius vanishes.

## Playback and visible gyration

Check the clock against the **+450 km/s** reference launch with the thesis geometry, a 1,050 km/s spread, a magnetic moment of 0.25 keV/T and zero potential. Its first turn is at $Z_b=0.86424\,\mathrm{m}$. A *full bounce* returns through the midplane with the original velocity sign. In physical time,

$$
T_b=4\int_0^{Z_b}\frac{(ds/dZ)\,dZ}{\sqrt{2[H-U(Z)]/m}}
    =9.261\,\mu\mathrm{s}.
$$

Label the apparatus **“1 exhibit second = 2 µs of particle motion.”** This reference bounce takes 4.630 exhibit seconds. Keep the same clock for every launch and slider setting so changes in bounce and transit times remain visible.

Draw the gyromotion about the local field tangent with physical radius $\rho=mv_\perp/(|q|B)$ and angular frequency magnitude $\Omega=|q|B/m$. Integrate $d\theta=\Omega\,dt$ on the same physical clock as the bounce, in the positive ion’s sense of rotation. At the reference midplane this gives 8.03 turns per exhibit second. A passing ion at the throat makes 252.3 turns per exhibit second. Sample the trail between display frames to resolve its winding. At the reference midplane $\rho=4.45\,\mathrm{mm}$, about 2.4 cm at display scale. Transform the physical gyro offset with the line, and fade the last 0.2 exhibit seconds of each trail.

## Checks for the first build

- **Geometry.** Use the `data/1x-beams/` snapshot whose hashes are recorded in the tabletop manifest to verify these reference values for frame 0, time 0 s. At the positive midplane-adjacent cell centre, expect $Z=0.010876\,\mathrm{m}$ and $B=0.53087\,\mathrm{T}$. The positive peak cell has $Z=0.979165\,\mathrm{m}$ and $B=16.66235\,\mathrm{T}$. These are cell-centre evaluations of the saved linear DG field in `zzim-geo_int_bmag.gkyl`, paired with `zzim-geo_corn_mc2nu_pos_deflated.gkyl`. Check the default model at those same physical coordinates to within 0.1%. Cross-check radii against `zzim-geo_corn_nodes.gkyl`, which gives 0.10000 m at the midplane node and 0.01785 m at the node nearest the positive throat. At the expander tips, the saved nodes at $Z=\pm2.5\,\mathrm{m}$ have radius 0.19998 m. The adjacent field cells are centred at $|Z|=2.4875\,\mathrm{m}$ with field strength 0.13563 T. Record these files, `sim.c`, the analytic slider formula and the display scaling in the exhibit manifest. The launch points, potentials and trajectories are analytic exhibit settings. [Tabletop manifest](museum/mirror/reference/manifest.json) · [Simulation data workflow](PLAN.md#platform-and-simulation-data)
- **Orbits and plot.** At the opening settings the escape threshold is 1,238.8 km/s. All eight launches turn. Reducing the magnetic moment to the 0.25 keV/T calibration value lowers the threshold to 619.4 km/s. With straight lines and zero potential, every moving launch escapes. With the reference geometry, $\mu=0.25\,\mathrm{keV/T}$ and $\Delta\phi=+4\,\mathrm{kV}$, the barrier is about 0.097 keV at $Z=0.964\,\mathrm{m}$. Set $V=490$ km/s and follow the +70 km/s particle. It turns at $Z=0.950\,\mathrm{m}$. A throat-only comparison would incorrectly predict escape.
- **Timing and interaction.** On desktop, check ten full reference bounces for less than 0.1% drift in energy relative to the launch kinetic energy, turns within 1 mm of the predicted position and a 4.630-exhibit-second return within 1%. Verify the same resets and slider releases with a controller ray. Keep the controls readable from a chair. Start the orbit clock when the visitor crosses the painted threshold into the gallery or teleports inside. Verify that the clock runs at both axial viewpoints and pauses with the trails when the visitor returns to the atrium. Resume the same trial on re-entry. Check the active display with all 40 markers against the sustained 72 fps Quest 3 target.
