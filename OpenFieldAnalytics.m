% ==== Load and preprocess position data ====
clc; clear; close all;
load raw_position_data;

% Plot raw position data
rawPosData = figure; 
subplot(2,1,1); plot(t, x); xlabel('Time (ms)'); ylabel('Pixel value'); axis tight
subplot(2,1,2); plot(t, y); xlabel('Time (ms)'); ylabel('Pixel value'); axis tight
sgtitle('Extracted, Raw Position Data');

% Smooth x and y
dt = median(abs(diff(t)))/1000;
filtsize = ceil(0.5 / dt);
filter = ones([1 filtsize]) ./ filtsize;
smooth_x = conv(x, filter, 'same');
smooth_y = conv(y, filter, 'same');
smooth_x(1:ceil(filtsize/2)) = x(1:ceil(filtsize/2));
smooth_y(1:ceil(filtsize/2)) = y(1:ceil(filtsize/2));

% Normalize and center
range_x = max(smooth_x) - min(smooth_x);
range_y = max(smooth_y) - min(smooth_y);
slope_y = 80 / range_y; intercept_y = -40 - (slope_y * min(smooth_y));
slope_x = 80 / range_x; intercept_x = -40 - (slope_x * min(smooth_x));
centered_x = (slope_x * smooth_x) + intercept_x;
centered_y = (slope_y * smooth_y) + intercept_y;

% Velocity, speed, direction
vel_x = diff([centered_x; centered_x(end)]);
vel_y = diff([centered_y; centered_y(end)]);
speed_per_frame = sqrt(vel_x.^2 + vel_y.^2);
vel_t = diff([t; t(end)]) ./ 1000;
speed = speed_per_frame ./ vel_t;
theta = atan2d(centered_y(2:end)-centered_y(1:end-1), centered_x(2:end)-centered_x(1:end-1));
theta = cat(1, theta, NaN);

% Full trajectory
fullTraj = figure;
plot(centered_x, centered_y);
xlabel('X-position (cm)'); ylabel('Y-position (cm)'); title('Continuous Behavioral Data')
xlim([-40 40]); ylim([-40 40]); axis square

% Time series signals
figure;
sgtitle("Filtered Time-Series Analytics")
subplot(4,1,1); plot(t, centered_x); ylabel('X-position (cm)'); axis tight;
subplot(4,1,2); plot(t, centered_y); ylabel('Y-position (cm)'); axis tight;
subplot(4,1,3); plot(t, speed); ylabel('Speed (cm/sec)'); axis tight;
subplot(4,1,4); plot(t, theta); xlabel('Time (ms)'); ylabel('Head Orientation (deg)'); axis tight;

% Head direction binning
partitions = 12;
bin_size = 360 / partitions;
bin_num = discretize(theta+180, 0:bin_size:360);
bin_theta = bin_num * bin_size;

% Rose and angle-time plot
figure;
rose(theta, max(bin_num)); title('Distribution of Head Orientation (deg)')
%subplot(1, 4, [2:4]); hold on; plot(bin_theta); plot(theta + 180); axis tight

% Segment movement
speedTime = (speed > 7.5);
idx1 = 1;
intersectTimes = zeros(partitions, 1000);
for h = bin_size:bin_size:360    
    thetaTime = (bin_theta == h);
    intersect = (speedTime & thetaTime);
    idx2 = 1;
    start0 = find(intersect == true, 1);
    if isempty(start0), idx1 = idx1 + 1; continue; end
    start1 = start0 + 1; counter = 0;

    while ~isempty(start0)
        for i = start1:length(intersect)
            if intersect(i), counter = counter + 1; else, break; end
        end
        if counter >= 4
            intersectTimes(idx1, idx2) = start0;
            intersectTimes(idx1, idx2 + 1) = i - (~intersect(i));
            idx2 = idx2 + 2;
        end
        start1 = i + 1;
        if start1 > length(intersect), break; end
        nextStart = find(intersect(start1:end), 1);
        if isempty(nextStart), break; end
        start0 = nextStart + start1 - 1;
        start1 = start0 + 1;
        counter = 0;
    end
    idx1 = idx1 + 1;
end

% Path segments
segmentFig = figure;
hold on; xlabel('X-position (cm)'); ylabel('Y-position (cm)'); title('Linear Trajectories');
xlim([-40 40]); ylim([-40 40]); axis square
for j = 1:size(intersectTimes, 1)
    temp = unique(intersectTimes(j, :)); temp = temp(temp > 0);
    for k = 1:2:length(temp)-1
        if k+1 <= length(temp)
            plot(centered_x(temp(k):temp(k+1)), centered_y(temp(k):temp(k+1)), ...
                'Color', [0, 0.4470, 0.7410]);
        end
    end
end

% Build data cubes
dir1cube = cell(1, 1000, partitions/2);
dir2cube = cell(1, 1000, partitions/2);
for i = 1:partitions/2
    temp = unique(intersectTimes(i, :)); temp = temp(temp > 0);
    for j = 1:2:length(temp)-1
        if j+1 <= length(temp)
            dir1cube{1, j, i} = centered_x(temp(j):temp(j+1));
            dir1cube{1, j+1, i} = centered_y(temp(j):temp(j+1));
        end
    end    
end
counter = 1;
for i = (partitions/2 + 1):partitions
    temp = unique(intersectTimes(i, :)); temp = temp(temp > 0);
    for j = 1:2:length(temp)-1
        if j+1 <= length(temp)
            dir2cube{1, j, counter} = centered_x(temp(j):temp(j+1));
            dir2cube{1, j+1, counter} = centered_y(temp(j):temp(j+1));
        end
    end
    counter = counter + 1;
end

% Combined Trajectory Figure (All 6 Bins)
combinedTrajFig = figure;
sgtitle('\color{blue}Opposing, Linear Trajectories by Head-Orientation')
angleTitles = {
    '\color{red}0  - 30  \color{black}, 180  - 210 '
    '\color{red}30  - 60  \color{black}, 210  - 240 '
    '\color{red}60  - 90  \color{black}, 240  - 270 '
    '\color{red}90  - 120  \color{black}, 270  - 300 '
    '\color{red}120  - 150  \color{black}, 300  - 330 '
    '\color{red}150  - 180  \color{black}, 330  - 360 '
};

for j = 1:6
    subplot(2, 3, j);
    title(angleTitles{j})
    xlim([-40 40]); ylim([-40 40]); axis square; hold on
    for k = 1:2:size(dir1cube, 2)
        temp1 = dir1cube(:, :, j);
        temp1 = temp1(k:k+1);
        temp1 = cell2mat(temp1);
        if ~isempty(temp1)
            plot(temp1(:,1), temp1(:,2), 'Color', 'Red');
        end
    end
    for k = 1:2:size(dir2cube, 2)
        temp2 = dir2cube(:, :, j);
        temp2 = temp2(k:k+1);
        temp2 = cell2mat(temp2);
        if ~isempty(temp2)
            plot(temp2(:,1), temp2(:,2), 'Color', 'Black');
        end
    end
end

% Mean Distance Cube
meanDisCube = zeros(500, 500, partitions/2);
for i = 1:size(dir1cube, 3)
    ct1 = 1;
    for j = 1:2:size(dir1cube, 2)-1
        temp1 = dir1cube{1, j, i}; temp2 = dir1cube{1, j+1, i};
        if isempty(temp1) || isempty(temp2), continue; end
        temp3 = [temp1, temp2];
        ct2 = 1;
        for k = 1:2:size(dir2cube, 2)-1
            temp4 = dir2cube{1, k, i}; temp5 = dir2cube{1, k+1, i};
            if isempty(temp4) || isempty(temp5), continue; end
            temp6 = [temp4, temp5];
            disMatrix = pdist2(temp3, temp6);
            meanDisCube(ct2, ct1, i) = mean(disMatrix(:));
            ct2 = ct2 + 1;
        end
        ct1 = ct1 + 1;
    end
end
%% ==== Find "close-enough" black and red trajectories (using 5th percentile) ====
linearMDC = meanDisCube(:); 
linearMDC = linearMDC(linearMDC > 0);
prctileMDC = prctile(linearMDC, 5);

trajR = cell(1, 10000, partitions/2); % red (dir1cube)
trajB = cell(1, 10000, partitions/2); % black (dir2cube)

for a = 1:size(meanDisCube, 3)
    disMatrixTemp = meanDisCube(:, :, a);
    disMatrixTemp = round(disMatrixTemp, 4); % ensure numeric stability
    flatDisMatrix = disMatrixTemp(:);
    flatDisMatrix(flatDisMatrix == 0) = [];  
    flatDisMatrix2 = flatDisMatrix(flatDisMatrix <= prctileMDC);
    
    counter = 1;
    for p = 1:length(flatDisMatrix2)
        [b, r] = find(disMatrixTemp == flatDisMatrix2(p));
        
        % Use only the first matching pair (in case of duplicates)
        if ~isempty(r) && ~isempty(b)
            r = r(1);
            b = b(1);
            
            temp1 = dir1cube(1, r*2-1, a);
            temp2 = dir1cube(1, r*2, a);
            temp3 = [temp1, temp2];
            trajR(1, counter:counter+1, a) = temp3;

            temp4 = dir2cube(1, b*2-1, a);
            temp5 = dir2cube(1, b*2, a);
            temp6 = [temp4, temp5];
            trajB(1, counter:counter+1, a) = temp6;

            counter = counter + 2;
        end
    end
end
%% ==== Plot Close-Enough Trajectories (All Bins) ====
closeEnoughFig = figure;
sgtitle('\color{blue}Proximal Opposing Trajectories by Head-Orientation');

angleTitles = {
    '\color{red}0  - 30  \color{black}, 180  - 210 '
    '\color{red}30  - 60  \color{black}, 210  - 240 '
    '\color{red}60  - 90  \color{black}, 240  - 270 '
    '\color{red}90  - 120  \color{black}, 270  - 300 '
    '\color{red}120  - 150  \color{black}, 300  - 330 '
    '\color{red}150  - 180  \color{black}, 330  - 360 '
};

for a = 1:6
    subplot(2, 3, a);
    title(angleTitles{a});
    xlim([-40 40]); ylim([-40 40]); axis square; hold on;

    redTrajTemp = trajR(1, :, a);
    blackTrajTemp = trajB(1, :, a);

    logicalR = false(1, length(redTrajTemp));
    logicalB = false(1, length(blackTrajTemp));

    for s = 1:length(redTrajTemp)
        logicalR(s) = ~isempty(redTrajTemp{1, s});
        logicalB(s) = ~isempty(blackTrajTemp{1, s});
    end

    redTrajTemp = redTrajTemp(logicalR);
    blackTrajTemp = blackTrajTemp(logicalB);

    for h = 1:2:length(blackTrajTemp)-1
        blackTrajX = blackTrajTemp{1,h}(:);
        blackTrajY = blackTrajTemp{1,h+1}(:);
        plot(blackTrajX(:), blackTrajY(:), 'Color', 'Black');

        redTrajX = redTrajTemp{1,h}(:);
        redTrajY = redTrajTemp{1,h+1}(:);
        plot(redTrajX(:), redTrajY(:), 'Color', 'Red');
    end
end


% Combined Histogram for 6 Directional Bins
histFig = figure;
sgtitle('\color{blue}Mean Pairwise Distances by Head-Orientation');
binLabels = {
    '0  - 30 , 180  - 210 '
    '30  - 60 , 210  - 240 '
    '60  - 90 , 240  - 270 '
    '90  - 120 , 270  - 300 '
    '120  - 150 , 300  - 330 '
    '150  - 180 , 330  - 360 '
};
for i = 1:6
    subplot(2, 3, i);
    disMatrixTemp = meanDisCube(:, :, i);
    flatDisMatrix = disMatrixTemp(:);
    flatDisMatrix(flatDisMatrix == 0) = [];
    histogram(flatDisMatrix, 30, 'EdgeColor', [0, 0.4470, 0.7410], ...
        'FaceColor', [0, 0.4470, 0.7410]);
    title(['\color{blue}', binLabels{i}]);
    if i == 2 || i == 5
        ylabel('Frequency');
    end
    if i > 3
        xlabel('Distance');
    end
end

% Composite Histogram with 5th Percentile Threshold
mpdCompositeFig = figure;
prctileMDC = prctile(linearMDC, 5);
histogram(linearMDC, 50, 'EdgeColor', [0, 0.4470, 0.7410], ...
    'FaceColor', [0, 0.4470, 0.7410]);
hold on
plot([prctileMDC prctileMDC], get(gca, 'ylim'), ...
    'Color', 'blue', 'LineWidth', 2);
xlabel('Distance');
ylabel('Frequency');
title('Composite Mean Pairwise Distances (5th Percentile Marked)');

% ==== Save all figures and workspace to ./assets directory ====

% Create full path to "assets" directory relative to this script
[scriptDir, ~, ~] = fileparts(mfilename('fullpath'));
assetsDir = fullfile(scriptDir, 'assets');

% Create directory if it doesn't exist
if ~exist(assetsDir, 'dir')
    mkdir(assetsDir);
end

% Save all open figures
figHandles = findall(0, 'Type', 'figure');
for i = 1:length(figHandles)
    figure(figHandles(i));
    figName = sprintf('Figure_%d', i);
    savefig(figHandles(i), fullfile(assetsDir, [figName, '.fig']));
    saveas(figHandles(i), fullfile(assetsDir, [figName, '.png']));
end

% Save workspace variables (excluding figure handles)
save('output_analysis_data.mat', ...
    'centered_x', 'centered_y', 'speed', 'theta', ...
    'dir1cube', 'dir2cube', 'meanDisCube', ...
    'intersectTimes', 'bin_theta', 'prctileMDC');

disp(['All figures and data saved to: ', assetsDir]);

