
clear; clc; close all;

filename = 'Parametros_Nyquist_Ajuste_mincuadpond_NEW.xlsx';
data = readtable(filename);

% ← Filas (por posición, 1 = primera fila de datos, 2 = segunda, ...) que se
% excluyen del cálculo del polinomio Y de la gráfica. Ej: [7] o [7, 12, 20].
% Dejar [] para no excluir ninguna.
filas_excluir_fit = [8];

ciclos = data.Ciclo;
parametros = {'L0_H', 'R0_Ohm', 'R1_Ohm', 'C1_F', 'R2_Ohm', 'C2_F'};
nombres   = {'L0 (H)', 'R0 (Ω)', 'R1 (Ω)', 'C1 (F)', 'R2 (Ω)', 'C2 (F)'};

mask_fit = true(height(data), 1);
filas_excluir_fit = filas_excluir_fit(filas_excluir_fit >= 1 & filas_excluir_fit <= height(data));
mask_fit(filas_excluir_fit) = false;
if ~isempty(filas_excluir_fit)
    fprintf('Excluyendo del ajuste y de la gráfica %d fila(s) (Ciclo): %s\n\n', ...
        numel(filas_excluir_fit), mat2str(ciclos(filas_excluir_fit)'));
end

grado = 3;                    % ← Cambia aquí: 8, 9 o 10

outputFolder = 'Fits_Polyfit_AltoGrado';
if ~exist(outputFolder, 'dir')
    mkdir(outputFolder);
end

fprintf('=== POLYFIT GRADO %d ===\n\n', grado);

for i = 1:length(parametros)
    var_name = parametros{i};
    y = data.(var_name);

    % Solo los puntos no excluidos entran al ajuste
    x_fit_data = ciclos(mask_fit);
    y_fit_data = y(mask_fit);

    % === AJUSTE POLYFIT ===
    p = polyfit(x_fit_data, y_fit_data, grado);          % coeficientes del polinomio
    y_fit = polyval(p, x_fit_data);                       % valores ajustados en los puntos usados

    % Curva fina para graficar (sobre el rango de los puntos usados en el ajuste)
    x_fino = linspace(min(x_fit_data), max(x_fit_data), 500);
    y_fino = polyval(p, x_fino);

    % === CÁLCULO DE MÉTRICAS (sobre los puntos usados en el ajuste) ===
    y_mean = mean(y_fit_data);
    SS_res = sum((y_fit_data - y_fit).^2);
    SS_tot = sum((y_fit_data - y_mean).^2);
    R2 = 1 - (SS_res / SS_tot);
    RMSE = sqrt(SS_res / length(y_fit_data));
    error_relativo = mean(abs(y_fit_data - y_fit) ./ abs(y_fit_data)) * 100;   % %

    % ==================== MOSTRAR RESULTADOS ====================
    fprintf('PARÁMETRO: %s  (Grado %d)\n', nombres{i}, grado);
    fprintf('R² = %.4f | RMSE = %.6e | Error relativo medio = %.4f %%\n', R2, RMSE, error_relativo);
    fprintf('Polinomio: p(x) = ');
    for k = 1:grado+1
        if k > 1 && p(k) >= 0, fprintf('+ '); end
        fprintf('%.6e x^%d ', p(k), grado+1-k);
    end
    fprintf('\n\n');

    % ==================== GRÁFICA ====================
    figure('Position',[100 100 950 580]);
    plot(x_fit_data, y_fit_data, 'o', 'MarkerSize',9, 'LineWidth',1.8, 'DisplayName','Datos Experimentales');
    hold on;
    plot(x_fino, y_fino, 'r-', 'LineWidth',2.5, 'DisplayName',sprintf('Polyfit Grado %d', grado));

    title(['Polyfit Grado ' num2str(grado) ' - ' nombres{i}], 'FontSize',15);
    xlabel('Ciclo', 'FontSize',13);
    ylabel(nombres{i}, 'FontSize',13);
    grid on;
    legend('Location','best');

    % Guardar
    saveas(gcf, fullfile(outputFolder, ['Polyfit' num2str(grado) '_' var_name '.png']));
end

disp('Polyfit de alto grado completado.');
disp(['Gráficas guardadas en carpeta: ' outputFolder]);