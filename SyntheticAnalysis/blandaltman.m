% Compute Bland-Altman axes
set(0, 'DefaultAxesFontSize', 16)
set(0, 'DefaultTextFontSize', 16)
ba_mean = (AgedTables.Overall.Actual + AgedTables.Overall.Calculated) / 2;
ba_diff = AgedTables.Overall.Actual - AgedTables.Overall.Calculated;

% Flatten to vectors, drop NaNs
ba_mean = ba_mean(:);
ba_diff = ba_diff(:);
valid   = ~isnan(ba_mean) & ~isnan(ba_diff);
ba_mean = ba_mean(valid);
ba_diff = ba_diff(valid);

% Percentile markers
p5  = prctile(ba_diff, 5);
p25 = prctile(ba_diff, 25);
p75 = prctile(ba_diff, 75);
p95 = prctile(ba_diff, 95);
bias = mean(ba_diff);

% Plot heatmap
figure;
histogram2(ba_mean, ba_diff, 100, 'DisplayStyle', 'tile', 'ShowEmptyBins', 'off');
colorbar;
cb = colorbar;
cb.Label.String   = 'Number of Occurences';
cb.Label.FontSize = 16;
clim([0 1500]);
hold on;
yline(5,  'c-', '5 mmHg', 'LabelHorizontalAlignment','center','LineWidth', 2.5, 'FontSize', 16);
x_pos = min(ba_mean) + 0.13 * range(ba_mean);
x_pos2 = min(ba_mean) + 0.05 * range(ba_mean);
% Overlay percentile lines
yline(bias, 'w-', 'LineWidth', 1.5);
text(x_pos, bias, 'Bias', 'FontSize', 16, 'Color', 'w','VerticalAlignment', 'bottom');
yline(p95,  'r--', '95th', 'LineWidth', 1.2, 'FontSize', 16, 'LabelHorizontalAlignment', 'left');
yline(p5,   'r--', '5th',  'LineWidth', 1.2, 'FontSize', 16, 'LabelHorizontalAlignment', 'left');
yline(p75,  'm:',  'LineWidth', 1.0);
text(x_pos2, p75, '75th', 'FontSize', 16, 'Color', 'm','VerticalAlignment', 'bottom');
yline(p25,  'm:',  'LineWidth', 1.0);
text(x_pos2, p25, '25th', 'FontSize', 16, 'Color', 'm','VerticalAlignment', 'bottom');

xlabel('Mean of Actual and Calculated (mmHg)');
ylabel('Difference (Actual - Calculated) (mmHg)');
title('Bland-Altman Heatmap');