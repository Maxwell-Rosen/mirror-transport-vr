# Gallery 3 · Time Dilation

**Which lights fall behind the beat?** Enter the second gallery on the left. Ten amber bulbs orbit on a suspended brass mobile. The fixed lamp above the rim pulses every 3.6 exhibit seconds. Choose **Start together** and watch the brass index as the reference lamp pulses again.

The mobile opens on the right mirror throat. Seven of the ten bulbs return together. The outer three glow more faintly and take longer to come around. **Use reference beat** puts all ten clocks at full rate for comparison. **View midplane** moves the same ten velocity samples to the first cell on the positive side of the midplane. **Inspect next ring** moves the white hoop to another lamp and updates the lectern. Point and click or use the right Quest trigger. On desktop, Tab and Shift+Tab move focus at the lectern and Enter activates the selected button.

## What the lamps measure

Each ring is a clock representing one phase-space cell in the `1x-beams` ion run, at frame 75 and saved time 0.500150 s. The equal ring spacing orders ten increasing positive parallel velocities at magnetic moment μ = 0.04437 keV/T. The lectern gives the selected velocity and axial cell centre. The radii and circular motion are sculptural.

- **Timing.** The cellwise `fdot_multiplier` gives the dimensionless local time factor β. One turn and one smooth pulse take 3.6/β exhibit seconds. In the near-midplane cut at Z = +0.014865 m every sampled β is 1. At the right throat at Z = +0.979129 m the outermost lamp has β = 0.186021 and a period of 19.35 exhibit seconds. The animation compares rates at a single saved instant.
- **Brightness.** The peak filament intensity shows the magnitude of the cell-average ion distribution |fᵢ| relative to the largest sampled value on the current cut. A logarithmic mapping covers 24 decades and retains a 15% minimum peak so the faintest lamp stays visible. This normalization compares velocities within each cut. Gkeyll chooses which cells to slow from their local numerical time-step limit.

The exporter reads the original DG coefficients with Postgkyl, evaluates the run’s coordinate maps, removes the saved Jacobians from the ion distribution and checks its full velocity integral against the saved ion density at both locations. Only twenty cell samples ship with the game. [Asset manifest](../simulation-renders/gallery-3/manifest.json) · [Conversion and checks](tools/export_lamps.py)

## Reproduce and check

From the repository root, run the following commands with Postgkyl and Godot 4.7 available.

```sh
python3 gallery-3/tools/export_lamps.py --check
godot --headless --path . --xr-mode off --script res://gallery-3/tools/check_lamps.gd
godot --headless --path . --xr-mode off --script res://tools/check_quest_controls.gd
```

Omit `--check` to regenerate the asset. For pictures of the installed mobile and the seated lectern, run the gallery check on a desktop display without `--headless` and append `-- --pictures`.
