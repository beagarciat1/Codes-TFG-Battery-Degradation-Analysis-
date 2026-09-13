function [tabla_espectro, tabla_evolucion] = plot_Z_evolution(rutaCarpeta, frecuencias_fijas, ciclos_excluir)
% EVOLUCION_IMPEDANCIA_CICLOS_BATERIA18  Igual que evolucion_impedancia_ciclos.m
%   (batería 1) pero para la batería 18 (batería 2), usando el mismo
%   ajuste LM ponderado que BATERIA18_dibujo_fit_nyquist_conjunto_seleccion_ponderado.m.
%
%   ÚNICA DIFERENCIA REAL respecto a la versión de la batería 1: en esta
%   batería el número que aparece en el nombre del archivo (CICLOn...) ya
%   es el ciclo real de la medida (p.ej. CICLO267 -> ciclo 267), NO hay
%   que multiplicarlo por 25.
%
%   Datos crudos esperados en:
%     Beatriz\BATERÍA 18. JUNIO 2026 100 CICLOS
%
%   FIGURA (a) - Diagrama de Bode en módulo: |Z| frente a la frecuencia,
%                una curva experimental por ciclo.
%
%   FIGURA (b) - Evolución de |Z| frente al número de ciclo en 4
%                frecuencias representativas, modelo (LM ponderado) vs
%                experimental:
%                  · 1 kHz    -> resistencia óhmica (AC-IR), ~R0
%                  · 100 Hz   -> primer semicírculo (SEI)
%                  · 10 Hz    -> segundo semicírculo (transferencia de carga/difusión)
%                  · f mínima del barrido -> extremo derecho del Nyquist
%
%   USO:
%     plot_Z_evolution()
%     plot_Z_evolution(rutaCarpeta)
%     plot_Z_evolution(rutaCarpeta, [1000 100 10])
%     plot_Z_evolution(rutaCarpeta, [1000 100 10], [267])
%
%   ENTRADAS (opcionales):
%     rutaCarpeta       : carpeta con los CICLO*.xlsx crudos (default: pwd)
%     frecuencias_fijas : frecuencias fijas en Hz a seguir en la figura
%                          (b), sin contar la mínima del barrido
%                          (default: [1000 100 10])
%     ciclos_excluir    : vector con números de ciclo reales (p.ej. [267])
%                          que se omiten de ambas figuras y de las tablas
%                          (default: [], no se excluye ninguno)
%
%   SALIDAS:
%     tabla_espectro  : Ciclo, Frecuencia_Hz, |Z| experimental (figura a)
%     tabla_evolucion : Ciclo, f_min y |Z| modelo/experimental en f_min y
%                        en cada frecuencia fija (figura b)

    if nargin < 1 || isempty(rutaCarpeta)
        rutaCarpeta = pwd;
    end
    if nargin < 2 || isempty(frecuencias_fijas)
        frecuencias_fijas = [1000, 100, 10];
    end
    if nargin < 3 || isempty(ciclos_excluir)
        ciclos_excluir = [];
    end

    %% ==================== 1. LOCALIZAR Y ORDENAR ARCHIVOS ====================
    archivos = dir(fullfile(rutaCarpeta, 'CICLO*.xlsx'));
    % Además de los archivos de resultados/salida, en la carpeta de la
    % batería 18 hay también CICLOn_CARGAS.xlsx / CICLOn_DESCARGAS.xlsx
    % (datos de capacidad, no de impedancia): se excluyen igual.
    archivos = archivos(~contains({archivos.name}, ...
        {'Parametros', 'Errores', 'Resultados', 'CARGAS', 'DESCARGAS', 'TOTALES'}));
    if isempty(archivos)
        error('No se encontraron archivos CICLO*.xlsx en: %s', rutaCarpeta);
    end

    nums = zeros(1, numel(archivos));
    for k = 1:numel(archivos)
        tok = regexp(archivos(k).name, '\d+', 'match');
        if ~isempty(tok)
            nums(k) = str2double(tok{1});
        end
    end
    [~, ord] = sort(nums);
    archivos = archivos(ord);
    nums = nums(ord);

    ciclos_vistos = [];
    n = numel(archivos);
    colores = lines(n);

    % x = [R0, R1, C1, R2, C2, L0]
    z_model = @(x, w) x(1) + x(6)*1i*w + ...
                      x(2)./(1 + 1i*w*x(2)*x(3)) + ...
                      x(4)./(1 + 1i*w*x(4)*x(5));

    %% ==================== 2. FIGURA (a): PREPARACIÓN ====================
    figure('Name', 'Bode en módulo - Batería 18 - Evolución del espectro con el envejecimiento', 'Color', 'w');
    hold on; grid on; box on;
    set(gca, 'XScale', 'log', 'YScale', 'log');
    xlabel('Frecuencia (Hz)');
    ylabel('|Z| (\Omega)');
    title('Diagrama de Bode (módulo) - Batería 18 - una curva por ciclo');
    leyenda_bode = {};

    Ciclo_esp = [];
    Frecuencia_esp = [];
    Zmod_esp = [];

    % Acumuladores para la figura (b)
    n_frec_fijas = numel(frecuencias_fijas);
    Ciclo_all = [];
    Zmod_modelo_fijas = [];
    Zmod_exp_fijas    = [];
    Zmod_modelo_fmin  = [];
    Zmod_exp_fmin     = [];
    f_min_por_ciclo   = [];

    %% ==================== 3. BUCLE POR CICLO: AJUSTE + DATOS ====================
    for k = 1:n
        nombreArchivo = archivos(k).name;
        rutaCompleta  = fullfile(rutaCarpeta, nombreArchivo);
        ciclo_match = regexp(nombreArchivo, '\d+', 'match');
        if isempty(ciclo_match)
            continue;
        end
        % El número del nombre del archivo (CICLOn...) ya es el ciclo real
        % en esta batería (p.ej. CICLO267 -> ciclo 267), no se multiplica por 25.
        ciclo = nums(k);

        if ismember(ciclo, ciclos_excluir)
            fprintf('Archivo "%s" omitido: el ciclo %d está en ciclos_excluir.\n', nombreArchivo, ciclo);
            continue;
        end

        if ismember(ciclo, ciclos_vistos)
            fprintf('Archivo "%s" omitido: el ciclo %d ya fue procesado con otro archivo.\n', nombreArchivo, ciclo);
            continue;
        end

        try
            data = readmatrix(rutaCompleta, 'Range', 'A2');
            if size(data,2) < 3
                error('El archivo no tiene al menos 3 columnas.');
            end

            f_corte = 1000000;
            idx_ok = data(:,1) < f_corte & ~isnan(data(:,1)) & ~isnan(data(:,2)) & ~isnan(data(:,3));
            f_raw = data(idx_ok,1);
            R_raw = data(idx_ok,2);
            X_raw = data(idx_ok,3);

            if numel(f_raw) < 5
                error('No hay suficientes datos válidos para ajustar.');
            end

            % Orden ascendente de frecuencia (necesario para interpolar luego)
            [f_raw, ord_f] = sort(f_raw);
            R_raw = R_raw(ord_f);
            X_raw = X_raw(ord_f);

            ciclos_vistos(end+1) = ciclo; %#ok<AGROW>

            % ==================== AJUSTE LM PONDERADO (idéntico al original) ====================
            R_fit = -R_raw;
            X_fit = -X_raw;
            w_fit = 2*pi*f_raw;
            Z_exp = R_fit + 1i*X_fit;
            mod_Z = abs(Z_exp) + eps;

            fit_func = @(x, w) [ ...
                (real(z_model(x, w)) - real(Z_exp)) ./ (mod_Z.^2); ...
                (imag(z_model(x, w)) - imag(Z_exp)) ./ (mod_Z.^2) ...
                ];
            y_data = zeros(2*numel(Z_exp), 1);

            [~, idx_R0] = min(abs(X_fit));
            R0_est = R_fit(idx_R0);
            deltaR = max(R_fit) - R0_est;
            if deltaR <= 0
                deltaR = max(R_fit) - min(R_fit);
            end
            if deltaR <= 0
                deltaR = 1e-3;
            end

            x0 = [R0_est*0.3, deltaR*0.001, 0.01, max(mean(R_fit) - deltaR*0.001, 1e-6), 0.01, 1e-09];
            lb = [R0_est, deltaR*0.01, 1e-5, deltaR*0.01, 1e-5, 1e-09];
            ub = [R0_est, deltaR, 1, deltaR, 1, 1e-01];

            options = optimoptions('lsqcurvefit', ...
                'Algorithm', 'levenberg-marquardt', ...
                'Display', 'off', ...
                'FunctionTolerance', 1e-15, ...
                'StepTolerance', 1e-15);

            x_opt = lsqcurvefit(fit_func, x0, w_fit, y_data, lb, ub, options);

            % ==================== FIGURA (a): |Z| EXPERIMENTAL vs f ====================
            Z_mod_exp_espectro = sqrt(R_raw.^2 + X_raw.^2);
            plot(f_raw, Z_mod_exp_espectro, '-o', 'LineWidth', 1.3, 'MarkerSize', 3, ...
                 'Color', colores(k,:));
            leyenda_bode{end+1} = sprintf('Ciclo %d', ciclo); %#ok<AGROW>

            Ciclo_esp = [Ciclo_esp; repmat(ciclo, numel(f_raw), 1)]; %#ok<AGROW>
            Frecuencia_esp = [Frecuencia_esp; f_raw]; %#ok<AGROW>
            Zmod_esp = [Zmod_esp; Z_mod_exp_espectro]; %#ok<AGROW>

            % ==================== FIGURA (b): FRECUENCIAS FIJAS ====================
            fila_modelo = nan(1, n_frec_fijas);
            fila_exp    = nan(1, n_frec_fijas);

            for j = 1:n_frec_fijas
                f_j = frecuencias_fijas(j);

                % Valor del modelo: evaluación analítica exacta del ajuste
                Z_mod_j = z_model(x_opt, 2*pi*f_j);
                fila_modelo(j) = abs(Z_mod_j);

                % Valor experimental: interpolación (en log-frecuencia) si f_j
                % cae dentro del rango medido; si no, se deja NaN.
                if f_j >= min(f_raw) && f_j <= max(f_raw)
                    R_j = interp1(log10(f_raw), R_raw, log10(f_j), 'pchip');
                    X_j = interp1(log10(f_raw), X_raw, log10(f_j), 'pchip');
                    fila_exp(j) = sqrt(R_j^2 + X_j^2);
                else
                    fprintf('Aviso: %g Hz fuera del rango medido en "%s" (ciclo %d). Se deja NaN.\n', ...
                        f_j, nombreArchivo, ciclo);
                end
            end

            Zmod_modelo_fijas = [Zmod_modelo_fijas; fila_modelo]; %#ok<AGROW>
            Zmod_exp_fijas    = [Zmod_exp_fijas; fila_exp];       %#ok<AGROW>

            % Frecuencia mínima del barrido de este ciclo (extremo derecho del Nyquist)
            f_min = f_raw(1);
            Z_modelo_fmin = abs(z_model(x_opt, 2*pi*f_min));
            Z_exp_fmin = sqrt(R_raw(1)^2 + X_raw(1)^2);

            Ciclo_all(end+1,1)        = ciclo;          %#ok<AGROW>
            f_min_por_ciclo(end+1,1)  = f_min;          %#ok<AGROW>
            Zmod_modelo_fmin(end+1,1) = Z_modelo_fmin;  %#ok<AGROW>
            Zmod_exp_fmin(end+1,1)    = Z_exp_fmin;     %#ok<AGROW>

            fprintf('Ciclo %d procesado (%s)\n', ciclo, nombreArchivo);

        catch ME
            fprintf('Error en "%s": %s\n', nombreArchivo, ME.message);
        end
    end

    if ~isempty(leyenda_bode)
        legend(leyenda_bode, 'Location', 'bestoutside');
    end
    hold off;

    %% ==================== 4. FIGURA (b): EVOLUCIÓN A FRECUENCIAS REPRESENTATIVAS ====================
    n_paneles = n_frec_fijas + 1;   % + panel de la frecuencia mínima del barrido
    n_filas = ceil(n_paneles / 2);

    figure('Name', 'Evolución de |Z| con el ciclo - Batería 18 - Modelo vs Experimental', ...
           'Color', 'w', 'Position', [100 100 1100 800]);

    for j = 1:n_frec_fijas
        subplot(n_filas, 2, j);
        plot(Ciclo_all, Zmod_modelo_fijas(:,j), 'o-', 'LineWidth', 1.8, ...
             'Color', [0.000 0.447 0.741], 'DisplayName', 'Z modelo (LM ponderado)');
        hold on;
        plot(Ciclo_all, Zmod_exp_fijas(:,j), 's--', 'LineWidth', 1.8, ...
             'Color', [0.850 0.325 0.098], 'DisplayName', 'Z experimental');
        hold off;
        grid on;
        xlabel('Ciclo');
        ylabel('|Z| (\Omega)');
        title(sprintf('%g Hz', frecuencias_fijas(j)));
        legend('Location', 'best');
    end

    subplot(n_filas, 2, n_frec_fijas + 1);
    plot(Ciclo_all, Zmod_modelo_fmin, 'o-', 'LineWidth', 1.8, ...
         'Color', [0.000 0.447 0.741], 'DisplayName', 'Z modelo (LM ponderado)');
    hold on;
    plot(Ciclo_all, Zmod_exp_fmin, 's--', 'LineWidth', 1.8, ...
         'Color', [0.850 0.325 0.098], 'DisplayName', 'Z experimental');
    hold off;
    grid on;
    xlabel('Ciclo');
    ylabel('|Z| (\Omega)');
    title('Frecuencia mínima del barrido (extremo derecho del Nyquist)');
    legend('Location', 'best');

    sgtitle('Batería 18 - Evolución de |Z| con el número de ciclo (modelo LM ponderado vs experimental)');

    %% ==================== 5. TABLAS DE SALIDA ====================
    tabla_espectro = table(Ciclo_esp, Frecuencia_esp, Zmod_esp, ...
        'VariableNames', {'Ciclo', 'Frecuencia_Hz', 'Z_mod_experimental'});

    nombres_frec = arrayfun(@(f) sprintf('f_%gHz', f), frecuencias_fijas, 'UniformOutput', false);
    T_fijas = array2table([Zmod_modelo_fijas, Zmod_exp_fijas], ...
        'VariableNames', [strcat(nombres_frec, '_modelo'), strcat(nombres_frec, '_exp')]);

    tabla_evolucion = [table(Ciclo_all, f_min_por_ciclo, Zmod_modelo_fmin, Zmod_exp_fmin, ...
        'VariableNames', {'Ciclo', 'f_min_Hz', 'Z_modelo_fmin', 'Z_exp_fmin'}), T_fijas];

    fprintf('\n=== EVOLUCIÓN DE |Z| POR CICLO - BATERÍA 18 ===\n');
    disp(tabla_evolucion);

end
