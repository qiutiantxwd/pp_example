%% Loss functions
% Loss functions used in the point pillars network.

function [angLoss, occLoss, locLoss, szLoss, hdLoss, clfLoss]...
    = computePointPillarLoss(YPredictions, YTargets)
    
    % Create a mask of anchors for which the loss has to computed.
    posMask = YTargets{1,3} == 1;
    
    % Compute the loss.
    occLoss = occupancyLoss(YTargets{1,3}, YPredictions{1,3}, 1.0);
    locLoss = locationLoss(YTargets{1,2}, YPredictions{1,2}, posMask, 2.0);
    szLoss = sizeLoss(YTargets{1,1}, YPredictions{1,1}, posMask,2.0);
    angLoss = angleLoss(YTargets{1,6}, YPredictions{1,6}, posMask,2.0);
    hdLoss = headingLoss(YTargets{1,5}, YPredictions{1,5}, posMask,0.2); 
    clfLoss = classificationLoss(YTargets{1,4}, YPredictions{1,4}, posMask, 1.0);
end

% Compute the huber loss.
function loss = huberLoss(Targets, Predictions, varargin)
    if nargin > 3
        delta = varargin{1};
    else
        delta = 1.0;
    end

    x = Targets - Predictions;
    xabs = abs(x);
    loss = xabs;
    loss(xabs <= delta) = 0.5 * (x(xabs <= delta) .^ 2);
    loss(xabs > delta) = 0.5 * delta * delta + delta*(xabs(xabs > delta) - delta);
end

% Compute the occupancy loss.
function loss = occupancyLoss(Targets, Predictions, focalWeight)
    loss = focalCrossEntropy(Predictions,Targets,'TargetCategories','independent','Reduction','none');
    posMask = (Targets == 1) | (Targets == 0);
    loss = loss .* posMask;
    nanInd = isnan(extractdata(loss));
    loss(nanInd) = 0;
    dFactor = max(sum(posMask,'all'),1);
    loss = sum(loss,'all')/dFactor;
    loss = loss * focalWeight;
end

% Compute the cross entropy loss.
function loss = binaryCrossEntropyLoss(Targets, Predictions)
    loss = focalCrossEntropy(Predictions,Targets,'Gamma',0,...
           'Alpha',1,'TargetCategories','independent','Reduction','none');
end

% Compute the location loss.
 function loss = locationLoss(Targets, Predictions, mask, locWeight)
    mask = repmat(mask,[1,1,3,1]);
    loss = huberLoss(Targets, Predictions);
    loss = loss .* mask;
    nanInd = isnan(extractdata(loss));
    loss(nanInd) = 0;
    dFactor = sum(mask,'all');
    loss = sum(loss,'all')/dFactor;
    loss = loss * locWeight;
 end

% Compute the size loss.
function loss = sizeLoss(Targets, Predictions, mask, sizeWeight)
    mask = repmat(mask,[1,1,3,1]);
    loss = huberLoss(Targets, Predictions);
    loss = loss .* mask;
    nanInd = isnan(extractdata(loss));
    loss(nanInd) = 0;
    dFactor = sum(mask,'all');
    loss = sum(loss,'all')/dFactor;
    loss = loss * sizeWeight;
end

% Compute the angle loss.
function loss = angleLoss(Targets, Predictions, mask, angleWeight)
    loss = huberLoss(Targets, Predictions);
    loss = loss .* mask;
    nanInd = isnan(extractdata(loss));
    loss(nanInd) = 0;
    dFactor = sum(mask,'all');
    loss = sum(loss,'all')/dFactor;
    loss = loss * angleWeight;
end

% Compute the heading loss.
function loss = headingLoss(Targets, Predictions, mask, headingWeight)
    loss = binaryCrossEntropyLoss(Targets, Predictions);
    loss = loss .* mask;
    nanInd = isnan(extractdata(loss));
    loss(nanInd) = 0;
    dFactor = sum(mask,'all');
    loss = sum(loss,'all')/dFactor;
    loss = loss * headingWeight;
end

% Compute the classification loss
function loss = classificationLoss(Targets, Predictions, mask, classWeight)
    Predictions = sigmoid(Predictions);
    loss = binaryCrossEntropyLoss(Targets,Predictions);
    loss = loss .* mask;
    nanInd = isnan(extractdata(loss));
    loss(nanInd) = 0;
    dFactor = sum(mask,'all');
    loss = sum(loss,'all')/dFactor;
    loss = loss * classWeight;
end