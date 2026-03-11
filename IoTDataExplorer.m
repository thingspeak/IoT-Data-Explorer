classdef IoTDataExplorer < matlab.apps.AppBase
    % IoTDataExplorer - Visualize and compare IoT data from ThingSpeak.
    %
    %   Rewritten as a standalone .m file (no App Designer required).
    %   Improvement: On startup, queries ThingSpeak for the channel's
    %   earliest data point and sets the Start Date accordingly.
    %
    %   Usage:
    %       app = IoTDataExplorer;
    %
    %   Copyright 2020 The MathWorks, Inc.
    %   Rewritten 2026.

    % UI components
    properties (Access = public)
        IoTDataExplorerForThingSpeakUIFigure  matlab.ui.Figure
        GridLayout                  matlab.ui.container.GridLayout
        LeftPanel                   matlab.ui.container.Panel
        UpdateButton                matlab.ui.control.Button
        QuitButton                  matlab.ui.control.Button
        StartDateDatePickerLabel    matlab.ui.control.Label
        StartDateDatePicker         matlab.ui.control.DatePicker
        DurationDropDownLabel       matlab.ui.control.Label
        DurationDropDown            matlab.ui.control.DropDown
        CompareLengthDropDownLabel  matlab.ui.control.Label
        CompareLengthDropDown       matlab.ui.control.DropDown
        ChannelIDEditFieldLabel     matlab.ui.control.Label
        ChannelIDEditField          matlab.ui.control.NumericEditField
        ReadAPIKeyEditFieldLabel    matlab.ui.control.Label
        ReadAPIKeyEditField         matlab.ui.control.EditField
        StartHourDropDownLabel      matlab.ui.control.Label
        StartHourDropDown           matlab.ui.control.DropDown
        XEditField_2Label           matlab.ui.control.Label
        plotDuration                matlab.ui.control.NumericEditField
        XEditFieldLabel             matlab.ui.control.Label
        plotLengthofComparison      matlab.ui.control.NumericEditField
        RetimeDropDown              matlab.ui.control.DropDown
        RetimeDropDownLabel         matlab.ui.control.Label
        AMPMSwitchLabel             matlab.ui.control.Label
        AMPMSwitch                  matlab.ui.control.Switch
        MinDropDownLabel            matlab.ui.control.Label
        MinDropDown                 matlab.ui.control.DropDown
        OutputtoWorkspaceButton     matlab.ui.control.Button
        F1CheckBox                  matlab.ui.control.CheckBox
        F2CheckBox                  matlab.ui.control.CheckBox
        F3CheckBox                  matlab.ui.control.CheckBox
        F4CheckBox                  matlab.ui.control.CheckBox
        F5CheckBox                  matlab.ui.control.CheckBox
        F6CheckBox                  matlab.ui.control.CheckBox
        F7CheckBox                  matlab.ui.control.CheckBox
        F8CheckBox                  matlab.ui.control.CheckBox
        RightPanel                  matlab.ui.container.Panel
        StatusLabel                 matlab.ui.control.Label
    end

    properties (Access = private)
        onePanelWidth = 576;
    end

    properties (Access = public)
        legendLabel1
        legendLabel2
        myChans
    end

    methods (Access = public)

        function displayFields = enumerateSelectedFields(app)
            % Create array of the fields for processing
            displayFields = [app.F1CheckBox.Value, app.F2CheckBox.Value, ...
                app.F3CheckBox.Value, app.F4CheckBox.Value, ...
                app.F5CheckBox.Value, app.F6CheckBox.Value, ...
                app.F7CheckBox.Value, app.F8CheckBox.Value];
        end
    end

    methods (Access = private)

        function [query, queryRecent, queryOld] = buildQueryFromInputs(app)
            %   buildQueryFromInputs   Build the query inputs into a struct.
            query = struct();
            queryRecent = struct();
            queryOld = struct();
            app.StatusLabel.Text = 'Status';

            query.APIKey = app.ReadAPIKeyEditField.Value;
            query.channelID = app.ChannelIDEditField.Value;
            query.startHour = hours(str2double(app.StartHourDropDown.Value));
            query.startMinute = minutes(str2double(app.MinDropDown.Value));
            query.dmult = app.plotDuration.Value;
            query.lmult = app.plotLengthofComparison.Value;

            % Build the start date with date, minutes, hours and AM/PM
            queryRecent.startDate = app.StartDateDatePicker.Value + ...
                query.startHour + query.startMinute;

            if app.AMPMSwitch.Value == "PM"
                queryRecent.startDate = queryRecent.startDate + hours(12);
            end

            queryRecent.endDate = queryRecent.startDate + getCompareDuration(app);
            query.fieldsList = {};

            queryDisplayFields = enumerateSelectedFields(app);

            % Build the fields list for ThingSpeak Read
            for i = 1:8
                if queryDisplayFields(i) > 0
                    query.fieldsList = [query.fieldsList, i];
                end
            end
            query.fieldsList = cell2mat(query.fieldsList);

            queryOld.startDate = queryRecent.startDate - getCompareWidth(app);
            queryOld.endDate = queryOld.startDate + getCompareDuration(app);
        end


        function myData = getDataFromQuery(app, query, queryStartEnd)
            %   getDataFromQuery   Retrieve data from ThingSpeak.
            try
                myData = thingSpeakRead(query.channelID, ...
                    'ReadKey', query.APIKey, ...
                    'DateRange', [queryStartEnd.startDate queryStartEnd.endDate], ...
                    'Fields', query.fieldsList, ...
                    'OutputFormat', 'Timetable');

            catch readingError
                myData = timetable();
                uialert(app.IoTDataExplorerForThingSpeakUIFigure, ...
                    readingError.identifier, "Data error for that time interval");
                return
            end

            if isempty(myData)
                uialert(app.IoTDataExplorerForThingSpeakUIFigure, ...
                    "No Data for that time interval", "Pick some different data");
                myData = timetable();
                return
            end
            if height(myData) >= 8000
                app.StatusLabel.Text = "Read limit reached. Duration may be shorter than expected";
            end
            % Use retime if the user has selected that option
            if app.RetimeDropDown.Value ~= "Raw"
                myData = retime(myData, app.RetimeDropDown.Value, 'linear');
            end
        end

        function visualizeData(app, recentData, oldData, queryInfo)
            %   visualizeData   Display the data in tiled plots.
            dataDisplayFields = enumerateSelectedFields(app);

            if sum(dataDisplayFields) > width(oldData)
                uialert(app.IoTDataExplorerForThingSpeakUIFigure, ...
                    "Not enough Fields selected", ...
                    "Pick a different channel or different fields.");
            end

            if width(recentData) == 0
                return
            end
            if width(oldData) == 0
                return
            end

            t = tiledlayout(app.RightPanel, sum(dataDisplayFields), 1, 'tilespacing', 'none');

            % Change data to elapsed time
            elapsedRecent = recentData.Timestamps - recentData.Timestamps(1) + ...
                queryInfo.startHour + queryInfo.startMinute;

            elapsedOld = oldData.Timestamps - oldData.Timestamps(1) + ...
                queryInfo.startHour + queryInfo.startMinute;

            % Determine which set is shortest
            minLength = min(height(oldData), height(recentData));

            myTile = 0;
            for index = 1:8
                if dataDisplayFields(index) > 0
                    myTile = myTile + 1;
                    myAxes = nexttile(t);
                    plotVar = recentData.(myTile);
                    plot(myAxes, elapsedRecent(1:minLength), plotVar(1:minLength), '-o', 'MarkerSize', 2);

                    if app.CompareLengthDropDown.Value ~= minutes(0)
                        hold(myAxes, "on");
                        plotVar2 = oldData.(myTile);
                        plot(myAxes, elapsedOld(1:minLength), plotVar2(1:minLength), '-*', 'MarkerSize', 2);
                    end

                    title(myAxes, recentData.Properties.VariableNames(myTile));

                    if myTile > 1
                        set(myAxes, 'xtick', []);
                        legend(myAxes, ["Recent", "Old"]);
                    else
                        legend(myAxes, {app.legendLabel1, app.legendLabel2});
                    end
                end
            end
        end

        function compareDuration = getCompareDuration(app)
            % Determine the duration of each data window.
            dmult = app.plotDuration.Value;
            compareDuration = app.DurationDropDown.Value * dmult;
        end

        function legendLabel = getLegendLabel(app, startDate)
            % Format the legend label based on start date and duration.
            dmult = app.plotDuration.Value;
            switch app.DurationDropDown.Value
                case minutes(1)
                    legendLabel = string(dmult) + ' Minutes on ' + string(startDate);
                case hours(1)
                    legendLabel = string(dmult) + ' Hours on ' + string(startDate);
                case hours(24)
                    legendLabel = string(dmult) + ' Days on ' + string(startDate);
                case days(7)
                    legendLabel = string(dmult) + ' Weeks on ' + string(startDate);
                case days(365)
                    legendLabel = string(dmult) + ' Years on ' + string(startDate);
            end
            if app.RetimeDropDown.Value ~= "Raw"
                legendLabel = legendLabel + " " + string(app.RetimeDropDown.Value);
            end
        end

        function compareWidth = getCompareWidth(app)
            % Determine the time offset between recent and old data.
            lmult = app.plotLengthofComparison.Value;
            compareWidth = app.CompareLengthDropDown.Value * lmult;
        end

    end

    % Callbacks
    methods (Access = private)

        function startupFcn(app)
            % Set dropdown data values (they won't evaluate if set as
            % Items strings in the component definition).
            app.DurationDropDown.ItemsData = [minutes(1), hours(1), days(1), days(7)];
            app.CompareLengthDropDown.ItemsData = [minutes(0), minutes(1), hours(1), days(1), days(7), days(365)];

            % Default start date to one day ago
            app.StartDateDatePicker.Value = datetime('yesterday');
        end

        function updateAppLayout(app, event)
            currentFigureWidth = app.IoTDataExplorerForThingSpeakUIFigure.Position(3);
            if currentFigureWidth <= app.onePanelWidth
                app.GridLayout.RowHeight = {511, 511};
                app.GridLayout.ColumnWidth = {'1x'};
                app.RightPanel.Layout.Row = 2;
                app.RightPanel.Layout.Column = 1;
            else
                app.GridLayout.RowHeight = {'1x'};
                app.GridLayout.ColumnWidth = {241, '1x'};
                app.RightPanel.Layout.Row = 1;
                app.RightPanel.Layout.Column = 2;
            end
        end

        function UpdateButtonPushed(app, event)
            [query, queryRecent, queryOld] = buildQueryFromInputs(app);

            recentData = getDataFromQuery(app, query, queryRecent);
            oldData = getDataFromQuery(app, query, queryOld);

            app.legendLabel1 = getLegendLabel(app, queryRecent.startDate);
            app.legendLabel2 = string(queryOld.startDate);

            visualizeData(app, recentData, oldData, query)
        end

        function QuitButtonPushed(app, event)
            app.delete
        end

        function OutputtoWorkspaceButtonPushed(app, event)
            [query, queryRecent, queryOld] = buildQueryFromInputs(app);
            recentData = getDataFromQuery(app, query, queryRecent);
            oldData = getDataFromQuery(app, query, queryOld);

            labels = {'Save recent data to timetable named:' 'Save old data to timetable named:'};
            vars = {'oldData', 'recentData'};
            values = {recentData, oldData};
            export2wsdlg(labels, vars, values);
        end
    end

    % Component initialization
    methods (Access = private)

        function createComponents(app)

            % Create UIFigure
            app.IoTDataExplorerForThingSpeakUIFigure = uifigure('Visible', 'off');
            app.IoTDataExplorerForThingSpeakUIFigure.AutoResizeChildren = 'off';
            app.IoTDataExplorerForThingSpeakUIFigure.Position = [100 100 710 511];
            app.IoTDataExplorerForThingSpeakUIFigure.Name = 'ThingSpeak Data Explorer';
            app.IoTDataExplorerForThingSpeakUIFigure.SizeChangedFcn = createCallbackFcn(app, @updateAppLayout, true);

            % Create GridLayout
            app.GridLayout = uigridlayout(app.IoTDataExplorerForThingSpeakUIFigure);
            app.GridLayout.ColumnWidth = {241, '1x'};
            app.GridLayout.RowHeight = {'1x'};
            app.GridLayout.ColumnSpacing = 0;
            app.GridLayout.RowSpacing = 0;
            app.GridLayout.Padding = [0 0 0 0];
            app.GridLayout.Scrollable = 'on';

            % Create LeftPanel
            app.LeftPanel = uipanel(app.GridLayout);
            app.LeftPanel.Layout.Row = 1;
            app.LeftPanel.Layout.Column = 1;

            % Create UpdateButton
            app.UpdateButton = uibutton(app.LeftPanel, 'push');
            app.UpdateButton.ButtonPushedFcn = createCallbackFcn(app, @UpdateButtonPushed, true);
            app.UpdateButton.BackgroundColor = [0 1 0];
            app.UpdateButton.Position = [124 146 73 22];
            app.UpdateButton.Text = 'Update';

            % Create QuitButton
            app.QuitButton = uibutton(app.LeftPanel, 'push');
            app.QuitButton.ButtonPushedFcn = createCallbackFcn(app, @QuitButtonPushed, true);
            app.QuitButton.BackgroundColor = [1 0 0];
            app.QuitButton.Position = [124 82 72 22];
            app.QuitButton.Text = 'Quit';

            % Create StartDateDatePickerLabel
            app.StartDateDatePickerLabel = uilabel(app.LeftPanel);
            app.StartDateDatePickerLabel.HorizontalAlignment = 'right';
            app.StartDateDatePickerLabel.Position = [8 376 67 22];
            app.StartDateDatePickerLabel.Text = 'Start Date';

            % Create StartDateDatePicker (default will be overridden by fetchEarliestDate)
            app.StartDateDatePicker = uidatepicker(app.LeftPanel);
            app.StartDateDatePicker.Position = [117 376 109 22];
            app.StartDateDatePicker.Value = datetime('today');

            % Create DurationDropDownLabel
            app.DurationDropDownLabel = uilabel(app.LeftPanel);
            app.DurationDropDownLabel.HorizontalAlignment = 'right';
            app.DurationDropDownLabel.Position = [7 275 57 22];
            app.DurationDropDownLabel.Text = 'Duration';

            % Create DurationDropDown
            app.DurationDropDown = uidropdown(app.LeftPanel);
            app.DurationDropDown.Items = {'Minute', 'Hour', 'Day', 'Week'};
            app.DurationDropDown.Position = [102 275 65 22];
            app.DurationDropDown.Value = 'Day';

            % Create CompareLengthDropDownLabel
            app.CompareLengthDropDownLabel = uilabel(app.LeftPanel);
            app.CompareLengthDropDownLabel.HorizontalAlignment = 'right';
            app.CompareLengthDropDownLabel.Position = [10 244 90 22];
            app.CompareLengthDropDownLabel.Text = 'Compare Length';

            % Create CompareLengthDropDown
            app.CompareLengthDropDown = uidropdown(app.LeftPanel);
            app.CompareLengthDropDown.Items = {'None', 'Minute', 'Hour', 'Day', 'Week', 'Year'};
            app.CompareLengthDropDown.Position = [113 244 67 22];
            app.CompareLengthDropDown.Value = 'Week';

            % Create ChannelIDEditFieldLabel
            app.ChannelIDEditFieldLabel = uilabel(app.LeftPanel);
            app.ChannelIDEditFieldLabel.HorizontalAlignment = 'right';
            app.ChannelIDEditFieldLabel.Position = [12 464 66 22];
            app.ChannelIDEditFieldLabel.Text = 'Channel ID';

            % Create ChannelIDEditField
            app.ChannelIDEditField = uieditfield(app.LeftPanel, 'numeric');
            app.ChannelIDEditField.ValueDisplayFormat = '%.0f';
            app.ChannelIDEditField.Position = [93 464 55 22];
            app.ChannelIDEditField.Value = 38629;

            % Create ReadAPIKeyEditFieldLabel
            app.ReadAPIKeyEditFieldLabel = uilabel(app.LeftPanel);
            app.ReadAPIKeyEditFieldLabel.HorizontalAlignment = 'right';
            app.ReadAPIKeyEditFieldLabel.Position = [13 434 74 22];
            app.ReadAPIKeyEditFieldLabel.Text = 'ReadAPIKey';

            % Create ReadAPIKeyEditField
            app.ReadAPIKeyEditField = uieditfield(app.LeftPanel, 'text');
            app.ReadAPIKeyEditField.Position = [102 434 100 22];

            % Create StartHourDropDownLabel
            app.StartHourDropDownLabel = uilabel(app.LeftPanel);
            app.StartHourDropDownLabel.HorizontalAlignment = 'right';
            app.StartHourDropDownLabel.Position = [10 348 63 22];
            app.StartHourDropDownLabel.Text = 'Start Hour';

            % Create StartHourDropDown
            app.StartHourDropDown = uidropdown(app.LeftPanel);
            app.StartHourDropDown.Items = {'0', '1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11', '12'};
            app.StartHourDropDown.ItemsData = {'0', '1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11', '12'};
            app.StartHourDropDown.Position = [22 325 44 22];
            app.StartHourDropDown.Value = '0';

            % Create XEditField_2Label
            app.XEditField_2Label = uilabel(app.LeftPanel);
            app.XEditField_2Label.HorizontalAlignment = 'right';
            app.XEditField_2Label.Position = [172 275 25 22];
            app.XEditField_2Label.Text = 'X';

            % Create plotDuration
            app.plotDuration = uieditfield(app.LeftPanel, 'numeric');
            app.plotDuration.Limits = [1 365];
            app.plotDuration.Position = [205 275 30 22];
            app.plotDuration.Value = 1;

            % Create XEditFieldLabel
            app.XEditFieldLabel = uilabel(app.LeftPanel);
            app.XEditFieldLabel.HorizontalAlignment = 'right';
            app.XEditFieldLabel.Position = [172 244 25 22];
            app.XEditFieldLabel.Text = 'X';

            % Create plotLengthofComparison
            app.plotLengthofComparison = uieditfield(app.LeftPanel, 'numeric');
            app.plotLengthofComparison.Limits = [1 365];
            app.plotLengthofComparison.Position = [205 244 30 22];
            app.plotLengthofComparison.Value = 1;

            % Create RetimeDropDown
            app.RetimeDropDown = uidropdown(app.LeftPanel);
            app.RetimeDropDown.Items = {'Raw', 'minutely', 'hourly', 'daily', 'weekly', 'monthly'};
            app.RetimeDropDown.Position = [107 210 89 22];
            app.RetimeDropDown.Value = 'Raw';

            % Create RetimeDropDownLabel
            app.RetimeDropDownLabel = uilabel(app.LeftPanel);
            app.RetimeDropDownLabel.HorizontalAlignment = 'right';
            app.RetimeDropDownLabel.Position = [47 210 45 22];
            app.RetimeDropDownLabel.Text = 'Retime';

            % Create AMPMSwitchLabel
            app.AMPMSwitchLabel = uilabel(app.LeftPanel);
            app.AMPMSwitchLabel.HorizontalAlignment = 'center';
            app.AMPMSwitchLabel.Position = [169 346 45 22];
            app.AMPMSwitchLabel.Text = 'AM/PM';

            % Create AMPMSwitch
            app.AMPMSwitch = uiswitch(app.LeftPanel, 'slider');
            app.AMPMSwitch.Items = {'AM', 'PM'};
            app.AMPMSwitch.Position = [166 325 45 20];
            app.AMPMSwitch.Value = 'AM';

            % Create MinDropDownLabel
            app.MinDropDownLabel = uilabel(app.LeftPanel);
            app.MinDropDownLabel.HorizontalAlignment = 'right';
            app.MinDropDownLabel.Position = [80 348 36 22];
            app.MinDropDownLabel.Text = 'Min';

            % Create MinDropDown
            app.MinDropDown = uidropdown(app.LeftPanel);
            app.MinDropDown.Items = {'0', '1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11', '12', '13', '14', '15', '16', '17', '18', '19', '20', '21', '22', '23', '24', '25', '26', '27', '28', '29', '30', '31', '32', '33', '34', '35', '36', '37', '38', '39', '40', '41', '42', '43', '44', '45', '46', '47', '48', '49', '50', '51', '52', '53', '54', '55', '56', '57', '58', '59', '60'};
            app.MinDropDown.ItemsData = {'0', '1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11', '12', '13', '14', '15', '16', '17', '18', '19', '20', '21', '22', '23', '24', '25', '26', '27', '28', '29', '30', '31', '32', '33', '34', '35', '36', '37', '38', '39', '40', '41', '42', '43', '44', '45', '46', '47', '48', '49', '50', '51', '52', '53', '54', '55', '56', '57', '58', '59', '60'};
            app.MinDropDown.Position = [92 325 44 22];
            app.MinDropDown.Value = '0';

            % Create OutputtoWorkspaceButton
            app.OutputtoWorkspaceButton = uibutton(app.LeftPanel, 'push');
            app.OutputtoWorkspaceButton.ButtonPushedFcn = createCallbackFcn(app, @OutputtoWorkspaceButtonPushed, true);
            app.OutputtoWorkspaceButton.BackgroundColor = [0.8 0.8 0.8];
            app.OutputtoWorkspaceButton.Position = [97 115 128 22];
            app.OutputtoWorkspaceButton.Text = 'Output to Workspace';

            % Create F1CheckBox
            app.F1CheckBox = uicheckbox(app.LeftPanel);
            app.F1CheckBox.Text = 'F1';
            app.F1CheckBox.Position = [14 178 36 22];
            app.F1CheckBox.Value = true;

            % Create F2CheckBox
            app.F2CheckBox = uicheckbox(app.LeftPanel);
            app.F2CheckBox.Text = 'F2';
            app.F2CheckBox.Position = [13 157 36 22];

            % Create F3CheckBox
            app.F3CheckBox = uicheckbox(app.LeftPanel);
            app.F3CheckBox.Text = 'F3';
            app.F3CheckBox.Position = [14 136 36 22];

            % Create F4CheckBox
            app.F4CheckBox = uicheckbox(app.LeftPanel);
            app.F4CheckBox.Text = 'F4';
            app.F4CheckBox.Position = [14 115 36 22];

            % Create F5CheckBox
            app.F5CheckBox = uicheckbox(app.LeftPanel);
            app.F5CheckBox.Text = 'F5';
            app.F5CheckBox.Position = [14 94 36 22];

            % Create F6CheckBox
            app.F6CheckBox = uicheckbox(app.LeftPanel);
            app.F6CheckBox.Text = 'F6';
            app.F6CheckBox.Position = [14 73 36 22];

            % Create F7CheckBox
            app.F7CheckBox = uicheckbox(app.LeftPanel);
            app.F7CheckBox.Text = 'F7';
            app.F7CheckBox.Position = [14 52 36 22];

            % Create F8CheckBox
            app.F8CheckBox = uicheckbox(app.LeftPanel);
            app.F8CheckBox.Text = 'F8';
            app.F8CheckBox.Position = [13 31 36 22];

            % Create RightPanel
            app.RightPanel = uipanel(app.GridLayout);
            app.RightPanel.Layout.Row = 1;
            app.RightPanel.Layout.Column = 2;

            % Create StatusLabel
            app.StatusLabel = uilabel(app.RightPanel);
            app.StatusLabel.Position = [2 1 449 22];
            app.StatusLabel.Text = 'Status';

            % Show the figure after all components are created
            app.IoTDataExplorerForThingSpeakUIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        function app = IoTDataExplorer
            % Construct app
            createComponents(app)

            % Register the app with App Designer
            registerApp(app, app.IoTDataExplorerForThingSpeakUIFigure)

            % Execute the startup function
            runStartupFcn(app, @startupFcn)

            if nargout == 0
                clear app
            end
        end

        function delete(app)
            delete(app.IoTDataExplorerForThingSpeakUIFigure)
        end
    end
end
