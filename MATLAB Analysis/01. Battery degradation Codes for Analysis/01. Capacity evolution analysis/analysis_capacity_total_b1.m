function Q_loss_real = analysis_capacity_total_b1()
% =========================================================
% analysis_capacity_total_b1.m
%
% Lee TOTALES_CARGAS.xlsx (Hoja1 = cargas, Hoja2 = descargas,
% col B = índice de ciclo, col C = capacidad en mAh).
%
% Outliers fuera de [lim_min, lim_max] se interpolan linealmente
% entre los vecinos válidos más próximos (no se excluyen).
%
% Calcula la media (carga + descarga) / 2 por ciclo en el rango
% común y guarda MEDIA_EXP_BATERIA1_25.xlsx en ANÁLISIS RESULTADOS.
%
% SALIDA:
%   Q_loss_real  Vector columna de longitud N+1 en mAh:
%                [Cn; media_ciclo1; ...; media_cicloN]
%                donde Cn es la capacidad inicial (ciclo 0, carga CC).
%
% Uso en nuevo_objective_function.m:
%   [Q_loss_real] = analysis_capacity_total_b1();
%   Q_loss_real   = Q_loss_real(1:number_cycles+1);  % recortar al nº de ciclos
% =========================================================

% ---- Rutas ----
archivo     = 'C:\your_route\your_file.xlsx';
ruta_salida = 'C:\your_route\your_file.xlsx';

% Capacidad nominal con carga CC (antes del primer ciclo de envejecimiento).
% Con carga CC pura la batería llega a ~130 mAh en lugar de ~180 mAh
% porque el voltaje medido incluye la caída en la resistencia interna.
Cn = 130; % mAh  <-- ajustar si es necesario

% ---- Límites para identificar outliers (mismos que en el gráfico) ----
lim_min = 107;
lim_max = 130;

% ====================================================================
% 1. Lectura de datos
%    Fila 1 = encabezado en ambas hojas -> empezamos en fila 2
% ====================================================================
raw_c = readmatrix(archivo, 'Sheet', 'Hoja1', 'Range', 'B2:C560', 'UseExcel', false);
raw_d = readmatrix(archivo, 'Sheet', 'Hoja2', 'Range', 'B2:C560', 'UseExcel', false);

% Eliminar filas con NaN (celdas vacías al final del rango)
raw_c = raw_c(~any(isnan(raw_c), 2), :);
raw_d = raw_d(~any(isnan(raw_d), 2), :);

fprintf('[DEBUG] Leyendo archivo: %s\n', archivo);
fprintf('[DEBUG] Ciclos leídos: cargas=%d, descargas=%d\n', size(raw_c,1), size(raw_d,1));
fprintf('[DEBUG] Últimos 3 valores descarga: %.2f | %.2f | %.2f\n', raw_d(end-2,2), raw_d(end-1,2), raw_d(end,2));

x_c = raw_c(:, 1);   % índice de ciclo (cargas)
y_c = raw_c(:, 2);   % capacidad de carga [mAh]
x_d = raw_d(:, 1);   % índice de ciclo (descargas)
y_d = raw_d(:, 2);   % capacidad de descarga [mAh]

% ====================================================================
% 2. Interpolación de outliers
%    Los puntos fuera de [lim_min, lim_max] (p.ej. ceros o picos
%    espurios) se sustituyen por interpolación lineal entre los
%    vecinos válidos más cercanos.
% ====================================================================
valid_c = (y_c >= lim_min) & (y_c <= lim_max);
valid_d = (y_d >= lim_min) & (y_d <= lim_max);

y_c_interp = y_c;
y_d_interp = y_d;

if any(~valid_c) && sum(valid_c) > 1
    y_c_interp(~valid_c) = interp1(x_c(valid_c), y_c(valid_c), ...
        x_c(~valid_c), 'linear', 'extrap');
end
if any(~valid_d) && sum(valid_d) > 1
    y_d_interp(~valid_d) = interp1(x_d(valid_d), y_d(valid_d), ...
        x_d(~valid_d), 'linear', 'extrap');
end

% ====================================================================
% 3. Alineación por ciclo común y cálculo de la media
% ====================================================================
ciclos_comunes = intersect(x_c, x_d);
N = length(ciclos_comunes);

y_c_alineado = zeros(N, 1);
y_d_alineado = zeros(N, 1);

for i = 1:N
    y_c_alineado(i) = y_c_interp(x_c == ciclos_comunes(i));
    y_d_alineado(i) = y_d_interp(x_d == ciclos_comunes(i));
end

media = (y_c_alineado + y_d_alineado) / 2;

% ====================================================================
% 4. Guardar Excel en ANÁLISIS RESULTADOS
% ====================================================================
T = table(ciclos_comunes, y_c_alineado, y_d_alineado, media, ...
    'VariableNames', {'Ciclo', 'Carga_mAh', 'Descarga_mAh', 'Media_mAh'});
writetable(T, ruta_salida, 'Sheet', 'Media');
fprintf('Excel guardado: %s\n', ruta_salida);

% ====================================================================
% 5. Gráficas
% ====================================================================
figure;
plot(x_c, y_c_interp, '-o', 'Color', [0.12 0.47 0.71], 'MarkerSize', 3);
xlabel('N.º de ciclo acumulado');
ylabel('Capacidad (mAh)');
title('Variacion de capacidad — Cargas');
grid on;

figure;
plot(x_d, y_d_interp, '-o', 'Color', [0.84 0.35 0.07], 'MarkerSize', 3);
xlabel('N.º de ciclo acumulado');
ylabel('Capacidad (mAh)');
title('Variacion de capacidad — Descargas');
grid on;

figure;
plot(ciclos_comunes, media, '-o', 'Color', [0.47 0.67 0.19], 'MarkerSize', 3, 'LineWidth', 1.5);
xlabel('N.º de ciclo acumulado');
ylabel('Capacidad (mAh)');
title('Variacion de capacidad — Media (carga + descarga) / 2');
grid on;

eficiencia_coulombica = y_d_alineado ./ y_c_alineado * 100;  % en %

figure;
plot(ciclos_comunes, eficiencia_coulombica, '-o', 'Color', [0.49 0.18 0.56], 'MarkerSize', 3, 'LineWidth', 1.5);
xlabel('N.º de ciclo acumulado');
ylabel('Eficiencia culómbica (%)');
title('Eficiencia culómbica por ciclo (Q_{descarga} / Q_{carga})');
grid on;

% ====================================================================
% 6. Vector de retorno
%    [Cn; media_ciclo1; media_ciclo2; ...; media_cicloN]
%    Cn ocupa el lugar del ciclo 0 (antes del envejecimiento).
% ====================================================================
Q_loss_real = [Cn; media];

end
