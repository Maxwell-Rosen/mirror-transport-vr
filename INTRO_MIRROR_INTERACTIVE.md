# Interactive mirror demo

This is the first thing players are met with. Exhibit 1. This is an interactive demo to explore the mirror loss cone. The double lorentzian geometry is shown in a table-top device. 8 field lines are shown, where there are 2 tori at the mirror throats. This is a simple mirror. The demo sits atop a pedestal, where there are various sliders on a control pannel. Particles orbit the field lines, bouncing at a reasonable speed, period around 4 seconds but keeping units rather physical, however the bouncing should not be too fast. There are several, around 5, particles on each field line which are tracing particle orbits. Each particle should have a disappearing trailing fading tail, which helps players see the history of where the particles were.

The animated mirror has a few sliders. The mirror ratio can be adjusted, going from straight field lines, mirror ratio 1, to high confinement, mirror ratio 50. The radius at the midplane z=0 remains fixed when the magnetic field strength is changed.

A graphic lies on the control panel, showing the mirror loss cone, which is the trapped passing boundary. The coordinates are magnetic moment on the y-axis and parallel velocity on the x-axis. All particles start at z=0.The 8 field lines have particles with different parallel velocities, which are fixed in 8 equally spaced points, shown on the graphic. THe field lines are all blue, and the particles on the same field line are the same color, but the color of the particles varies from field line to field line. This color is shown as a point on the control pannel so that players understand which point is which particle trace. The spread of the parallel velocity points can be controlled by a slider on the control panel

A slider controls the magnetic moment of the particles. Another slider controls the ambipolar potential in the mirror. This can be represented as a parabola. A graphic on the control panel should show the potential here, as well as the loss cone changing according to the ambipolar potential. The potential slider can either be positive or negative, so it should start at zero, which is in the middle.

There is a reset button to put all particles back to z=0

For simplicity, you may want to implement some reduced equations. The code may want to track the gyrocenters and rotation frequency, employing a drift-kinetic framework.

The animation should stop when players get too far away from the exhibit to save on compute. Place a yellow and black line on the floor to show that there is a radius which animations play inside. It should be quite generous.
