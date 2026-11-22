# Mirror Transport VR

Walk through the museum for Maxwell Rosen’s PhD thesis on magnetic mirror equilibrium and plasma transport. The first doors on the left and right lead to **The Magnetic Mirror** and **Between Bounces**. The second pair opens into **Time Dilation** on the left and **Which ions can reach a wall?** on the right. The third left-hand arch opens into **Fuel in a simple mirror**. Galleries 6–8 are under construction.

## Gallery layout

The 16 m wide atrium has four 10 m bays on each side. Numbering runs from the foyer toward the far wall, with odd numbers on the left. The open galleries have 4 m entrances and 5 m ceilings. Gallery 1 is 16 m deep. Gallery 2 extends 20 m and Gallery 3 extends 38 m, with open reading areas beyond their last stations. [Museum layout and sightlines](SETTING.md) · [Exhibit roadmap](PLAN.md#galleries)

| Gallery | Visitor question | Status |
| --- | --- | --- |
| [1 · The Magnetic Mirror](gallery-1/README.md) | Which particles turn back, and which escape through the ends? | Playable |
| [2 · Between Bounces](gallery-2/README.md) | Can you predict how much plasma escapes without computing every bounce? | Playable |
| [3 · Time Dilation](gallery-3/README.md) | Does a slower clock change the final glow? | Playable |
| [4 · Which ions can reach a wall?](gallery-4/README.md) | Can a trapped ion sit inside a cell that Gkeyll holds? | Playable |
| [5 · Fuel in a simple mirror](gallery-5/README.md) | With the same feed, does beam or Maxwellian injection hold more fuel? | Playable |

Each gallery has a top-level folder named for its entrance number, such as `gallery-1/` or `gallery-2/`. Start a new gallery’s plan in its `README.md`. Put its Godot scenes, scripts, and resources in `game/`, design drawings in `sketches/`, and its exporters and checks in `tools/`. The Quest APK and editor ZIP automatically collect each numbered gallery’s `game/` files.

The shared museum scene places the exhibits. The foyer, atrium, visitor controls and menus live in `museum/`. Dimensions are in metres. [Entry scene](museum/museum.tscn) · [Museum geometry](museum/museum.gd)

## Visit the museum

Open `project.godot` with Godot 4.7 and press **F5**. On the laptop, run this command from the project directory to launch directly with the installed Flatpak:

```sh
flatpak run org.godotengine.Godot --path . --xr-mode off
```

Choose **Enter the museum** from the title screen, or **Exit** to close the game. The desktop visitor is 1.83 m tall with a standing eye height of 1.71 m. Walk with **WASD** or the **arrow keys** and hold **Shift** to sprint. Look with the mouse and left-click to interact. Press **Esc** to pause, see the controls, and adjust or mute the audio. Choose **Resume visit** to continue, or **Reset to title** to return to the main menu.

On a system with an active OpenXR runtime and Touch controllers, launch with `--xr-mode on`. Use the **right controller** for all controls. Tilt its **thumbstick** in any direction and aim the arc at the floor. Release the stick to teleport to the circle, up to **4 m** away. Pull the **index trigger** to select, hold it to drag, and press **A** to pause or resume.

Run the teleport and menu checks with a simulated right controller from the project directory.

```sh
flatpak run org.godotengine.Godot --headless --path . --xr-mode off --script res://tools/check_quest_controls.gd
```

## Build and install the Quest 3 APK

Run the build from the project directory on the Linux laptop.

```sh
./build_apk
```

The signed standalone game is `exports/MirrorTransport.apk`. The build takes a fresh copy of the saved game files, including uncommitted changes. It checks the APK signature, ARM64 libraries, immersive Quest launch settings and packaged reference data for all five exhibits before replacing the previous APK.

1. With Developer Mode enabled, connect the Quest 3 to the laptop with a **USB-C data cable**. Put on the headset and approve **Allow USB debugging** for this laptop.
2. Run `./build_apk --install-only` to install the existing APK. If several Android devices are attached, the script lists them. Set `ANDROID_SERIAL` to the Quest’s serial and run the command again.
3. After **Success**, unplug the cable. In the headset open **Library → Unknown Sources → Mirror Transport Museum**. Select **Enter the museum** with the right trigger. [Meta’s device installation guide](https://developers.meta.com/vr/documentation/android-apps/enable-developer-mode/)

For future updates, save the game and run `./build_apk --install` with the Quest connected. This builds the new APK and runs `adb install -r` to update the same library entry and preserve its saved settings. For a new numbered release, increase `version/code` and set `version/name` in `tools/quest_export_presets.cfg`. [Android Debug Bridge](https://developer.android.com/tools/adb#pm)

### First build on another Linux laptop

The build uses Python 3.9+, `curl`, `unzip`, and OpenJDK 17. It can use the JDK from this laptop’s Godot Flatpak or a JDK selected with `JAVA_HOME`. On first use it downloads Godot 4.7.2, its matching Android build template and OpenXR Vendors 5.2.0, with SHA-256 checks. It uses the Android SDK at `ANDROID_HOME`, `ANDROID_SDK_ROOT`, or the usual `~/Android/Sdk` if available. Otherwise it provisions `build/quest/sdk`. SDK Manager prompts for Google’s SDK license when needed. The first build also downloads Gradle dependencies. Subsequent builds reuse the tools in `build/quest/`. [Godot 4.7.2 Android build versions](https://github.com/godotengine/godot/blob/4.7.2-stable/platform/android/java/app/config.gradle) · [OpenXR Vendors release](https://github.com/GodotVR/godot_openxr_vendors/releases/tag/5.2.0-stable)

The first build creates a private signing identity in `.godot_credentials/quest/`. Back up that directory securely and restore it when moving the project to another computer. Android uses the signing key and the package ID `org.mirrortransport.museum` to recognize updates. Teams with an existing release key can set `GODOT_ANDROID_KEYSTORE_RELEASE_PATH`, `GODOT_ANDROID_KEYSTORE_RELEASE_USER` and `GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD` before building.

### Update the Quest project ZIP

For editing the project in Godot on the headset, save your changes on the laptop and run this from the repository root with Python 3.

```sh
python3 tools/build_quest_zip.py
```

The script rebuilds `exports/MirrorTransport-Quest-Project.zip` from the current game files, including uncommitted changes. It adds the Quest rendering settings and Android export preset to the packaged project and checks the ZIP before replacing the previous build.

1. Connect the Quest 3 with a USB-C data cable and allow file access in the headset. In the laptop’s file manager, copy the new ZIP to the headset’s **Internal shared storage → Download** folder, replacing the older ZIP.
2. Open **Godot Game Engine** on the Quest and return to the Project Manager. Choose **Import**, select the ZIP in **Download**, and choose a fresh project folder such as `Documents/MirrorTransport-02`. Godot extracts a separate copy each time you import. [Godot project import guide](https://docs.godotengine.org/en/4.7/tutorials/editor/project_manager.html)
3. Open the newly imported project and select **▶ Run Project**. At the title screen, point the right controller at **Enter the museum** and pull the index trigger.

## Simulation data

The original Gkeyll runs live locally in `gkeyll-data/<run>/`. Use Postgkyl (`import postgkyl as pg`) in Python to load and plot their diagnostics. Store the simulation textures and 3D data for desktop and Quest in `simulation-renders/` and commit them to GitHub. Keep each file under 100 MB for quick loading and a small game download. Check that each export reproduces the source values and geometry at the positions visitors can inspect. [Asset guide and Python plotting example](simulation-renders/README.md)

Gallery 1 includes the commands to reproduce its 400-cell field cut and run the desktop checks. [Mirror reference and checks](gallery-1/README.md#game-files-and-reference-checks)
