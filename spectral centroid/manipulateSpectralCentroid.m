function y = manipulateSpectralCentroid(x, fs, percentChange)
    % Spectral centroid manipulation for short sounds (around 30 ms)
    % Pitch and duration remain constant; only timbre (brightness) changes.
    %
    % x: input signal (mono)
    % fs: sampling frequency
    % percentChange: + value = brighten, - value = darken

    x = x(:);                     % ensure column vector
    tiltSlope = percentChange/100;
    f_ref = 1000;                 % reference frequency (Hz)
    % --- FFT-based single-frame processing ---
    lenx = length(x);
    N = 2^nextpow2(lenx*2);       % FFT length (slightly larger than sample length)
    X = fft(x, N);

    % Positive frequency axis
    halfN = floor(N/2);
    freqs = (0:halfN)*(fs/N);

    % Weighting (tilt) function
    weights = (freqs / f_ref).^tiltSlope;
    weights(freqs==0) = 1;
    weights = min(max(weights, 0.1), 12);
    weights = weights(:);
    if length(weights) ~= halfN+1
        weights = interp1(1:length(weights),weights,linspace(1,length(weights),halfN+1),'linear','extrap');
    end

    % Magnitude and phase
    mag = abs(X(1:halfN+1)) .* weights;
    phase = angle(X(1:halfN+1));
    X_new = mag .* exp(1i*phase);

    % Hermitian symmetry (for real signal generation)
    X_full = zeros(size(X));
    X_full(1:halfN+1) = X_new;
    X_full(halfN+2:end) = conj(flipud(X_new(2:end-1)));

    % Inverse FFT
    y = real(ifft(X_full));
    y = y(1:lenx);

    % RMS preservation
    rms_orig = sqrt(mean(x.^2));
    rms_mod  = sqrt(mean(y.^2));
    if rms_mod > 1e-9
        y = y * (rms_orig / rms_mod);
    end

    y = real(y);
    y(isnan(y) | isinf(y)) = 0;
end
