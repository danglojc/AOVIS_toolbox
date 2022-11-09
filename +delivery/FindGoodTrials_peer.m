
function [logging_gtrial_saccade, logging_bad_trials, logging_bad_frame, eye_position_x_y, subtotalSessions, eccentricity, foldernum_name] = ...
    FindGoodTrials_peer(f, eyeorRWvideo, conditionString, endFrame, framert, ppd_x, ppd_y, cross_count, subFolderNames, logging_gtrial_saccade, logging_bad_trials, logging_bad_frame)
%  
% Find "good trials": 
%    -- Looks at the average pixel value of four 6x6-pixel-quadrants surrounding 
%        the white cross "pixel_avg". If the decrement is present, then "pixel_avg"
%        will be low. This is how we determine if decrement is missing.
%    -- Looks at the frame-to-frame pixel diff. If diff is bigger than threshold
%        (defined in line 63) then prompts you to manually check video)

%    --To determine good trial:   
%         1) If decrement is missing in the first few frames, then drop those frames, keep trial. 
%         2) If decrement is missing mid-trial, then drop entire trial
%         3) Checks for saccades, check video and make sure tracking is okay
%   -----------------------------------
%   Input
%   -----------------------------------
%   f                       : subfolder that contains  1)all 60 "_plot.csv" (findCross output)
%                               2)exp .mat file 3) "_all_sessions.csv"
%   eyeorRWvideo            : 1: analyzing only gain+1 videos (to calculate DC eye motion), 
%                             2: analyzing only gain-1 and gain0 videos (to check if good trial)
%                             3: analyze rw stimulus in all videos (to check if good trial)
%   conditionString         : (ie '10003L_') make sure it's in this format 'subjectID+Eye_month_day_year' 
%   endFrame                : stimulus duration in frames, (ie 46 default)
%   framert                 : 30 frames/second default
%   ppd_x                   : pixels per degree for x (recorded during desinusoid)
%   ppd_y                   : pixels per degree for y (recorded during desinusoid)
%   cross_count             : total number of tracking crosses in one frame
%                               (ie for 2IFCexp it's 1, but for peer stimulus exp it's 3)
%   subFolderNames          : array of strings that have subfolder names (ie subFolderNames = {subFolders(3:end).name};) 
%   logging_gtrial_saccade  : pass in pre-defined empty table 
%   logging_bad_trials      : pass in pre-defined empty table
%   logging_bad_frame       : pass in pre-defined empty table
%   
%   -----------------------------------
%   Output
%   -----------------------------------
%   logging_gtrial_saccade  : logs trials that were prompted to be checked that you responded "yes--keep" 
%   logging_bad_trials      : logs dropped trials and specifies bad frame 
%   logging_bad_frame       : logs dropped-frames in the beginning of trial that were missing decrements 
%   eye_position_x_y        : (46x2xn) array. ROW: 46 frames. COLUMNS: 1:x-pixels, 2:y-pixels, 
%                              and third dimension 'n': the total number of good trials in that session
%   subtotalSessions        : contains 60 trials from one eccentricity exp session
%   eccentricity            : eccentricity of interest 
%   foldernum_name          : string of foldernumber

% Josie D'Angelo October 12, 2022
%%
    %defining type of video check to do
    if eyeorRWvideo == 1
        gain = 1;
        stim1stim2 = 2; %this means that RW stimulus is stimulus 2, (indicating that you should analyze stimulus 1, gain-contingent)
    elseif eyeorRWvideo == 2
        gain = [-1 0.002]; 
        stim1stim2 = 2;
    elseif eyeorRWvideo == 3  %looking at rw stimulus tracking in both gain +1 and gain -1 videos
        stim1stim2 = 1; %this means that RW stimulus is stimulus 1, (indicating that you should analyze stimulus 1,RW)
    end

    %Calculating a threshold of acceptable frame-to-frame pixel dif. (Citation: Mecê P, Jarosz J, Conan JM, Petit C, Grieve K, Paques M, Meimon S. Fixational eye movement: a negligible source of dynamic aberration. Biomed Opt Express. 2018 Jan 22;9(2):717-727. doi: 10.1364/BOE.9.000717.) PMID: 29552407; PMCID: PMC5854073.
    %defining eye movement
    drifts = 0.5; % units are deg/s.
    
    %setting threshold for bad trials <--based the threshold off of tremor since more constrained
    jump_threshold_x = ceil(drifts * ppd_x /framert) + 2; % 0.5 deg/sec * 298pixels/deg * 1sec/30frames = 5 pixels/frame
    jump_threshold_y = ceil(drifts * ppd_y /framert) + 2; % ambiguously chose "+2" pixels for wiggle-room

    % finding and storing only raw_videos _plot csv's
    cd(string(subFolderNames(f)));
    
    %defining strings-- foldername and directory
    folder_name = char(subFolderNames(f));
    foldernum_name = str2num(strrep(string(folder_name(5:13)),'_',''));
    startDir = strcat( '', cd,'');
    
    %opening the mat file to get eccentricity
    matfile = dir([startDir filesep conditionString '*.mat']);
    matfile_of_interest = load(matfile.name);
    eccentricity = matfile_of_interest.expParameters.eccentricity;
    clear matfile_of_interest;
    
    % Search mat files that start with the condition string
    fileNames = dir([startDir filesep conditionString '*.csv']);
    
    % finding the raw csvs and saving them to 'raw_csv_names'.
    for i = 1: size(fileNames,1)
        csv_of_interest(i) =  contains(fileNames(i).name, '_plot.csv');
    end
    
    %find and store all csvs names
    element = 1;
    for i = 1: size(fileNames,1)
        if csv_of_interest(i) == 1
            raw_csv_names(element) = cellstr(fileNames(i).name);
            element = element + 1;
        end
    end
    
    %finding "all_sessions"
    for i = 1: size(fileNames,1)
        if contains(fileNames(i).name, 'all_sessions.csv') == 1
            full_data = readtable(fileNames(i).name);
        end
    end
    
    %defining which videos you want to analyze (ie only gain +1, only gain-1, or all)
    if exist('gain','var') == 1
        if length(gain)>1
            gain_trials = full_data.Gain == gain(1) | full_data.Gain == gain(2);
        else
            gain_trials = full_data.Gain == gain;
        end
        subtotalSessions = full_data(full_data.Eccentricity == eccentricity & gain_trials,:);
    else
        subtotalSessions = full_data(full_data.Eccentricity == eccentricity,:);
    end
    
    %defining variables
    element = 1;
    newNames = ["frame"];
    eye_position_x_y = nan(endFrame,2, length(subtotalSessions.TrialNum_of_60));
    
    %prepping names for _plot csv
    for crossct = 1: cross_count
        cross_name = ["x"+crossct "y"+crossct "pixel_avg"+crossct];
        newNames = [newNames cross_name];
    end
    newNames = [newNames "notUsed"];
    
    % Going frame-by-frame to check for good stimulus delivery
    for i = 1: max(subtotalSessions.TrialNum_of_60)
        startIndex = regexp(raw_csv_names{i},sprintf("0%d_plot",subtotalSessions.TrialNum_of_60(element)),'match');
        if isempty(string(startIndex)) == 0
            if string(startIndex{1}) == sprintf("0%d_plot",subtotalSessions.TrialNum_of_60(element))
                
                data_to_analyze = readtable(raw_csv_names{i});
                data_to_analyze.Properties.VariableNames = newNames;
                
                %assigning variables for 'updateLessGreater' function later
                less = [];
                greater = [];
                
                %setting rough starting threshold based off manual plot estimate
                if element == 1
                    [first_check_pix] = PixelThresholdFirstCheck_peer(eyeorRWvideo, conditionString, cross_count, fileNames, eccentricity);
                end
                
                %fine-tuning threshold estimate by calculating mean and std
                %if it's less than the rough 'first_check_pix' it's probably a good frame, so put it into array "less"
                %we find mean & std of 'less' to calculate the fine-tuned 'pixel_threshold'
                
                if eyeorRWvideo == 1 || eyeorRWvideo == 2 %calculate Retina contingent data only
                    if subtotalSessions.RW_stimulus(element) == 1 %RWstim is stim 1 x2/y2
                        [less, greater] = updateLessGreater(first_check_pix, data_to_analyze.pixel_avg3, less, greater);
                    else
                        [less, greater] = updateLessGreater(first_check_pix, data_to_analyze.pixel_avg2, less, greater);
                    end
                else  %looking at RW stimulus only
                    if subtotalSessions.RW_stimulus(element) == 1 %RWstim is stim 1 x2/y2
                        [less, greater] = updateLessGreater(first_check_pix, data_to_analyze.pixel_avg2, less, greater);
                    else
                        [less, greater] = updateLessGreater(first_check_pix, data_to_analyze.pixel_avg3, less, greater);
                    end
                end
                
                %this changes for each trial
                pixel_threshold = mean(less)+ 5*std(less);
                
                frame_start = 2; %this is actually frame 1 (since frame 0 is index 1, frame 1 is index 2, and frame 2 is index 3)
                
                if data_to_analyze.x2(frame_start)==0 && data_to_analyze.y2(frame_start)==0 &&data_to_analyze.x2(frame_start+51+1)~=0 && data_to_analyze.y2(frame_start+51+1)~=0 ...
                        && data_to_analyze.x3(frame_start)==0 && data_to_analyze.y3(frame_start)==0 &&data_to_analyze.x3(frame_start+51+1)~=0 && data_to_analyze.y3(frame_start+51+1)~=0 %checking both circle stims for frames
                    frame_start = 3; %this means that the stimulus presentation started at frame 2:53, instead of 1:52, (frame 2 is index 3)
                end
                
                %Stimulus started at frame 1 for raw videos, mostly
                %(sometimes frame 2, so added a if statement to account for these cases)
                if subtotalSessions.RW_stimulus(subtotalSessions.TrialNum_of_60 == i) == stim1stim2 %stim2 for g = 1, so gainstim is x2y2
                    
                    % running through function to check for bad frames
                    [eye_position_x_y, element, logging_bad_frame, logging_bad_trials, logging_gtrial_saccade] = Findbadframes(eye_position_x_y, frame_start, ...
                        data_to_analyze.pixel_avg2,data_to_analyze.x2, data_to_analyze.y2, pixel_threshold, subtotalSessions, element, foldernum_name, jump_threshold_x, jump_threshold_y, logging_bad_frame, logging_bad_trials, logging_gtrial_saccade, endFrame);
                    
                else %otherwise, RW is stim1, so gain-stimulus is stim2, which is x3/y3/pixel_avg3
                    
                    [eye_position_x_y, element, logging_bad_frame, logging_bad_trials, logging_gtrial_saccade] = Findbadframes(eye_position_x_y, frame_start, ...
                        data_to_analyze.pixel_avg3,data_to_analyze.x3, data_to_analyze.y3, pixel_threshold, subtotalSessions, element, foldernum_name, jump_threshold_x, jump_threshold_y, logging_bad_frame, logging_bad_trials, logging_gtrial_saccade, endFrame);
                end

            end
            clear less greater;
            element = element + 1;
        end
    end
    cd ..;

    %% Function to find bad frames and look for large pixel movements that aren't for saccades/drifts
    function [eye_position_x_y, element, logging_bad_frame, logging_bad_trials, logging_gtrial_saccade] = ...
        Findbadframes(eye_position_x_y, frame_start,pixel_avg, x, y, pixel_threshold, subtotalSessions, element, foldernum_name, jump_threshold_x, jump_threshold_y, logging_bad_frame, logging_bad_trials, logging_gtrial_saccade, endFrame)
        
        %assigning variables
        frame_tracking = 1;
        curframe = frame_start;
        consecutiveMiss = 0; 
        issues = 0;
        
        %arrays tracking good&bad trials
        gtrial_saccade= [];
        bad_frame = [];
        bad_trials = [];
        
        %counters tracking bad frames, bad trials, and goodtrials_with_saccades
        b_frame_element = 1;
        b_trial_element = 1;
        g_saccade_element = 1;
        
        %Stim_of_interest 
        if subtotalSessions.RW_stimulus(element) == stim1stim2
            stim_interest = "(Left Stimulus)";
        else
            stim_interest = "(Right Stimulus)";
        end

        for fr = 1: endFrame %endFrame = 46 since stim frame duration
            if frame_tracking > endFrame
                break;
            end
            
            %catching bad trials that ended abruptly 
            %if pixel_threshold is nan, that means that 'less' was empty, meaning all frames were missing a digital cross, bad delivery
            if length(pixel_avg)<endFrame || isnan(pixel_threshold) == 1
                [bad_trials, b_trial_element] = Savetoarray(subtotalSessions, foldernum_name,  curframe, length(pixel_avg), element, bad_trials, b_trial_element, issues);
                eye_position_x_y(:,:,element) = nan;
                break;
            end
            
            %this means decrement is not present
            if pixel_avg(curframe) > pixel_threshold 

                %if it's frame 1, then drop frame1 and subsequent missing-decrement-frames. Start saving frames when decrement appears
                if fr == 1
                    checking = curframe;
                    while pixel_avg(checking) > pixel_threshold
                        [bad_frame, b_frame_element] = Savetoarray(subtotalSessions, foldernum_name, checking, pixel_avg(checking), element, bad_frame, b_frame_element, consecutiveMiss);
                        eye_position_x_y(frame_tracking,:,element) = nan;
                        frame_tracking = frame_tracking+ 1;
                        checking = checking + 1;
                    end
                    
                    curframe = checking-1; % -1 so that it doesn't skip the frame
                    frame_tracking = frame_tracking-1; % -1 so that it doesn't skip the frame
               
                %this is the first missing decrement square, so tracking issues and if there are consecutive frames of missing dec
                elseif consecutiveMiss == 0  
                    consecutiveMiss = 1; %if it's the first mid-trial missing-decrement, then keep trial but check later if it's consecutive
                    issues = issues + 1;
                    
                    if issues >= 3
                        prompt = "Video " + subtotalSessions.TrialNum_of_60(element) + " in folder " + foldernum_name + " "+stim_interest+ ", frames before " + (curframe -1) + ", looks okay? y/n (y-keep trial; n-drop trial)";
                        response = input(prompt, 's');
                        
                        if response == 'n' %drop trial
                            [bad_trials, b_trial_element] = Savetoarray(subtotalSessions, foldernum_name, curframe, pixel_avg(curframe), element, bad_trials, b_trial_element, issues);
                            eye_position_x_y(:,:,element) = nan;
                            break;
                        else %keep going through frames, but check each missing dec going forward
                            [bad_frame, b_frame_element] = Savetoarray(subtotalSessions, foldernum_name, curframe, pixel_avg(curframe), element, bad_frame, b_frame_element, consecutiveMiss);
                            eye_position_x_y(frame_tracking,:,element) = [x(curframe) y(curframe)];
                        end
                    else %this applies if it's just one missing decrement, so we'll keep it
                        eye_position_x_y(frame_tracking,:,element) = [x(curframe) y(curframe)];
                        [bad_frame, b_frame_element] = Savetoarray(subtotalSessions, foldernum_name, curframe, pixel_avg(curframe), element, bad_frame, b_frame_element, consecutiveMiss);
                    end
                    
                  
                else %otherwise, we'd have had 2 consectuive missing decrements,
                    issues = issues + 1;
                    [bad_trials, b_trial_element] = Savetoarray(subtotalSessions, foldernum_name, curframe, pixel_avg(curframe), element, bad_trials, b_trial_element, issues);
                    eye_position_x_y(:,:,element) = nan;
                    break;
                end
                
            %decrement IS present on currentframe and it's after frame 1. Looking for big pixel jumps (via framepixel diff)
            elseif pixel_avg(curframe) < pixel_threshold && fr > 1
                consecutiveMiss = 0; %reset since this frame is good, so not consecutive
                
                diff_trial = abs(diff([x(curframe-1: curframe) y(curframe-1: curframe)]));
                if diff_trial(1,1) > jump_threshold_x || diff_trial(1,2) > jump_threshold_y
                    
                    if eyeorRWvideo ~= 3
                        prompt = "Video " + subtotalSessions.TrialNum_of_60(element) + " in folder " + foldernum_name+ " " + stim_interest +", is there a true saccade before frame " + (curframe -1) +"? y/n (y-keep trial; n-drop trial)";
                        response = input(prompt, 's');
                    else
                        response = 'y'; %3 means checking RW stimulus, we don't care what pixel diff is for RW, we only care about decrement being present (via pixel_threshold)
                    end
                    if response == 'n'

                        if diff_trial(1,1) > jump_threshold_x
                            [bad_trials, b_trial_element] = Savetoarray(subtotalSessions, foldernum_name, curframe, diff_trial(1,1), element, bad_trials, b_trial_element, issues);
                        elseif diff_trial(1,2) > jump_threshold_y
                            [bad_trials, b_trial_element] = Savetoarray(subtotalSessions, foldernum_name, curframe, diff_trial(1,2), element, bad_trials, b_trial_element, issues);
                        end

                        eye_position_x_y(:,:,element) = nan;
                        break;
                    else
                        if diff_trial(1,1) > jump_threshold_x
                            [gtrial_saccade, g_saccade_element] = Savetoarray(subtotalSessions, foldernum_name, curframe, diff_trial(1,1), element, gtrial_saccade, g_saccade_element, consecutiveMiss);
                        elseif diff_trial(1,2) > jump_threshold_y
                            [gtrial_saccade, g_saccade_element] = Savetoarray(subtotalSessions, foldernum_name, curframe, diff_trial(1,2), element, gtrial_saccade, g_saccade_element, consecutiveMiss);
                        end
                        eye_position_x_y(frame_tracking,:,element) = [x(curframe) y(curframe)];
                        
                    end
                else
                    eye_position_x_y(frame_tracking,:,element) = [x(curframe) y(curframe)]; 
                end

            %decrement is present and it's frame 1
            else
                eye_position_x_y(frame_tracking,:,element) = [x(curframe) y(curframe)]; 
            end

            curframe = curframe + 1;
            frame_tracking = frame_tracking+ 1;
        end
        if b_trial_element > 1
            logging_bad_trials = [logging_bad_trials; array2table(bad_trials(:,1:7),'VariableNames',{'Subject', 'Folder', 'Eccentricity', 'TrialNum_of_60', 'Frame_bad','PixelAvg_DiffValue', 'NumTrialsMissingDec'})];
        end
        if b_frame_element > 1
            logging_bad_frame = [logging_bad_frame; array2table(bad_frame(:,1:7),'VariableNames',{'Subject', 'Folder', 'Eccentricity', 'TrialNum_of_60', 'Frame_bad', 'PixelAvg', 'ConsecutiveMissingDecTF'})];
        end
        if g_saccade_element > 1
            logging_gtrial_saccade = [logging_gtrial_saccade; array2table(gtrial_saccade(:,1:7),'VariableNames',{'Subject', 'Folder', 'Eccentricity', 'TrialNum_of_60','Frame_checked', 'DiffValue', 'ConsecutiveMissingDecTF'})];
        end
    end


    %% Function for saving bad_frames, bad_trials, or good_trials
    function [array_saving_to, index] = Savetoarray(subtotalSessions, foldernum_name, curframe, pixel_value, element, array_saving_to, index, consecutiveMiss)
        array_saving_to(index, 1) = subtotalSessions.Subject(element);
        array_saving_to(index, 2) = foldernum_name;
        array_saving_to(index, 3) = subtotalSessions.Eccentricity(element);
        array_saving_to(index, 4) = subtotalSessions.TrialNum_of_60(element);
        array_saving_to(index, 5) = (curframe - 1);  %curframe - 1 since curframe is index to start at +1 (frame 0 = 1)
        array_saving_to(index, 6) = pixel_value;
        array_saving_to(index, 7) = consecutiveMiss;
        index = index + 1;
    end

    %% Function for updating less and greater pixel variables
    function [less, greater] = updateLessGreater(first_check_pix, pixel_avg, less, greater)
        less_element = 1;
        greater_element = 1;
        for px = 1: length(pixel_avg)
            if pixel_avg(px) <= first_check_pix && pixel_avg(px) ~=0
                less(less_element) = pixel_avg(px);
                
                less_element = less_element + 1;
            elseif pixel_avg(px) > first_check_pix && pixel_avg(px) ~=0
                greater(greater_element) = pixel_avg(px);
                
                greater_element =greater_element + 1;
            end
        end
    end

end
