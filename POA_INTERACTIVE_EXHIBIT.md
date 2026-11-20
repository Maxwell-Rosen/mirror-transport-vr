# Exhibit 2 · Between Bounces

**Can you predict how much plasma escapes without computing every bounce?** Three marks on a closed orbit and two on a path to the wall are enough to try. At the pedestal, pin the outlet gauge and predict which readings will move when you advance the solver. Then move the plasma source to a different point on the orbit. A shortcut that worked with evenly distributed feeding now overestimates the distribution at one of the marks.

## The sculpture

Sign the first gallery on the right, opposite **The Magnetic Mirror**, with **2 · Between Bounces** and **Pseudo-orbit averaging (POA)** beneath it. Through the 4 m opening, visitors see a bronze rod running diagonally through an open cubic frame. A point with a short trail winds around the rod. Set the frame about 4 m inside the room on a waist-high plinth. Keep a level route around it, a seated viewpoint facing the controls, and a clear view back to the atrium. [Museum layout](SETTING.md) · [First mirror](INTRO_MIRROR_INTERACTIVE.md)

On the sloping face of the plinth, engrave a closed orbit with three numbered studs and an open path with two studs and an arrow to the wall. Label this **Schematic mirror phase space**, with axial position $z$ across the engraving and signed parallel velocity $v_\parallel$ up it. The studs mark places to sample the distribution. Select one and its matching axis or gauge lights up.

Inside the frame, the three perpendicular axes give the distribution at the **three trapped-orbit samples**, $f_{o1},f_{o2},f_{o3}$. One point locates all three readings at once. The bronze diagonal is where the readings are equal. A collar on it marks their mean, $\bar f_o=(f_{o1}+f_{o2}+f_{o3})/3$. A thin spoke joins the collar to the point. Two adjacent gauges show $f_{t1}$ at the entrance to the passing path and $f_{t2}$ farther downstream. Give the gauges their own labelled scale so the small escaping population is visible. At each full-phase endpoint, also show **Exhaust as a fraction of supply**, $\nu_\parallel f_{t2}/(3S)$. A reading of 1 means as much leaves as enters.

Drag the frame's rim to turn the sculpture. **Look down the rod** brings the fast rotation face-on. **Look from the side** reveals how far the collar has travelled as the source fills the orbit and collisions scatter particles out. The visitor stays on the floor in both views. The point traces the evolution of a distribution. The engraved paths show where its five values come from.

## Three experiments at the pedestal

1. **Catch the outlet holding still.** Start with equal feeding and collisional coupling at all three orbit studs and a small excess at stud 1. Play a direct calculation (white line) alongside POA (copper, with step markers). Stop at the end of the first full dynamics phase. Pin the copper outlet gauge at its current, nonzero height. Press **Next phase**. The copper point moves and its mean rises, while the gauge sits exactly on the mark. Step into full dynamics and the outlet moves again. The same model clock drives both traces.
2. **Count the steps to the same time.** Select **Run to equilibrium**. The rates are now far enough apart that drawing every turn would hide the result. Show the saved phase endpoints, the analytic equilibrium marks on all five scales, and each solver's step count. In the thesis's uniformly fed case, direct fourth-order Runge–Kutta (RK4) takes **1,506,140 steps** to reach $t\nu_c=20$. POA takes **40**. Let visitors select the outlet to inspect its relative error as well as the error in the trapped mean. Label the counter **RK4 steps to this model time**. [Thesis uniform-source experiment](<../PhD-thesis-latex/Chapter POA Toy Models/tex-files/fiveeq_distS_distL.tex>)
3. **Move the source.** Concentrate the collisional coupling at stud 1. Give the visitor a source handle with two sockets. Feed stud 1, then move the same source to stud 2 and replay. With separated feeding and loss, the slow orbital motion during a long phase gives stud 3 an excess that is visible as a spoke extending away from the diagonal. Try a tenfold increase in the advection factor $\alpha$. The excess shrinks and the step count rises. Then try **Average the three trapped samples** at the original $\alpha$. The projected point lands on the diagonal, keeping its mean. Compare the next full-phase readings with the direct solution. [Thesis localized-source experiments](<../PhD-thesis-latex/Chapter POA Toy Models/tex-files/fiveeq_locS_locL.tex>)

## Text for the gallery walls

**Entrance wall · Why average a bounce?**

> A trapped ion can cross the mirror many times before a collision puts it on a path to the wall. Average a reading $g$ over one complete bounce of duration $T_b$. Places where the ion spends longer count more. A passing particle reaches the wall before it can complete a return trip.
>
> $$\langle g\rangle_b=\frac{1}{T_b}\oint g\,dt$$

**Wall beside the rod · What does a turn preserve?**

> Look down the rod. Fast motion carries an excess from one orbit sample to the next. Add the three *changes* caused by that motion and they sum to zero. Now look from the side. Feeding and scattering can move the mean along the rod. Can you follow the mean while taking fewer turns?

**Wall facing the phase control · What changes in a long step?**

> **Full dynamics phase (FDP).** Take small steps everywhere. Trapped particles bounce, collisions scatter them, and passing particles stream out. Following every turn sets a short time limit on each step.
>
> **Orbit-averaged phase (OAP).** Slow the fast motion on trapped orbits by a factor $\alpha$. Keep feeding and collisions at their original rates there. Hold the passing distribution at its last value. Larger steps can now follow the slow change. Return to full dynamics to update the outlet.
>
> $$\mathrm{FDP}\quad \partial_t f=A(f)+C(f)+S$$
>
> $$\mathrm{OAP}\quad \partial_t f=H_{\rm orbit}\,[\alpha A(f)+C(f)+S]$$
>
> $A$ transports the distribution $f$ along trajectories, $C$ scatters particles, and $S$ supplies them. The mask $H_{\rm orbit}$ is 1 on trapped orbits and 0 on passing paths. The accelerated trace shows a calculation approaching equilibrium. Read the direct trace to follow the timing of individual oscillations.

In the thesis derivation, integrating $\partial f/\partial\theta$ around the closed orbit gives $f(2\pi)-f(0)=0$. To leading order the orbit mean therefore evolves on the slow timescale. Reducing the orbital rate still permits this averaging when the reduced rate is much faster than scattering. With uniform feeding and coupling, the benchmark can push the two rates as far as equality. When feeding and loss occur at different sites, the time taken to carry particles between them matters. Baseline POA alternates the two equations. The **Average** button adds the separate operation of explicitly averaging around a trapped orbit. [Thesis derivation](<../PhD-thesis-latex/Chapter POA Toy Models/tex-files/algorithm.tex>) · [Rosen, Francisquez and Hammett, §2](https://arxiv.org/html/2604.00121v3#S2)

**Return wall · How does this become a mirror calculation?**

> The thesis solver, Gkeyll, works on a grid in position and velocity. It checks whether a trajectory from each corner of a cell can reach a wall. A cell advances in the long phase only when every corner is trapped. In full dynamics the passing cells can empty through the ends again.

Beside this sign, draw one grid cell straddling the trapped/passing boundary. Mark the passing corner and hatch the whole cell to show what Gkeyll holds. [Thesis implementation](<../PhD-thesis-latex/Chapter Gkeyll Foundations/tex-files/orbit-average-phase-implementation.tex>)

## Equations and settings for the sculpture

Use the five-equation toy model. Write $o_i=f_{oi}$, $p_j=f_{tj}$ and wrap the orbit indices cyclically. The fast rate $\nu_\parallel$ controls circulation and exhaust. Each orbit sample has a source $S_i$ and a slow collisional coupling rate $\nu_{ci}$ to the first passing sample. In full dynamics,

$$
\begin{aligned}
\dot o_i &= -\nu_\parallel(o_{i+1}-o_{i-1})+\nu_{ci}(p_1-o_i)+S_i,\\
\dot p_1 &= -\nu_\parallel p_1+\sum_{i=1}^{3}\nu_{ci}(o_i-p_1),\\
\dot p_2 &= \nu_\parallel(p_1-p_2).
\end{aligned}
$$

In the OAP multiply only the first term in $\dot o_i$ by $\alpha$ and set $\dot p_1=\dot p_2=0$. The held $p_1$ still enters the orbit equations. In the FDP, summing all five derivatives gives $\sum_i S_i-\nu_\parallel p_2$. At full equilibrium the exhaust $\nu_\parallel p_2$ balances total injection. [Thesis five-equation model](<../PhD-thesis-latex/Chapter POA Toy Models/tex-files/five_equation_toy_model.tex>)

With only orbital advection, $\dot{\mathbf o}=\nu_\parallel(1,1,1)\times\mathbf o$. The point rotates about the diagonal at angular frequency $\sqrt{3}\nu_\parallel$, keeping both its mean and its distance from the rod fixed. Slowing that term multiplies the angular frequency by $\alpha$. Fit the axes to both traces together for each trial and lock them during playback. Use equal scales on the three axes. To check the direction, a pure-advection point starting at $(1.2,0.9,0.9)$ must reach $(0.9,1.2,0.9)$ after a third of a turn, with the collar at 1 throughout.

Label the axes and probes **Distribution / $f_*$**, with $f_*=S/\nu_c$ the nominal per-stud source divided by the nominal coupling rate. Label time **Elapsed collision times $t\nu_c$**. Use $S=\nu_c=1$ in toy units. Start with $o_1/f_*=0.005$ and the other four values zero. Cycle OAP then FDP.

| Trial | Rates and phase lengths | What to render |
| --- | --- | --- |
| Catch the outlet | $S_i=S$, $\nu_{ci}=\nu_c$, $\nu_\parallel/\nu_c=10^3$, $\alpha=0.1$, $\tau_O\nu_c=1/180$, $\tau_F\nu_\parallel=1.4\pi$ | One exhibit second advances $0.001$ collision times. A full-rate turn takes 3.63 exhibit seconds. End at $t\sqrt{3}\nu_\parallel=50$. Include signed ticks for the early oscillations. |
| Count the steps | Same distributed source and coupling, $\nu_\parallel/\nu_c=10^5$, $\alpha=\nu_c/(\sqrt{3}\nu_\parallel)$, $\tau_O\nu_c=5.5$, $\tau_F\nu_\parallel=4.7\sqrt{3}$ | Compare at $t\nu_c=20$. The full equilibrium is $o_i/f_*=1.00003$ and $p_1/f_*=p_2/f_*=0.00003$. Show the maximum fractional error across all five samples. |
| Move the source | Same fast rate and phase lengths as the count trial. Set $\nu_{c1}=3\nu_c$, supply $3S$ at the selected stud, and set the other couplings and supplies to zero. Start at $\alpha=10\sqrt{3}\nu_c/\nu_\parallel$. | Run to $t\nu_c=50$. With the source at 2, the stationary unprojected gap is $o_3-o_1=3S/(\alpha\nu_\parallel)$ in the OAP and $3S/\nu_\parallel$ in the FDP. These are reference marks for relaxed phases. |

Use the thesis's RK4 step estimate $\Delta t=c/(\max_i\nu_{ci}+\beta\sqrt{3}\nu_\parallel)$ with $\beta=1$ in the FDP and $\beta=\alpha$ in the OAP. Use $c=1$ for the short trial and $2.3$ for the long trials. Shorten the last step at a phase boundary or the requested end time. For **Average**, project the three orbit values to their arithmetic mean at the intermediate OAP RK4 stages and at the completed step. Keep baseline trials unfiltered. [Short and long trial inputs](<../PhD-thesis-latex/Chapter POA Toy Models/scripts/paper_fiveeq_time_evolution_demonstration_distS_distLoss.ipynb>) · [Stage-wise projection in the authors' figure code](<../POA-toy-model-paper/figures/module_fiveeq_POA_counterlocLoss.py>)

## The velocity bench

Give the second thesis toy model a low table along the far wall. Cast its solution as a relief with **velocity coordinate $v/L_v$** across the table, **model time $tD/L_v^2$** into its depth and **distribution $f/(SL_v^2/D)$** as height. Drag a straightedge through time to lift out one profile. Switch between direct RK4 and POA on identical axes. Inlay the trapped/passing boundary in the base at $a/L_v=0.9$. Snap two pins on opposite sides, near $v/L_v=0.45$ and $0.912$. On the POA relief, stop the straightedge at the first phase switch. The inner pin has already risen. Advance through the short full phase to see the outer pin lift for the first time. Give that interval a time magnifier labelled with its endpoints and magnification.

**Wall above the bench · How far past the edge do particles get?**

> Collisions spread particles across the seam. On the far side they can still diffuse while they stream away. The diffusion coefficient $D$ and the escape rate $\nu_\parallel$ set the width of this edge. Fit the ruler to it. If escape takes 100 times longer, how much wider will it grow?
>
> $$\text{Characteristic width in velocity}\qquad \ell_v=\sqrt{D/\nu_\parallel}$$

Use the thesis's diffusion and loss equation with reflecting boundary $f_v(0)=0$, absorbing boundary $f(L_v)=0$, and initial $f=0$. The step functions $H$ place the source below $a$ and the streaming loss above it. Velocity is the only coordinate in this model. In the OAP the trapped side keeps its diffusion and source, using the held neighbour across the seam.

$$
\partial_t f=D\,\partial_v^2 f+S H(a-v)-\nu_\parallel H(v-a)f .
$$

Use $D=S=L_v=1$, $\nu_\parallel=10^5$, velocity spacings $1/10$ and $1/300$ on the trapped and passing sides, $\tau_O D/L_v^2=5$ and $\tau_F\nu_\parallel=5$ ($\alpha=0.002$ in the OAP step estimate). Put the seam on a cell face and export to $tD/L_v^2=20$. For the ruler, overlay a separately labelled **Changed physical loss rate** equilibrium at $\nu_\parallel=10^3$. Its characteristic width grows from $0.00316L_v$ to $0.0316L_v$. Slowing escape everywhere would predict this wider tail and too much trapped plasma. Compute both analytic overlays with the finite absorbing boundary. The thesis's exponential tail applies when the boundary is many widths from the seam. [Thesis 1D model and figure settings](<../PhD-thesis-latex/Chapter POA Toy Models/tex-files/oneD_toy_model.tex>) · [Matching nonuniform-grid figure notebook](<../POA-toy-model-paper/figures/paper_oneD-numerical-solve-compare.ipynb>)

## Building and checking the room

- **First playable version.** Build the five-sample sculpture, both uniform trials and the phase wall first. Add the movable source and the velocity bench next. Use one Godot 4 scene and the same offline-generated histories on desktop and Quest 3. Label both instruments **Thesis toy model**. Package the export script and a manifest with each toy run's ID, source file and revision, diagnostic, parameters, initial state, grid or stud, solver and phase schedule, saved step and time, normalization and display scales.
- **Playback and controls.** Point and click or squeeze the trigger. Drag with the button held. Give the frame, source sockets and straightedge single-click presets within seated reach. **Reset** replays the current case. A parameter change loads a fresh matched pair. Pause on leaving the room. Hold **Home** on desktop or left **X** on Quest to return to the foyer. Show the current case, method, phase, model time, playback rate and any zoom at the instrument. Mark computed states and label joins as interpolation. Preserve phase boundaries and held values when reducing trails for display. [Museum controls](CONTROLS.md)
- **Check the sculpture against the equations.** In the short trial, $p_2/f_*$ reaches $2.74582\times10^{-5}$ at the first FDP end, $t\nu_c=0.009953785$, and has the same value at the next OAP end, $0.015509341$. In the count trial, reproduce both step counts and check that the largest fractional error of the five POA values at $t\nu_c=20$ is below $3\times10^{-7}$. With the separated source, the stationary gap at the starting $\alpha$ is $0.173205f_*$ versus $0.00003f_*$ at full rate. Check the raw arrays and the values picked from the rendered sculpture. An independent linear-system solve gives the equilibrium marks.
- **Check the bench at its actual coordinates.** Compare each pinned value and the switch times with an independent integration on the same nonuniform grid. Label the outer pin by its saved centre, $v/L_v=0.911666\ldots$ (rounded to $0.912$ in the thesis figure). For the $10^5$ loss rate the *continuum* equilibrium overlay should read $0.306596$ at the inner pin and $7.11196\times10^{-5}$ at the outer pin, in the displayed units. Compare the discrete solution to that curve under mesh refinement.
- **Try it with a visitor.** From a chair, can they pin the downstream gauge, predict when it will move, and show a case where taking a larger step costs accuracy? Repeat with mouse and controller. On Quest 3, check label legibility and sustained native 72 fps through ten minutes of rotating, probing and replaying the busiest view.
