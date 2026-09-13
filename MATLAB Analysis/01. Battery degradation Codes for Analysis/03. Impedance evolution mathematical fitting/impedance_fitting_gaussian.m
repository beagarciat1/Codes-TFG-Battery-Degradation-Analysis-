 %% ==================== GAUSSIAN PROCESS REGRESSION ====================

clear; clc; close all;

filename = 'Resultados_Parametros_Nyquist.xlsx';
data = readtable(filename);

ciclos = data.Ciclo;
parametros = {'L0_H', 'R0_Ohm', 'R1_Ohm', 'C1_F', 'R2_Ohm', 'C2_F'};
nombres   = {'L0 (H)', 'R0 (Ω)', 'R1 (Ω)', 'C1 (F)', 'R2 (Ω)', 'C2 (F)'};

outputFolder = 'Fits_GaussianProcess';
if ~exist(outputFolder, 'dir')
    mkdir(outputFolder);
end

fprintf('=== GAUSSIAN PROCESS REGRESSION ===\n\n');

for i = 1:length(parametros)
    var_name = parametros{i};
    y = data.(var_name);
    
    % ==================== AJUSTE GPR ====================
    gprMdl = fitrgp(ciclos, y, ...
        'BasisFunction', 'none', ...
        'KernelFunction', 'squaredexponential', ...   % buena opción general
        'OptimizeHyperparameters', 'auto', ...        % optimiza automáticamente
        'Standardize', true);
    
    % Predicción con incertidumbre
    x_fino = linspace(min(ciclos), max(ciclos)+50, 300)';  % hasta +50 ciclos para ver tendencia
    [y_pred, y_sd] = predict(gprMdl, x_fino);               % y_sd = desviación estándar
    
    % ==================== MÉTRICAS ====================
    y_fit = predict(gprMdl, ciclos);
    RMSE = sqrt(mean((y - y_fit).^2));
    R2 = 1 - sum((y - y_fit).^2)/sum((y - mean(y)).^2);
    
    fprintf('PARÁMETRO: %s\n', nombres{i});
    fprintf('R²   = %.4f\n', R2);
    fprintf('RMSE = %.6f\n\n', RMSE);
    
    % ==================== GRÁFICA ====================
    figure('Position',[100 100 1000 620]);
    plot(ciclos, y, 'o', 'MarkerSize',10, 'LineWidth',1.8, 'DisplayName','Datos Experimentales');
    hold on;
    
    % Curva media
    plot(x_fino, y_pred, 'r-', 'LineWidth',2.5, 'DisplayName','GPR Predicción');
    
    % Banda de incertidumbre (±2σ)
    fill([x_fino; flipud(x_fino)], [y_pred+2*y_sd; flipud(y_pred-2*y_sd)], ...
         'r', 'FaceAlpha',0.15, 'EdgeColor','none', 'DisplayName','±2σ (95% confianza)');
    
    title(['Gaussian Process Regression - ' nombres{i}], 'FontSize',15);
    xlabel('Ciclo', 'FontSize',13);
    ylabel(nombres{i}, 'FontSize',13);
    grid on;
    legend('Location','best');
    
    saveas(gcf, fullfile(outputFolder, ['GPR_' var_name '.png']));
end

disp('✅ Gaussian Process Regression completado.');
disp(['Gráficas guardadas en: ' outputFolder]);

%% === RESUMEN DETALLADO DEL MODELO ===
fprintf('\n=== RESUMEN DETALLADO DEL GPR ===\n');
disp(gprMdl)

fprintf('\nKernel usado: %s\n', gprMdl.KernelInformation.Name);
fprintf('Función base: %s\n', char(gprMdl.BasisFunction));
fprintf('Datos estandarizados: %d\n', gprMdl.Standardize);

% Parámetros del kernel
params = gprMdl.KernelInformation.KernelParameters;
if isstruct(params)
    fieldnames(params)
    disp(params)
end