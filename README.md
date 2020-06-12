# IoT Data Explorer for ThingSpeak using MATLAB

A MATLAB app to visualize ThingSpeak data. Make time comparisons of your data, retime data, and export data.

![App Screen Shot](https://github.com/thingspeak/IoT-Data-Explorer/blob/master/IoTExploreGuiView1.png)

## Getting Started

These instructions will get you a copy of the project up and running on your local machine for development and testing purposes. 

### Prerequisites

MATLAB R2020a

### Installing

1. Download the program and unzip it to a local directory. 
2. Locate the app installation file which is characterized by the suffix '.mlappinstall'.
3. Double-click the installation file.
4. A dialog is opened. Click Install.
5. Once installed, the app is added to the MATLAB Toolstrip.

### Using the app

* Channel ID: Enter the channel ID for the channel if interest.
* ReadAPIKey: Enter ReadAPIKey for private channels
* StartDate: Start Date the selcted data.  The time will start at 12:00 AM unless otherwise selected.
* StartHour: Start Hour 
* Min: Start Minute to read the data.
* AM/PM: Ante Meridian, Post Meridian
* Duration: The width in time for the plot of the data, you can read up to 8000 points.  Select the base with and choose a multiplier. For example if yopu wish to show 3 hoursa, select hours and a multiplier of 3.
* Compare Length:  The time difference between the selcted date and the older time period.  Select the length and multiplier similar to the duration.
* Retime: time basis for smoothing of data.  Linear interpolation is used.
* F1 through F8: Check box to include a particular field, if data is available.
* Update: Updatethe present visualization using the settings.
* Output to Workspace:  Run the current querry and write the output data to the workspace for variable names you choose.
* Quit: Stop the program and delete the UI figure.

### Built With
MATLAB App Designer

### Authors
* Christopher Stapels - Initial work - MathWorks
* Alain Kutcha - Code review - MathWorks

### Resources
* [ThingSpeak for IoT Projects](https://thingspeak.com)
* [MATLAB App Designer](https://www.mathworks.com/products/matlab/app-designer.html)
