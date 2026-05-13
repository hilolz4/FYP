% === Iterate over all groups in AgedTables and compute stats for each ===
var_groups = fieldnames(AgedTables);    % {'Overall','age25','age35',...,'age75'}

for var_g = 1:length(var_groups)
    var_name = var_groups{var_g};
    Calculated.(var_name) = compute_stats(AgedTables.(var_name));
end


% =========================================================
% Helper: compute all error statistics for one age group
% Input:  T  - one entry from AgedTables (struct with fields
%              Actual, Calculated, Inaccuracy, bPs, bPs_calc,
%              ActualMAP, CalculatedMAP)
% Output: S  - struct of computed statistics
% =========================================================
function S = compute_stats(T)
    medium_bPserror = T.bPs - T.bPs_calc;                              % peak pressure error
    medium_MAerror  = mean(T.Inaccuracy, 2, 'omitmissing');            % mean absolute error per patient
    medium_MASD     = std(T.Inaccuracy,  0, 2, 'omitmissing');         % SD per patient

    table_RMSinaccuracy = T.Inaccuracy .^ 2;
    medium_RMSerror     = sqrt(mean(table_RMSinaccuracy, 2, 'omitmissing')); % RMS error per patient

    medium_upper_bound_error = mean(medium_MAerror) + std(medium_MAerror) * 1.96;  % confidence interval
    medium_lower_bound_error = mean(medium_MAerror) - std(medium_MAerror) * 1.96;

    [~, medium_t_pValue, ~, medium_t_stat] = ttest(medium_MAerror);    % one sample t-test

    medium_MAPdiff = T.ActualMAP - T.CalculatedMAP;

    S.Actual          = T.Actual;
    S.Calculated      = T.Calculated;
    S.Inaccuracy      = T.Inaccuracy;
    S.RMSerror        = medium_RMSerror;
    S.RMSerrorMean    = mean(medium_RMSerror);
    S.RMSerrorSD      = std(medium_RMSerror);
    S.MAerror         = medium_MAerror;
    S.MASD            = medium_MASD;
    S.MAerrorMean     = mean(medium_MAerror);
    S.MAerrorSD       = std(medium_MAerror);
    S.MAerroraveSD    = mean(medium_MASD);
    S.MAUpperbound    = medium_upper_bound_error;
    S.MALowerbound    = medium_lower_bound_error;
    S.BPSerror        = medium_bPserror;
    S.BPSerrorMean    = mean(medium_bPserror);
    S.BPSerrorSD      = std(medium_bPserror);
    S.tStat           = medium_t_stat.tstat;
    S.pValue          = medium_t_pValue;
    S.ActualMAP       = T.ActualMAP;
    S.CalculatedMAP   = T.CalculatedMAP;
    S.MAPdiff         = medium_MAPdiff;
    S.MAPdiffMean     = mean(medium_MAPdiff);
    S.MAPdiffSD       = std(medium_MAPdiff);
end
