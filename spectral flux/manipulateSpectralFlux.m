function y = manipulateSpectralFlux_30ms(x, fs, percentChange)
    % ----------------------------------------------------------
    % "Active" spectral flux manipulation for short sounds (30 ms)
    % - Adds micro-fluctuations to magnitude in consecutive frames
    % - Preserves phase, matches RMS to input (does not affect loudness)
    % - percentChange: +25 / +50 / +75 (positive only)
    % ----------------------------------------------------------
    x = x(:);
    N = length(x);

    % Very small STFT windows: sufficient number of frames within 30 ms
    winSize = 128;         % ~2.9 ms @ 44.1 kHz
    hopSize = 32;          % ~0.7 ms
    w = hann(winSize, 'periodic');

    % STFT
    [S, ~, ~] = stft(x, fs, 'Window', w, ...
        'OverlapLength', winSize - hopSize, 'Centered', true);

    mag   = abs(S);
    phase = angle(S);

    % --- Frame-based amplitude modulation to make Flux visible ---
    % Mod depth: +25 -> 0.25, +50 -> 0.5, +75 -> 0.75
    depth = max(0, percentChange/100);                 % [0..]
    T = size(mag, 2);
    if T <= 1
        % If only one frame remains, manipulation is meaningless; return directly
        y = x; return;
    end

    % Rapid sinusoidal oscillation on the time axis (artificial flux)
    t = linspace(0, 2*pi, T);
    % Mixing a few harmonics for a bit more "movement":
    modShape = 1 + depth*(0.6*sin(t) + 0.3*sin(2*t) + 0.1*sin(3*t));
    modShape = max(0.05, modShape);                    % ensure not negative/too small

    % Apply to each frame
    mag_mod = mag;
    for k = 1:T
        mag_mod(:,k) = mag_mod(:,k) .* modShape(k);
    end

    % Preserve phase and reconstruct
    S_mod = mag_mod .* exp(1i*phase);
    y = istft(S_mod, fs, 'Window', w, ...
        'OverlapLength', winSize - hopSize, 'Centered', true);

    % --- RMS preservation: do not touch loudness ---
    rms_orig = sqrt(mean(x.^2) + eps);
    rms_mod  = sqrt(mean(y.^2) + eps);
    y = y * (rms_orig / rms_mod);

    % Match length to input and safety check
    y = y(1:min(length(y), N));
    y = real(y);
    y(isnan(y) | isinf(y)) = 0;
end
