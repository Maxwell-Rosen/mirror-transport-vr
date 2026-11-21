uniform float reference_laps = 0.0;
uniform float settle_laps = 4.0;
uniform bool use_dilation = true;
uniform bool steady_view = false;

// Instance data carries clockwise azimuth (turns), saved beta, peak drive
// and wave amplitude (zero on the lectern's permanent steady reference).
float lamp_drive(vec4 lamp) {
	float local_laps = reference_laps * (use_dilation ? lamp.g : 1.0);
	float amplitude = steady_view ? 0.0 : lamp.a * (1.0 - smoothstep(0.0, settle_laps, local_laps));
	float crest = cos(TAU * (lamp.r - local_laps));
	// A narrow bright crest and an opposite dark trough have zero angular mean.
	return 0.5 * lamp.b * (1.0 + amplitude * crest * crest * crest);
}
