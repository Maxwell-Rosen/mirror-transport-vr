# Five-sample pedestal study

This folder preserves the former Gallery 2 pedestal, its five-equation reference data and design notes. Rebuild the stored readings with `python gallery-2/tools/export_five_sample.py`. [Provenance](manifest.json)

## Interactive pedestal · Pin the outlet

**Can the trapped population grow while the outlet reading stays exactly where you marked it?** Give visitors five fixed sampling sites and five matching gauges. Start with the diagram on the sloping face, then put the gauges immediately above it. Pressing a stud highlights the matching gauge. The three green sites lie on one closed orbit. The other two sample **successive places on a single path** to the wall. P2 is the downstream site.

![A map from three fixed sites on the same closed orbit and two consecutive sites on one passing path to their five gauges.](../../sketches/pedestal-map.svg)

> Pin the purple bar. Take one long step. Check your mark, then look at the three orbit gauges. Now take a full step. When does the outlet first move away from your mark?

![Three stills with a common outlet scale. Pin 2.7458, hold 2.7458 as the trapped mean rises, then read 5.6879 after a full step.](../../sketches/pedestal.svg)

![The five gauges through the pin, hold and release sequence. The passing bars carry their own magnified scale.](../../sketches/pedestal-readings.webp)

The pin records the visitor’s reference reading. The calculation holds both passing values throughout the orbit-averaged phase (OAP), while trapped advection slows and collisions and feeding continue. In the full dynamics phase (FDP) all five sites evolve. The passing scale is magnified by $10^5$ and labelled at the gauges. Read exhaust at a full-phase endpoint as the physical streaming rate times P2. The earlier cube put a single dot at $(O1,O2,O3)$ to encode three simultaneous readings. Its diagonal meant all three agreed. The face now shows each reading and their arithmetic mean directly. [Play or scrub the gauges](../../sketches/pedestal-readings.mp4) · [Model equations and trial settings](#reference-settings-for-the-five-sample-demo)

Keep **Pin**, **Next phase** and **Reset** within seated reach. Use click or controller trigger and provide Tab and Enter on desktop. After this trial, **Count the steps** compares direct integration and POA at the same model time. **Move the source** lets visitors separate feeding from loss, inspect the spread between the three orbit gauges, and compare with explicit orbit averaging. [Benchmarks and verification](#reference-checks)

## Reference settings for the five-sample demo

Use the five-equation toy model. Write $o_i=f_{oi}$, $p_j=f_{tj}$ and wrap the orbit indices cyclically. The fast rate $\nu_\parallel$ controls circulation and exhaust. Each orbit sample has a source $S_i$ and a slow collisional coupling rate $\nu_{ci}$ to the first passing sample. In full dynamics,

$$
\begin{aligned}
\dot o_i &= -\nu_\parallel(o_{i+1}-o_{i-1})+\nu_{ci}(p_1-o_i)+S_i,\\
\dot p_1 &= -\nu_\parallel p_1+\sum_{i=1}^{3}\nu_{ci}(o_i-p_1),\\
\dot p_2 &= \nu_\parallel(p_1-p_2).
\end{aligned}
$$

In the OAP multiply only the first term in $\dot o_i$ by $\alpha$ and set $\dot p_1=\dot p_2=0$. The held $p_1$ still enters the orbit equations. In the FDP, summing all five derivatives gives $\sum_i S_i-\nu_\parallel p_2$. At full equilibrium the exhaust $\nu_\parallel p_2$ balances total injection. Artificially slowing the open path as well would require $1/\alpha$ times the passing concentration to carry that same supply to the wall. [Thesis five-equation model](<../../../../PhD-thesis-latex/Chapter POA Toy Models/tex-files/five_equation_toy_model.tex>)

For a check of the direction of circulation, switch off the source and collisions. The three trapped derivatives then sum to zero. A pure-advection state starting at $(1.2,0.9,0.9)$ reaches $(0.9,1.2,0.9)$ after a third of a turn, with mean 1 throughout.

Label the gauges and probes **Distribution / $f_*$**, with $f_*=S/\nu_c$ the nominal per-stud source divided by the nominal coupling rate. Label time **Elapsed collision times $t\nu_c$**. Use $S=\nu_c=1$ in toy units. Start with $o_1/f_*=0.005$ and the other four values zero. Cycle OAP then FDP.

| Trial | Rates and phase lengths | What to render |
| --- | --- | --- |
| Catch the outlet | $S_i=S$, $\nu_{ci}=\nu_c$, $\nu_\parallel/\nu_c=10^3$, $\alpha=0.1$, $\tau_O\nu_c=1/180$, $\tau_F\nu_\parallel=1.4\pi$ | One exhibit second advances $0.001$ collision times. A full-rate turn takes 3.63 exhibit seconds. End at $t\sqrt{3}\nu_\parallel=50$. Include signed ticks for the early oscillations. |
| Count the steps | Same distributed source and coupling, $\nu_\parallel/\nu_c=10^5$, $\alpha=\nu_c/(\sqrt{3}\nu_\parallel)$, $\tau_O\nu_c=5.5$, $\tau_F\nu_\parallel=4.7\sqrt{3}$ | Compare at $t\nu_c=20$. The full equilibrium is $o_i/f_*=1.00003$ and $p_1/f_*=p_2/f_*=0.00003$. Show the maximum fractional error across all five samples. |
| Move the source | Same fast rate and phase lengths as the count trial. Set $\nu_{c1}=3\nu_c$, supply $3S$ at the selected stud, and set the other couplings and supplies to zero. Start at $\alpha=10\sqrt{3}\nu_c/\nu_\parallel$. | Run to $t\nu_c=50$. With the source at 2, the stationary unprojected gap is $o_3-o_1=3S/(\alpha\nu_\parallel)$ in the OAP and $3S/\nu_\parallel$ in the FDP. These are reference marks for relaxed phases. |

Use the thesis's RK4 step estimate $\Delta t=c/(\max_i\nu_{ci}+\beta\sqrt{3}\nu_\parallel)$ with $\beta=1$ in the FDP and $\beta=\alpha$ in the OAP. Use $c=1$ for the short trial and $2.3$ for the long trials. Shorten the last step at a phase boundary or the requested end time. For **Average**, project the three orbit values to their arithmetic mean at the intermediate OAP RK4 stages and at the completed step. Keep baseline trials unfiltered. [Short and long trial inputs](<../../../../PhD-thesis-latex/Chapter POA Toy Models/scripts/paper_fiveeq_time_evolution_demonstration_distS_distLoss.ipynb>) · [Stage-wise projection in the authors' figure code](<../../../../POA-toy-model-paper/figures/module_fiveeq_POA_counterlocLoss.py>)

## Reference checks

- **Pin the outlet.** Check the rendered bars against the RK4 states before rounding. At the end of the first FDP, $t\nu_c=0.009953785$, $p_2/f_*=2.74582\times10^{-5}$. At the next OAP end, $0.015509341$, both passing values are unchanged and the trapped mean has risen from $0.01155466$ to $0.01703097$. At the next FDP end, $0.019907571$, $p_2/f_*=5.68791\times10^{-5}$. Join saved states by labelled interpolation. The clip holds the pin for 3 exhibit seconds at the start and the final readings for 2 seconds. The advancing intervals use 0.001 collision times per exhibit second. [Short-trial calculation](../../tools/preview_models.py)
- **Count the steps.** Run direct RK4 and POA to $t\nu_c=20$. The direct calculation takes 1,506,140 steps and POA takes 40 under the settings above. At that same time the maximum relative difference across the five POA and direct readings is about $2.1\times10^{-7}$. Show the analytic equilibrium marks alongside them. In the separated-source trial, move the feed from stud 1 to 2. The steady unprojected OAP gap at the initial $\alpha$ is $0.173205f_*$ against $0.00003f_*$ at physical speed. Compare a tenfold increase in $\alpha$ and direct projection to the orbit mean. [Distributed trial](<../../../../PhD-thesis-latex/Chapter POA Toy Models/tex-files/fiveeq_distS_distL.tex>) · [Localized trials](<../../../../PhD-thesis-latex/Chapter POA Toy Models/tex-files/fiveeq_locS_locL.tex>)
