%% Opensesame Processing Script
% Script developed by Adolphe J. Béquet during his Post-Doc in University of Salamanca (2023)
% This script processes Opensesame CSV data files (from processed experiments)
% to extract reaction time (RT) metrics for congruent and incongruent trials,
% adjust for second-chance responses (by adding 600 ms when necessary), clip
% RT values, compute summary statistics (mean, std, D-score), and store all results
% in a results table. Finally, the table is saved as a CSV file.
%
% NOTE:
%   - Update the variables 'dataDir' and 'resultDir' with your actual directories.
%   - Reaction times are extracted from specific rows in the CSV files.
%   - The algorithm follows guidelines from O'Donnel et al. (2020) and Chassard (2006).

%% Configuration: Directories
dataDir = 'D:\DATA_EcoRenew';    % <-- Replace with your data directory
resultDir = 'D:\DATA_EcoRenew'; % <-- Replace with your results directory

%% Pre-creation of Result Variables and Table
% Initialize empty arrays for each result variable
participant_id = {};  % Cell array to store participant IDs

% Block 1 results
block1_congruent_RT = [];
block1_incongruent_RT = [];
block1_dscore = [];
block1_congruent_std = [];
block1_incongruent_std = [];
block1_congruent_NBerrors = [];
block1_incongruent_NBerrors = [];

% Block 2 results
block2_congruent_RT = [];
block2_incongruent_RT = [];
block2_dscore = [];
block2_congruent_std = [];
block2_incongruent_std = [];
block2_congruent_NBerrors = [];
block2_incongruent_NBerrors = [];

% Create a table to hold all the results
tableau_results = table(participant_id, block1_congruent_RT, block1_incongruent_RT, block1_dscore, ...
    block1_congruent_std, block1_incongruent_std, block1_congruent_NBerrors, block1_incongruent_NBerrors, ...
    block2_congruent_RT, block2_incongruent_RT, block2_dscore, block2_congruent_std, block2_incongruent_std, ...
    block2_congruent_NBerrors, block2_incongruent_NBerrors);

%% Flexible File Search: Locate CSV Files by Participant Number
% Search the dataDir for files whose names contain the participant number formatted as "data_pXX".
% For example: "data_p01_condition_3.csv", "data_p02_condition_4.csv", etc.

% Get a list of all CSV files in the data directory
csv_all = dir(fullfile(dataDir, '**', '*.csv'));

% Extract participant numbers from the file names using a regular expression.
fileParticipantNumbers = nan(length(csv_all), 1);
for i = 1:length(csv_all)
    % Look for the pattern 'P' followed by 2 digits 
    tokens = regexp(csv_all(i).name, 'P(\d{2})', 'tokens');
    if ~isempty(tokens)
        fileParticipantNumbers(i) = str2double(tokens{1}{1});
    end
end

% Identify unique participant numbers present in the data
uniqueParticipants = unique(fileParticipantNumbers(~isnan(fileParticipantNumbers)));

%% Loop over Participants (from the unique list)
for p = uniqueParticipants'
    % Save the participant ID as "pXX"
    tableau_results.participant_id{p} = sprintf('p%02d', p);
    
    % Skip participants if necessary (if you want to exclude specific numbers)
    % (For example, to skip participant 17, you could do:
    % if ismember(p, [17]), continue; end)
    
    % Get all CSV files corresponding to this participant
    participantFiles = csv_all(fileParticipantNumbers == p);
    
    %% Loop over each CSV file for this participant (each file is assumed to correspond to one block)
    for i = 1:length(participantFiles)
        filename = fullfile(participantFiles(i).folder, participantFiles(i).name);
        
        % Extract block number from filename.
        % (This assumes that the block number is embedded in the filename,
        % e.g., "data_p01_condition_3_block1.csv" or similar.)
        tokens = regexp(participantFiles(i).name, 'block(\d+)', 'tokens');
        if ~isempty(tokens)
            block_number = str2double(tokens{1}{1});
        else
            % Fallback: attempt to extract block number from a specific character position.
            block_number = str2double(participantFiles(i).name(end-4));
        end
        
        % Read the CSV file into a table.
        csv_file = readtable(filename, 'Delimiter', ',');
        
        %% Calculate Reaction Times
        % Extract reaction times for congruent and incongruent trials.
        % (Assumes rows 51:90 correspond to congruent trials and rows 121:160 to incongruent trials;
        % adjust if needed.)
        RT_congruent_with_secondchance = table2array(csv_file(51:90, 'response_time'));
        RT_incongruent_with_secondchance = table2array(csv_file(121:160, 'response_time'));
        
        RT_congruent_without_secondchance = table2array(csv_file(51:90, 'response_time_keyboard_response'));
        RT_incongruent_without_secondchance = table2array(csv_file(121:160, 'response_time_keyboard_response'));
        
        %% Adjust for Second-Chance Responses
        % If the reaction time with second chance differs from the keyboard response,
        % add 600 ms.
        mistake_congruent = 0;
        mistake_incongruent = 0;
        for tIdx = 1:40
            if RT_congruent_with_secondchance(tIdx) ~= RT_congruent_without_secondchance(tIdx)
                RT_congruent_with_secondchance(tIdx) = RT_congruent_with_secondchance(tIdx) + 600;
                mistake_congruent = mistake_congruent + 1;
            end
            if RT_incongruent_with_secondchance(tIdx) ~= RT_incongruent_without_secondchance(tIdx)
                RT_incongruent_with_secondchance(tIdx) = RT_incongruent_with_secondchance(tIdx) + 600;
                mistake_incongruent = mistake_incongruent + 1;
            end
        end
        
        %% Clip Reaction Times
        % Enforce a minimum of 300 ms and a maximum of 3000 ms.
        RT_congruent_with_secondchance = max(min(RT_congruent_with_secondchance, 3000), 300);
        RT_incongruent_with_secondchance = max(min(RT_incongruent_with_secondchance, 3000), 300);
        
        %% Compute Summary Statistics and D-Score
        % Exclude the first two trials (per Chassard, 2006).
        mean_congruent = mean(RT_congruent_with_secondchance(2:40));
        sd_congruent = std(RT_congruent_with_secondchance(2:40));
        mean_incongruent = mean(RT_incongruent_with_secondchance(2:40));
        sd_incongruent = std(RT_incongruent_with_secondchance(2:40));
        
        % Compute D-score (a positive value indicates a preference for incongruent trials).
        D_score = mean_congruent - mean_incongruent;
        
        %% Store Results in the Table Based on Block Number
        switch block_number
            case 1
                tableau_results.block1_congruent_RT(p) = mean_congruent;
                tableau_results.block1_incongruent_RT(p) = mean_incongruent;
                tableau_results.block1_dscore(p) = D_score;
                tableau_results.block1_congruent_std(p) = sd_congruent;
                tableau_results.block1_incongruent_std(p) = sd_incongruent;
                tableau_results.block1_congruent_NBerrors(p) = mistake_congruent;
                tableau_results.block1_incongruent_NBerrors(p) = mistake_incongruent;
            case 2
                tableau_results.block2_congruent_RT(p) = mean_congruent;
                tableau_results.block2_incongruent_RT(p) = mean_incongruent;
                tableau_results.block2_dscore(p) = D_score;
                tableau_results.block2_congruent_std(p) = sd_congruent;
                tableau_results.block2_incongruent_std(p) = sd_incongruent;
                tableau_results.block2_congruent_NBerrors(p) = mistake_congruent;
                tableau_results.block2_incongruent_NBerrors(p) = mistake_incongruent;
        end
    end
end

%% Save the Results
resultFile = fullfile(resultDir, 'opensesameResults.csv');
writetable(tableau_results, resultFile);
