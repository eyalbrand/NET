function hekaBrowser(varargin)
% Browser for files generated by the Heka Patchmaster software
% A gui can be used to display the data and navigate through the data set.


if nargin == 0
    [fName pName] = uigetfile('*.mat;*.dat','Choose data file');
    if fName == 0
        return
    end
else
    fName = varargin{1};
    pName = '';
end

[pn fn ext] = fileparts([pName fName]);
% Load data file
switch ext
    case '.mat'
        % Previously prepared data
        data = load([pName fName]);
    case '.dat'
        % Import and transform data 
        fName = transformHekaDat([pName fName]);
        data = load([pName fName]);
end
groups = data.groups;
series = data.series;
sweeps = data.sweeps;
data   = data.data; % mh change @16102014 > backchnage 17102014
fName = which(fName);


% Prepare GUI and plots
scrSz = get(0,'ScreenSize');
guiPos = [10 scrSz(4)-480 400 450];
gui = figure('Position',guiPos,'Menubar','none','Name',fn, 'NumberTitle','off',...
    'CloseRequestFcn',@closeGui);
% Listboxes for navigating through tree structure
lbSz = [95 guiPos(4)-100];
strgs = {'Groups','Series','Sweeps','Traces'};
for i=1:4
    txt_lbTitle(i) = uicontrol('Style','text','Position',[(i-1)*(lbSz(1)+2)+5 guiPos(4)-14 lbSz(1) 12],...
        'String',strgs{i},'HorizontalAlignment','center','BackgroundColor',get(gui,'color'));
    lb(i) = uicontrol('style','listbox','Position',[(i-1)*(lbSz(1)+3)+5 guiPos(4)-lbSz(2)-15 lbSz],...
        'Callback',{@updateListbox,i});

end
set(lb(3:4), 'Max',2);
% Hide groups-listbox, since I don't use groups so far. Listbox
% functionality is implemented and should work fine.
set([lb(1) txt_lbTitle(1)],'Visible','off');
% Make Series-listbox bigger for long names
set(lb(2), 'Position',[5 guiPos(4)-lbSz(2)-15 lbSz(1)*2+3 lbSz(2)]);
set(txt_lbTitle(2), 'Position',[5 guiPos(4)-14 lbSz(1)*2+3 12]);
% Options for data display
cb_showAllSweeps = uicontrol('Style','checkbox','Position',[(3-1)*(lbSz(1)+3)+5 guiPos(4)-lbSz(2)-15-15 lbSz(1) 14],...
    'String','Show all', 'Value',1, 'Backgroundcolor',get(gui, 'Color'), 'Callback', @updatePlots);
cb_concatenateSweeps = uicontrol('Style','checkbox','Position',[(3-1)*(lbSz(1)+3)+5 guiPos(4)-lbSz(2)-15-30 lbSz(1) 14],...
    'String','Concatenate', 'Value',0, 'Backgroundcolor',get(gui, 'Color'), 'Callback', @updatePlots);
cb_averageSelection = uicontrol('Style','checkbox','Position',[(3-1)*(lbSz(1)+3)+5 guiPos(4)-lbSz(2)-15-45 lbSz(1) 14],...
    'String','Average', 'Value',0, 'Backgroundcolor',get(gui, 'Color'), 'Callback', @updatePlots);
cb_showAllTraces = uicontrol('Style','checkbox','Position',[(4-1)*(lbSz(1)+3)+5 guiPos(4)-lbSz(2)-15-15 lbSz(1) 14],...
    'String','Show all', 'Value',1, 'Backgroundcolor',get(gui, 'Color'), 'Callback', @updatePlots);
cb_keepXLim = uicontrol('Style','checkbox','Position',[(4-1)*(lbSz(1)+3)+5 guiPos(4)-lbSz(2)-15-30 lbSz(1) 14],...
    'String','Keep x-lim', 'Value',0, 'Backgroundcolor',get(gui, 'Color'), 'Callback', @updatePlots);
cb_keepYLim = uicontrol('Style','checkbox','Position',[(4-1)*(lbSz(1)+3)+5 guiPos(4)-lbSz(2)-15-45 lbSz(1) 14],...
    'String','Keep y-lim', 'Value',0, 'Backgroundcolor',get(gui, 'Color'));
set(gui, 'HandleVisibility','off');

% Initial values
currGroup = 1;
currSeries = 1;
currSweep = 1;
currTrace = 1;
traceInd = [];

% Prepare figure for data plots
plotFig = figure('Position',[10 10 scrSz(3)-20 600],'Name',fName, 'NumberTitle','off');
plotAx = []; % will contain axes handles

% Fill in listboxes for initial setting (also calls updatePlots)
updateListbox(0,0,1)

% Nested functions
    function updatePlots(varargin)
        set(0,'CurrentFigure',plotFig)
        if ~isempty(plotAx)
            xl = get(plotAx(1),'Xlim');
            for ii = 1:numel(traceInd)
                yl{traceInd(ii)} = get(plotAx(ii), 'YLim');
            end
        end
        plotAx = [];
        clf(plotFig);
        if get(cb_showAllSweeps, 'Value')
            sweepInd = 1:numel(series{currSeries});
        else
            sweepInd = get(lb(3), 'Value');
        end
        if get(cb_showAllTraces, 'Value')
            traceInd = 1:numel(sweeps{currSweep(1)});
        else
            traceInd = get(lb(4), 'Value');
        end
        for ii=1:numel(traceInd)
%             plotAx(ii) = subplot(numel(traceInd),1,ii);
            fpos = get(plotFig, 'Position');
            plotAx(ii) = axes('units','pixel','Position',[80 fpos(4)-ii*((fpos(4)-100)/numel(traceInd))-30 fpos(3)-160 ((fpos(4)-100)/numel(traceInd))]);
            if numel(sweepInd) > 3
                set(gca,'nextplot','replacechildren', 'COlororder',jet(numel(sweepInd)));
            end
            plotData = data.series(currSeries).trace(traceInd(ii)).data(:,sweepInd);
            if get(cb_averageSelection, 'Value')
                plotData = mean(plotData,2);
            end
            if get(cb_concatenateSweeps, 'Value')
                plotData = reshape(plotData,[],1);
            end
            tv = data.series(currSeries).trace(traceInd(ii)).timeInfo.t0+(data.series(currSeries).trace(traceInd(ii)).timeInfo.dt:data.series(currSeries).trace(traceInd(ii)).timeInfo.dt:data.series(currSeries).trace(traceInd(ii)).timeInfo.dt*size(plotData,1));
            plot(tv,plotData);
            ylabel([data.series(currSeries).trace(traceInd(ii)).header.title ' [' data.series(currSeries).trace(traceInd(ii)).header.adc.Units ']']);
            if ii == numel(traceInd)
                xlabel(['time [' data.series(currSeries).trace(traceInd(ii)).timeInfo.unit ']']);
            else
                set(gca,'XTickLabel',[]);
            end
            set(plotAx,'box','on','units','normalized');
            if numel(traceInd) > 1
                set(plotAx(2:2:end), 'YAxisLocation','right');
            end
        end
        if get(cb_keepXLim, 'Value')
            set(plotAx, 'Xlim', xl);
        end
        if get(cb_keepYLim, 'Value')
            for ii = 1:numel(traceInd)
                if ~isempty(yl{traceInd(ii)})
                    set(plotAx(ii), 'Ylim', yl{traceInd(ii)});
                end
            end
        end
        linkaxes(plotAx, 'x');
    end
    function updateListbox(hh,oo,idx)
        switch idx
            case 1
                updateGroupSelection;
            case 2
                updateSeriesSelection;
            case 3
                updateSweepSelection;
            case 4
                updateTraceSelection;
        end
    end
        function updateGroupSelection
            currGroup = get(lb(1), 'Value');
            groupSeries = groups{currGroup};
            for ii=1:numel(groupSeries)
                if strcmp(data.series(ii).trace(1).header.Patch.Type, 'Current-lamp')
                    str{ii} = 'CC - ';
                else
                    str{ii} = 'VC - ';
                end
                if isempty(data.series(ii).comment)
                    str{ii} = [num2str(ii,'%02d') ' ' str{ii} data.series(ii).label];
                else
                    str{ii} = [num2str(ii,'%02d') ' ' str{ii} data.series(ii).label ' (' data.series(ii).comment ')'];
                end
            end
            set(lb(2), 'String', str);
            currSeries = 1;
            set(lb(2), 'Value', currSeries);
            updateSeriesSelection;
        end
        function updateSeriesSelection
            currSeries = groups{currGroup}(get(lb(2), 'Value'));
            seriesSweeps = series{currSeries};
            for ii=1:numel(seriesSweeps)
                str{ii} = ['Sweep ' num2str(ii,'%02d')];
            end
            set(lb(3), 'String', str);
            if numel(seriesSweeps) < get(lb(3), 'Value')
                set(lb(3), 'Value',numel(seriesSweeps));
            end
            updateSweepSelection;
        end
        function updateSweepSelection
            currSweep = series{currSeries}(get(lb(3), 'Value'));
            sweepTraces = sweeps{currSweep};
            for ii=1:numel(sweepTraces)
                str{ii} = data.series(currSeries).trace(ii).header.title;
            end
            set(lb(4), 'String', str);
            if numel(sweepTraces) < get(lb(4), 'Value')
                set(lb(4), 'Value',numel(sweepTraces));
            end
            updateTraceSelection;
        end
        function updateTraceSelection
            vl = get(lb(4), 'Value');
            vl(vl>numel(sweeps{currSweep(1)})) = [];
            set(lb(4), 'Value',vl);
            currTrace = sweeps{currSweep(1)}(get(lb(4), 'Value'));
            updatePlots;
        end
    function closeGui(varargin)
        delete(gui);
        delete(plotFig);
    end
end


