function tabla_parametros = plot_fit_nyquist_lsq(rutaCarpeta)
% Ajuste de Nyquist con Levenberg-Marquardt (lsqcurvefit) SIN ponderación.
% Minimiza la suma de cuadrados de residuos reales e imaginarios sin dividir
% por |Z|^2, a diferencia de dibujo_fit_nyquist_conjunto_seleccion_ponderado.

    if nargin < 1 || isempty(rutaCarpeta)
        rutaCarpeta = pwd;
    end

    archivos = dir(fullfile(rutaCarpeta, '*.xlsx'));
    if isempty(archivos)
        error('No se encontraron archivos .xlsx en la carpeta: %s', rutaCarpeta);
    end

    ciclos_excluir = [7];
    colores = lines(length(archivos));

    figure('Name', 'Diagramas de Nyquist con ajuste LM', 'Color', 'w');
    hold on; grid on; axis equal;
    xlabel('Z_{real} (\Omega)');
    ylabel('-Z_{imaginaria} (\Omega)');
    title('Diagramas de Nyquist con ajuste (Levenberg-Marquardt)');

    ciclos = [];
    R0_all = []; R1_all = []; C1_all = [];
    R2_all = []; C2_all = []; L0_all = [];
    resnorm_all = []; rmse_all = []; error_rel_all = [];
    nombres_archivo = {};
    leyenda = {};

    for k = 1:length(archivos)
        nombreArchivo = archivos(k).name;
        rutaCompleta = fullfile(rutaCarpeta, nombreArchivo);

        ciclo_match = regexp(nombreArchivo, '\d+', 'match');
        if ~isempty(ciclo_match)
            ciclo = str2double(ciclo_match{1});
        else
            ciclo = NaN;
        end

        if ismember(ciclo, ciclos_excluir)
            continue;
        end

        try
            data = readmatrix(rutaCompleta, 'Range', 'A2');

            if size(data,2) < 3
                error('El archivo no tiene al menos 3 columnas.');
            end

            f_corte = 1000000;
            indices_buenos = data(:,1) < f_corte;

            f = data(:,1);
            R = data(:,2);
            X = data(:,3);

            f = f(indices_buenos);
            R = R(indices_buenos);
            X = X(indices_buenos);

            if numel(f) < 5
                error('No hay suficientes datos válidos para ajustar.');
            end

            % ===== CONVENCIÓN DE SIGNOS =====
            R_fit_data = -R;
            X_fit_data = -X;

            indices_buenos = f < f_corte;
            f_fit = f(indices_buenos);
            R_fit = R_fit_data(indices_buenos);
            X_fit = X_fit_data(indices_buenos);

            if numel(f_fit) < 5
                error('No hay suficientes datos tras el filtrado para ajustar.');
            end

            w = 2*pi*f_fit;
            Z_exp = R_fit + 1i*X_fit;

            % ===== MODELO =====
            z_model = @(x, w) x(1) + x(6)*1i*w + ...
                              x(2)./(1 + 1i*w*x(2)*x(3)) + ...
                              x(4)./(1 + 1i*w*x(4)*x(5));

            % ===== FUNCIÓN DE AJUSTE SIN PONDERACIÓN =====
            fit_func = @(x, w) [ ...
                real(z_model(x, w)) - real(Z_exp); ...
                imag(z_model(x, w)) - imag(Z_exp) ...
            ];
            y_data = zeros(2*numel(Z_exp), 1);

            % ===== ESTIMACIONES INICIALES Y LÍMITES =====
            [~, idx_R0] = min(abs(X_fit));
            R0_est = R_fit(idx_R0);
            deltaR = max(R_fit) - R0_est;
            if deltaR <= 0
                deltaR = max(R_fit) - min(R_fit);
            end
            if deltaR <= 0
                deltaR = 1e-3;
            end

            x0 = [R0_est, deltaR*0.3, 0.01, deltaR*0.3, 0.01, 1e-7];
            lb = [R0_est*0.8, deltaR*0.01, 1e-5, deltaR*0.01, 1e-5, 6e-08];
            ub = [R0_est*1.2, deltaR,       1,    deltaR,       1,    1   ];

            % ===== LEVENBERG-MARQUARDT =====
            options = optimoptions('lsqcurvefit', ...
                'Algorithm',         'levenberg-marquardt', ...
                'Display',           'off', ...
                'FunctionTolerance', 1e-15, ...
                'StepTolerance',     1e-15);

            [x_opt, resnorm] = lsqcurvefit(fit_func, x0, w, y_data, lb, ub, options);

            R0 = x_opt(1); R1 = x_opt(2); C1 = x_opt(3);
            R2 = x_opt(4); C2 = x_opt(5); L0 = x_opt(6);

            % ===== ERRORES =====
            Z_fit = z_model(x_opt, w);
            residual = [real(Z_exp) - real(Z_fit); imag(Z_exp) - imag(Z_fit)];
            rmse = sqrt(resnorm / length(Z_exp));
            error_relativo = mean(abs(residual) ./ (abs([real(Z_exp); imag(Z_exp)]) + eps)) * 100;

            ciclos(end+1,1) = ciclo;
            R0_all(end+1,1) = R0; R1_all(end+1,1) = R1; C1_all(end+1,1) = C1;
            R2_all(end+1,1) = R2; C2_all(end+1,1) = C2; L0_all(end+1,1) = L0;
            resnorm_all(end+1,1) = resnorm; rmse_all(end+1,1) = rmse;
            error_rel_all(end+1,1) = error_relativo;
            nombres_archivo{end+1,1} = nombreArchivo;

            h = plot(-R, X, 'o-', 'LineWidth', 1.2, 'MarkerSize', 4, ...
                'Color', colores(k,:), 'MarkerFaceColor', colores(k,:));
            h.DataTipTemplate.DataTipRows(end+1) = dataTipTextRow('Archivo', ...
                repmat({nombreArchivo}, length(R), 1));

            plot(real(Z_fit), -imag(Z_fit), '-', 'LineWidth', 2, 'Color', colores(k,:));

            leyenda{end+1} = sprintf('%s exp', nombreArchivo);
            leyenda{end+1} = sprintf('%s fit (LM)', nombreArchivo);

            fprintf('\n--- %s ---\n', nombreArchivo);
            fprintf('R0 = %.6f Ohm\n', R0); fprintf('R1 = %.6f Ohm\n', R1);
            fprintf('C1 = %.6e F\n', C1);   fprintf('R2 = %.6f Ohm\n', R2);
            fprintf('C2 = %.6e F\n', C2);   fprintf('L0 = %.6e H\n', L0);
            fprintf('RMSE = %.6e\n', rmse);
            fprintf('Error relativo medio = %.4f %%\n', error_relativo);

        catch ME
            fprintf('Error en "%s": %s\n', nombreArchivo, ME.message);
        end
    end

    if ~isempty(leyenda)
        legend(leyenda, 'Location', 'best');
    end
    hold off;

    tabla_parametros = table(ciclos, R0_all, R1_all, C1_all, R2_all, C2_all, L0_all, ...
        resnorm_all, rmse_all, error_rel_all, nombres_archivo, ...
        'VariableNames', {'Ciclo','R0','R1','C1','R2','C2','L0','Resnorm','RMSE','ErrorRelativoMedio','Archivo'});

    tabla_parametros = sortrows(tabla_parametros, 'Ciclo');
    disp(tabla_parametros);

    fprintf('\n=== ESTADÍSTICAS PROMEDIO ===\n');
    fprintf('Media de Resnorm          = %.6e\n', mean(tabla_parametros.Resnorm));
    fprintf('Media de RMSE             = %.6e\n', mean(tabla_parametros.RMSE));
    fprintf('Media de Error Relativo   = %.4f %%\n', mean(tabla_parametros.ErrorRelativoMedio));

    hacer_grafica_parametro(tabla_parametros.Ciclo, tabla_parametros.R0, 'R0', 'R0 (\Omega)');
    hacer_grafica_parametro(tabla_parametros.Ciclo, tabla_parametros.R1, 'R1', 'R1 (\Omega)');
    hacer_grafica_parametro(tabla_parametros.Ciclo, tabla_parametros.C1, 'C1', 'C1 (F)');
    hacer_grafica_parametro(tabla_parametros.Ciclo, tabla_parametros.R2, 'R2', 'R2 (\Omega)');
    hacer_grafica_parametro(tabla_parametros.Ciclo, tabla_parametros.C2, 'C2', 'C2 (F)');
    hacer_grafica_parametro(tabla_parametros.Ciclo, tabla_parametros.L0, 'L0', 'L0 (H)');
end


function hacer_grafica_parametro(ciclos, valores, nombreParametro, etiquetaY)
    idx = ~isnan(ciclos) & ~isnan(valores);
    ciclos = ciclos(idx);
    valores = valores(idx);
    figure('Name', ['Evolución de ', nombreParametro, ' (LM)'], 'Color', 'w');
    plot(ciclos, valores, 'o-', 'LineWidth', 1.5, 'MarkerSize', 6, 'MarkerFaceColor', 'auto');
    grid on; xlabel('Ciclo'); ylabel(etiquetaY);
    title(['Evolución de ', nombreParametro, ' por ciclo (LM)']);
end
