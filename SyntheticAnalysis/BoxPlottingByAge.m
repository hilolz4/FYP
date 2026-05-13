% Build data and group label vectors
var_groups = {'Overall', 'age25', 'age35', 'age45', 'age55', 'age65', 'age75'};
var_labels = {'Overall', '25', '35', '45', '55', '65', '75'};

data_all   = [];
group_all  = [];

for var_g = 1:length(var_groups)
    var_name = var_groups{var_g};
    var_err  = Calculated.(var_name).MAerror;   % one value per patient
    data_all  = [data_all;  var_err];
    group_all = [group_all; repmat(var_labels(var_g), length(var_err), 1)];
end
% Set global figure defaults — add at top of each script
set(0, 'DefaultAxesFontSize',    14);   % axis tick labels
set(0, 'DefaultTextFontSize',    14);   % text() annotations
set(0, 'DefaultAxesTitleFontSizeMultiplier', 1.1);  % titles slightly larger
set(0, 'DefaultAxesLabelFontSizeMultiplier', 1.0);  % axis labels same size
set(0, 'DefaultLegendFontSize',  12);   % legend text
figure;
boxplot(data_all, group_all, 'Symbol', '', 'OutlierSize', 0.001, 'Colors', 'b');
yline(5, 'r-', '+5 mmHg', 'LineWidth', 2, 'FontSize', 14);
xlabel('Age Group');
ylabel('Error (mmHg)');
title('Error Distribution by Age Group');