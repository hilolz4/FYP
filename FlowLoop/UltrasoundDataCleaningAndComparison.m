% =========================================================
% Flow Loop Pressure Estimation from Diameter Waveform
% Uses exponential formula: P(t) = bPd * exp(a*(A(t)/Ad - 1))
% =========================================================

% === LOAD DIAMETER DATA ===
diam_data = readtable('diameter_results.csv');
t_ms      = diam_data{:,2};
D_mm      = diam_data{:,6};
t_s       = t_ms / 1000;

dt = mean(diff(t_s));
Fs = 1 / dt;
fprintf('Diameter sampling frequency: %.2f Hz\n', Fs);

% === CALIBRATION FROM PRESSURE PHASE AVERAGE ===
% Run Filteringthing.m first so bPs and bPd are in workspace
bPs_sensor = bPs;
bPd_sensor = bPd;
P_sensor_avg = P_final;   % phase averaged sensor pressure (1 x 500)

fprintf('Sensor calibration — bPs: %.2f mmHg, bPd: %.2f mmHg\n', ...
    bPs_sensor, bPd_sensor);

% === STEP 1: FILTER DIAMETER ===
fc     = 7;
[b, a] = butter(4, fc / (Fs/2), 'low');
D_filt = filtfilt(b, a, D_mm);

% === STEP 2: CONVERT DIAMETER TO AREA ===
A_t = pi .* (D_filt / 2).^2;   % mm^2

% === STEP 3: FIND CARDIAC CYCLES ===
min_cycle_samples = round(0.6 * Fs);

[~, trough_locs] = findpeaks(-D_filt, ...
    'MinPeakDistance',   min_cycle_samples, ...
    'MinPeakProminence', 0.1);

n_cycles = length(trough_locs) - 1;
N_points = 500;
t_norm   = linspace(0, 1, N_points);

fprintf('Detected %d cycles\n', n_cycles);
fprintf('Mean cycle time: %.3f s  |  BPM: %.1f\n', ...
    mean(diff(trough_locs)) / Fs, ...
    60 / (mean(diff(trough_locs)) / Fs));

% === STEP 4: CALIBRATION FROM OVERALL SIGNAL EXTREMES ===
% Use full signal min/max for calibration so it is not biased
% by any single cycle
As = max(A_t);
Ad = min(A_t);
alpha = (Ad * log(bPs_sensor / bPd_sensor)) / (As - Ad);

fprintf('Calibration — As: %.4f mm2, Ad: %.4f mm2\n', As, Ad);
fprintf('Alpha (rigidity): %.6f\n', alpha);

% === STEP 5: APPLY FORMULA TO EACH CYCLE THEN PHASE AVERAGE ===
D_cycles = zeros(n_cycles, N_points);
P_cycles = zeros(n_cycles, N_points);

for i = 1:n_cycles
    % Extract one cycle of diameter and area
    seg_d = D_filt(trough_locs(i):trough_locs(i+1));
    seg_a = A_t(trough_locs(i):trough_locs(i+1));

    % Interpolate to fixed length
    t_seg = linspace(0, 1, length(seg_d));
    seg_d_interp = interp1(t_seg, seg_d, t_norm, 'pchip');
    seg_a_interp = interp1(t_seg, seg_a, t_norm, 'pchip');

    % Store diameter cycle
    D_cycles(i,:) = seg_d_interp;

    % Apply formula to this individual cycle
    P_cycles(i,:) = bPd_sensor .* exp(alpha .* (seg_a_interp ./ Ad - 1));
end

% Phase average across all cycles
D_avg     = mean(D_cycles, 1);
P_formula = mean(P_cycles, 1);
P_formula = smoothdata(P_formula, 'gaussian', 15);

fprintf('Formula pressure — min: %.2f mmHg, max: %.2f mmHg\n', ...
    min(P_formula), max(P_formula));

% === STEP 6: ERROR METRICS ===
inaccuracy    = P_sensor_avg - P_formula;
MAE           = mean(abs(inaccuracy));
RMSE          = sqrt(mean(inaccuracy.^2));
pct_within_5  = sum(abs(inaccuracy) < 5) / N_points * 100;

fprintf('\nComparison Results:\n');
fprintf('  MAE:           %.3f mmHg\n', MAE);
fprintf('  RMSE:          %.3f mmHg\n', RMSE);
fprintf('  Within 5 mmHg: %.1f%%\n',    pct_within_5);

% === PLOT 1: Individual diameter cycles + phase average ===
figure('Color','white','Position',[100 100 900 400]);
for i = 1:n_cycles
    h_ind = plot(t_norm, D_cycles(i,:), 'Color', [0.7 0.85 0.95], ...
        'LineWidth', 0.5);
    hold on;
end
h_avg = plot(t_norm, D_avg, 'k', 'LineWidth', 2.5);
ylabel('Diameter (mm)',           'FontSize', 12, 'FontName', 'Arial');
xlabel('Normalised Cardiac Cycle','FontSize', 12, 'FontName', 'Arial');
title('Phase-Averaged Diameter Waveform', 'FontSize', 12);
legend([h_ind, h_avg], {'Individual cycles','Phase average'}, ...
    'Location','northeast');
ax = gca; ax.Box = 'off'; ax.XTick = []; ax.FontName = 'Arial';

% === PLOT 2: Individual calculated pressure cycles + phase average ===
figure('Color','white','Position',[100 100 900 400]);
for i = 1:n_cycles
    h_ind = plot(t_norm, P_cycles(i,:), 'Color', [0.7 0.85 0.95], ...
        'LineWidth', 0.5);
    hold on;
end
h_avg = plot(t_norm, P_formula, 'b', 'LineWidth', 2.5);
ylabel('Estimated Pressure (mmHg)', 'FontSize', 12, 'FontName', 'Arial');
xlabel('Normalised Cardiac Cycle',  'FontSize', 12, 'FontName', 'Arial');
title('Formula-Estimated Pressure: Individual Cycles + Phase Average', 'FontSize', 12);
legend([h_ind, h_avg], {'Individual cycles','Phase average'}, ...
    'Location','northeast');
ax = gca; ax.Box = 'off'; ax.XTick = []; ax.FontName = 'Arial';
ylim([bPd_sensor - 10, bPs_sensor + 10]);

% === PLOT 3: Overlay sensor vs formula ===
figure('Color','white','Position',[100 100 900 450]);
h_sensor  = plot(t_norm, P_sensor_avg, 'k',   'LineWidth', 2.5);
hold on;
h_formula = plot(t_norm, P_formula,    'b--', 'LineWidth', 2.0);
ylabel('Pressure (mmHg)',          'FontSize', 12, 'FontName', 'Arial');
xlabel('Normalised Cardiac Cycle', 'FontSize', 12, 'FontName', 'Arial');
title('Sensor vs Formula Estimated Pressure', 'FontSize', 12);
legend([h_sensor, h_formula], {'Sensor (phase avg)','Formula estimate'}, ...
    'Location','northeast');
ax = gca; ax.Box = 'off'; ax.XTick = []; ax.FontName = 'Arial';
ylim([bPd_sensor - 15, bPs_sensor + 15]);

% === PLOT 4: Pointwise error ===
figure('Color','white','Position',[100 100 900 300]);
plot(t_norm, inaccuracy, 'r', 'LineWidth', 1.5);
hold on;
yline( 5, 'b--', 'LineWidth', 1.2);
yline(-5, 'b--', 'LineWidth', 1.2);
yline( 0, 'k',   'LineWidth', 1.0);
ylabel('Error (mmHg)',             'FontSize', 12, 'FontName', 'Arial');
xlabel('Normalised Cardiac Cycle', 'FontSize', 12, 'FontName', 'Arial');
title('Pointwise Error: Sensor - Formula', 'FontSize', 12);
legend({'Error','±5 mmHg limit'}, 'Location','northeast');
ax = gca; ax.Box = 'off'; ax.XTick = []; ax.FontName = 'Arial';
ylim([-10 55]);