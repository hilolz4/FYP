var_As = data.pw_inds.Carotid_Amax_V;   % area systolic
var_Ad = data.pw_inds.Carotid_Amin;     % area diastolic
var_bPs = data.pw_inds.Carotid_SBP_V;  % systolic pressure
var_bPd = data.pw_inds.Carotid_DBP;    % diastolic pressure
var_agecolumn = table2array(data.pw_inds(:,2));  % age per patient

% Convert area waveform cell array to padded double matrix
var_ListofArea = data.waves.A_Carotid;
var_At = zeros(4374, 500);
for var_i = 1:4374
    var_filler = cell2mat(var_ListofArea(1, var_i));
    var_At(var_i, 1:length(var_filler)) = var_filler;
end

% Calibration term per patient
var_calibrationterm = (var_Ad .* log(var_bPs ./ var_bPd)) ./ (var_As - var_Ad);

% Calculate estimated pressure at every time point
table_Calculated = zeros(4374, 500);
for var_i = 1:4374
    for var_j = 1:500
        if var_At(var_i, var_j) ~= 0
            table_Calculated(var_i, var_j) = var_bPd(var_i) * exp( ...
                var_calibrationterm(var_i) * ((var_At(var_i, var_j) / var_Ad(var_i)) - 1));
        end
    end
end

% Convert actual pressure waveform cell array to padded double matrix
table_ActualList     = data.waves.P_Carotid;
table_ActualPressure = zeros(4374, 500);
for var_i = 1:4374
    var_filler = cell2mat(table_ActualList(1, var_i));
    table_ActualPressure(var_i, 1:length(var_filler)) = var_filler;
end

% Replace empty time points with NaN
for var_i = 1:4374
    for var_j = 1:500
        if var_At(var_i, var_j) == 0
            table_Calculated(var_i, var_j)     = NaN;
            table_ActualPressure(var_i, var_j) = NaN;
        end
    end
end

% Find calculated pressure at the timing of peak actual pressure
var_Calculated_bPs = zeros(4374, 1);
for var_i = 1:4374
    [~, var_j]             = max(table_ActualPressure(var_i, :));
    var_Calculated_bPs(var_i) = table_Calculated(var_i, var_j);
end

% Mean arterial pressures and inaccuracy
table_ActualMAP            = mean(table_ActualPressure, 2, 'omitmissing');
table_CalculatedMAP        = mean(table_Calculated,     2, 'omitmissing');
table_CalculationInaccuracy = table_ActualPressure - table_Calculated;

% =========================================================
% Build age-stratified data tables
% Keys: 'Overall', 'age25', 'age35', ..., 'age75'
% Each entry holds .Actual, .Calculated, .Inaccuracy,
%                  .bPs, .bPs_calc, .ActualMAP, .CalculatedMAP
% =========================================================
AgedTables = struct();

% Overall (all patients)
AgedTables.Overall.Actual      = table_ActualPressure;
AgedTables.Overall.Calculated  = table_Calculated;
AgedTables.Overall.Inaccuracy  = table_CalculationInaccuracy;
AgedTables.Overall.bPs         = var_bPs;
AgedTables.Overall.bPs_calc    = var_Calculated_bPs;
AgedTables.Overall.ActualMAP   = table_ActualMAP;
AgedTables.Overall.CalculatedMAP = table_CalculatedMAP;

% Per age group
for filterage = [25, 35, 45, 55, 65, 75]
    var_agemask = var_agecolumn == filterage;
    var_name    = sprintf('age%d', filterage);

    AgedTables.(var_name).Actual       = table_ActualPressure(var_agemask, :);
    AgedTables.(var_name).Calculated   = table_Calculated(var_agemask, :);
    AgedTables.(var_name).Inaccuracy   = table_CalculationInaccuracy(var_agemask, :);
    AgedTables.(var_name).bPs          = var_bPs(var_agemask);
    AgedTables.(var_name).bPs_calc     = var_Calculated_bPs(var_agemask);
    AgedTables.(var_name).ActualMAP    = table_ActualMAP(var_agemask);
    AgedTables.(var_name).CalculatedMAP = table_CalculatedMAP(var_agemask);
end
