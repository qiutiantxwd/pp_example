%% *Generate Training Data*
% To save each point cloud as a mat file in the specified location
function saveptCldToPCD(trainData,dataLocation)
    if ~exist(dataLocation,'dir')
        mkdir(dataLocation)
    end
    tmpStr = '';
    numFiles = size(trainData,1);
    for i = 1:numFiles
        ptCloud = trainData{i,1};
        pcFilePath = fullfile(dataLocation,sprintf('%06d.ply',i));% Change to .ply for Linux
        pcwrite(ptCloud,pcFilePath);
        
         %Display progress after 300 files on screen.
        if ~mod(i,300)
            msg = sprintf('Processing data %3.2f%% complete', (i/numFiles)*100.0);
            fprintf(1,'%s',[tmpStr, msg]);
            tmpStr = repmat(sprintf('\b'), 1, length(msg));
        end
        
    end
    
    % Print completion message when done.
    msg = sprintf('Processing data 100%% complete');
    fprintf(1,'%s',[tmpStr, msg]);
end