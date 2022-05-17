function [processedData, processedLabels] = createFrontViewFromLidarData(ptCloudData, groundTruth, gridParams, fview)
    numFiles = size(ptCloudData,1);
    processedLabels = cell(size(groundTruth));
    processedData = cell(size(ptCloudData));

    theta = pi;
    rot = [cos(theta) sin(theta) 0; ...
          -sin(theta) cos(theta) 0; ...
                   0  0  1];
    trans = [0, 0, 0];
    tform = rigid3d(rot, trans);
    tmpStr = '';
    for i = 1:numFiles
        ptCloud = ptCloudData{i,1};
        ptCloud = pctransform(ptCloud,tform);

        % Get the indices of the point cloud that constitute the RoI
        % defined in the calibration parameters.
        [~, indices] = projectLidarPointsOnImage(ptCloud,fview.cameraParams, rigid3d(fview.tform.T));
        ptCloudTransformed = select(ptCloud, indices,'outputSize','full');
        ptCloudTransformed = pctransform(ptCloudTransformed, tform);

        % Set the limits for the point cloud.
        [row, column] = find( ptCloudTransformed.Location(:,:,1) < gridParams{1,2}{1} ...
                            & ptCloudTransformed.Location(:,:,1) > gridParams{1,1}{1} ...
                            & ptCloudTransformed.Location(:,:,2) < gridParams{1,2}{2} ...
                            & ptCloudTransformed.Location(:,:,2) > gridParams{1,1}{2} ...
                            & ptCloudTransformed.Location(:,:,3) < gridParams{1,2}{3} ...
                            & ptCloudTransformed.Location(:,:,3) > gridParams{1,1}{3});    
        ptCloudTransformed = select(ptCloudTransformed, row, column, 'OutputSize', 'full'); 
        finalPC = removeInvalidPoints(ptCloudTransformed);

        % Get the classes from the ground truth labels.
        classNames = groundTruth.Properties.VariableNames; 
        for ii = 1:numel(classNames)

            labels = groundTruth(i,classNames{ii}).Variables;
            labels = labels{1};
            if ~isempty(labels)

                % Get the label indices that are in the selected RoI.
                labelsIndices = labels(:,1) > gridParams{1,1}{1} ...
                            & labels(:,1) < gridParams{1,2}{1} ...
                            & labels(:,2) > gridParams{1,1}{2} ...
                            & labels(:,2) < gridParams{1,2}{2};
                labels = labels(labelsIndices,:);

                % Change the dimension of the ground truth object to fixed
                % value.
                carNewDim = repmat([3.9 1.6 1.56], size(labels,1),1);
                labels(:,4:6) = carNewDim;

                if ~isempty(labels)
                    % Find the number of points inside each ground truth
                    % label.
                    numPoints = arrayfun(@(x)(findPointsInsideCuboid(cuboidModel(labels(x,:)),finalPC)),...
                                (1:size(labels,1)).','UniformOutput',false);
                    posLabels = cellfun(@(x)(~isempty(x)),numPoints);
                    labels = labels(posLabels,:);
                end
            end
                processedLabels{i,ii} = labels;
        end
        
        % Display progress after 300 files on screen.
        if ~mod(i,300)
            msg = sprintf('Processing data %3.2f%% complete', (i/numFiles)*100.0);
            fprintf(1,'%s',[tmpStr, msg]);
            tmpStr = repmat(sprintf('\b'), 1, length(msg));
        end
        processedData{i,1} = finalPC;
    end
    
    processedLabels = cell2table(processedLabels);
    numClasses = size(processedLabels,2);
    for j = 1:numClasses
        processedLabels.Properties.VariableNames{j} = classNames{j};
    end
    
    % Consider only class car for the detections.
    processedLabels = processedLabels(:,1);
    
     % Print completion message when done.
    msg = sprintf('Processing data 100%% complete');
    fprintf(1,'%s',[tmpStr, msg]);
end
