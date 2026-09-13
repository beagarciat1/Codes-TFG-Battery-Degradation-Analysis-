function tabla_parametros = plot_fit_nyquist_bode100_keysight_lsq_weighted(rutaCarpeta)
% BATERÍA18_TODAS  Ajuste LM ponderado de diagramas de Nyquist para la
%   batería 18, combinando archivos del Bode100 (.xlsx) y del Keysight
%   E4990A (.csv) en una única función.
%
%   Uso:
%       tabla = BATERÍA18_TODAS()             % usa carpeta actual
%       tabla = BATERÍA18_TODAS(rutaCarpeta)  % usa carpeta indicada

    if nargin < 1 || isempty(rutaCarpeta)
        rutaCarpeta = pwd;
    end

    % ==================== CONFIGURACIÓN ====================
    f_corte       = 1e6;   % Corte de frecuencia: 1 MHz
    ciclos_excluir = [];   % Ciclos a excluir de gráficas (ej. [175])
    % =======================================================

    % --- Recopilar archivos de ambos tipos ---
    arch_xlsx = dir(fullfile(rutaCarpeta, 'CICLO*.xlsx'));
    arch_csv  = dir(fullfile(rutaCarpeta, 'CICLO*.csv'));

    % Excluir archivos de resultados que puedan coincidir con el patrón
    arch_xlsx = arch_xlsx(~contains({arch_xlsx.name}, {'Parametros','Errores','Resultados'}));

    archivos = struct('name', {}, 'folder', {}, 'tipo', {});
    for k = 1:length(arch_xlsx)
        archivos(end+1).name   = arch_xlsx(k).name;
        archivos(end).folder   = arch_xlsx(k).folder;
        archivos(end).tipo     = 'xlsx';
    end
    for k = 1:length(arch_csv)
        archivos(end+1).name   = arch_csv(k).name;
        archivos(end).folder   = arch_csv(k).folder;
        archivos(end).tipo     = 'csv';
    end

    if isempty(archivos)
        error('No se encontraron archivos CICLO*.xlsx ni CICLO*.csv en:\n  %s', rutaCarpeta);
    end

    % Ordenar por número de ciclo
    nums = zeros(1, length(archivos));
    for k = 1:length(archivos)
        tok = regexp(archivos(k).name, '\d+', 'match');
        if ~isempty(tok); nums(k) = str2double(tok{1}); end
    end
    [~, ord] = sort(nums);
    archivos = archivos(ord);

    ciclos_vistos = [];
    colores = lines(length(archivos));

    % --- Figura Nyquist ---
    figure('Name', 'Nyquist — BATERÍA18 TODAS', 'Color', 'w');
    hold on; grid on; axis equal;
    xlabel('Z_{real} (\Omega)');
    ylabel('-Z_{imaginaria} (\Omega)');
    title('Diagramas de Nyquist con ajuste — BATERÍA18 TODAS');

    % Acumuladores
    ciclos = []; R0_all = []; R1_all = []; C1_all = [];
    R2_all = []; C2_all = []; L0_all = [];
    resnorm_all = []; rmse_all = []; error_rel_all = [];
    nombres_archivo = {}; tipo_analizador = {}; leyenda = {};

    for k = 1:length(archivos)
        nombreArchivo = archivos(k).name;
        rutaCompleta  = fullfile(archivos(k).folder, nombreArchivo);
        tipo          = archivos(k).tipo;

        tok = regexp(nombreArchivo, '\d+', 'match');
        ciclo = NaN;
        if ~isempty(tok); ciclo = str2double(tok{1}); end

        % Omitir ciclos duplicados (un mismo ciclo en xlsx y csv)
        if ~isnan(ciclo)
            if ismember(ciclo, ciclos_vistos)
                fprintf('Omitido "%s": ciclo %d ya procesado.\n', nombreArchivo, ciclo);
                continue;
            end
            ciclos_vistos(end+1) = ciclo; %#ok<AGROW>
        end

        es_atipico = ismember(ciclo, ciclos_excluir);

        try
            % --- Lectura según analizador ---
            if strcmp(tipo, 'xlsx')
                % Bode100: exporta R y X con signo invertido respecto al
                % convenio estándar → se niegan para obtener Z física.
                data = readmatrix(rutaCompleta, 'Range', 'A2');
                f    = data(:,1);
                R    = -data(:,2);
                X    = -data(:,3);
            else
                % Keysight E4990A: convenio estándar directo.
                [f, R, X] = leer_csv_keysight(rutaCompleta);
            end

            % Filtrar por frecuencia y eliminar NaN
            idx_ok = f < f_corte & ~isnan(f) & ~isnan(R) & ~isnan(X);
            f = f(idx_ok); R = R(idx_ok); X = X(idx_ok);

            if numel(f) < 5
                error('No hay suficientes datos tras el filtrado (< 5 puntos).');
            end

            w     = 2*pi*f;
            Z_exp = R + 1i*X;
            mod_Z = abs(Z_exp) + eps;

            % Modelo: R0 + jωL0 + R1/(1+jωR1C1) + R2/(1+jωR2C2)
            z_model = @(x,w) x(1) + x(6)*1i.*w + ...
                              x(2)./(1 + 1i.*w.*x(2).*x(3)) + ...
                              x(4)./(1 + 1i.*w.*x(4).*x(5));

            % Función objetivo ponderada (residuos normalizados por |Z|²)
            fit_func = @(x,w) [ (real(z_model(x,w)) - real(Z_exp)) ./ (mod_Z.^2); ...
                                 (imag(z_model(x,w)) - imag(Z_exp)) ./ (mod_Z.^2) ];
            y_data = zeros(2*numel(Z_exp), 1);

            % Estimación inicial de parámetros
            [~, idx_R0] = min(abs(X));
            R0_est = R(idx_R0);
            deltaR = max(R) - R0_est;
            if deltaR <= 0; deltaR = max(R) - min(R); end
            if deltaR <= 0; deltaR = 1e-3; end

            x0 = [R0_est*0.3,  deltaR*0.001, 0.01, max(mean(R)-deltaR*0.001, 1e-6), 0.01, 1e-9];
            lb = [R0_est,       deltaR*0.01,  1e-5, deltaR*0.01,1e-5, 1e-9];
            ub = [R0_est,       deltaR,        1,    deltaR,1,    1e-1];

            options = optimoptions('lsqcurvefit', ...
                'Algorithm',         'levenberg-marquardt', ...
                'Display',           'off', ...
                'FunctionTolerance', 1e-15, ...
                'StepTolerance',     1e-15);

            [x_opt, resnorm, ~] = lsqcurvefit(fit_func, x0, w, y_data, lb, ub, options);

            R0 = x_opt(1); R1 = x_opt(2); C1 = x_opt(3);
            R2 = x_opt(4); C2 = x_opt(5); L0 = x_opt(6);

            % Error real (sin ponderación)
            Z_fit_final    = z_model(x_opt, w);
            rmse           = sqrt(mean(abs(Z_fit_final - Z_exp).^2));
            error_relativo = mean(abs(Z_fit_final - Z_exp) ./ (abs(Z_exp) + eps)) * 100;

            % Acumular resultados
            ciclos(end+1,1)          = ciclo;
            R0_all(end+1,1)          = R0;
            R1_all(end+1,1)          = R1;
            C1_all(end+1,1)          = C1;
            R2_all(end+1,1)          = R2;
            C2_all(end+1,1)          = C2;
            L0_all(end+1,1)          = L0;
            resnorm_all(end+1,1)     = resnorm;
            rmse_all(end+1,1)        = rmse;
            error_rel_all(end+1,1)   = error_relativo;
            nombres_archivo{end+1,1} = nombreArchivo;
            tipo_analizador{end+1,1} = upper(tipo);

            % Dibujar en figura Nyquist
            if ~es_atipico
                h = plot(R, -X, 'o-', 'LineWidth', 1.2, 'MarkerSize', 4, ...
                    'Color', colores(k,:), 'MarkerFaceColor', colores(k,:));
                h.DataTipTemplate.DataTipRows(end+1) = ...
                    dataTipTextRow('Archivo', repmat({nombreArchivo}, length(R), 1));
                Z_fit = z_model(x_opt, w);
                n = plot(real(Z_fit), -imag(Z_fit), '-', 'LineWidth', 2, 'Color', colores(k,:));
                n.DataTipTemplate.DataTipRows(end+1) = ...
                    dataTipTextRow('Archivo', repmat({nombreArchivo}, length(R), 1));
                leyenda{end+1} = sprintf('C%d exp [%s]', ciclo, upper(tipo)); %#ok<AGROW>
                leyenda{end+1} = sprintf('C%d fit',  ciclo);                  %#ok<AGROW>
            end

            fprintf('\n--- %s [%s] ---\n', nombreArchivo, upper(tipo));
            fprintf('R0=%.6f  R1=%.6f  C1=%.4e  R2=%.6f  C2=%.4e  L0=%.4e\n', R0,R1,C1,R2,C2,L0);
            fprintf('RMSE=%.4e  Error relativo=%.2f%%\n', rmse, error_relativo);

        catch ME
            fprintf('Error en "%s": %s\n', nombreArchivo, ME.message);
        end
    end

    if ~isempty(leyenda); legend(leyenda, 'Location', 'best'); end
    hold off;

    % --- Tabla de resultados ---
    tabla_parametros = table(ciclos, R0_all, R1_all, C1_all, R2_all, C2_all, L0_all, ...
        resnorm_all, rmse_all, error_rel_all, nombres_archivo, tipo_analizador, ...
        'VariableNames', {'Ciclo','R0','R1','C1','R2','C2','L0', ...
                          'Resnorm','RMSE','ErrorRelativoMedio','Archivo','Analizador'});
    tabla_parametros = sortrows(tabla_parametros, 'Ciclo');
    disp(tabla_parametros);

    % --- Guardar Excel ---
    tabla_excel = table( ...
        tabla_parametros.Ciclo, tabla_parametros.L0, tabla_parametros.R0, ...
        tabla_parametros.R1,    tabla_parametros.C1, tabla_parametros.R2, ...
        tabla_parametros.C2,    tabla_parametros.Analizador, ...
        'VariableNames', {'Ciclo','L0_H','R0_Ohm','R1_Ohm','C1_F','R2_Ohm','C2_F','Analizador'});

    nombreExcel = fullfile(pwd, 'Parametros_Nyquist_BATERIA18_TODAS.xlsx');
    writetable(tabla_excel, nombreExcel);
    fprintf('\nExcel guardado en: %s\n', nombreExcel);

    % --- Estadísticas globales ---
    fprintf('\n=== ESTADÍSTICAS PROMEDIO (todos los ciclos) ===\n');
    fprintf('Media RMSE           = %.4e\n', mean(tabla_parametros.RMSE));
    fprintf('Media Error Relativo = %.2f %%\n', mean(tabla_parametros.ErrorRelativoMedio));

    % --- Gráficas de evolución de parámetros ---
    hacer_grafica(tabla_parametros.Ciclo, tabla_parametros.R0,                   'R0',      'R0 (\Omega)',      ciclos_excluir);
    hacer_grafica(tabla_parametros.Ciclo, tabla_parametros.R1,                   'R1',      'R1 (\Omega)',      ciclos_excluir);
    hacer_grafica(tabla_parametros.Ciclo, tabla_parametros.C1,                   'C1',      'C1 (F)',           ciclos_excluir);
    hacer_grafica(tabla_parametros.Ciclo, tabla_parametros.R2,                   'R2',      'R2 (\Omega)',      ciclos_excluir);
    hacer_grafica(tabla_parametros.Ciclo, tabla_parametros.C2,                   'C2',      'C2 (F)',           ciclos_excluir);
    hacer_grafica(tabla_parametros.Ciclo, tabla_parametros.L0,                   'L0',      'L0 (H)',           ciclos_excluir);
    hacer_grafica(tabla_parametros.Ciclo, tabla_parametros.R0+tabla_parametros.R1+tabla_parametros.R2, ...
                                                                                  'R total', 'R0+R1+R2 (\Omega)',ciclos_excluir);
end

% =========================================================================
function hacer_grafica(ciclos, valores, nombre, etiquetaY, ciclos_excluir)
    idx = ~isnan(ciclos) & ~isnan(valores) & ~ismember(ciclos, ciclos_excluir);
    figure('Name', ['Evolución de ', nombre, ' — BATERÍA18 TODAS'], 'Color', 'w');
    plot(ciclos(idx), valores(idx), 's-', 'LineWidth', 1.5, 'MarkerSize', 6, 'Color', [1, 0.85, 0], 'MarkerFaceColor', [1, 0.85, 0]);
    grid on;
    xlabel('Ciclo');
    ylabel(etiquetaY);
    title(['Evolución de ', nombre, ' por ciclo — BATERÍA18 TODAS']);
end

% =========================================================================
function [f, R, X] = leer_csv_keysight(rutaCompleta)
% Lee un CSV del Keysight E4990A. Soporta formato R-X y |Z|-ángulo.
% Maneja el ruido de punto y coma y la mezcla de coma/punto decimal.

    lineas = readlines(rutaCompleta);
    lineas = lineas(strlength(lineas) > 0);

    idx_begin = find(contains(lineas, 'BEGIN'), 1);
    idx_end   = find(contains(lineas, 'END'),   1);
    if isempty(idx_begin) || isempty(idx_end) || idx_end <= idx_begin + 2
        error('Formato no reconocido: falta bloque BEGIN/END en %s', rutaCompleta);
    end

    linea_cab = erase(lineas(idx_begin + 1), ';');
    es_polar  = contains(linea_cab, '|Z|') || contains(lower(linea_cab), 'theta');

    lineas_datos = lineas(idx_begin+2 : idx_end-1);
    n = numel(lineas_datos);
    f  = nan(n,1); c2 = nan(n,1); c3 = nan(n,1);

    patron = '[+-]?\d+[.,]\d+[eE][+-]?\d+';
    for i = 1:n
        tok = regexp(lineas_datos(i), patron, 'match');
        if numel(tok) < 3; continue; end
        vals = str2double(strrep(tok(1:3), ',', '.'));
        f(i) = vals(1); c2(i) = vals(2); c3(i) = vals(3);
    end

    idx = ~isnan(f) & ~isnan(c2) & ~isnan(c3);
    f = f(idx); c2 = c2(idx); c3 = c3(idx);

    if es_polar
        theta_rad = deg2rad(c3);
        R = c2 .* cos(theta_rad);
        X = c2 .* sin(theta_rad);
    else
        R = c2; X = c3;
    end
end
