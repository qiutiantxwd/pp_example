% Detection with PointPillars example script. No training, test with PCs
% compressed to different levels.
% This script is modified from this example: https://www.mathworks.com/help/releases/R2020b/lidar/ug/PointPillars.html
close all; clear; clc;
base_dir='/home/tianqiu/Documents/Research/PointPillars_example_20b';
%% Load pre-trained network
preTrainedMATFile=fullfile(base_dir,'trainedPointPillars','trainedPointPillarsNet.mat');
pretrainedNet = load(preTrainedMATFile);
net = pretrainedNet.net;  
%% Load dataset
% What is this dataset: Captured on highway
% Lidar spec: 64 channels vertical, 1024 channels horizontal.
% FoV: +/- 22.5 vertical, 360 horizontal
% Rotation rate 10 or 20 Hz
% It's organized as a cell of PointCloud objects.
load(fullfile(base_dir, 'WPI_LidarData', 'WPI_LidarData.mat'),'lidarData');
lidarData = reshape(lidarData,size(lidarData,2),1);% Reshape from 1x1617 to 1617x1
%% Load 3D bounding box lables ground truth
% Labels are organized as timetable. Sampled per every one second. It has
% only one class: car.

load('WPI_LidarGroundTruth.mat','bboxGroundTruth');
Labels = timetable2table(bboxGroundTruth);
Labels = Labels(:,2:end);
%% display
figure('Position',[500 500 1200 800])
ax = pcshow(lidarData{1,1}.Location);% Color by z-axis
% ax = pcshow(lidarData{1,1}.Location,lidarData{1,1}.Intensity);% Color by intensity
set(ax,'XLim',[-50 50],'YLim',[-40 40]);
zoom(ax,2.5);
axis off;
%% Preprocess data

xMin = 0.0;     % Minimum value along X-axis.
yMin = -39.68;  % Minimum value along Y-axis.
zMin = -5.0;    % Minimum value along Z-axis.
xMax = 69.12;   % Maximum value along X-axis.
yMax = 39.68;   % Maximum value along Y-axis.
zMax = 5.0;     % Maximum value along Z-axis.
% PointPillars uses a (0.16m)^2 area 2D bin. 
xStep = 0.16;   % Resolution along X-axis.
yStep = 0.16;   % Resolution along Y-axis.
dsFactor = 2.0; % Downsampling factor.

% Calculate the dimensions for pseudo-image.
Xn = round(((xMax - xMin) / xStep));
Yn = round(((yMax - yMin) / yStep));

% Define pillar extraction parameters.
gridParams = {{xMin,yMin,zMin},{xMax,yMax,zMax},{xStep,yStep,dsFactor},{Xn,Yn}};
% Crop the front view
% Load the calibration parameters.
fview = load('calibrationValues.mat');
[inputPointCloud, boxLabels] = createFrontViewFromLidarData(lidarData, Labels, gridParams, fview); 
%% Display the cropped view
figure
ax1 = pcshow(inputPointCloud{1,1}.Location, inputPointCloud{1,1}.Intensity);
gtLabels = boxLabels.car(1,:);
showShape('cuboid', gtLabels{1,1}, 'Parent', ax1, 'Opacity', 0.1, 'Color', 'green','LineWidth',0.5);
zoom(ax1,2);
%% Create FileDatastore and BoxLabelDatastore Objects for Training
rng(1);
shuffledIndices = randperm(size(inputPointCloud,1));
idx = floor(0.7 * length(shuffledIndices));

trainData = inputPointCloud(shuffledIndices(1:idx),:); % 1131
testData = inputPointCloud(shuffledIndices(idx+1:end),:); % 486
%%
trainLabels = boxLabels(shuffledIndices(1:idx),:);
testLabels = boxLabels(stestDataLocation = fullfile(base_dir, 'WPI_LidarData', 'TestData');
saveptCldToPCD(testData,testDataLocation);huffledIndices(idx+1:end),:);
dataLocation = fullfile(base_dir, 'WPI_LidarData', 'InputData');
saveptCldToPCD(trainData,dataLocation);
lds = fileDatastore(dataLocation,'ReadFcn',@(x) pcread(x));
bds = boxLabelDatastore(trainLabels);
cds = combine(lds,bds);

% Custom starts -------------------------------------------------------------------------------------------
%% 1. Save test data to ply file.
testDataLocation = fullfile(base_dir, 'WPI_LidarData', 'TestData');
saveptCldToPCD(testData,testDataLocation);
%% 2. Compress to various levels with Draco
num_test_frames = numel(testData);
for i = 1:num_test_frames
    i
    argument = sprintf("%06d",i);
    command = append("bash ./compress_test_data.sh ",argument);
    status = system(command);
end
%% Visualize a sample encoded pointcloud
figure
sample_source_PC='../WPI_LidarData/TestData/000001.ply';
source_ptCloud = pcread(sample_source_PC);
pcshow(source_ptCloud);
figure
sample_encoded_PC='../WPI_LidarData/CompressedTestData/geom_and_attr/decoded_ply/000001_cl_7_decoded.ply';
encoded_ptCloud = pcread(sample_encoded_PC);
% Custom ends -------------------------------------------------------------------------------------------
%% Data Augmentation
augData = read(cds);
augptCld = augData{1,1};
augLabels = augData{1,2};
figure;
ax2 = pcshow(augptCld.Location);
showShape('cuboid', augLabels, 'Parent', ax2, 'Opacity', 0.1, 'Color', 'green','LineWidth',0.5);
zoom(ax2,2);
reset(cds);
gtData = generateGTDataForAugmentation(trainData,trainLabels);
cdsAugmented = transform(cds,@(x) groundTruthDataAugmenation(x,gtData));
cdsAugmented = transform(cdsAugmented,@(x) augmentData(x));
augData = read(cdsAugmented);
augptCld = augData{1,1};
augLabels = augData{1,2};
figure;
ax3 = pcshow(augptCld(:,1:3));
showShape('cuboid', augLabels, 'Parent', ax3, 'Opacity', 0.1, 'Color', 'green','LineWidth',0.5);
zoom(ax3,2);
reset(cdsAugmented);
%% Extract Pillar Information from Point Clouds
% Define number of prominent pillars.
P = 12000; 

% Define number of points per pillar.
N = 100;   
cdsTransformed = transform(cdsAugmented,@(x) createPillars(x,gridParams,P,N));
%% Define PointPillars Network
anchorBoxes = {{3.9, 1.6, 1.56, -1.78, 0}, {3.9, 1.6, 1.56, -1.78, pi/2}};
numAnchors = size(anchorBoxes,2);
classNames = trainLabels.Properties.VariableNames;
lgraph = pointpillarNetwork(numAnchors,gridParams,P,N);
%% Specify Training Options
% numEpochs = 160;
% miniBatchSize = 2;
% learningRate = 0.0002;
% learnRateDropPeriod = 15;
% learnRateDropFactor = 0.8;
% gradientDecayFactor = 0.9;
% squaredGradientDecayFactor = 0.999;
% trailingAvg = [];
% trailingAvgSq = [];
%% Train Model
executionEnvironment = "auto";
% if canUseParallelPool
%     dispatchInBackground = true;
% else
%     dispatchInBackground = false;
% end
% 
% mbq = minibatchqueue(cdsTransformed,3,...
%                      "MiniBatchSize",miniBatchSize,...
%                      "OutputEnvironment",executionEnvironment,...
%                      "MiniBatchFcn",@(features,indices,boxes,labels) createBatchData(features,indices,boxes,labels,classNames),...
%                      "MiniBatchFormat",["SSCB","SSCB",""],...
%                      "DispatchInBackground",dispatchInBackground);
% if doTraining
%     % Convert layer graph to dlnetwork.
%     net = dlnetwork(lgraph);
%     
%     % Initialize plot.
%     fig = figure;
%     lossPlotter = configureTrainingProgressPlotter(fig);    
%     iteration = 0;
%     
%     % Custom training loop.
%     for epoch = 1:numEpochs
%         
%         % Reset datastore.
%         reset(mbq);
%         
%         while(hasdata(mbq))
%             iteration = iteration + 1;
%             
%             % Read batch of data.
%             [pillarFeatures, pillarIndices, boxLabels] = next(mbq);
%                         
%             % Evaluate the model gradients and loss using dlfeval and the modelGradients function.
%             [gradients, loss, state] = dlfeval(@modelGradients, net, pillarFeatures, pillarIndices, boxLabels,...
%                                                 gridParams, anchorBoxes, executionEnvironment);
%             
%             % Do not update the network learnable parameters if NaN values
%             % are present in gradients or loss values.
%             if checkForNaN(gradients,loss)
%                 continue;
%             end
%                     
%             % Update the state parameters of dlnetwork.
%             net.State = state;
%             
%             % Update the network learnable parameters using the Adam
%             % optimizer.
%             [net.Learnables, trailingAvg, trailingAvgSq] = adamupdate(net.Learnables, gradients, ...
%                                                                trailingAvg, trailingAvgSq, iteration,...
%                                                                learningRate,gradientDecayFactor, squaredGradientDecayFactor);
%             
%             % Update training plot with new points.         
%             addpoints(lossPlotter, iteration,double(gather(extractdata(loss))));
%             title("Training Epoch " + epoch +" of " + numEpochs);
%             drawnow;
%         end
%                 
%         % Update the learning rate after every learnRateDropPeriod.
%         if mod(epoch,learnRateDropPeriod) == 0
%             learningRate = learningRate * learnRateDropFactor;
%         end
%     end
% end
% Custom starts---------------------------------------------------------------------
%% Create new test dataset from encoded test data
% Draco parameters
draco_cl = 7;
encoded_testData = cell(size(testData));
encoded_test_data_dir='../WPI_LidarData/CompressedTestData/geom_and_attr/decoded_ply/';
for i = 1:size(testData)
    encoded_PC = append(encoded_test_data_dir, sprintf('%06d',i), '_cl_', int2str(draco_cl),'_decoded.ply');
    encoded_ptCloud = pcread(sample_encoded_PC);
    encoded_ptCloud.Intensity=ones(encoded_ptCloud.Count,1);
    encoded_testData{i} = encoded_ptCloud;
    
end
% Custom ends---------------------------------------------------------------------
%% Evaluate Model
numInputs = numel(testData);

% Generate rotated rectangles from the cuboid labels.
bds = boxLabelDatastore(testLabels);
groundTruthData = transform(bds,@(x) createRotRect(x));

% Set the threshold values.
nmsPositiveIoUThreshold = 0.5;
confidenceThreshold = 0.25;
overlapThreshold = 0.1;

%%
% Set numSamplesToTest to numInputs to evaluate the model on the entire
% test data set.
numSamplesToTest = 50;% Original is 50
detectionResults = table('Size',[numSamplesToTest 3],...
                        'VariableTypes',{'cell','cell','cell'},...
                        'VariableNames',{'Boxes','Scores','Labels'});
tmpStr = '';
for num = 1:numSamplesToTest
    if ~mod(num,10)
        msg = sprintf('Testing data %04d frames',num);
        fprintf(1,'%s',[tmpStr, msg]);
        tmpStr = repmat(sprintf('\b'), 1, length(msg));
    end
    ptCloud = testData{num,1};
%     ptCloud = encoded_testData{num,1};
    
    [box,score,labels] = generatePointPillarDetections(net,ptCloud,anchorBoxes,gridParams,classNames,confidenceThreshold,...
                                            overlapThreshold,P,N,executionEnvironment);
 
    % Convert the detected boxes to rotated rectangles format.
    if ~isempty(box)
        detectionResults.Boxes{num} = box(:,[1,2,4,5,7]);
    else
        detectionResults.Boxes{num} = box;
    end
    detectionResults.Scores{num} = score;
    detectionResults.Labels{num} = labels;
end
%%
metrics = evaluateDetectionAOS(detectionResults,groundTruthData,nmsPositiveIoUThreshold)
%save('./results/original_detection_results_50.mat','detectionResults');
%% Detect Objects Using Point Pillars
ptCloud = testData{3,1};
gtLabels = testLabels{3,1}{1};

% Display the point cloud.
figure;
ax4 = pcshow(ptCloud.Location);

% The generatePointPillarDetections function detects the bounding boxes, scores for a
% given point cloud.
confidenceThreshold = 0.5;
overlapThreshold = 0.1;
[box,score,labels] = generatePointPillarDetections(net,ptCloud,anchorBoxes,gridParams,...
                    classNames,confidenceThreshold,overlapThreshold,P,N,executionEnvironment);

% Display the detections on the point cloud.
showShape('cuboid', box, 'Parent', ax4, 'Opacity', 0.1, 'Color', 'red','LineWidth',0.5);hold on;
showShape('cuboid', gtLabels, 'Parent', ax4, 'Opacity', 0.1, 'Color', 'green','LineWidth',0.5);
zoom(ax4,2);
%% Helper
function [gradients, loss, state] = modelGradients(net, pillarFeatures, pillarIndices, boxLabels, gridParams, anchorBoxes,...
                                                   executionEnvironment)
      
    % Extract the predictions from the network.
    YPredictions = cell(size(net.OutputNames));
    [YPredictions{:}, state] = forward(net,pillarIndices,pillarFeatures);
    
    % Generate target for predictions from the ground truth data.
    YTargets = generatePointPillarTargets(YPredictions, boxLabels, pillarIndices, gridParams, anchorBoxes);
    YTargets = cellfun(@ dlarray,YTargets,'UniformOutput', false);
    if (executionEnvironment == "auto" && canUseGPU) || executionEnvironment == "gpu"
        YTargets = cellfun(@ gpuArray,YTargets,'UniformOutput', false);
    end
     
    [angLoss, occLoss, locLoss, szLoss, hdLoss, clfLoss] = computePointPillarLoss(YPredictions, YTargets);
    
    % Compute the total loss.
    loss = angLoss + occLoss + locLoss + szLoss + hdLoss + clfLoss;
    
    % Compute the gradients of the learnables with regard to the loss.
    gradients = dlgradient(loss,net.Learnables);
 
end

function [pillarFeatures, pillarIndices, labels] = createBatchData(features, indices, groundTruthBoxes, groundTruthClasses, classNames)
% Returns pillar features and indices combined along the batch dimension
% and bounding boxes concatenated along batch dimension in labels.
    
    % Concatenate features and indices along batch dimension.
    pillarFeatures = cat(4, features{:,1});
    pillarIndices = cat(4, indices{:,1});
    
    % Get class IDs from the class names.
    classNames = repmat({categorical(classNames')}, size(groundTruthClasses));
    [~, classIndices] = cellfun(@(a,b)ismember(a,b), groundTruthClasses, classNames, 'UniformOutput', false);
    
    % Append the class indices and create a single array of responses.
    combinedResponses = cellfun(@(bbox, classid)[bbox, classid], groundTruthBoxes, classIndices, 'UniformOutput', false);
    len = max(cellfun(@(x)size(x,1), combinedResponses));
    paddedBBoxes = cellfun( @(v) padarray(v,[len-size(v,1),0],0,'post'), combinedResponses, 'UniformOutput',false);
    labels = cat(4, paddedBBoxes{:,1});
end

% function lidarData = downloadWPIData(outputFolder, lidarURL)
% % Download the data set from the given URL into the output folder.
% 
%     lidarDataTarFile = fullfile(outputFolder,'WPI_LidarData.tar.gz');
%     if ~exist(lidarDataTarFile, 'file')
%         mkdir(outputFolder);
%         
%         disp('Downloading WPI Lidar driving data (760 MB)...');
%         websave(lidarDataTarFile, lidarURL);
%         untar(lidarDataTarFile,outputFolder);
%     end
%     
%     % Extract the file.
%     if ~exist(fullfile(outputFolder, 'WPI_LidarData.mat'), 'file')
%         untar(lidarDataTarFile,outputFolder);
%     end
%     load(fullfile(outputFolder, 'WPI_LidarData.mat'),'lidarData');
%     lidarData = reshape(lidarData,size(lidarData,2),1);
% end

% function net = downloadPretrainedPointPillarsNet(outputFolder, pretrainedNetURL)
% % Download the pretrained PointPillars detector.
% 
%     preTrainedMATFile = fullfile(outputFolder,'trainedPointPillarsNet.mat');
%     preTrainedZipFile = fullfile(outputFolder,'trainedPointPillars.zip');
%     
%     if ~exist(preTrainedMATFile,'file')
%         if ~exist(preTrainedZipFile,'file')
%             disp('Downloading pretrained detector (8.3 MB)...');
%             websave(preTrainedZipFile, pretrainedNetURL);
%         end
%         unzip(preTrainedZipFile, outputFolder);   
%     end
%     pretrainedNet = load(preTrainedMATFile);
%     net = pretrainedNet.net;       
% end

function lossPlotter = configureTrainingProgressPlotter(f)
% The configureTrainingProgressPlotter function configures training
% progress plots for various losses.
    figure(f);
    clf
    ylabel('Total Loss');
    xlabel('Iteration');
    lossPlotter = animatedline;
end

function retValue = checkForNaN(gradients,loss)
% Based on experiments it is found that the last convolution head
% 'occupancy|conv2d' contains NaNs as the gradients. This function checks
% whether gradient values contain NaNs. Add other convolution
% head values to the condition if NaNs are present in the gradients. 
    gradValue = gradients.Value((gradients.Layer == 'occupancy|conv2d') & (gradients.Parameter == 'Bias'));
    if (sum(isnan(extractdata(loss)),'all') > 0) || (sum(isnan(extractdata(gradValue{1,1})),'all') > 0)
        retValue = true;
    else
        retValue = false;
    end
end
