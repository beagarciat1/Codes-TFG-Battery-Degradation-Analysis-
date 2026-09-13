clear; clc; close all;

filename = 'Parametros_Nyquist_BATERIA18_TODAS.xlsx';
data = readtable(filename);

ciclos = data.Ciclo;
parametros = {'L0_H', 'R0_Ohm', 'R1_Ohm', 'C1_F', 'R2_Ohm', 'C2_F'};
nombres    = {'L0 (H)', 'R0 (Ω)', 'R1 (Ω)', 'C1 (F)', 'R2 (Ω)', 'C2 (F)'};

% ← Filas (por posición, 1 = primera fila de datos, 2 = segunda, ...) que se
% excluyen SOLO del cálculo del ajuste. El punto sigue apareciendo en la
% gráfica, marcado en otro color para distinguirlo. Ej: [7] o [7, 12, 20].
% Dejar [] para no excluir ninguna.
filas_excluir_fit = [];
mask_fit = true(height(data), 1);
filas_excluir_fit = filas_excluir_fit(filas_excluir_fit >= 1 & filas_excluir_fit <= height(data));
mask_fit(filas_excluir_fit) = false;
if ~isempty(filas_excluir_fit)
    fprintf('Excluyendo del ajuste %d fila(s) (Ciclo): %s  (se siguen mostrando en la gráfica)\n\n', ...
        numel(filas_excluir_fit), mat2str(ciclos(filas_excluir_fit)'));
end

% ==================== STARTPOINTS PERSONALIZADOS (Exp + Lineal) ====================
startPoints = {
    [1e-9,   0.001,  1e-11,  8.9e-8], ...   % L0_H     → ruido, sin tendencia real
    [0.0008, 0.015, 0.0002, 0.159], ... % R0_Ohm
    [1e-5,   0.001,  1e-6,   0.059],  ...   % R1_Ohm   → ruido, sin tendencia real
    [1e-5,   0.01,  -5e-7,   0.00135], ...  % C1_F     → tendencia débil, mejora limitada
    [0.05,  -0.005, -1e-4,   0.170],  ...   % R2_Ohm   → ya iba razonable, refinado
    [0.001,  0.005,  2e-5,   0.014],  ...   % C2_F     → b mucho más pequeño, deja que domine la tendencia lineal
};

outputFolder = 'Fits_Exponencial_Lineal';
if ~exist(outputFolder, 'dir'), mkdir(outputFolder); end

fprintf('=== AJUSTE EXPONENCIAL + LINEAL (y = a*exp(b*x) + d*x + e) ===\n\n');

for i = 1:length(parametros)
    var_name = parametros{i};
    y = data.(var_name);
    x = ciclos;
    x_fit = x(mask_fit);
    y_fit_data = y(mask_fit);

    ft = fittype('a*exp(b*x) + d*x + e', 'independent','x');

    opts = fitoptions('Method','NonlinearLeastSquares',...
        'StartPoint', startPoints{i}, ...
        'Lower',      [0, -2, -Inf, 0], ...
        'Upper',      [Inf, 2, Inf, Inf], ...
        'Robust',     'on', ...
        'MaxIter',    2000, ...
        'TolFun',     1e-9);

    [fitobj, gof] = fit(x_fit, y_fit_data, ft, opts);
    coeff = coeffvalues(fitobj);
    y_hat = fitobj(x_fit);
    error_relativo = mean(abs(y_fit_data - y_hat) ./ abs(y_fit_data)) * 100;

    fprintf('PARÁMETRO: %s\n', nombres{i});
    fprintf('R² = %.4f | RMSE = %.6e | Error relativo medio = %.4f %%\n', gof.rsquare, gof.rmse, error_relativo);
    fprintf('Ecuación: y = %.6e*exp(%.6e*x) + %.6e*x + %.6e\n', ...
            coeff(1), coeff(2), coeff(3), coeff(4));
    fprintf('StartPoint usado: [%g, %g, %g, %g]\n\n', startPoints{i});

    x_fino = linspace(min(x), max(x)+2, 500);
    y_fino = fitobj(x_fino);

    figure('Position',[100 100 950 580]);
    plot(x_fit, y_fit_data, 'o', 'MarkerSize',9, 'LineWidth',1.8, 'DisplayName','Datos Experimentales');
    hold on;
    if any(~mask_fit)
        plot(x(~mask_fit), y(~mask_fit), 'x', 'MarkerSize',12, 'LineWidth',2.5, ...
            'Color',[0.6 0.6 0.6], 'DisplayName','Excluido del ajuste');
    end
    plot(x_fino, y_fino, 'r-', 'LineWidth',2.8, 'DisplayName','Exponencial + Lineal');
    title(['Exponencial + Lineal - ' nombres{i}], 'FontSize',15);
    xlabel('Ciclo', 'FontSize',13); ylabel(nombres{i}, 'FontSize',13);
    grid on; legend('Location','best');
    
    saveas(gcf, fullfile(outputFolder, ['Exp_Lineal_' var_name '.png']));
end

disp('Ajuste Exponencial + Lineal terminado.');