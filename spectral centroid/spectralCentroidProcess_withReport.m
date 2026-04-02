function spectralCentroidProcess_withReport()
    % --- Select input folder ---
    inputFolder = uigetdir([], 'Select the folder containing input .wav files');
    if inputFolder == 0
        disp('Operation cancelled.');
        return;
    end
    
    % --- Output folder ---
    outputFolder = fullfile(inputFolder, 'out_SC');
    if ~exist(outputFolder, 'dir')
        mkdir(outputFolder);
    end

    % --- Find files ---
    files = dir(fullfile(inputFolder, '*.wav'));
    if isempty(files)
        error('No .wav files found in the selected folder!');
    end

    % --- Manipulation levels ---
    manipLevels = [25, 50, 75];

    fprintf('\nTotal %d files to be processed...\n', length(files));

    % --- Variables for results table ---
    results = {};

    % --- For each file ---
    for i = 1:length(files)
        fprintf('\n[%d/%d] Processing %s...\n', i, length(files), files(i).name);

        [x, fs] = audioread(fullfile(files(i).folder, files(i).name));
        [~, name, ~] = fileparts(files(i).name);

        % Convert to mono if stereo
        if size(x,2) > 1
            x = mean(x,2);
        end

        % --- Measure Original Centroid ---
        % --- Create safe 30 ms window ---
        wlen = round(0.03 * fs);                 % 30 ms
        wlen = min(wlen, length(x));             % shorten if sound is shorter
        win = hamming(wlen, 'periodic');         % window
        overlap = round(0.5*wlen);               % %50 overlap

        origCentroid = mean(spectralCentroid(x, fs, ...
        'Window', win, 'OverlapLength', overlap));


        % --- For each manipulation level ---
        for m = 1:length(manipLevels)
            scale = manipLevels(m);

            % Apply manipulation
            x_mod = manipulateSpectralCentroid(x, fs, scale);

            % Normalization and fade
            x_mod = x_mod / max(abs(x_mod)) * 0.95;
            fadeLen = round(0.01 * fs);
            fadeIn = linspace(0, 1, fadeLen)';
            fadeOut = linspace(1, 0, fadeLen)';
            x_mod(1:fadeLen) = x_mod(1:fadeLen) .* fadeIn;
            x_mod(end-fadeLen+1:end) = x_mod(end-fadeLen+1:end) .* fadeOut;

            % Output filename
            outname = sprintf('%s_SC_%+d.wav', name, scale);
            outpath = fullfile(outputFolder, outname);
            audiowrite(outpath, x_mod, fs);

            % --- Measure Manipulated Centroid ---
            newCentroid = mean(spectralCentroid(x_mod, fs, ...
            'Window', win, 'OverlapLength', overlap));


            % --- Record (in Hz) ---
            results(end+1,:) = {name, scale, origCentroid, newCentroid, ...
                                ((newCentroid - origCentroid) / origCentroid) * 100};
            
            % (Optional) Create visualization
            if i == 1 && m == 1
                createComparisonPlot(x, x_mod, fs, scale, outputFolder, name);
            end
        end
    end

    % --- Create table and save ---
    resultsTable = cell2table(results, ...
        'VariableNames', {'File', 'Manipulation_Pct', 'Original_SC_Hz', 'New_SC_Hz', 'Change_Pct'});
    
    % CSV Save
    csvPath = fullfile(outputFolder, 'SpectralCentroid_Report.csv');
    writetable(resultsTable, csvPath);

    fprintf('\n✓ Process completed.\n');
    fprintf('→ Report: %s\n', csvPath);
    fprintf('→ Output files: %s\n\n', outputFolder);
    
    disp(resultsTable);
end


function createComparisonPlot(x_orig, x_mod, fs, scale, outputFolder, name)
    % Comparative spectrogram
    fig = figure('Position', [100, 100, 1200, 800], 'Visible', 'off');
    subplot(2,2,1);
    plot((0:length(x_orig)-1)/fs, x_orig);
    title('Original Signal'); xlabel('Time (s)'); ylabel('Amplitude'); grid on;

    subplot(2,2,2);
    plot((0:length(x_mod)-1)/fs, x_mod);
    title(sprintf('Manipulated Signal (SC %+d%%)', scale)); xlabel('Time (s)'); ylabel('Amplitude'); grid on;

    subplot(2,2,3);
    spectrogram(x_orig, hamming(512), 384, 512, fs, 'yaxis');
    title('Original Spectrogram');

    subplot(2,2,4);
    spectrogram(x_mod, hamming(512), 384, 512, fs, 'yaxis');
    title(sprintf('Manipulated Spectrogram (SC %+d%%)', scale));

    saveas(fig, fullfile(outputFolder, sprintf('%s_SC_%+d_comparison.png', name, scale)));
    close(fig);
end
