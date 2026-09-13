% =========================================================
% lanzar_comparacion.m
%
% Compara el modelo de degradación con los datos experimentales
% con los parámetros que tú impongas. Úsalo para ajustar a mano.
%
% Los datos experimentales se leen del Excel guardado por
% analysis_capacity_total_b1 (MEDIA_EXP_BATERIA1_25.xlsx), que
% contiene la curva "Media (carga+descarga)/2" ya procesada.
% Si el archivo no existe aún, se genera automáticamente.
% =========================================================

% Forzar recarga de funciones y datos (evita caché de MATLAB)
clear functions
clear variables

% ---- Parámetros a probar ----
alpha         = 158147.09;
beta          =  84947.02;
eta           =   7748.43;
z             =     0.5630;

% ---- Número de ciclos a simular ----
number_cycles = 550;   % ponlo menor al principio para ir rápido


% ==========================================================
% NO TOCAR LO DE ABAJO
% ==========================================================

% ---- Datos experimentales ----
% Se lee directamente del Excel generado por analysis_capacity_total_b1
% para usar EXACTAMENTE la misma curva "Media (carga+descarga)/2"
% que dibuja esa función, sin depender del path de MATLAB.

ruta_media = 'C:\your_route\your_file.xlsx';

if ~isfile(ruta_media)
    fprintf('[INFO] Excel no encontrado. Ejecutando analysis_capacity_total_b1...\n');
    % Forzar la versión correcta (Batería 1)
    addpath('C:\your_route\your_folder', '-begin');
    analysis_capacity_total_b1();
end

T          = readtable(ruta_media, 'Sheet', 'Media');
Cn         = 130;                        % capacidad inicial (ciclo 0) en mAh
Q_exp_full = [Cn; T.Media_mAh];

fprintf('[INFO] Datos experimentales: %d ciclos cargados desde Excel\n', ...
        length(Q_exp_full) - 1);

number_cycles = min(number_cycles, length(Q_exp_full) - 1);
Q_exp = Q_exp_full(1:number_cycles+1);

% ---- Predicción del modelo ----
Q_pred = Q_loss_model(alpha, beta, eta, z, number_cycles, 'CC', 'CC');

Ciclos = 0:number_cycles;

% ---- Métricas de error ----
n   = number_cycles + 1;
res = Q_pred(:) - Q_exp(:);

SSE  = sum(res.^2);
RMSE = sqrt(SSE / n);
MAE  = mean(abs(res));
MAPE = mean(abs(res ./ Q_exp(:))) * 100;
SS_tot = sum((Q_exp(:) - mean(Q_exp(:))).^2);
R2   = 1 - SSE / SS_tot;

fprintf('\n============================================\n');
fprintf('  MÉTRICAS DE ERROR  (alpha=%.0f, beta=%.0f, eta=%.0f, z=%.4f)\n', alpha, beta, eta, z);
fprintf('--------------------------------------------\n');
fprintf('  SSE  (suma cuad. errores)   = %.4f  mAh²\n', SSE);
fprintf('  RMSE (raíz error cuad. med) = %.4f  mAh\n',  RMSE);
fprintf('  MAE  (error absoluto medio) = %.4f  mAh\n',  MAE);
fprintf('  MAPE (error relativo medio) = %.4f  %%\n',   MAPE);
fprintf('  R²   (bondad de ajuste)     = %.6f\n',       R2);
fprintf('============================================\n\n');

% ---- Gráfica ----
figure;
hold on;
plot(Ciclos, Q_pred, '-',  'Color', 'b', 'LineWidth', 1.5, ...
     'DisplayName', 'Modelo');
plot(Ciclos, Q_exp,  '-o', 'Color', [0.47 0.67 0.19], 'MarkerSize', 3, ...
     'LineWidth', 1.5, 'DisplayName', 'Experimental (media)');
xlabel('Número de ciclos');
ylabel('Capacidad (mAh)');
title(sprintf('Modelo vs Experimental  |  RMSE=%.3f mAh  |  R²=%.4f', RMSE, R2));
legend('Location', 'best');
grid on;
hold off;
