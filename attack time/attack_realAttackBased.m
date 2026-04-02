%% =======================
%   ATTACK MANIPULATION
%   - Increase attack by 25% / 50% / 75%
%   - t10–t90 measurement
%   - If attack not found = 0
%   - CSV report
% =========================

clear; clc; close all;

inputFolder = uigetdir([], 'Select the folder containing audio files');
if inputFolder == 0, return; end

outputFolder = fullfile(inputFolder, "output_attack");
if ~exist(outputFolder,'dir'), mkdir(outputFolder); end

files = dir(fullfile(inputFolder, '*.wav'));
ratios = [0.25 0.50 0.75];

report = {};

fprintf("\nATTACK ENHANCEMENT STARTED \n=========================\n\n");

for f = 1:length(files)
    fname = files(f).name;
    fprintf("\n[%d/%d] %s\n", f, length(files), fname);

    [x, fs] = audioread(fullfile(files(f).folder, fname));
    x = x(:);  
    x = x / (max(abs(x)) + eps);

    t = (0:length(x)-1)/fs * 1000;

    %% --- Envelope (2 ms smoothing) ---
    win = max(1, round(0.002 * fs));
    env = movmean(abs(x), win);
    env = env / max(env);

    %% --- Find t10 / t90 ---
    t10 = find(env >= 0.10, 1, 'first');
    t90 = find(env >= 0.90, 1, 'first');

    %% =====================================================
    %   IF NO ATTACK → SET ALL TO 0 (AS REQUESTED)
    % =====================================================
    if isempty(t10) || isempty(t90)
        fprintf("  ⚠ Attack not found → all manipulations set to 0\n");
        
        for R = ratios
            report(end+1,:) = {fname, round(R*100), 0, 0, 0};
        end
        continue;
    end

    %% --- Calculate Attack ---
    origAttack_ms = (t90 - t10)/fs * 1000;
    fprintf("  Orijinal attack = %.2f ms\n", origAttack_ms);

    %% =====================================================
    % FOR EACH MANIPULATION (25% / 50% / 75%)
    % =====================================================
    for R = ratios

        target_ms = origAttack_ms * (1 + R);
        fprintf("   +%d%% hedef = %.2f ms\n", round(R*100), target_ms);

        %% --- Attack Segment ---
        atkSeg = x(t10:t90);
        orig_len = length(atkSeg);

        target_len = round(orig_len * (1 + R));

       %% --- If no attack segment or single sample → write 0, skip interp1 ---
    if origAttack_ms == 0 || orig_len < 2
    fprintf("  ⚠ Atak bölgesi yok veya çok kısa → tüm manipülasyonlar 0\n");

    % Still generate WAV output
    outWav = sprintf("%s_ATTACK_+%d.wav", fname(1:end-4), round(R*100));
    audiowrite(fullfile(outputFolder, outWav), x, fs);

    report(end+1,:) = {fname, round(R*100), 0, 0, 0};
    continue;
end


        %% --- Expand attack segment ---
        atk_new = interp1(linspace(0,1,orig_len), atkSeg, linspace(0,1,target_len), 'linear');

        %% --- Create new signal ---
        x_mod = [ x(1:t10-1); atk_new(:); x(t90+1:end) ];

        %% --- Normalization ---
        x_mod = x_mod / max(abs(x_mod)) * 0.95;

        %% --- New attack measurement ---
        env_mod = movmean(abs(x_mod), win);
        env_mod = env_mod / max(env_mod);
        t10m = find(env_mod >= 0.10, 1, 'first');
        t90m = find(env_mod >= 0.90, 1, 'first');

        if isempty(t10m) || isempty(t90m)
            newAttack_ms = 0;
        else
            newAttack_ms = (t90m - t10m)/fs * 1000;
        end

        %% --- Save WAV ---
        outWav = sprintf("%s_ATTACK_+%d.wav", fname(1:end-4), round(R*100));
        audiowrite(fullfile(outputFolder, outWav), x_mod, fs);

        %% --- Add to report ---
        report(end+1,:) = {fname, round(R*100), origAttack_ms, newAttack_ms, newAttack_ms-origAttack_ms};
    end
end

%% ============================
% CSV REPORT
% ============================
T = cell2table(report, 'VariableNames', ...
    {'Dosya','ManipPercent','OrigAttack_ms','NewAttack_ms','Fark_ms'});

writetable(T, fullfile(outputFolder, "Attack_real_Report.csv"));

fprintf("\n✔ TAMAMLANDI → %s\n", outputFolder);
