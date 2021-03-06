%% extrapSonTekIQ
% A script to compute power law extrapolation for supplied SonTek IQ+ data
%
% TODO: output time and depth for averaging interval; document

% Inputs
% sontekMatFile = './example/01467087_20210322_175842.mat';
% sontekVelFile = './example/01467087_20210322_175842.VEL';
sontekMatFile = './example/01467087_20210324_000110.mat';
sontekVelFile = './example/01467087_20210324_000110.VEL';
columnSkip = 6;
columnCellCenter = 14;
usedFlowMean = false;
minDepthForFit = 0;
averageInterval = 5;  % For averaging profiles
fitType = 'PowerPower';


%%% --- DO NOT EDIT BELOW THIS LINE ---

clc; close all;
clearvars -except sontekVelFile sontekMatFile columnSkip columnCellCenter usedFlowMean minDepthForFit fitType averageInterval

%% Load input SonTek File and Parse to variables
[time, flowDepth, zdim, udim, u, w] = parseSonTekIQ(sontekVelFile, sontekMatFile, columnCellCenter, columnSkip, usedFlowMean);


%% Process the flow data
% Explanation
disp('Computing extrap for each data point...')
[exponent, alpha, time_extrap] = computeExtrap(time, flowDepth, udim, zdim, minDepthForFit, fitType, 1, false);

% Average every averageInterval samples, include a plot
disp(['Computing extrap at data point interval of every ' averageInterval  ' elements...'])
[exponent_avg, alpha_avg, time_extrap_avg] = computeExtrap(time, flowDepth, udim, zdim, minDepthForFit, fitType, averageInterval, false);

%% Create a plot of the data
fh = figure(1);
fh.Position = [1000 700 1000 600];
set(fh,'Name', 'Processed ADVM Data');
gcf; clf;
h1 = plot(time_extrap, exponent, 'Color', 'blue', 'LineStyle', '-', LineWidth=1.5); hold on
h2 = plot(time_extrap_avg, exponent_avg, 'bs', 'markerSize', 8, 'MarkerFaceColor','white');
h3 = plot(time_extrap, alpha, 'Color', 'green', 'LineStyle', '-', LineWidth=1.5); hold on
h4 = plot(time_extrap_avg, alpha_avg, 'gs', 'markerSize', 8, 'MarkerFaceColor','white');
datetick x
legend('Exponent', 'Avg Exponent', 'Alpha', 'Avg Alhpa')
title('Results of fitting ADVM data with extrap')
xlabel('Time')
ylabel('Value')

%% Create CSV files of the results
[fpath, name, ext]  = fileparts(sontekMatFile);
unitCSVFilename = fullfile(fpath, [name '.csv']);
avgCSVFilename = fullfile(fpath, [name '_avg.csv']);
unitHeaders = {'SampleTimeMat', 'SampleTime','Exponent','Alpha'};
avgHeaders = {'SampleTimeMat', 'SampleTime','AvgExponent','AvgAlpha'};

tab = table(time, datestr(time), exponent', alpha');
Tc = [unitHeaders; table2cell(tab)];
unitTable = cell2table(Tc, 'VariableNames', tab.Properties.VariableNames);

tab = table(time_extrap_avg', datestr(time_extrap_avg'), exponent_avg', alpha_avg');
Tc = [avgHeaders; table2cell(tab)];
avgTable = cell2table(Tc, 'VariableNames', tab.Properties.VariableNames);

writetable(unitTable, unitCSVFilename);
writetable(avgTable, avgCSVFilename);


%% Helper Functions
function [exponent, alpha, time_extrap] = computeExtrap(time, flowDepth, udim, zdim, minDepthForFit, fitType, averageInterval, makePlot)
reverseStr = '';
if (averageInterval == 1)
    for i = 1:numel(flowDepth)
        if flowDepth(i)>=minDepthForFit
            [exponent(i), alpha(i)] = extrapADVM(udim, zdim, i, fitType, makePlot);
            time_extrap(i) = time(i); 
        else
            exponent(i) = nan;
            alpha(i) = nan;
        end
        percentDone = 100 * i / numel(flowDepth);
        msg = sprintf('Computing Extrap. Percent done: %3.1f', percentDone); %Don't forget this semicolon
        fprintf([reverseStr, msg]);
        reverseStr = repmat(sprintf('\b'), 1, length(msg));
    end
    newline; % done

else
    j=1;
    for i = 1:averageInterval:numel(flowDepth)-averageInterval-1
        if nanmin(flowDepth(i:i+averageInterval-1))>=minDepthForFit
            [exponent(j),alpha(j)] = extrapADVM(udim,zdim,i:i+averageInterval-1, fitType, makePlot);
            time_extrap(j) = nanmean(time(i:i+averageInterval-1));
        else
            exponent(j)=nan;
            alpha(j)=nan;
        end
        j=j+1;
        percentDone = 100 * i / numel(flowDepth);
        msg = sprintf('Computing Extrap. Percent done: %3.1f', percentDone); %Don't forget this semicolon
        fprintf([reverseStr, msg]);
        reverseStr = repmat(sprintf('\b'), 1, length(msg));
    end
    newline; % done
end
end

function [time, flowDepth, zdim, udim, u, w] = parseSonTekIQ(sontekVelFile, sontekMatFile, columnCellCenter, columnSkip, usedFlowMean)
disp('Loading Sontek Vel file. This can take a moment, please be patient...')
alldatacell = importSonTekVELfile(sontekVelFile);
disp('   Sontek Vel file loaded.')
disp('Loading Sontek Mat file...')
[flowDepth,U] = loadSonTekMat(sontekMatFile);
disp('   Sontek Mat file loaded.')
maxColumns = 78;
cellcenters = [columnCellCenter:columnSkip:maxColumns];
cellvelX =    [columnCellCenter+1:columnSkip:maxColumns];
cellvelZ =    [columnCellCenter+2:columnSkip:maxColumns];
id = cell2mat(alldatacell(:,1));
time  = cell2mat(alldatacell(:,3));
z  = cell2mat(alldatacell(:,cellcenters));
u  = cell2mat(alldatacell(:,cellvelX));
w  = cell2mat(alldatacell(:,cellvelZ));

% Normalize velocities by depth averaged. If enabbled, attempt to use the
% SonTek "Flow Mean" parameter. Otherwise, compute a layer averaged mean
% from the cell velocities
for i = 1:numel(flowDepth)
    if ~usedFlowMean
        U(i) = layerAverageMean(z(i,:)', u(i,:)');
    end
    zdim(i,:) = z(i,:)./flowDepth(i);
    udim(i,:) = u(i,:)./U(i);
end
end

function alldatacell = importSonTekVELfile(filename, startRow, endRow)
%IMPORTFILE Import numeric data from a text file as a matrix.
%   ALLDATACELL = IMPORTFILE(FILENAME) Reads data from text file FILENAME
%   for the default selection.
%
%   ALLDATACELL = IMPORTFILE(FILENAME, STARTROW, ENDROW) Reads data from
%   rows STARTROW through ENDROW of text file FILENAME.
%
% Example:
%   alldatacell = importfile('lspivADVM_20161128_110610_profiles.VEL', 2, 1531);
%
%    See also TEXTSCAN.

% Auto-generated by MATLAB on 2017/03/08 11:10:05

%% Initialize variables.
delimiter = ',';
if nargin<=2
    startRow = 2;
    endRow = inf;
end

% Read columns of data as strings:
% For more information, see the TEXTSCAN documentation.
formatSpec = '%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%[^\n\r]';
% formatSpec = '%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%f%f%f%f%f%f%f%f%f%f%f%f%f%f%f%f%f%f%f%f%f%f%f%f%f%f%f%f%f%f%f%f%f%f%f%f%f%f%f%f%f%f%f%f%f%f%f%f%f%f%f%f%f%f%f%f%f%f%f%f%[^\n\r]';

% Open the text ,%ile.
fileID = fopen(filename,'r');

% Read columns of data according to format string.
% This call is based on the structure of the file used to generate this
% code. If an error occurs for a different file, try regenerating the code
% from the Import Tool.
dataArray = textscan(fileID, formatSpec, endRow(1)-startRow(1)+1, 'Delimiter', delimiter, 'HeaderLines', startRow(1)-1, 'ReturnOnError', false);
for block=2:length(startRow)
    frewind(fileID);
    dataArrayBlock = textscan(fileID, formatSpec, endRow(block)-startRow(block)+1, 'Delimiter', delimiter, 'HeaderLines', startRow(block)-1, 'ReturnOnError', false);
    for col=1:length(dataArray)
        dataArray{col} = [dataArray{col};dataArrayBlock{col}];
    end
end

% Close the text file.
fclose(fileID);

% Convert the contents of columns containing numeric strings to numbers.
% Replace non-numeric strings with NaN.
raw = repmat({''},length(dataArray{1}),length(dataArray)-1);
for col=1:length(dataArray)-1
    raw(1:length(dataArray{col}),col) = dataArray{col};
end
numericData = NaN(size(dataArray{1},1),size(dataArray,2));

for col=[1,3,4,5,6,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51,52,53,54,55,56,57,58,59,60,61,62,63,64,65,66,67,68,69,70,71,72,73,74,75,76,77]
    % Converts strings in the input cell array to numbers. Replaced non-numeric
    % strings with NaN.
    rawData = dataArray{col};
    for row=1:size(rawData, 1);
        % Create a regular expression to detect and remove non-numeric prefixes and
        % suffixes.
        regexstr = '(?<prefix>.*?)(?<numbers>([-]*(\d+[\,]*)+[\.]{0,1}\d*[eEdD]{0,1}[-+]*\d*[i]{0,1})|([-]*(\d+[\,]*)*[\.]{1,1}\d+[eEdD]{0,1}[-+]*\d*[i]{0,1}))(?<suffix>.*)';
        try
            result = regexp(rawData{row}, regexstr, 'names');
            numbers = result.numbers;

            % Detected commas in non-thousand locations.
            invalidThousandsSeparator = false;
            if any(numbers==',');
                thousandsRegExp = '^\d+?(\,\d{3})*\.{0,1}\d*$';
                if isempty(regexp(thousandsRegExp, ',', 'once'));
                    numbers = NaN;
                    invalidThousandsSeparator = true;
                end
            end
            % Convert numeric strings to numbers.
            if ~invalidThousandsSeparator;
                numbers = textscan(strrep(numbers, ',', ''), '%f');
                numericData(row, col) = numbers{1};
                raw{row, col} = numbers{1};
            end
        catch me
        end
    end
end


% Split data into numeric and cell columns.
rawNumericColumns = raw(:, [1,3,4,5,6,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51,52,53,54,55,56,57,58,59,60,61,62,63,64,65,66,67,68,69,70,71,72,73,74,75,76,77]);
rawCellColumns = raw(:, [2,7,8]);


% Replace non-numeric cells with NaN
R = cellfun(@(x) ~isnumeric(x) && ~islogical(x),rawNumericColumns); % Find non-numeric cells
rawNumericColumns(R) = {NaN}; % Replace non-numeric cells

% Put it back together again
out = [rawNumericColumns(:,1) rawCellColumns(:,1) rawNumericColumns(:,2:5) rawCellColumns(:,2:3) rawNumericColumns(:,6:end)];

% Create output variable
N = 2; B = cellfun(@datenum, out(:,2));
D = [out(:,1:N) num2cell(B) out(:,N+1:end)];
alldatacell = D;
end

function lam = layerAverageMean(x,y)
% Computes the layer averaged mean of y over the depth range.
% Assumes the data outside the depth range have been set to NaN.
%
% P.R. Jackson, USGS 1-7-09

% Preallocate
intgrl = nan*ones(1,size(y,2));
dz = nan*ones(1,size(y,2));

for i = 1:size(y,2)
    indx        = find(~isnan(y(:,i)));
    if isempty(indx)
        intgrl(i) = NaN;
        dz(i)     = NaN;
    elseif length(indx) == 1;  %Allows a single value mean: mean value = single value (nan before) %PRJ, 3-11-11
        intgrl(i) = y(indx,i);
        dz(i)     = 1;
    elseif length(indx) > 1;
        xt          = x(indx,i);
        yt          = y(indx,i);
        intgrl(i)   = trapz(xt,yt,1);
        dz(i)       = nanmax(xt) - nanmin(xt);
    end
    clear indx
end
lam = intgrl./dz;
end

function [H,U] = loadSonTekMat(filename)
load(filename)
H = FlowData_Depth;
U = FlowData_Vel_Mean;
nullData = -214748368;
U(U==nullData) = nan; % replace null with NaN
end

function [exponent,alpha] = extrapADVM(udim,zdim,range,fitcombo, makePlot)
plotPause = 0.2;
method = 'optimize';  % Use extrap to determine best fit
% fitcombo='ConstantNo Slip';
% fitcombo='PowerPower';

avgz = nanmean(zdim(range,:),1);
y    = nanmean(udim(range,:),1);

[avgz,ind]=sort(avgz,'descend');
y=y(ind);
idxz = find(~isnan(avgz));

if makePlot
    % Start a figure, showing the average of the dimesionless profile
    figure(1);clf
    plot(udim(range,:),zdim(range,:),'.','color', [0.6 0.6 0.6], 'MarkerSize', 10); hold on
    plot(y(idxz),avgz(idxz),'ks', 'MarkerFaceColor', 'k', 'MarkerSize', 8)
end

% Initialize fit boundaries
lowerbnd=[-Inf 0.01];
upperbnd=[Inf   1];


% If less than 4 cells, use default P/P 1/6, otherwise optimize the fit

switch fitcombo
    case ('PowerPower')
        obj.z=0:0.01:1;
        obj.z=obj.z';
        zc=nan;
        uc=nan;
        idxpower = idxz;
    case ('ConstantPower')
        obj.z=0:0.01:max(avgz(idxz));
        obj.z=[obj.z' ; nan];
        zc=max(avgz(idxz))+0.01:0.01:1;
        zc=zc';
        uc=repmat(y(idxz(1)),size(zc));

    case ('3-PointPower')
        obj.z=0:0.01:max(avgz(idxz));
        obj.z=[obj.z' ; nan];
        % If less than 6 bins use constant at the top
        if length(idxz)<6
            zc=max(avgz(idxz))+0.01:0.01:1;
            zc=zc';
            uc=repmat(y(idxz(1)),size(zc));
        else
            p=polyfit(avgz(idxz(1:3)),y(idxz(1:3)),1);
            zc=max(avgz(idxz))+0.01:0.01:1;
            zc=zc';
            uc=zc.*p(1)+p(2);
        end % if nbins

    case ('ConstantNo Slip')

        % Optimize Constant / No Slip if sufficient cells
        % are available.
        if strcmpi(method,'optimize')
            idx=idxz(1+end-floor(length(avgz(idxz))/3):end);
            if length(idx)<3
                method='default';
            end % if

            % Compute Constant / No Slip using WinRiver II and
            % RiverSurveyor Live default cells
        else
            idx=find(avgz(idxz)<=0.2);
            if isempty(idx)
                idx=idxz(end);
            else
                idx=idxz(idx);
            end
        end % if method

        % Configure u and z arrays
        idxns=idx;
        obj.z=0:0.01:avgz(idxns(1));
        obj.z=[obj.z' ; nan];
        idxpower=idx;
        zc=max(avgz(idxz))+0.01:0.01:1;
        zc=zc';
        uc=repmat(y(idxz(1)),size(zc));

    case '3-PointNo Slip'

        % Optimize Constant / No Slip if sufficient cells
        % are available.
        if strcmpi(method,'optimize')
            idx=idxz(1+end-floor(length(avgz(idxz))/3):end);
            if length(idx)<4
                method='default';
            end % if

            % Compute Constant / No Slip using WinRiver II and
            % RiverSurveyor Live default cells
        else
            idx=find(avgz(idxz)<=0.2);
            if isempty(idx)
                idx=idxz(end);
            else
                idx=idxz(idx);
            end
        end % if method

        % Configure u and z arrays
        idxns=idx;
        obj.z=0:0.01:avgz(idxns(1));
        obj.z=[obj.z' ; nan];
        idxpower=idx;

        % If less than 6 bins use constant at the top
        if length(idxz)<6
            zc=max(avgz(idxz))+0.01:0.01:1;
            zc=zc';
            uc=repmat(y(idxz(1)),size(zc));
        else
            p=polyfit(avgz(idxz(1:3)),y(idxz(1:3)),1);
            zc=max(avgz(idxz))+0.01:0.01:1;
            zc=zc';
            uc=zc.*p(1)+p(2);
        end % if nbins

end % switch fitcombo

% Compute exponent
zfit=avgz(idxpower);
yfit=y(idxpower);

% Check data validity
ok_ = isfinite(zfit) & isfinite(yfit);
if ~all( ok_ )
    warning( 'GenerateMFile:IgnoringNansAndInfs', ...
        'Ignoring NaNs and Infs in data' );
end % if

obj.exponent=nan;
obj.exponent95confint=[nan nan];
obj.rsqr=nan;

switch lower(method)
    case ('manual')
        %obj.exponent=varargin{1};
        model=['x.^' num2str(obj.exponent)];
        ft_=fittype({model},'coefficients',{'a1'});
        fo_ = fitoptions('method','LinearLeastSquares');
    case ('default')
        obj.exponent=1./6;
        model=['x.^' num2str(obj.exponent)];
        ft_=fittype({model},'coefficients',{'a1'});
        fo_ = fitoptions('method','LinearLeastSquares');
    case ('optimize')

        % Set fit options
        fo_ = fitoptions('method','NonlinearLeastSquares','Lower',lowerbnd,'Upper',upperbnd);
        ft_ = fittype('power1');

        % Set fit data
        strt=yfit(ok_);
        st_ = [strt(end) 1./6 ];
        set(fo_,'Startpoint',st_);
end % switch method

% Fit data
if length(ok_)>1
    [cf, gof, ~] = fit(zfit(ok_)',yfit(ok_)',ft_,fo_);

    % Extract exponent and confidence intervals from fit
    if strcmpi(method,'optimize')
        obj.exponent=cf.b;
        if obj.exponent<0.05
            obj.exponent=0.05;
        end %  if exponent
    end % if method

    if length(zfit(ok_))>2
        exponent95ci=confint(cf);
        if strcmpi(method,'optimize')
            exponent95ci=exponent95ci(:,2);
        end % if
        obj.exponent95confint=exponent95ci;
        obj.rsqr=gof.rsquare;
    else
        exponent95ci=nan;
        exponent95ci=nan;
        obj.exponent95confint=nan;
        obj.rsqr=nan;
    end % if confint
end % if ok_

% Fit power curve to appropriate data
obj.coef=((obj.exponent+1).*0.05.*nansum(y(idxpower)))./...
    nansum(((avgz(idxpower)+0.5.*0.05).^(obj.exponent+1))-((avgz(idxpower)-0.5.*0.05).^(obj.exponent+1)));

% Compute residuals
obj.residuals=y(idxpower)-obj.coef.*avgz(idxpower).^(obj.exponent);

% Compute values (velocity or discharge) based on exponent and compute
% coefficient
obj.u=obj.coef.*obj.z.^(obj.exponent);
if ~isnan(zc)
    obj.u=[obj.u ; uc];
    obj.z=[obj.z ; zc];
end % if zc

% Assign variables to object properties
% obj.fileName=normData.fileName;
% obj.topMethod=top;
% obj.botMethod=bot;
% obj.expMethod=method;
% obj.dataType=normData.dataType;
%%

if makePlot
    figure(1); hold on
    plot(obj.u,obj.z,'k-','linewidth',2)
    title (...
        {'Normalized Extrap'})
    xlabel('Velocity(z)/Avg Velocity')
    ylabel('Depth(z)/Vertical Beam Depth')
    pause(plotPause);
end


k = 1/(obj.exponent + 1);
exponent = obj.exponent;
alpha = k;
%disp(['Exponent: ' num2str(exponent) ' | Alpha (k-index): ' num2str(k)])
end