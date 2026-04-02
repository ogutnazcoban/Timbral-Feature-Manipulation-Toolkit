function spectralFluxProcess_withReport()
    % ----------------------------------------------------------
    % SPECTRAL FLUX manipulation for short (30 ms) stimuli + REPORT
    % ----------------------------------------------------------

    inputFolder = uigetdir([], 'Select the folder containing 30 ms .wav files');
    if inputFolder == 0
        disp('Operation cancelled.'); return;
    end

    outputFolder = fullfile(inputFolder, 'out_flux_report');
    if ~exist(outputFolder, 'dir'), mkdir(outputFolder); end

    files = dir(fullfile(inputFolder, '*.wav'));
    if isempty(files), error('No .wav files found in the folder!'); end

    manipLevels = [25, 50, 75];
    fprintf('Total %d files to be processed...\n', numel(files));

    % Result record table
    results = {};

    for i = 1:numel(files)
        [x, fs] = audioread(fullfile(files(i).folder, files(i).name));
        [~, name] = fileparts(files(i).name);
        if size(x,2) > 1, x = mean(x,2); end
        fprintf('\n[%d/%d] %s\n', i, numel(files), name);

        % Original flux value
        origFlux = mean(spectralFluxValue(x, fs));

        % --- For each manipulation level ---
        for m = 1:numel(manipLevels)
            sc = manipLevels(m);
            y = applyFluxManipulation(x, fs, sc);

            % Fade in/out (prevent clicks)
            fadeLen = max(1, round(0.002 * fs));
            winIn  = linspace(0,1,fadeLen)'; 
            winOut = linspace(1,0,fadeLen)';
            if numel(y) >= 2*fadeLen
                y(1:fadeLen) = y(1:fadeLen).*winIn;
                y(end-fadeLen+1:end) = y(end-fadeLen+1:end).*winOut;
            end
            y = real(y);

            % Save file
            outname = sprintf('%s_FLUX_%+d.wav', name, sc);
            audiowrite(fullfile(outputFolder, outname), y, fs);

            % New flux value
            newFlux = mean(spectralFluxValue(y, fs));

            % Percentage change
            changePct = ((newFlux - origFlux) / origFlux) * 100;

            % Add to table
            results(end+1,:) = {name, sc, origFlux, newFlux, changePct};

            % Visual difference analysis
            if i == 1 && m == 1
                createFluxComparison(x, y, fs, sc, outputFolder, name);
            end

            fprintf('  %+d%% completed (Flux change: %.2f%%)\n', sc, changePct);
        end
    end

    % Create table
    resultsTable = cell2table(results, ...
        'VariableNames', {'File', 'Manipulation_Pct', 'Original_Flux', 'New_Flux', 'Change_Pct'});
    
    % Save as CSV
    csvPath = fullfile(outputFolder, 'SpectralFlux_Report.csv');
    writetable(resultsTable, csvPath);

    fprintf('\n✓ All operations completed.\n');
    fprintf('→ Report saved: %s\n', csvPath);
    fprintf('→ Output files: %s\n\n', outputFolder);

    disp(resultsTable);
end


% ================================================================
% Spectral flux value calculation function
% ================================================================
function fluxVals = spectralFluxValue(x, fs)
    % SCalculates flux from consecutive frame differences using STFT
    win = hann(256, 'periodic');
    hop = 128;
    [S,~,~] = stft(x, fs, 'Window', win, 'OverlapLength', 256-hop, 'Centered', true);
    mag = abs(S);

    % Frame farkları
    diffMag = diff(mag,1,2);
    fluxVals = sqrt(sum(diffMag.^2, 1));  % L2 norm (classic spectral flux definition)
end


% ================================================================
% Manipulation
% ================================================================
function y = applyFluxManipulation(x, fs, percentChange)
    x = x(:);
    N = length(x);
    winSize = 128; hopSize = 32;
    w = hann(winSize, 'periodic');

    [S,~,~] = stft(x, fs, 'Window', w, ...
        'OverlapLength', winSize - hopSize, 'Centered', true);
    mag = abs(S); phase = angle(S);

    depth = percentChange / 50;  % +25→0.5, +50→1.0, +75→1.5
    [numBins, numFrames] = size(mag);
    freqs = linspace(0,1,numBins)';  
    t = linspace(0,2*pi,numFrames);
    modShape = 1 + depth * (0.6*sin(t) + 0.3*sin(2*t));
    tilt = 1 + 0.8 * depth * freqs;

    for k = 1:numFrames
        mag(:,k) = mag(:,k) .* modShape(k) .* tilt;
    end

    S_mod = mag .* exp(1i*phase);
    y = istft(S_mod, fs, 'Window', w, ...
        'OverlapLength', winSize - hopSize, 'Centered', true);

    rms_orig = sqrt(mean(x.^2) + eps);
    rms_mod  = sqrt(mean(y.^2) + eps);
    y = y * ((0.7 * rms_orig / rms_mod) + 0.3);

    y = y(1:min(length(y), N));
    y(isnan(y) | isinf(y)) = 0;
    y = real(y);
end


% ================================================================
% Visual difference analysis (optional)
% ================================================================
function createFluxComparison(x, y, fs, sc, outputFolder, name)
    [Sx,F,T] = stft(x, fs, 'Window', hamming(256,'periodic'), ...
        'OverlapLength',192, 'Centered', true);
    [Sy,~,~] = stft(y, fs, 'Window', hamming(256,'periodic'), ...
        'OverlapLength',192, 'Centered', true);

    diffMap = abs(abs(Sy) - abs(Sx));
    diffMap = 20*log10(1 + diffMap);

    figure('Position',[100 100 1200 600],'Visible','off');
    sgtitle(sprintf('%s — Spektral Flux %+d%%', name, sc),'FontSize',14);

    subplot(2,2,1);
    spectrogram(x,hamming(256),192,512,fs,'yaxis');
    title('Orijinal Spektrogram'); ylim([0 10]);

    subplot(2,2,2);
    spectrogram(y,hamming(256),192,512,fs,'yaxis');
    title(sprintf('Manipulated (%+d%%)', sc)); ylim([0 10]);

    subplot(2,2,[3 4]);
    imagesc(T,F,diffMap,[0 10]); axis xy;
    caxis([0 10]); colormap(turbo);
    title('Spectral Difference Map (|Y|-|X|)');
    xlabel('Time (s)'); ylabel('Frequency (kHz)');
    colorbar;

    saveas(gcf, fullfile(outputFolder, ...
        sprintf('%s_FLUX_%+d_analysis.png', name, sc)));
    close(gcf);
end
