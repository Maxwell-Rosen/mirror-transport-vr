# Gallery 2 model notes

The [exhibit plan](exhibit-2-POA.md) gives the visitor sequence and playback studies. These settings support the scientific labels and the later build.

## Distributed scattering on the bead stand

Radius labels an orbit in phase space. Angle measures progress through one bounce. The bead positions are a stochastic illustration of the thesis phase split, with a source on the innermost orbit and losses on open trajectories. The thesis's layered mirror model motivates the inner source. Its proposed two-dimensional model motivates the closed and open contours. The probabilities and counts below belong to the exhibit. [POA algorithm](<../../PhD-thesis-latex/Chapter POA Toy Models/tex-files/algorithm.tex>) · [Layered orbits](<../../PhD-thesis-latex/Chapter POA Toy Models/tex-files/layered_tandem_models.tex>) · [Combined model](<../../PhD-thesis-latex/Chapter POA Toy Models/tex-files/compare_contrast.tex>)

| Setting | Value |
| --- | --- |
| Tabletop radii, inner to outer | 0.38, 0.58 and 0.78 m trapped, 0.92 m blue, 1.06 m orange |
| Passing geometry | Both paths span −π to 0 radians, then turn onto a 2.25 m straight tangent to the semicircle |
| Feed | 2.32 equal-weight beads per model second, uniformly in phase on the inner ring |
| Collision clocks | 0.208 per model second per neighbouring trapped ring, 0.64 from the outer ring to blue where adjacent, 1.40 each way between blue and orange on their bends |
| Playback and ensemble | 4 exhibit seconds per model second, seed 236, 900 model seconds of full-dynamics warm-up |
| Phase schedule | 0–8 exhibit s full, 8–26 s orbit-averaged, 26–36 s full. Full lap 5 s, slowed lap 15 s. |
| Passing motion | 0.72 radians per active exhibit second on each bend, then 0.72 m per active exhibit second on the straight |

Each independent collision clock is exponential while a bead is available to scatter. Ring-to-ring attempts can occur at any orbital phase. An outer-to-blue attempt is accepted along their common half-turn. A transfer takes 0.65 exhibit seconds with a smooth interpolation between the two moving contours. In the live counts a bead belongs to its departure ring until it completes the crossing. No new collision is drawn during a transfer. The tilted display preserves the calculated tabletop distances. [Native paths and clocks](tools/planar_models.py) · [Export manifest](../simulation-renders/gallery-2/manifest.json)

During the orbit-averaged phase the trapped collision clocks and the source keep running. The open-path clock stops, including any transfer already in progress between blue and orange. A trapped bead scattered out during the hold ends at the boundary halfway to blue. Each such loss increments **Left rings during hold**. A wall counter increments when a passing bead reaches the end of its straight. Both passing motion and passing collisions resume at full rate after release.

The source and absorbing edge produce a density gradient. In the opening frame the ring counts from the centre outward are **34, 24 and 10**. At 17 s they are **41, 19 and 6**. Wall 1 and Wall 2 hold at **6 and 1** throughout the long phase, with 17 trapped losses accumulated by release. Bead 2078 carries the halo. It completes the transfer to orange at 7.595 s, holds at tabletop coordinates (−0.16714, −1.04674) m and reaches Wall 2 at 29.345 s. [Godot coordinate, population and control checks](tools/check_bounces.gd)

## Pendulum and mirror clocks

The signed angle is $q=10^\circ e^{-s}\cos(2\pi\,16\beta s)$ with $s=t/\tau_d$. The two phase rates use $\beta=1$ and $1/4$. Sixteen exhibit seconds represent one damping time. At $s=3/8$ the two angles are $+6.873^\circ$ and $-6.873^\circ$. At $s=1$ the envelope on each scale is $10^\circ/e=3.679^\circ$. In the long-time limit both angles tend to zero. The bobs and graph pens evaluate this prescribed mode at the same instant. [Pendulum model](game/pendulum_motion.gd)

For the time-step example, fix the angular resolution at eight steps per cycle. The periods are 1 and 4 exhibit seconds, so $\Delta t=T/8$ gives 0.125 and 0.5 s. Advancing one damping time takes 128 or 32 such steps. The plotted strokes sample the analytic curves more finely for drawing. In the mirror analogy one bounce average uses the time spent at each place, $\langle g\rangle_b=T_b^{-1}\oint g\,dt$. The retained slow evolution is accurate to leading order when the slowed orbit still explores the source and loss regions rapidly compared with their damping times. [Thesis orbit averaging](<../../PhD-thesis-latex/Chapter POA Toy Models/tex-files/algorithm.tex>)

## River with gradual exchange

**Loop and sluice.** The river table repeats every 28 exhibit seconds. At 4 s the loop switches from $w=0.5$ to $0.05$ turns/s and the passing stream and sluice freeze. At 12 s both resume full dynamics. Write $q$ for position in turns and $F=f/f_*$ for normalized dye concentration. A raised cosine $g(z)=[1-\cos(2\pi z/b)]/b$ of width $b=1/4$ gives a feed $g_s$ starting at $q=0$ and a drain $g_d$ starting at $q=1/2$. Each integrates to one. Dye mixes along the loop according to

$$
\partial_t F+w(t)\partial_q F=D\partial_{qq}F+k(g_s-g_d F),
\qquad D=0.006\ {\rm turns^2/s},\quad k=0.01\ {\rm s}^{-1}.
$$

Dye accumulates near the feed during the orbit-averaged phase. After release, the excess circulates and disperses. Dispersion alone damps the longest spatial harmonic on a time scale $1/(4\pi^2D)=4.22$ s. The displayed maximum minus minimum is about 0.022 on entering OAP, 0.205 at release, and 0.047 eight seconds later. The bank probes sample $q=0.375$ (H) and $0.875$ (L). The dashed line is the stationary solution at the slow speed. The original point-source ring motivates the localized feed and drain. [Thesis continuum ring](<../../PhD-thesis-latex/Chapter POA Toy Models/tex-files/fiveeq_locS_locL.tex>)

In active passing time $a$, a well-mixed sluice with residence time $\tau_g=0.5$ s obeys $\tau_g\,dB/da=\int g_d F\,dq-B$. Its outflow feeds the middle of the receiving channel. The downstream signal is $B(a-\Delta q/v)$ with $v=0.25$ channel lengths per active second. A half-cosine mixing strip spans the upstream half of the physical opening. The sluice lip samples the same receiving-bank coordinate along its entire width. During OAP the passing clock stops while the loop's feed and sink continue. A full cycle returns the concentrations, wave crests and marked parcel to their initial positions.

**Independent straight river.** The front channel is 3 m long with constant cross-section $A$. Its tap sits opposite the sluice mouth and defines $x=0$. Clean water flows from $x=-1.5$ m to the tap, where dye enters a well-mixed pool of volume $V$ at mass rate $J$. Dye decays between the tap and the outlet at $x=+1.5$ m at first-order rate $\lambda$. For constant speed $u$, steady flux balance at the tap gives $AuC(0)=J$. Along a dyed parcel, $dC/dt=-\lambda C$ and $dx/dt=u$. For $x\geq 0$,

$$
C(x)=\frac{J}{Au}e^{-\lambda x/u},\qquad
\ell=\frac{u}{\lambda},\qquad
\left.\frac{dC}{dx}\right|_{0^+}=-\frac{\lambda J}{Au^2}.
$$

With $J/(A C_*)=0.6$ m/s and $\lambda=0.5$ s⁻¹ the two steady profiles have directly measurable differences.

| Speed | Tap $C(0)/C_*$ | Decay length $\ell$ | Slope just downstream of tap in $C_*/\mathrm{m}$ | Outlet $C(1.5)/C_*$ |
| --- | --- | --- | --- | --- |
| 1 m/s | 0.60 | 2 m | −0.30 | 0.283 |
| 0.5 m/s | 1.20 | 1 m | −1.20 | 0.268 |

During playback the speed changes at the same instants as the loop. The finite mixing volume at the tap, $V/A=1$ m, makes its colour rise and fall continuously according to $V\,dC_{\rm in}/dt=J-Au(t)C_{\rm in}$. Each downstream parcel at $(x,t)$ crossed the tap at $t_i$ with $\int_{t_i}^t u(s)\,ds=x$. Its current concentration is $C_{\rm in}(t_i)e^{-\lambda(t-t_i)}$. The water and the solid graph sample this transient. The white ring follows a parcel from tap to outlet in both views. At half speed a parcel spends twice as long in each metre of river.

The exporter solves for a repeating cycle, checks the loop against a finer integration and checks the straight river against the characteristic from its inlet. The saved texture covers 129 positions per channel every 0.05 s, with an identical closing frame. The final row supplies the steady references. [Model](tools/river_model.py) · [Export and numerical checks](tools/export_gallery.py) · [Asset manifest](../simulation-renders/gallery-2/manifest.json)

## The dye whirlpool

The whirlpool is an annular dye-transport teaching model. Its central opening has radius $a=0.20R$. The inner rim supplies dye uniformly in angle, and the entire outer rim leaks into the spiral collector. The model starts on a repeating cycle with the same azimuthal symmetry. Slowing circulation therefore creates no concentration difference around a disk. A radial gradient drives dye from the source to the rim in both phases. The thesis analyzes the corresponding distributed source and distributed coupling on a trapped orbit. [Thesis model](<../../PhD-thesis-latex/Chapter POA Toy Models/tex-files/fiveeq_distS_distL.tex>)

Use $c=C/C_*$ for normalized dye concentration, $s=r/R$ for normalized radius, and $t$ in exhibit seconds. On $0.20\le s\le 1$ the field obeys

$$
\partial_t c=\frac{D}{s}\partial_s(s\,\partial_s c),\qquad
c(0.20,t)=0.73+0.26\sin(2\pi t/28),\qquad
-D\,\partial_s c(1,t)=k\,c(1,t).
$$

Here $D=0.085$ and $k=0.055$ per exhibit second in normalized coordinates. The open channel collects equal water inflows per unit angle, mixes them across its width and advects the mixture out of the nozzle. A trip takes 5 active seconds. Dye circles the rim for the first 3.125 and spends the last 0.25 in the falling sheet between nozzle and drain. From 4 through 12 exhibit seconds the open clock holds. The disks slow from 2 to 20 seconds per lap while the boundary conditions and radial diffusion keep their rates. On release, collection resumes from the current rim.

| Exhibit time (s) | Central feed $c$ | A and B at $r/R=0.60$ | Outer rim $c$ | Outlet $c$ |
| --- | --- | --- | --- | --- |
| 4 | 0.933 | 0.519 | 0.369 | 0.296 |
| 8 | 0.983 | 0.606 | 0.445 | 0.296 |
| 12 | 0.843 | 0.595 | 0.455 | 0.296 |
| 18 | 0.527 | 0.432 | 0.346 | 0.419 |

The exporter checks the packed frames against a four-times finer radial solution, the rim flux and an independent reconstruction of the parcels at the outlet. Godot samples the two physical probes and the colour field from that same lossless atlas. The plaque reports normalized concentration. Its water reflections mark motion. The wall board compares both water sculptures at release, dividing each lap by its own mean. [Dye model](tools/whirlpool_model.py) · [Export checks](tools/export_gallery.py) · [Packaged data](../simulation-renders/gallery-2/manifest.json)

## Optional velocity cut in the transport stand

After the main sculptures are readable, fit a shallow numerical relief into the side of the particle stand underneath the rings. Label it **Velocity cut · 1D thesis toy model**. The axes are velocity coordinate $v/L_v$ across the base, model time $tD/L_v^2$ into its depth and distribution $f/(SL_v^2/D)$ as height. An automatic straightedge sweeps the direct RK4 and POA reliefs on identical axes. Mark the boundary at $a/L_v=0.9$ and pin two actual grid centres near $v/L_v=0.45$ and $0.912$. Pause the sweep at the first phase switch. The inner pin has risen. In the short full phase the outer pin lifts for the first time. Give that interval a time magnifier labelled with its endpoints and magnification.

**Label on the relief · How far past the edge do particles get?**

> Collisions spread particles across the seam. On the far side they can still diffuse while they stream away. The diffusion coefficient $D$ and the escape rate $\nu_\parallel$ set the width of this edge. Watch the ruler. If escape takes 100 times longer, how much wider will it grow?
>
> $$\text{Characteristic width in velocity}\qquad \ell_v=\sqrt{D/\nu_\parallel}$$

Use the thesis's diffusion and loss equation with reflecting boundary $f_v(0)=0$, absorbing boundary $f(L_v)=0$, and initial $f=0$. The step functions $H$ place the source below $a$ and the streaming loss above it. Velocity is the only coordinate in this model. In the OAP the trapped side keeps its diffusion and source, using the held neighbour across the seam.

$$
\partial_t f=D\,\partial_v^2 f+S H(a-v)-\nu_\parallel H(v-a)f .
$$

Use $D=S=L_v=1$, $\nu_\parallel=10^5$, velocity spacings $1/10$ and $1/300$ on the trapped and passing sides, $\tau_O D/L_v^2=5$ and $\tau_F\nu_\parallel=5$ ($\alpha=0.002$ in the OAP step estimate). Put the seam on a cell face and export to $tD/L_v^2=20$. For the ruler, overlay a separately labelled **Changed physical loss rate** equilibrium at $\nu_\parallel=10^3$. Its characteristic width grows from $0.00316L_v$ to $0.0316L_v$. Slowing escape everywhere would predict this wider tail and too much trapped plasma. Compute both analytic overlays with the finite absorbing boundary. The thesis's exponential tail applies when the boundary is many widths from the seam. [Thesis 1D model and figure settings](<../../PhD-thesis-latex/Chapter POA Toy Models/tex-files/oneD_toy_model.tex>) · [Matching nonuniform-grid figure notebook](<../../POA-toy-model-paper/figures/paper_oneD-numerical-solve-compare.ipynb>)

## Checks for the physical build

- **The 1D relief.** Check the saved grid centres, phase switches and values against an independent integration on the same nonuniform grid. The outer pin is at $v/L_v=0.911666\ldots$. For the $10^5$ loss rate the continuum equilibrium at the two pins is $0.306596$ and $7.11196\times10^{-5}$. Check convergence of the discrete solution under refinement.
- Check the ring faces and playback controls at standing and seated heights. Measure sustained 72 fps on the headset. Record any future simulation exports with source diagnostic, coordinates, time, transformation and independent value checks. [Asset guide](../simulation-renders/README.md)

Rebuild the plan-view bead study with `python gallery-2/tools/animate_studies.py transport`. The renderer uses NumPy, Pillow, DejaVu fonts and FFmpeg. The earlier five-sample study has its own notes and exporter. [Five-sample reference](studies/five-sample/README.md)
