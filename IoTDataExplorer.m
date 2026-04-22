classdef IoTDataExplorer < matlab.apps.AppBase
    % IoTDataExplorer - Visualize and compare IoT data from ThingSpeak.
    %
    %   Rewritten as a standalone .m file (no App Designer required).
    %   Supports two modes:
    %     - Time Compare: overlay Recent vs Old data for a single channel
    %     - Channel Compare: stack fields from multiple channels
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
        RightPanel                  matlab.ui.container.Panel
        StatusLabel                 matlab.ui.control.Label
        % Mode toggle and channel management
        CompareModeSwitchLabel      matlab.ui.control.Label
        CompareModeSwitch           matlab.ui.control.DropDown
        AddChannelButton            matlab.ui.control.Button
        RemoveChannelButton         matlab.ui.control.Button
        ChannelTabGroup             matlab.ui.container.TabGroup
        DarkModeSwitch              matlab.ui.control.Switch
        DarkModeSwitchLabel         matlab.ui.control.Label
    end

    properties (Access = private)
        onePanelWidth = 576;
        % Struct array for channel configurations. Each entry has:
        %   .channelID, .apiKey, .channelName,
        %   .fieldNames (1x8 string), .fieldEnabled (1x8 logical),
        %   .tab (uitab handle), .checkboxes (1x8 uicheckbox handles)
        ChannelConfigs = struct('channelID', {}, 'apiKey', {}, ...
            'channelName', {}, 'fieldNames', {}, 'fieldEnabled', {}, ...
            'tab', {}, 'checkboxes', {})
        % Track whether a plot has been made, so auto-update only fires
        % after the first manual Update click.
        HasPlotted = false
    end

    properties (Access = public)
        legendLabel1
        legendLabel2
        myChans
    end

    methods (Access = public)

        function displayFields = enumerateSelectedFields(app)
            % Return 1x8 logical of selected fields for the active channel tab.
            if isempty(app.ChannelConfigs)
                displayFields = false(1, 8);
                return
            end
            idx = getActiveChannelIdx(app);
            if isempty(idx)
                displayFields = false(1, 8);
                return
            end
            cbs = app.ChannelConfigs(idx).checkboxes;
            displayFields = false(1, 8);
            for i = 1:numel(cbs)
                if isvalid(cbs(i))
                    displayFields(i) = cbs(i).Value;
                end
            end
        end
    end

    methods (Access = private)

        function idx = getActiveChannelIdx(app)
            % Find the index in ChannelConfigs matching the selected tab.
            idx = [];
            if isempty(app.ChannelConfigs)
                return
            end
            selectedTab = app.ChannelTabGroup.SelectedTab;
            for i = 1:numel(app.ChannelConfigs)
                if isvalid(app.ChannelConfigs(i).tab) && app.ChannelConfigs(i).tab == selectedTab
                    idx = i;
                    return
                end
            end
        end

        function info = queryChannelFields(app, channelID, apiKey)
            % Query ThingSpeak REST API for channel metadata.
            % Returns struct with .channelName, .fieldNames (1x8 string),
            % .fieldEnabled (1x8 logical).
            info.channelName = "";
            info.fieldNames = repmat("", 1, 8);
            info.fieldEnabled = false(1, 8);

            try
                url = "https://api.thingspeak.com/channels/" + string(channelID) + "/feeds.json?results=0";
                if strlength(apiKey) > 0
                    url = url + "&api_key=" + apiKey;
                end
                data = webread(url);
                channel = data.channel;
                info.channelName = string(channel.name);

                for i = 1:8
                    fieldKey = "field" + string(i);
                    if isfield(channel, fieldKey) && ~isempty(channel.(fieldKey))
                        info.fieldEnabled(i) = true;
                        info.fieldNames(i) = string(channel.(fieldKey));
                    end
                end
            catch err
                app.StatusLabel.Text = "Could not read channel info: " + string(err.message);
            end
        end

        function createChannelTab(app, channelIdx)
            % Create a uitab with 8 checkboxes for the given channel config.
            cfg = app.ChannelConfigs(channelIdx);
            tabTitle = string(cfg.channelID);
            if strlength(cfg.channelName) > 0
                tabTitle = cfg.channelName;
                if strlength(tabTitle) > 12
                    tabTitle = extractBefore(tabTitle, 13);
                end
            end

            newTab = uitab(app.ChannelTabGroup, 'Title', tabTitle);
            cbs = gobjects(1, 8);
            for i = 1:8
                cbs(i) = uicheckbox(newTab);
                cbs(i).Position = [10, 165 - (i-1)*21, 200, 22];
                if cfg.fieldEnabled(i)
                    cbs(i).Enable = 'on';
                    cbs(i).Text = cfg.fieldNames(i);
                    cbs(i).ValueChangedFcn = createCallbackFcn(app, @autoUpdate, true);
                    if i == 1
                        cbs(i).Value = true;
                    end
                else
                    cbs(i).Enable = 'off';
                    cbs(i).Value = false;
                    cbs(i).Text = "F" + string(i);
                end
            end

            app.ChannelConfigs(channelIdx).tab = newTab;
            app.ChannelConfigs(channelIdx).checkboxes = cbs;
            app.ChannelTabGroup.SelectedTab = newTab;
        end

        function [query, queryRecent, queryOld] = buildQueryFromInputs(app)
            %   buildQueryFromInputs   Build the query inputs into a struct.
            %   Used in Time Compare mode for the active channel.
            query = struct();
            queryRecent = struct();
            queryOld = struct();
            app.StatusLabel.Text = 'Status';

            idx = getActiveChannelIdx(app);
            if isempty(idx)
                query.channelID = app.ChannelIDEditField.Value;
                query.APIKey = app.ReadAPIKeyEditField.Value;
            else
                query.channelID = app.ChannelConfigs(idx).channelID;
                query.APIKey = app.ChannelConfigs(idx).apiKey;
            end

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

        function queries = buildChannelCompareQueries(app)
            % Build one query struct per channel for Channel Compare mode.
            startHour = hours(str2double(app.StartHourDropDown.Value));
            startMinute = minutes(str2double(app.MinDropDown.Value));
            startDate = app.StartDateDatePicker.Value + startHour + startMinute;
            if app.AMPMSwitch.Value == "PM"
                startDate = startDate + hours(12);
            end
            endDate = startDate + getCompareDuration(app);

            queries = struct('channelID', {}, 'APIKey', {}, ...
                'fieldsList', {}, 'startDate', {}, 'endDate', {}, ...
                'startHour', {}, 'startMinute', {});

            for chIdx = 1:numel(app.ChannelConfigs)
                cfg = app.ChannelConfigs(chIdx);
                cbs = cfg.checkboxes;
                fieldsList = [];
                for i = 1:8
                    if isvalid(cbs(i)) && cbs(i).Value
                        fieldsList = [fieldsList, i]; %#ok<AGROW>
                    end
                end
                if isempty(fieldsList)
                    continue
                end
                q.channelID = cfg.channelID;
                q.APIKey = cfg.apiKey;
                q.fieldsList = fieldsList;
                q.startDate = startDate;
                q.endDate = endDate;
                q.startHour = startHour;
                q.startMinute = startMinute;
                queries = [queries, q]; %#ok<AGROW>
            end
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
            %   visualizeData   Display the data in tiled plots (Time Compare mode).
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

            tl = tiledlayout(app.RightPanel, sum(dataDisplayFields), 1, 'tilespacing', 'none');

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
                    myAxes = nexttile(tl);
                    plotVar = recentData.(myTile);
                    plot(myAxes, elapsedRecent(1:minLength), plotVar(1:minLength), '-o', 'MarkerSize', 2);

                    if app.CompareLengthDropDown.Value ~= minutes(0)
                        hold(myAxes, "on");
                        plotVar2 = oldData.(myTile);
                        plot(myAxes, elapsedOld(1:minLength), plotVar2(1:minLength), '-*', 'MarkerSize', 2);
                    end

                    tt = title(myAxes, recentData.Properties.VariableNames(myTile));
                    tt.Units = 'normalized';
                    tt.Position = [0.5 0.9 0];

                    if myTile > 1
                        set(myAxes, 'xtick', []);
                        legend(myAxes, ["Recent", "Old"], 'Location', 'best');
                    else
                        legend(myAxes, {app.legendLabel1, app.legendLabel2}, 'Location', 'best');
                    end
                    styleAxesForTheme(app, myAxes);
                end
            end
        end

        function visualizeDataChannelCompare(app, allData, queries)
            % Display stacked tiles for all channels (Channel Compare mode).
            totalTiles = 0;
            for i = 1:numel(queries)
                if ~isempty(allData{i}) && width(allData{i}) > 0
                    totalTiles = totalTiles + width(allData{i});
                end
            end

            if totalTiles == 0
                return
            end

            % Find the widest time range across all channels
            globalMin = NaT;
            globalMax = NaT;
            for i = 1:numel(allData)
                if ~isempty(allData{i}) && height(allData{i}) > 0
                    t1 = allData{i}.Timestamps(1);
                    t2 = allData{i}.Timestamps(end);
                    if isnat(globalMin) || t1 < globalMin
                        globalMin = t1;
                    end
                    if isnat(globalMax) || t2 > globalMax
                        globalMax = t2;
                    end
                end
            end

            tl = tiledlayout(app.RightPanel, totalTiles, 1, 'TileSpacing', 'compact');
            colors = lines(numel(queries));
            allAxes = gobjects(totalTiles, 1);
            tileIdx = 0;

            for chIdx = 1:numel(queries)
                data = allData{chIdx};
                if isempty(data) || width(data) == 0
                    continue
                end

                for fIdx = 1:width(data)
                    tileIdx = tileIdx + 1;
                    ax = nexttile(tl);
                    allAxes(tileIdx) = ax;
                    plot(ax, data.Timestamps, data.(fIdx), '-o', ...
                        'MarkerSize', 2, 'Color', colors(chIdx,:));

                    titleStr = "Ch " + string(queries(chIdx).channelID) + ": " + ...
                        string(data.Properties.VariableNames{fIdx});
                    tt = title(ax, titleStr);
                    tt.Units = 'normalized';
                    tt.Position = [0.5 0.9 0];
                    styleAxesForTheme(app, ax);
                end
            end

            % Align all axes to the widest time range
            if ~isnat(globalMin) && ~isnat(globalMax)
                for i = 1:tileIdx
                    xlim(allAxes(i), [globalMin globalMax]);
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

        function savePreferences(app)
            % Persist channel IDs, API keys, and theme to MATLAB prefs.
            ids = [];
            keys = {};
            for i = 1:numel(app.ChannelConfigs)
                ids(end+1) = app.ChannelConfigs(i).channelID; %#ok<AGROW>
                keys{end+1} = app.ChannelConfigs(i).apiKey; %#ok<AGROW>
            end
            setpref('IoTDataExplorer', 'ChannelIDs', ids);
            setpref('IoTDataExplorer', 'APIKeys', keys);
            setpref('IoTDataExplorer', 'DarkMode', app.DarkModeSwitch.Value);
        end

        function loadPreferences(app)
            % Restore saved channels and theme from MATLAB prefs.
            if ispref('IoTDataExplorer', 'DarkMode')
                app.DarkModeSwitch.Value = getpref('IoTDataExplorer', 'DarkMode');
                applyTheme(app);
            end

            if ispref('IoTDataExplorer', 'ChannelIDs')
                ids = getpref('IoTDataExplorer', 'ChannelIDs');
                keys = getpref('IoTDataExplorer', 'APIKeys');
                if ~isempty(ids)
                    % Load the first channel into the ID/key fields
                    app.ChannelIDEditField.Value = ids(1);
                    if numel(keys) >= 1
                        app.ReadAPIKeyEditField.Value = keys{1};
                    end
                    addChannelFromInputs(app);

                    % Load additional channels (Channel Compare mode)
                    for i = 2:numel(ids)
                        app.ChannelIDEditField.Value = ids(i);
                        if i <= numel(keys)
                            app.ReadAPIKeyEditField.Value = keys{i};
                        else
                            app.ReadAPIKeyEditField.Value = '';
                        end
                        addChannelFromInputs(app);
                    end
                    % Restore the first channel in the input fields
                    app.ChannelIDEditField.Value = ids(1);
                    if ~isempty(keys)
                        app.ReadAPIKeyEditField.Value = keys{1};
                    end
                    return
                end
            end
            % No saved prefs — add the default channel
            addChannelFromInputs(app);
        end

        function applyTheme(app)
            % Apply dark or light theme to the app.
            if app.DarkModeSwitch.Value == "On"
                bgColor = [0.15 0.15 0.15];
                fgColor = [0.9 0.9 0.9];
                panelBg = [0.2 0.2 0.2];
            else
                bgColor = [0.94 0.94 0.94];
                fgColor = [0 0 0];
                panelBg = [0.94 0.94 0.94];
            end

            app.IoTDataExplorerForThingSpeakUIFigure.Color = bgColor;
            app.LeftPanel.BackgroundColor = panelBg;
            app.LeftPanel.ForegroundColor = fgColor;
            app.RightPanel.BackgroundColor = panelBg;
            app.RightPanel.ForegroundColor = fgColor;

            % Update all labels
            labels = [app.CompareModeSwitchLabel, app.ChannelIDEditFieldLabel, ...
                app.ReadAPIKeyEditFieldLabel, app.StartDateDatePickerLabel, ...
                app.StartHourDropDownLabel, app.MinDropDownLabel, ...
                app.AMPMSwitchLabel, app.DurationDropDownLabel, ...
                app.XEditField_2Label, app.CompareLengthDropDownLabel, ...
                app.XEditFieldLabel, app.RetimeDropDownLabel, ...
                app.StatusLabel, app.DarkModeSwitchLabel];
            for i = 1:numel(labels)
                labels(i).FontColor = fgColor;
            end

            % Update any existing axes in the right panel
            axList = findobj(app.RightPanel, 'Type', 'axes');
            for i = 1:numel(axList)
                styleAxesForTheme(app, axList(i));
            end
        end

        function styleAxesForTheme(app, ax)
            % Apply current theme colors to an axes object.
            if app.DarkModeSwitch.Value == "On"
                ax.Color = [0.18 0.18 0.18];
                ax.XColor = [0.9 0.9 0.9];
                ax.YColor = [0.9 0.9 0.9];
                ax.Title.Color = [0.9 0.9 0.9];
                if ~isempty(ax.Legend)
                    ax.Legend.TextColor = [0.9 0.9 0.9];
                    ax.Legend.Color = [0.25 0.25 0.25];
                end
            else
                ax.Color = [1 1 1];
                ax.XColor = [0.15 0.15 0.15];
                ax.YColor = [0.15 0.15 0.15];
                ax.Title.Color = [0 0 0];
                if ~isempty(ax.Legend)
                    ax.Legend.TextColor = [0 0 0];
                    ax.Legend.Color = [1 1 1];
                end
            end
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

            % Load saved channels and theme (or add default channel)
            loadPreferences(app);
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
            resizeStatusLabel(app);
        end

        function resizeStatusLabel(app)
            % Stretch StatusLabel to the full width of RightPanel
            panelPos = app.RightPanel.Position;
            app.StatusLabel.Position = [2 1 panelPos(3)-4 22];
        end

        function ChannelIDChanged(app, ~)
            % In Time mode, update the single channel tab when ID or key changes.
            if app.CompareModeSwitch.Value == "Channel"
                return
            end

            channelID = app.ChannelIDEditField.Value;
            apiKey = app.ReadAPIKeyEditField.Value;

            % Remove existing channel and re-add with new ID/key
            if ~isempty(app.ChannelConfigs)
                delete(app.ChannelConfigs(1).tab);
                app.ChannelConfigs(1) = [];
            end

            info = queryChannelFields(app, channelID, apiKey);

            cfg.channelID = channelID;
            cfg.apiKey = apiKey;
            cfg.channelName = info.channelName;
            cfg.fieldNames = info.fieldNames;
            cfg.fieldEnabled = info.fieldEnabled;
            cfg.tab = matlab.ui.container.Tab.empty;
            cfg.checkboxes = gobjects(1, 8);

            if isempty(app.ChannelConfigs)
                app.ChannelConfigs = cfg;
            else
                app.ChannelConfigs = [app.ChannelConfigs, cfg];
            end
            createChannelTab(app, numel(app.ChannelConfigs));

            if strlength(info.channelName) > 0
                app.StatusLabel.Text = "Channel " + string(channelID) + ": " + info.channelName;
            end
            app.RetimeDropDown.Value = 'Raw';
        end

        function addChannelFromInputs(app, ~)
            % Add a channel using the current Channel ID and API Key fields.
            channelID = app.ChannelIDEditField.Value;
            apiKey = app.ReadAPIKeyEditField.Value;

            % Check for duplicate
            for i = 1:numel(app.ChannelConfigs)
                if app.ChannelConfigs(i).channelID == channelID
                    app.StatusLabel.Text = "Channel " + string(channelID) + " already added.";
                    return
                end
            end

            info = queryChannelFields(app, channelID, apiKey);

            cfg.channelID = channelID;
            cfg.apiKey = apiKey;
            cfg.channelName = info.channelName;
            cfg.fieldNames = info.fieldNames;
            cfg.fieldEnabled = info.fieldEnabled;
            cfg.tab = matlab.ui.container.Tab.empty;
            cfg.checkboxes = gobjects(1, 8);

            if isempty(app.ChannelConfigs)
                app.ChannelConfigs = cfg;
            else
                app.ChannelConfigs = [app.ChannelConfigs, cfg];
            end
            createChannelTab(app, numel(app.ChannelConfigs));

            if strlength(info.channelName) > 0
                app.StatusLabel.Text = "Added channel " + string(channelID) + ": " + info.channelName;
            else
                app.StatusLabel.Text = "Added channel " + string(channelID);
            end
            app.RetimeDropDown.Value = 'Raw';
        end

        function removeSelectedChannel(app, ~)
            % Remove the currently selected channel tab.
            idx = getActiveChannelIdx(app);
            if isempty(idx)
                return
            end
            % Don't allow removing the last channel in Time mode
            if app.CompareModeSwitch.Value == "Time" && numel(app.ChannelConfigs) <= 1
                app.StatusLabel.Text = "Cannot remove the only channel in Time mode.";
                return
            end

            delete(app.ChannelConfigs(idx).tab);
            app.ChannelConfigs(idx) = [];

            if isempty(app.ChannelConfigs)
                app.StatusLabel.Text = "No channels. Add one to continue.";
            else
                app.StatusLabel.Text = "Channel removed.";
            end
        end

        function CompareModeChanged(app, ~)
            % Toggle between Time Compare and Channel Compare modes.
            if app.CompareModeSwitch.Value == "Time"
                % Show time compare controls, hide add/remove buttons
                app.CompareLengthDropDownLabel.Visible = 'on';
                app.CompareLengthDropDown.Visible = 'on';
                app.XEditFieldLabel.Visible = 'on';
                app.plotLengthofComparison.Visible = 'on';
                app.AddChannelButton.Visible = 'off';
                app.RemoveChannelButton.Visible = 'off';

                % In Time mode, keep only the first channel
                while numel(app.ChannelConfigs) > 1
                    delete(app.ChannelConfigs(end).tab);
                    app.ChannelConfigs(end) = [];
                end

                % Re-sync with the Channel ID field
                ChannelIDChanged(app);
                app.StatusLabel.Text = "Time Compare mode";
            else
                % Hide time compare controls, show add/remove buttons
                app.CompareLengthDropDownLabel.Visible = 'off';
                app.CompareLengthDropDown.Visible = 'off';
                app.XEditFieldLabel.Visible = 'off';
                app.plotLengthofComparison.Visible = 'off';
                app.AddChannelButton.Visible = 'on';
                app.RemoveChannelButton.Visible = 'on';
                app.StatusLabel.Text = "Channel Compare mode — use +/- to add/remove channels";
            end
        end

        function DarkModeChanged(app, ~)
            applyTheme(app);
        end

        function autoUpdate(app, ~)
            % Re-fetch and re-plot when any control changes, but only
            % after the user has clicked Update at least once.
            % Errors are shown in the status label instead of modal alerts.
            if app.HasPlotted
                try
                    UpdateButtonPushed(app, []);
                catch err
                    app.StatusLabel.Text = "Update failed: " + string(err.message);
                end
            end
        end

        function UpdateButtonPushed(app, event)
            app.HasPlotted = true;
            d = uiprogressdlg(app.IoTDataExplorerForThingSpeakUIFigure, ...
                'Title', 'Fetching data', 'Message', 'Reading from ThingSpeak...', ...
                'Indeterminate', 'on');
            cleanupObj = onCleanup(@() close(d));

            if app.CompareModeSwitch.Value == "Time"
                % Existing Time Compare flow
                [query, queryRecent, queryOld] = buildQueryFromInputs(app);

                recentData = getDataFromQuery(app, query, queryRecent);
                oldData = getDataFromQuery(app, query, queryOld);

                app.legendLabel1 = getLegendLabel(app, queryRecent.startDate);
                app.legendLabel2 = string(queryOld.startDate);

                visualizeData(app, recentData, oldData, query);
            else
                % Channel Compare flow
                queries = buildChannelCompareQueries(app);
                if isempty(queries)
                    app.StatusLabel.Text = "No fields selected on any channel.";
                    return
                end

                allData = cell(1, numel(queries));
                for i = 1:numel(queries)
                    d.Message = "Reading channel " + string(i) + " of " + string(numel(queries)) + "...";
                    qse.startDate = queries(i).startDate;
                    qse.endDate = queries(i).endDate;
                    allData{i} = getDataFromQuery(app, queries(i), qse);
                end

                visualizeDataChannelCompare(app, allData, queries);
            end
        end

        function QuitButtonPushed(app, event)
            savePreferences(app);
            app.delete
        end

        function OutputtoWorkspaceButtonPushed(app, event)
            if app.CompareModeSwitch.Value == "Time"
                [query, queryRecent, queryOld] = buildQueryFromInputs(app);
                recentData = getDataFromQuery(app, query, queryRecent);
                oldData = getDataFromQuery(app, query, queryOld);

                labels = {'Save recent data to timetable named:' 'Save old data to timetable named:'};
                vars = {'recentData', 'oldData'};
                values = {recentData, oldData};
                export2wsdlg(labels, vars, values);
            else
                queries = buildChannelCompareQueries(app);
                if isempty(queries)
                    app.StatusLabel.Text = "No fields selected on any channel.";
                    return
                end
                labels = {};
                vars = {};
                values = {};
                for i = 1:numel(queries)
                    qse.startDate = queries(i).startDate;
                    qse.endDate = queries(i).endDate;
                    data = getDataFromQuery(app, queries(i), qse);
                    varName = "channel_" + string(queries(i).channelID);
                    labels{end+1} = "Save Ch " + string(queries(i).channelID) + " to:"; %#ok<AGROW>
                    vars{end+1} = char(varName); %#ok<AGROW>
                    values{end+1} = data; %#ok<AGROW>
                end
                export2wsdlg(labels, vars, values);
            end
        end
    end

    % Component initialization
    methods (Access = private)

        function createComponents(app)

            % Create UIFigure
            app.IoTDataExplorerForThingSpeakUIFigure = uifigure('Visible', 'off');
            app.IoTDataExplorerForThingSpeakUIFigure.AutoResizeChildren = 'off';
            app.IoTDataExplorerForThingSpeakUIFigure.Position = [100 100 900 630];
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

            % --- Compare Mode Switch (top of panel) ---
            app.CompareModeSwitchLabel = uilabel(app.LeftPanel);
            app.CompareModeSwitchLabel.HorizontalAlignment = 'right';
            app.CompareModeSwitchLabel.Position = [5 598 90 22];
            app.CompareModeSwitchLabel.Text = 'Compare Mode';

            app.CompareModeSwitch = uidropdown(app.LeftPanel);
            app.CompareModeSwitch.Items = {'Time', 'Channel'};
            app.CompareModeSwitch.Position = [100 598 90 22];
            app.CompareModeSwitch.Value = 'Time';
            app.CompareModeSwitch.ValueChangedFcn = createCallbackFcn(app, @CompareModeChanged, true);

            % --- Channel ID and API Key ---
            app.ChannelIDEditFieldLabel = uilabel(app.LeftPanel);
            app.ChannelIDEditFieldLabel.HorizontalAlignment = 'right';
            app.ChannelIDEditFieldLabel.Position = [5 572 66 22];
            app.ChannelIDEditFieldLabel.Text = 'Channel ID';

            app.ChannelIDEditField = uieditfield(app.LeftPanel, 'numeric');
            app.ChannelIDEditField.ValueDisplayFormat = '%.0f';
            app.ChannelIDEditField.ValueChangedFcn = createCallbackFcn(app, @ChannelIDChanged, true);
            app.ChannelIDEditField.Position = [76 572 55 22];
            app.ChannelIDEditField.Value = 38629;

            % Add/Remove channel buttons (hidden in Time mode)
            app.AddChannelButton = uibutton(app.LeftPanel, 'push');
            app.AddChannelButton.Text = '+';
            app.AddChannelButton.FontWeight = 'bold';
            app.AddChannelButton.Position = [136 572 30 22];
            app.AddChannelButton.ButtonPushedFcn = createCallbackFcn(app, @addChannelFromInputs, true);
            app.AddChannelButton.Visible = 'off';

            app.RemoveChannelButton = uibutton(app.LeftPanel, 'push');
            app.RemoveChannelButton.Text = '-';
            app.RemoveChannelButton.FontWeight = 'bold';
            app.RemoveChannelButton.Position = [170 572 30 22];
            app.RemoveChannelButton.ButtonPushedFcn = createCallbackFcn(app, @removeSelectedChannel, true);
            app.RemoveChannelButton.Visible = 'off';

            app.ReadAPIKeyEditFieldLabel = uilabel(app.LeftPanel);
            app.ReadAPIKeyEditFieldLabel.HorizontalAlignment = 'right';
            app.ReadAPIKeyEditFieldLabel.Position = [5 546 74 22];
            app.ReadAPIKeyEditFieldLabel.Text = 'ReadAPIKey';

            app.ReadAPIKeyEditField = uieditfield(app.LeftPanel, 'text');
            app.ReadAPIKeyEditField.ValueChangedFcn = createCallbackFcn(app, @ChannelIDChanged, true);
            app.ReadAPIKeyEditField.Position = [84 546 140 22];

            % --- Date/Time Controls ---
            app.StartDateDatePickerLabel = uilabel(app.LeftPanel);
            app.StartDateDatePickerLabel.HorizontalAlignment = 'right';
            app.StartDateDatePickerLabel.Position = [8 516 67 22];
            app.StartDateDatePickerLabel.Text = 'Start Date';

            app.StartDateDatePicker = uidatepicker(app.LeftPanel);
            app.StartDateDatePicker.Position = [117 516 109 22];
            app.StartDateDatePicker.Value = datetime('today');
            app.StartDateDatePicker.ValueChangedFcn = createCallbackFcn(app, @autoUpdate, true);

            app.StartHourDropDownLabel = uilabel(app.LeftPanel);
            app.StartHourDropDownLabel.HorizontalAlignment = 'right';
            app.StartHourDropDownLabel.Position = [10 488 63 22];
            app.StartHourDropDownLabel.Text = 'Start Hour';

            app.StartHourDropDown = uidropdown(app.LeftPanel);
            app.StartHourDropDown.Items = {'0', '1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11', '12'};
            app.StartHourDropDown.ItemsData = {'0', '1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11', '12'};
            app.StartHourDropDown.Position = [22 465 44 22];
            app.StartHourDropDown.Value = '0';
            app.StartHourDropDown.ValueChangedFcn = createCallbackFcn(app, @autoUpdate, true);

            app.MinDropDownLabel = uilabel(app.LeftPanel);
            app.MinDropDownLabel.HorizontalAlignment = 'right';
            app.MinDropDownLabel.Position = [80 488 36 22];
            app.MinDropDownLabel.Text = 'Min';

            app.MinDropDown = uidropdown(app.LeftPanel);
            app.MinDropDown.Items = {'0', '1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11', '12', '13', '14', '15', '16', '17', '18', '19', '20', '21', '22', '23', '24', '25', '26', '27', '28', '29', '30', '31', '32', '33', '34', '35', '36', '37', '38', '39', '40', '41', '42', '43', '44', '45', '46', '47', '48', '49', '50', '51', '52', '53', '54', '55', '56', '57', '58', '59', '60'};
            app.MinDropDown.ItemsData = {'0', '1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11', '12', '13', '14', '15', '16', '17', '18', '19', '20', '21', '22', '23', '24', '25', '26', '27', '28', '29', '30', '31', '32', '33', '34', '35', '36', '37', '38', '39', '40', '41', '42', '43', '44', '45', '46', '47', '48', '49', '50', '51', '52', '53', '54', '55', '56', '57', '58', '59', '60'};
            app.MinDropDown.Position = [92 465 44 22];
            app.MinDropDown.Value = '0';
            app.MinDropDown.ValueChangedFcn = createCallbackFcn(app, @autoUpdate, true);

            app.AMPMSwitchLabel = uilabel(app.LeftPanel);
            app.AMPMSwitchLabel.HorizontalAlignment = 'center';
            app.AMPMSwitchLabel.Position = [169 486 45 22];
            app.AMPMSwitchLabel.Text = 'AM/PM';

            app.AMPMSwitch = uiswitch(app.LeftPanel, 'slider');
            app.AMPMSwitch.Items = {'AM', 'PM'};
            app.AMPMSwitch.Position = [166 465 45 20];
            app.AMPMSwitch.Value = 'AM';
            app.AMPMSwitch.ValueChangedFcn = createCallbackFcn(app, @autoUpdate, true);

            % --- Duration and Compare Length ---
            app.DurationDropDownLabel = uilabel(app.LeftPanel);
            app.DurationDropDownLabel.HorizontalAlignment = 'right';
            app.DurationDropDownLabel.Position = [7 434 57 22];
            app.DurationDropDownLabel.Text = 'Duration';

            app.DurationDropDown = uidropdown(app.LeftPanel);
            app.DurationDropDown.Items = {'Minute', 'Hour', 'Day', 'Week'};
            app.DurationDropDown.Position = [102 434 65 22];
            app.DurationDropDown.Value = 'Day';
            app.DurationDropDown.ValueChangedFcn = createCallbackFcn(app, @autoUpdate, true);

            app.XEditField_2Label = uilabel(app.LeftPanel);
            app.XEditField_2Label.HorizontalAlignment = 'right';
            app.XEditField_2Label.Position = [172 434 25 22];
            app.XEditField_2Label.Text = 'X';

            app.plotDuration = uieditfield(app.LeftPanel, 'numeric');
            app.plotDuration.Limits = [1 365];
            app.plotDuration.Position = [205 434 30 22];
            app.plotDuration.Value = 1;
            app.plotDuration.ValueChangedFcn = createCallbackFcn(app, @autoUpdate, true);

            app.CompareLengthDropDownLabel = uilabel(app.LeftPanel);
            app.CompareLengthDropDownLabel.HorizontalAlignment = 'right';
            app.CompareLengthDropDownLabel.Position = [10 408 90 22];
            app.CompareLengthDropDownLabel.Text = 'Compare Length';

            app.CompareLengthDropDown = uidropdown(app.LeftPanel);
            app.CompareLengthDropDown.Items = {'None', 'Minute', 'Hour', 'Day', 'Week', 'Year'};
            app.CompareLengthDropDown.Position = [113 408 67 22];
            app.CompareLengthDropDown.Value = 'Week';
            app.CompareLengthDropDown.ValueChangedFcn = createCallbackFcn(app, @autoUpdate, true);

            app.XEditFieldLabel = uilabel(app.LeftPanel);
            app.XEditFieldLabel.HorizontalAlignment = 'right';
            app.XEditFieldLabel.Position = [172 408 25 22];
            app.XEditFieldLabel.Text = 'X';

            app.plotLengthofComparison = uieditfield(app.LeftPanel, 'numeric');
            app.plotLengthofComparison.Limits = [1 365];
            app.plotLengthofComparison.Position = [205 408 30 22];
            app.plotLengthofComparison.Value = 1;
            app.plotLengthofComparison.ValueChangedFcn = createCallbackFcn(app, @autoUpdate, true);

            % --- Retime ---
            app.RetimeDropDownLabel = uilabel(app.LeftPanel);
            app.RetimeDropDownLabel.HorizontalAlignment = 'right';
            app.RetimeDropDownLabel.Position = [47 382 45 22];
            app.RetimeDropDownLabel.Text = 'Retime';

            app.RetimeDropDown = uidropdown(app.LeftPanel);
            app.RetimeDropDown.Items = {'Raw', 'minutely', 'hourly', 'daily', 'weekly', 'monthly'};
            app.RetimeDropDown.Position = [107 382 89 22];
            app.RetimeDropDown.Value = 'Raw';
            app.RetimeDropDown.ValueChangedFcn = createCallbackFcn(app, @autoUpdate, true);

            % --- Channel Tab Group (replaces fixed F1-F8 checkboxes) ---
            app.ChannelTabGroup = uitabgroup(app.LeftPanel);
            app.ChannelTabGroup.Position = [5 80 231 295];

            % --- Action Buttons ---
            app.UpdateButton = uibutton(app.LeftPanel, 'push');
            app.UpdateButton.ButtonPushedFcn = createCallbackFcn(app, @UpdateButtonPushed, true);
            app.UpdateButton.BackgroundColor = [0 1 0];
            app.UpdateButton.Position = [5 53 55 22];
            app.UpdateButton.Text = 'Update';

            app.OutputtoWorkspaceButton = uibutton(app.LeftPanel, 'push');
            app.OutputtoWorkspaceButton.ButtonPushedFcn = createCallbackFcn(app, @OutputtoWorkspaceButtonPushed, true);
            app.OutputtoWorkspaceButton.BackgroundColor = [0.8 0.8 0.8];
            app.OutputtoWorkspaceButton.Position = [65 53 128 22];
            app.OutputtoWorkspaceButton.Text = 'Output to Workspace';

            app.QuitButton = uibutton(app.LeftPanel, 'push');
            app.QuitButton.ButtonPushedFcn = createCallbackFcn(app, @QuitButtonPushed, true);
            app.QuitButton.BackgroundColor = [1 0 0];
            app.QuitButton.Position = [198 53 40 22];
            app.QuitButton.Text = 'Quit';

            % --- Dark Mode Toggle ---
            app.DarkModeSwitchLabel = uilabel(app.LeftPanel);
            app.DarkModeSwitchLabel.HorizontalAlignment = 'right';
            app.DarkModeSwitchLabel.Position = [5 27 65 22];
            app.DarkModeSwitchLabel.Text = 'Dark Mode';

            app.DarkModeSwitch = uiswitch(app.LeftPanel, 'slider');
            app.DarkModeSwitch.Items = {'Off', 'On'};
            app.DarkModeSwitch.Position = [115 30 45 20];
            app.DarkModeSwitch.Value = 'Off';
            app.DarkModeSwitch.ValueChangedFcn = createCallbackFcn(app, @DarkModeChanged, true);

            % Create RightPanel
            app.RightPanel = uipanel(app.GridLayout);
            app.RightPanel.Layout.Row = 1;
            app.RightPanel.Layout.Column = 2;

            % Create StatusLabel anchored to bottom of RightPanel, full width
            app.StatusLabel = uilabel(app.RightPanel);
            app.StatusLabel.Text = 'Status';
            resizeStatusLabel(app);

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
            try
                savePreferences(app);
            catch
                % Preferences save may fail if components are already gone
            end
            delete(app.IoTDataExplorerForThingSpeakUIFigure)
        end
    end
end
