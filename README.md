# Timbral Feature Manipulation Toolkit

MATLAB-based signal processing scripts for systematic manipulation of two timbral acoustic features in ultra-short (30 ms) speech stimuli. Designed for psychoacoustic research investigating rapid phoneme categorization under controlled spectral and temporal timbral variation.

## Overview

Following the selection and peak-normalization of primary phoneme stimuli, each sound is subjected to precise timbral manipulations using the scripts in this repository. All manipulations are individually verified by the researchers through spectrogram inspection and numerical acoustic measurements. Unlike conventional morphing algorithms, these procedures operate through direct digital signal processing (DSP) techniques to maintain strict control over the temporal and spectral properties of 30 ms acoustic segments.

## Features

### 1. Spectral Centroid  
`manipulateSpectralCentroid.m`, `spectralCentroidProcess_withReport.m`

Targets the perceived brightness of phonemes without affecting fundamental frequency (F0) or duration. An FFT-based filtering approach applies a spectral tilt along the frequency axis. Positive manipulations at +25%, +50%, and +75% levels are achieved by weighting high-frequency components relative to a 1000 Hz reference frequency, thereby shifting the spectral center of gravity upward. Each manipulated signal is rescaled to its original RMS level to prevent loudness from acting as a confounding variable. Spectral distributions at each manipulation level are verified by the researchers through both spectrograms and numerical metrics.

**Key parameters:**

- FFT length: next power of 2, zero-padded
- Reference frequency: 1000 Hz
- Tilt function: `(f / f_ref)^slope`, clamped to `[0.1, 12]`
- RMS preservation applied post-manipulation

### 2. Logarithmic Attack Time  
`attack_realAttackBased.m`

Targets the perceived sharpness or emphasis of the phoneme onset. The attack phase is defined as the temporal interval between 10% and 90% of the maximum energy envelope. Using linear interpolation, this specific onset segment is stretched by +25%, +50%, and +75%, while the steady-state portion of the phoneme is preserved. After manipulation, the time-amplitude profile and attack duration values of each stimulus are computed and reviewed by the authors for consistency with the targeted ratios. This approach enables precise investigation of how different phoneme onset profiles affect rapid categorization under high processing demands.

**Key parameters:**

- Envelope smoothing: 2 ms moving average
- Attack boundaries: 10%–90% of peak envelope
- Expansion method: linear interpolation (`interp1`)
- Output normalization: peak-normalized to 0.95

## Validation

All manipulated stimuli undergo an additional verification process using the Timbre Toolbox. Metrics associated with spectral centroid and logarithmic attack time are automatically computed and compared against the targeted manipulation levels. This supplementary analysis supports the consistency and methodological reliability of the applied timbral modifications.

## Repository Structure

```text
├── manipulateSpectralCentroid.m           # Core SC manipulation function
├── spectralCentroidProcess_withReport.m   # Batch processing + CSV report for SC
├── attack_realAttackBased.m               # Attack time manipulation + CSV report
└── README.md
