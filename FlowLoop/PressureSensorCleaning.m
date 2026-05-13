% === STEP 1: Load Excel file ===
data = readtable('Data.xlsx');

% If your columns have headers, use the header names directly
% e.g. if headers are "DataNumber", "Time", "Pressure_mmHg"
%data_time = data.Time;           % adjust to match your actual header name
%P_raw     = data.Pressure;  % adjust to match your actual header name

% --- OR if you prefer column index numbers regardless of headers ---
data_time = data{6380:7380,2};  % column 2
P_raw     = data{6380:7380,4};  % column 3 — already in mmHg so skip conversion

% === STEP 2: Voltage to mmHg conversion — SKIP THIS ===
% Already converted in Excel, P_raw is already in mmHg

% === STEP 3: Get sampling frequency from time column ===
dt = mean(diff(data_time));
Fs = 1 / dt;
fprintf('Detected sampling frequency: %.1f Hz\n', Fs);

% === STEP 4: Low pass filter ===
fc = 8;
[b, a] = butter(4, fc / (Fs/2), 'low');
P_filt = filtfilt(b, a, P_raw);

% === STEP 5: Find cycle start points ===
min_cycle_samples = round(0.7 * Fs);

[~, trough_locs] = findpeaks(-P_filt, ...
    'MinPeakDistance', min_cycle_samples, ...
    'MinPeakProminence', 5);

fprintf('Detected %d cycles\n', length(trough_locs) - 1);

% Cycle lengths from trough locations
pressure_cycle_lengths = diff(trough_locs);
pressure_cycle_times   = pressure_cycle_lengths / Fs;

fprintf('Pressure cycle lengths (samples): min=%d, max=%d, mean=%.1f\n', ...
    min(pressure_cycle_lengths), max(pressure_cycle_lengths), mean(pressure_cycle_lengths));
fprintf('Pressure cycle times (seconds):   min=%.3f, max=%.3f, mean=%.3f\n', ...
    min(pressure_cycle_times), max(pressure_cycle_times), mean(pressure_cycle_times));
fprintf('Pressure estimated BPM: %.1f\n', 60 / mean(pressure_cycle_times));

% === STEP 6: Interpolate each cycle to fixed length ===
N_points  = 500;
n_cycles  = length(trough_locs) - 1;
cycles_matrix = zeros(n_cycles, N_points);

for i = 1:n_cycles
    seg   = P_filt(trough_locs(i):trough_locs(i+1));
    t_seg = linspace(0, 1, length(seg));
    t_new = linspace(0, 1, N_points);
    cycles_matrix(i,:) = interp1(t_seg, seg, t_new, 'pchip');
end

% === STEP 7: Phase average ===
P_averaged = mean(cycles_matrix, 1);
P_final    = smoothdata(P_averaged, 'gaussian', 15);
t_norm     = linspace(0, 1, N_points);

bPs = max(P_final);
bPd = min(P_final);

% === STEP 8: Plot ===
figure('Color','white','Position',[100 100 900 400]);

for i = 1:n_cycles
    h_ind = plot(t_norm, cycles_matrix(i,:), 'Color', [0.7 0.85 0.95], ...
        'LineWidth', 0.5);
    hold on;
end

h_avg = plot(t_norm, P_final, 'k', 'LineWidth', 2.5);

ylabel('Pressure (mmHg)',          'FontSize', 12, 'FontName', 'Arial');
xlabel('Normalised Cardiac Cycle', 'FontSize', 12, 'FontName', 'Arial');
title('Phase-Averaged Pressure Waveform', 'FontSize', 13, 'FontName', 'Arial');

% Use explicit handles so legend shows correct line thickness for each
legend([h_ind, h_avg], {'Individual cycles', 'Phase average'}, ...
    'Location', 'northeast');

ax = gca;
ax.Box = 'off';
ax.XTick = [];
ax.FontName = 'Arial';