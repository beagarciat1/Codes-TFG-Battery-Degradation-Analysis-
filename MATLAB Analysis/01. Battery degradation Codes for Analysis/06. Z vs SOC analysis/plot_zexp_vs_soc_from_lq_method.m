function plot_zexp_vs_soc_from_lq_method(rutaBase)
% plot_zexp_vs_soc_from_lq_method  Ajusta el modelo EIS en cada archivo SoC de las
%   carpetas CARGAS 1/2/3 y DESCARGAS 1/2/3 y dibuja cada parámetro vs SoC.
%
%   rutaBase : carpeta que contiene las subcarpetas 'CARGAS 1', 'CARGAS 2',
%              'CARGAS 3', 'DESCARGAS 1', 'DESCARGAS 2', 'DESCARGAS 3'.
%              Si se omite, se usa el directorio actual.

    if nargin < 1 || isempty(rutaBase)
        rutaBase = pwd;
    end

    nombres_c = {'CARGAS 1',    'CARGAS 2',    'CARGAS 3'};
    nombres_d = {'DESCARGAS 1', 'DESCARGAS 2', 'DESCARGAS 3'};

    fprintf('=== Procesando Cargas ===\n');
    resultados_c = cell(3,1);
    for i = 1:3
        fprintf('\n-- %s --\n', nombres_c{i});
        resultados_c{i} = ajustar_carpeta(fullfile(rutaBase, nombres_c{i}), false);
    end

    fprintf('\n=== Procesando Descargas ===\n');
    resultados_d = cell(3,1);
    for i = 1:3
        fprintf('\n-- %s --\n', nombres_d{i});
        resultados_d{i} = ajustar_carpeta(fullfile(rutaBase, nombres_d{i}), true);
    end

    % ---- Parámetros a representar ----
    campos   = {'R0',  'L0',  'R1',  'C1',  'R2',  'C2'};
    etiq_y   = {'R0 (m\Omega)', 'L0 (nH)', 'R1 (m\Omega)', 'C1 (mF)', 'R2 (m\Omega)', 'C2 (mF)'};
    factores = [1e3,   1e9,   1e3,   1e3,   1e3,   1e3];

    % Colores MATLAB por defecto (azul, naranja, amarillo)
    col = [0.0000 0.4470 0.7410;
           0.8500 0.3250 0.0980;
           0.9290 0.6940 0.1250];

    % Almacenamiento de líneas medias para exportar a Excel
    medias_c = cell(numel(campos), 1);
    medias_d = cell(numel(campos), 1);

    for p = 1:numel(campos)
        figure('Name', campos{p}, 'Color', 'w', 'Position', [100 100 1100 420]);

        % --- Cargas ---
        ax1 = subplot(1,2,1);
        hold(ax1,'on'); grid(ax1,'on');
        soc_c_all = {}; val_c_all = {};
        for i = 1:3
            r = resultados_c{i};
            if isempty(r), continue; end
            vals = r.(campos{p}) * factores(p);
            plot(ax1, r.soc, vals, 'o-', ...
                'Color', col(i,:), 'MarkerFaceColor', col(i,:), ...
                'LineWidth', 1.5, 'MarkerSize', 5, ...
                'DisplayName', sprintf('Carga %d', i));
            % Para la media de Carga 1, excluir puntos entre 0.6 y 0.8
            if i == 1
                mask = ~(r.soc > 0.6 & r.soc < 0.8);
                soc_c_all{end+1} = r.soc(mask);
                val_c_all{end+1} = vals(mask);
            else
                soc_c_all{end+1} = r.soc;
                val_c_all{end+1} = vals;
            end
        end
        if numel(soc_c_all) == 3
            [sm, vm] = calcular_media(soc_c_all{1}, val_c_all{1}, soc_c_all{2}, val_c_all{2}, soc_c_all{3}, val_c_all{3});
            plot(ax1, sm, vm, '-', 'Color', [0.2 0.6 0.2], 'LineWidth', 3.375, 'DisplayName', 'Media');
            medias_c{p} = struct('soc', sm, 'val', vm);
        end
        set(ax1, 'XTick', 0:0.2:1, 'FontSize', 12);
        xlabel(ax1, 'SoC', 'FontSize', 12);
        ylabel(ax1, etiq_y{p}, 'FontSize', 12);
        title(ax1, [campos{p}, ' vs SoC (Cargas)'], 'FontSize', 13);
        legend(ax1, 'Location', 'northoutside', 'FontSize', 10, 'Orientation', 'horizontal');

        % --- Descargas ---
        ax2 = subplot(1,2,2);
        hold(ax2,'on'); grid(ax2,'on');
        soc_d_all = {}; val_d_all = {};
        for i = 1:3
            r = resultados_d{i};
            if isempty(r), continue; end
            vals = r.(campos{p}) * factores(p);
            plot(ax2, r.soc, vals, 'o-', ...
                'Color', col(i,:), 'MarkerFaceColor', col(i,:), ...
                'LineWidth', 1.5, 'MarkerSize', 5, ...
                'DisplayName', sprintf('Descarga %d', i));
            soc_d_all{end+1} = r.soc;
            val_d_all{end+1} = vals;
        end
        if numel(soc_d_all) == 3
            [sm, vm] = calcular_media(soc_d_all{1}, val_d_all{1}, soc_d_all{2}, val_d_all{2}, soc_d_all{3}, val_d_all{3});
            plot(ax2, sm, vm, '-', 'Color', [0.2 0.6 0.2], 'LineWidth', 3.375, 'DisplayName', 'Media');
            medias_d{p} = struct('soc', sm, 'val', vm);
        end
        set(ax2, 'XTick', 0:0.2:1, 'FontSize', 12);
        xlabel(ax2, 'SoC', 'FontSize', 12);
        ylabel(ax2, etiq_y{p}, 'FontSize', 12);
        title(ax2, [campos{p}, ' vs SoC (Descargas)'], 'FontSize', 13);
        legend(ax2, 'Location', 'northoutside', 'FontSize', 10, 'Orientation', 'horizontal');

        carpeta_out = fullfile(pwd, 'Figuras_SoC');
        if ~exist(carpeta_out, 'dir'), mkdir(carpeta_out); end
        exportgraphics(gcf, fullfile(carpeta_out, ['DIBUJAR_', campos{p}, '.png']), 'Resolution', 150);
    end

    % ---- Exportar líneas medias a Excel en intervalos de SoC = 0.05 ----
    soc_out  = (0.05:0.05:1.00)';
    n_soc    = numel(soc_out);
    hdrs_unidades = {'R0_mOhm', 'L0_nH', 'R1_mOhm', 'C1_mF', 'R2_mOhm', 'C2_mF'};
    hdrs     = [{'SoC'}, hdrs_unidades];

    data_c = nan(n_soc, numel(campos));
    data_d = nan(n_soc, numel(campos));
    for p = 1:numel(campos)
        if ~isempty(medias_c{p})
            data_c(:,p) = interp1(medias_c{p}.soc, medias_c{p}.val, soc_out, 'pchip', NaN);
        end
        if ~isempty(medias_d{p})
            data_d(:,p) = interp1(medias_d{p}.soc, medias_d{p}.val, soc_out, 'pchip', NaN);
        end
    end

    T_c = array2table([soc_out, data_c], 'VariableNames', hdrs);
    T_d = array2table([soc_out, data_d], 'VariableNames', hdrs);

    ruta_excel = fullfile(fileparts(mfilename('fullpath')), 'Z_soc MÉTODO 2.xlsx');
    writetable(T_c, ruta_excel, 'Sheet', 'Cargas');
    writetable(T_d, ruta_excel, 'Sheet', 'Descargas');
    fprintf('\nExcel guardado en: %s\n', ruta_excel);
end

% =========================================================================
function [soc_mean, val_mean] = calcular_media(s1,v1,s2,v2,s3,v3)
    soc_grid = linspace(min([s1;s2;s3]), max([s1;s2;s3]), 200)';
    v1i = interp1(s1, v1, soc_grid, 'pchip', 'extrap');
    v2i = interp1(s2, v2, soc_grid, 'pchip', 'extrap');
    v3i = interp1(s3, v3, soc_grid, 'pchip', 'extrap');
    val_mean = mean([v1i v2i v3i], 2);
    soc_mean = soc_grid;
end

% =========================================================================
function r = ajustar_carpeta(ruta, es_descarga)
% Procesa todos los .xlsx de una carpeta, ajusta el modelo y devuelve
% una estructura con los parámetros ordenados por SoC.

    r = [];
    archivos = dir(fullfile(ruta, '*.xlsx'));

    if isempty(archivos)
        fprintf('  Sin archivos .xlsx en: %s\n', ruta);
        return;
    end

    % Descartar archivos con "(2)", "(3)"... que son medidas repetidas
    nombres = {archivos.name};
    mask = ~cellfun(@(n) ~isempty(regexp(n, '\(\d+\)', 'once')), nombres);
    archivos = archivos(mask);

    n = numel(archivos);
    soc_v  = nan(n,1);
    R0_v   = nan(n,1);
    R1_v   = nan(n,1);
    C1_v   = nan(n,1);
    R2_v   = nan(n,1);
    C2_v   = nan(n,1);
    L0_v   = nan(n,1);

    % Primera pasada: extraer todos los valores numéricos para normalizar
    vals_raw = nan(n,1);
    for k = 1:n
        tok = regexp(archivos(k).name, '(\d+)', 'tokens', 'once');
        if ~isempty(tok)
            vals_raw(k) = str2double(tok{1});
        end
    end
    max_val = max(vals_raw(~isnan(vals_raw)));
    if isempty(max_val) || max_val == 0
        fprintf('  No se pudo determinar el máximo SoC en: %s\n', ruta);
        return;
    end
    fprintf('  Máximo encontrado: %.0f → SoC normalizado por %.0f\n', max_val, max_val);

    for k = 1:n
        nombre       = archivos(k).name;
        ruta_archivo = fullfile(ruta, nombre);

        % Extraer valor y normalizar por el máximo de la carpeta
        tok = regexp(nombre, '(\d+)', 'tokens', 'once');
        if isempty(tok)
            fprintf('  No se pudo extraer SoC de: %s — omitido\n', nombre);
            continue;
        end
        val_raw = str2double(tok{1});

        if es_descarga
            % En descargas el número indica mAh extraídos: a más extraído, menor SoC
            soc_val = (max_val - val_raw) / max_val;
        else
            % En cargas el número indica mAh insertados: SoC = val / max
            % Excluir el punto SoC = 0 (batería vacía al inicio de la carga)
            if val_raw == 0
                continue;
            end
            soc_val = val_raw / max_val;
        end

        try
            % Leer como celda para manejar separador decimal coma (formato europeo)
            raw = readcell(ruta_archivo, 'Range', 'A2');
            data = celda_a_numeros(raw);

            if size(data,2) < 3
                error('Menos de 3 columnas en el archivo.');
            end

            f_raw = data(:,1);
            R_raw = data(:,2);
            X_raw = data(:,3);

            % Filtrar frecuencias válidas y por debajo de 1 MHz
            f_corte  = 1e6;
            idx_ok   = f_raw < f_corte & ~isnan(f_raw) & ~isnan(R_raw) & ~isnan(X_raw) & f_raw > 0;
            f = f_raw(idx_ok);
            R = -R_raw(idx_ok);   % convención: Zreal positivo
            X = -X_raw(idx_ok);   % convención

            if numel(f) < 5
                error('Datos insuficientes tras filtrado (%d puntos).', numel(f));
            end

            w     = 2*pi*f;
            Z_exp = R + 1i*X;
            mod_Z = abs(Z_exp) + eps;

            % Modelo: Z = R0 + jωL0 + R1/(1+jωR1C1) + R2/(1+jωR2C2)
            % x = [R0, R1, C1, R2, C2, L0]
            z_model  = @(x,w) x(1) + 1i*w*x(6) + ...
                               x(2)./(1 + 1i*w*x(2)*x(3)) + ...
                               x(4)./(1 + 1i*w*x(4)*x(5));

            % Ajuste ponderado: residuos divididos por |Z|² (igual que _ponderado)
            fit_func = @(x,w) [ ...
                (real(z_model(x,w)) - real(Z_exp)) ./ (mod_Z.^2); ...
                (imag(z_model(x,w)) - imag(Z_exp)) ./ (mod_Z.^2) ];
            y_data = zeros(2*numel(Z_exp), 1);

            [~, idx_R0] = min(abs(X));
            R0_est = R(idx_R0);
            deltaR = max(R) - R0_est;
            if deltaR <= 0, deltaR = max(R) - min(R); end
            if deltaR <= 0, deltaR = 1e-3; end

            x0 = [R0_est*0.3, deltaR*0.001, 0.01, max(mean(R)-deltaR*0.001, 1e-6), 0.01, 1e-9];
            lb = [R0_est,     deltaR*0.01,  1e-5, deltaR*0.01,                     1e-5, 1e-9];
            ub = [R0_est,     deltaR,       1,    deltaR,                           1,    1e-1];

            opts = optimoptions('lsqcurvefit', ...
                'Algorithm',         'levenberg-marquardt', ...
                'Display',           'off', ...
                'FunctionTolerance', 1e-15, ...
                'StepTolerance',     1e-15);

            x_opt = lsqcurvefit(fit_func, x0, w, y_data, lb, ub, opts);

            soc_v(k) = soc_val;
            R0_v(k)  = x_opt(1);
            R1_v(k)  = x_opt(2);
            C1_v(k)  = x_opt(3);
            R2_v(k)  = x_opt(4);
            C2_v(k)  = x_opt(5);
            L0_v(k)  = x_opt(6);

            fprintf('  %-25s SoC=%3.0f%%  R0=%6.2f mΩ  R1=%6.2f mΩ  R2=%6.2f mΩ\n', ...
                nombre, soc_val*100, x_opt(1)*1e3, x_opt(2)*1e3, x_opt(4)*1e3);

        catch ME
            fprintf('  Error en %s: %s\n', nombre, ME.message);
        end
    end

    % Ordenar por SoC y eliminar NaN
    idx_ok = ~isnan(soc_v);
    [soc_sorted, ord] = sort(soc_v(idx_ok));

    r.soc = soc_sorted;
    r.R0  = R0_v(idx_ok); r.R0 = r.R0(ord);
    r.R1  = R1_v(idx_ok); r.R1 = r.R1(ord);
    r.C1  = C1_v(idx_ok); r.C1 = r.C1(ord);
    r.R2  = R2_v(idx_ok); r.R2 = r.R2(ord);
    r.C2  = C2_v(idx_ok); r.C2 = r.C2(ord);
    r.L0  = L0_v(idx_ok); r.L0 = r.L0(ord);
end

% =========================================================================
function mat = celda_a_numeros(raw)
% Convierte un cell array a matriz numérica, manejando coma decimal europea.
    [nf, nc] = size(raw);
    mat = nan(nf, nc);
    for r = 1:nf
        for c = 1:nc
            v = raw{r,c};
            if isnumeric(v)
                mat(r,c) = v;
            elseif ischar(v) || isstring(v)
                mat(r,c) = str2double(strrep(char(v), ',', '.'));
            end
        end
    end
end
