# IoT Data Explorer for ThingSpeak using MATLAB

Visualize and compare IoT data from ThingSpeak channels directly in MATLAB. Supports time comparisons (recent vs. historical), multi-channel comparisons, auto-updating controls, dark mode, and data export.

![App Screen Shot](https://github.com/thingspeak/IoT-Data-Explorer/blob/master/IoTExploreGuiView1.png)

## Getting Started

### Prerequisites

- MATLAB (R2020a or later)
- ThingSpeak Support Toolbox (`thingSpeakRead`)

### Installing

**Option A: Toolbox installer (recommended)**
1. Download `IoT Data Explorer for ThingSpeak using MATLAB.mltbx` from the [File Exchange](https://www.mathworks.com/matlabcentral/fileexchange/) or the Releases page.
2. Double-click the `.mltbx` file. MATLAB will open an install dialog.
3. Click **Install**. The app is added to your MATLAB Add-Ons.
4. Launch from the MATLAB Toolstrip under **Apps**, or run `IoTDataExplorer` at the command line.

**Option B: Run directly from source**
1. Clone or download this repository.
2. Add the folder to your MATLAB path.
3. Run:
   ```matlab
   app = IoTDataExplorer;
   ```

### Using the app

**Modes**
* **Time Compare** (default): Overlay recent vs. older data for a single channel.
* **Channel Compare**: Stack fields from multiple channels side by side. Use the +/- buttons to add or remove channels.

**Controls**
* **Channel ID**: Enter the ThingSpeak channel ID.
* **ReadAPIKey**: Enter the Read API Key for private channels.
* **Start Date**: Select the start date for the data. Time starts at 12:00 AM unless otherwise selected.
* **Start Hour / Min / AM/PM**: Fine-tune the start time.
* **Duration**: The time window to plot (up to 8000 points). Select a base unit and a multiplier (e.g., Hour x 3 = 3 hours).
* **Compare Length** (Time mode): The offset between the recent and older time periods.
* **Retime**: Resample data to minutely, hourly, daily, weekly, or monthly intervals using linear interpolation.
* **Field checkboxes**: Select which fields to display.
* **Update**: Fetch and plot data. After the first update, controls auto-refresh the plot on change.
* **Output to Workspace**: Export the queried data to the MATLAB workspace.
* **Dark Mode**: Toggle between light and dark themes.
* **Quit**: Save preferences and close the app.

Channel IDs, API keys, and theme preference are saved between sessions.

### Built With
MATLAB (standalone .m classdef — no App Designer required)

### Authors
* Christopher Stapels - Initial work - MathWorks
* Alain Kutcha - Code review - MathWorks

### Resources
* [ThingSpeak for IoT Projects](https://thingspeak.com)
* [MATLAB](https://www.mathworks.com/products/matlab.html)
