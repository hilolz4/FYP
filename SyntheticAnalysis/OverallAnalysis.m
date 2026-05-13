% === Segment waveforms into fixed number of bins and average across patients ===
var_boxes = 40;

filler  = segment_average(AgedTables.Overall.Actual,     var_boxes);  % actual pressure
filler2 = segment_average(AgedTables.Overall.Calculated, var_boxes);  % calculated pressure
table_Segmented = segment_table(AgedTables.Overall.Inaccuracy, var_boxes); % inaccuracy per patient (for boxplot)

% === Plot ===
set(0, 'DefaultAxesFontSize', 14)
set(0, 'DefaultAxesFontName', 'Arial')
set(0, 'DefaultTextFontSize', 14)

figure;
yyaxis left;
plot(filler,  'Color', 'm');
hold on;
plot(filler2, 'Color', 'k');
ylabel('Average Pressure (mmHg)', 'Color', 'm');
ylim([60 115])

yyaxis right;
boxplot(table_Segmented, 'Symbol', '_', 'Colors', 'b', 'OutlierSize', 0.001);
yline(5, 'r--', '5 mmHg', 'FontSize', 14, 'LineWidth', 2.5);
ylabel('Distribution of Error (mmHg)', 'Color', 'b')
ylim([-1 14])
xticklabels([]);
xlabel('Average Cardiac Cycle')
title('Actual vs Calculated Blood Pressure')


% =========================================================
% Helper: segment each patient row into var_boxes bins,
% return the mean across all patients (1 x var_boxes)
% =========================================================
function out = segment_average(table_in, var_boxes)
    out = mean(segment_table(table_in, var_boxes), 1, 'omitmissing');
end


% =========================================================
% Helper: segment each patient row into var_boxes bins,
% return full table (nPatients x var_boxes)
% =========================================================
function table_Segmented = segment_table(table_in, var_boxes)
    var_Rows = size(table_in, 1);
    table_Segmented = nan(var_Rows, var_boxes);
    for var_i = 1:var_Rows
        var_row   = table_in(var_i, :);
        var_row   = var_row(~isnan(var_row));
        var_edges = round(linspace(1, numel(var_row) + 1, var_boxes + 1));
        for var_j = 1:var_boxes
            table_Segmented(var_i, var_j) = mean(var_row(var_edges(var_j):(var_edges(var_j+1)-1)));
        end
    end
end