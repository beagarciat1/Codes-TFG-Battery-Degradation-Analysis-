function [tabla_bat1, tabla_bat2] = impedance_evolution_numerous_batteries_lsq_weighted(rutaCarpeta_bat1, rutaCarpeta_bat2, ciclos_excluir_bat1, ciclos_excluir_bat2)
% COMPARAR_PARAMETROS_BATERIAS  Ajusta con LM ponderado (idéntico a
%   dibujo_fit_nyquist_conjunto_seleccion_ponderado.m /
%   BATERIA18_dibujo_fit_nyquist_conjunto_seleccion_ponderado.m) todos los
%   ciclos de la batería 1 y de la batería 18 (batería 2), y dibuja UNA
%   figura por cada parámetro del circuito equivalente (R0, R1, C1, R2,
%   C2, L0 y R total = R0+R1+R2) con la evolución de ambas baterías
%   superpuesta, para poder compararlas directamente.
%
%   Diferencia entre baterías (ya tenida en cuenta):
%     - Batería 1:  el número del archivo (CICLOn...) es un ÍNDICE que
%                    hay que multiplicar por 25 para obtener el ciclo real.
%     - Batería 18: el número del archivo YA es el ciclo real.
%
%   USO:
%     impedance_evolution_numerous_batteries_lsq_weighted()
%     impedance_evolution_numerous_batteries_lsq_weighted(rutaCarpeta_bat1, rutaCarpeta_bat2)
%     impedance_evolution_numerous_batteries_lsq_weighted(rutaCarpeta_bat1, rutaCarpeta_bat2, ciclos_excluir_bat1, ciclos_excluir_bat2)
%
%   ENTRADAS (opcionales):
%     rutaCarpeta_bat1    : carpeta con los CICLO*.xlsx crudos de la
%                           batería 1 (default: Beatriz\BATERÍA 1 CARGAS
%                           LARGAS\BATERÍA 1 EXCELS BODE 100)
%     rutaCarpeta_bat2    : carpeta con los CICLO*.xlsx crudos de la
%                           batería 18 (default: Beatriz\BATERÍA 18. JUNIO
%                           2026 100 CICLOS)
%     ciclos_excluir_bat1 : ciclos reales a excluir de la batería 1
%                           (default: [175])
%     ciclos_excluir_bat2 : ciclos reales a excluir de la batería 18
%                           (default: [])
%
%   SALIDAS:
%     tabla_bat1, tabla_bat2 : tablas con Ciclo, R0, R1, C1, R2, C2, L0
%                                de cada batería (ya ajustadas y ordenadas)

    if nargin < 1 || isempty(rutaCarpeta_bat1)
        rutaCarpeta_bat1 = 'C:\your_route\your_folder';
    end
    if nargin < 2 || isempty(rutaCarpeta_bat2)
        rutaCarpeta_bat2 = 'C:\your_route\your_folder';
    end
    if nargin < 3 || isempty(ciclos_excluir_bat1)
        ciclos_excluir_bat1 = [175];
    end
    if nargin < 4 || isempty(ciclos_excluir_bat2)
        ciclos_excluir_bat2 = [];
    end

    fprintf('Ajustando batería 1...\n');
    tabla_bat1 = ajustar_bateria(rutaCarpeta_bat1, true, ciclos_excluir_bat1);

    fprintf('\nAjustando batería 18...\n');
    tabla_bat2 = ajustar_bateria(rutaCarpeta_bat2, false, ciclos_excluir_bat2);

    %% ==================== GRÁFICAS DE COMPARACIÓN ====================
    color_bat1 = [0.000 0.447 0.741];
    color_bat2 = [0.850 0.325 0.098];

    parametros = { ...
        'R0', 'R0 (\Omega)'; ...
        'R1', 'R1 (\Omega)'; ...
        'C1', 'C1 (F)'; ...
        'R2', 'R2 (\Omega)'; ...
        'C2', 'C2 (F)'; ...
        'L0', 'L0 (H)'; ...
        };

    R_total_bat1 = tabla_bat1.R0 + tabla_bat1.R1 + tabla_bat1.R2;
    R_total_bat2 = tabla_bat2.R0 + tabla_bat2.R1 + tabla_bat2.R2;

    for i = 1:size(parametros, 1)
        nombre = parametros{i,1};
        etiqueta = parametros{i,2};

        figure('Name', ['Evolución de ', nombre, ' - Batería 1 vs Batería 18'], 'Color', 'w');
        plot(tabla_bat1.Ciclo, tabla_bat1.(nombre), 'o-', 'LineWidth', 1.8, 'MarkerSize', 6, ...
             'Color', color_bat1, 'MarkerFaceColor', color_bat1, 'DisplayName', 'Batería 1');
        hold on;
        plot(tabla_bat2.Ciclo, tabla_bat2.(nombre), 's-', 'LineWidth', 1.8, 'MarkerSize', 6, ...
             'Color', color_bat2, 'MarkerFaceColor', color_bat2, 'DisplayName', 'Batería 18 (Batería 2)');
        hold off;
        grid on;
        xlabel('Ciclo');
        ylabel(etiqueta);
        title(['Evolución de ', nombre, ' por ciclo - Batería 1 vs Batería 18']);
        legend('Location', 'best');
    end

    % R total = R0 + R1 + R2
    figure('Name', 'Evolución de R total - Batería 1 vs Batería 18', 'Color', 'w');
    plot(tabla_bat1.Ciclo, R_total_bat1, 'o-', 'LineWidth', 1.8, 'MarkerSize', 6, ...
         'Color', color_bat1, 'MarkerFaceColor', color_bat1, 'DisplayName', 'Batería 1');
    hold on;
    plot(tabla_bat2.Ciclo, R_total_bat2, 's-', 'LineWidth', 1.8, 'MarkerSize', 6, ...
         'Color', color_bat2, 'MarkerFaceColor', color_bat2, 'DisplayName', 'Batería 18 (Batería 2)');
    hold off;
    grid on;
    xlabel('Ciclo');
    ylabel('R total (\Omega)');
    title('Evolución de R total (R0+R1+R2) por ciclo - Batería 1 vs Batería 18');
    legend('Location', 'best');

end


% =========================================================================
function tabla = ajustar_bateria(rutaCarpeta, multiplicar_por_25, ciclos_excluir)
% Ajusta con LM ponderado todos los CICLO*.xlsx de rutaCarpeta y devuelve
% una tabla Ciclo,R0,R1,C1,R2,C2,L0 ordenada por ciclo.

    archivos = dir(fullfile(rutaCarpeta, 'CICLO*.xlsx'));
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

    z_model = @(x, w) x(1) + x(6)*1i*w + ...
                      x(2)./(1 + 1i*w*x(2)*x(3)) + ...
                      x(4)./(1 + 1i*w*x(4)*x(5));

    ciclos_vistos = [];
    ciclos = []; R0_all = []; R1_all = []; C1_all = [];
    R2_all = []; C2_all = []; L0_all = [];

    for k = 1:numel(archivos)
        nombreArchivo = archivos(k).name;
        rutaCompleta  = fullfile(rutaCarpeta, nombreArchivo);

        if multiplicar_por_25
            ciclo = nums(k) * 25;
        else
            ciclo = nums(k);
        end

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
            f_fit = data(idx_ok,1);
            R = data(idx_ok,2);
            X = data(idx_ok,3);

            if numel(f_fit) < 5
                error('No hay suficientes datos válidos para ajustar.');
            end

            ciclos_vistos(end+1) = ciclo; %#ok<AGROW>

            R_fit = -R;
            X_fit = -X;
            w = 2*pi*f_fit;
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

            x_opt = lsqcurvefit(fit_func, x0, w, y_data, lb, ub, options);

            ciclos(end+1,1) = ciclo;      %#ok<AGROW>
            R0_all(end+1,1) = x_opt(1);   %#ok<AGROW>
            R1_all(end+1,1) = x_opt(2);   %#ok<AGROW>
            C1_all(end+1,1) = x_opt(3);   %#ok<AGROW>
            R2_all(end+1,1) = x_opt(4);   %#ok<AGROW>
            C2_all(end+1,1) = x_opt(5);   %#ok<AGROW>
            L0_all(end+1,1) = x_opt(6);   %#ok<AGROW>

            fprintf('Ciclo %d procesado (%s)\n', ciclo, nombreArchivo);

        catch ME
            fprintf('Error en "%s": %s\n', nombreArchivo, ME.message);
        end
    end

    tabla = table(ciclos, R0_all, R1_all, C1_all, R2_all, C2_all, L0_all, ...
        'VariableNames', {'Ciclo', 'R0', 'R1', 'C1', 'R2', 'C2', 'L0'});
    tabla = sortrows(tabla, 'Ciclo');

end
