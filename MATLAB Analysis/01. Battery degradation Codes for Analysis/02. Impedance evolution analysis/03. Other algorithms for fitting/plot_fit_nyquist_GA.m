function tabla_parametros = plot_fit_nyquist_GA(rutaCarpeta)

    if nargin < 1 || isempty(rutaCarpeta)
        rutaCarpeta = pwd;
    end

    archivos = dir(fullfile(rutaCarpeta, '*.xlsx'));
    if isempty(archivos)
        error('No se encontraron archivos .xlsx en la carpeta: %s', rutaCarpeta);
    end

    ciclos_excluir = 7;   % Cambia aquí los ciclos que quieras excluir

    colores = lines(length(archivos));

    figure('Name', 'Diagramas de Nyquist con ajuste - Genetic Algorithm', 'Color', 'w');
    hold on;
    grid on;
    axis equal;
    xlabel('Z_{real} (\Omega)');
    ylabel('-Z_{imaginaria} (\Omega)');
    title('Diagramas de Nyquist con ajuste (Genetic Algorithm)');

    ciclos = [];
    R0_all = []; R1_all = []; C1_all = []; R2_all = []; C2_all = []; L0_all = [];
    resnorm_all = []; rmse_all = []; error_rel_all = [];
    nombres_archivo = {};
    leyenda = {};

    for k = 1:length(archivos)
        nombreArchivo = archivos(k).name;
        rutaCompleta = fullfile(rutaCarpeta, nombreArchivo);

        % Extraer número de ciclo
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

            f = data(:,1);
            R = data(:,2);
            X = data(:,3);

            R_fit_data = -R;
            X_fit_data = -X;

            % === FILTRADO MUY ROBUSTO ===
            idx_valid = ~isnan(f) & ~isnan(R) & ~isnan(X) & (f > 1) & (f < 1e6);
            f = f(idx_valid);
            R = R_fit_data(idx_valid);
            X = X_fit_data(idx_valid);

            if numel(f) < 8
                warning('Ciclo %s: muy pocos puntos válidos (%d)', nombreArchivo, numel(f));
                continue;
            end

            % Filtrar frecuencias altas (evita la parte inductiva baja que distorsiona)
            idx_high = f < 100000;          % 50 kHz suele ser un buen corte
            R_plot = R(idx_high);         % Negativo para Nyquist clásico
            X_plot = X(idx_high);

            if numel(R_plot) < 5
                continue;
            end

            % === PLOT EXPERIMENTAL ===
            h = plot(R_plot, -X_plot, 'o-', ...
                'LineWidth', 1.3, ...
                'MarkerSize', 5, ...
                'Color', colores(k,:), ...
                'MarkerFaceColor', colores(k,:));

            h.DataTipTemplate.DataTipRows(end+1) = dataTipTextRow('Archivo', ...
                repmat({nombreArchivo}, length(R_plot), 1));

            % === FITTING CON GENETIC ALGORITHM ===
            w = 2*pi * f(idx_high);
            Z_exp = R_plot + 1i * X_plot;     % Ya están negados

            z_model = @(x, w) x(1) + x(6)*1i*w + ...
                              x(2)./(1 + 1i*w*x(2)*x(3)) + ...
                              x(4)./(1 + 1i*w*x(4)*x(5));

            objective = @(x) sum(abs([real(z_model(x,w)) - real(Z_exp); ...
                                      imag(z_model(x,w)) - imag(Z_exp)]).^2);

            % Límites más conservadores
            R0_est = R_plot(1);   % Primer punto suele ser cercano a R0
           

            deltaR = max(R_fit) - R0_est;
            if deltaR <= 0
                deltaR = max(R_fit) - min(R_fit);
            end
            if deltaR <= 0
                deltaR = 1e-3;
            end

            lb = [R0_est*0.8, deltaR*0.01, 1e-5, max(mean(R_fit) - deltaR*0.001, 1e-6), 1e-4, 1e-09];
            ub = [R0_est, deltaR, 1, deltaR, 1, 1e-01];

           
            options = optimoptions('ga', ...
                'PopulationSize', 100, ...
                'MaxGenerations', 120, ...
                'Display', 'off', ...
                'FunctionTolerance', 1e-6);

            [x_opt, ~] = ga(objective, 6, [], [], [], [], lb, ub, [], options);
            R0 = x_opt(1);
            R1 = x_opt(2);
            C1 = x_opt(3);
            R2 = x_opt(4);
            C2 = x_opt(5);
            L0 = x_opt(6);
            
            % Error real
            Z_fit_final = z_model(x_opt, w);
            residual = Z_fit_final - Z_exp;
            
            resnorm_real = sum(abs(residual).^2);
            rmse_real = sqrt(mean(abs(residual).^2));
            error_relativo = mean(abs(residual) ./ (abs(Z_exp) + eps)) * 100;
            
            % Guardar
            ciclos(end+1,1) = ciclo;
            R0_all(end+1,1) = R0;
            R1_all(end+1,1) = R1;
            C1_all(end+1,1) = C1;
            R2_all(end+1,1) = R2;
            C2_all(end+1,1) = C2;
            L0_all(end+1,1) = L0;
            resnorm_all(end+1,1) = resnorm_real;
            rmse_all(end+1,1) = rmse_real;
            error_rel_all(end+1,1) = error_relativo;
            nombres_archivo{end+1,1} = nombreArchivo;
            % Plot del modelo
            Z_fit = z_model(x_opt, w);
            plot(real(Z_fit), -imag(Z_fit), '-', 'LineWidth', 2.2, 'Color', colores(k,:));

            leyenda{end+1} = sprintf('%s exp', nombreArchivo);
            leyenda{end+1} = sprintf('%s fit (GA)', nombreArchivo);

            fprintf('✓ %s procesado correctamente\n', nombreArchivo);

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
    %writetable(tabla_parametros, fullfile(rutaCarpeta, 'parametros_ajuste_GA.xlsx'));
    % ==================== MEDIAS AÑADIDAS ====================
    fprintf('\n=== ESTADÍSTICAS PROMEDIO ===\n');
    fprintf('Media de Resnorm          = %.6e\n', mean(tabla_parametros.Resnorm));
    fprintf('Media de RMSE             = %.6e\n', mean(tabla_parametros.RMSE));
    fprintf('Media de Error Relativo   = %.4f %%\n', mean(tabla_parametros.ErrorRelativoMedio));
    % ======================================================
    
    % Gráficas de evolución
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

    figure('Name', ['Evolución de ', nombreParametro], 'Color', 'w');
    plot(ciclos, valores, 'o-', 'LineWidth', 1.5, 'MarkerSize', 6, 'MarkerFaceColor', 'auto');
    grid on;
    xlabel('Ciclo');
    ylabel(etiquetaY);
    title(['Evolución de ', nombreParametro, ' por ciclo']);

end