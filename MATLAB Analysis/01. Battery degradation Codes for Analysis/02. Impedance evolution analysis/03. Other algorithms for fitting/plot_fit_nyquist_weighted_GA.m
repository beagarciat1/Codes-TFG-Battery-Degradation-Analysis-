function tabla_parametros = plot_fit_nyquist_weighted_GA(rutaCarpeta)
    if nargin < 1 || isempty(rutaCarpeta)
        rutaCarpeta = pwd;
    end
    
    archivos = dir(fullfile(rutaCarpeta, '*.xlsx'));
    if isempty(archivos)
        error('No se encontraron archivos .xlsx en la carpeta: %s', rutaCarpeta);
    end
    
    ciclos_excluir = [1,2,6,7,8,9];
    colores = lines(length(archivos));
    
    figure('Name', 'Diagramas de Nyquist con ajuste GA', 'Color', 'w');
    hold on;
    grid on;
    axis equal;
    xlabel('Z_{real} (\Omega)');
    ylabel('-Z_{imaginaria} (\Omega)');
    title('Diagramas de Nyquist - Ajuste con Genetic Algorithm (GA)');
    
    % Arrays para guardar resultados
    ciclos = [];
    R0_all = []; R1_all = []; C1_all = []; R2_all = []; C2_all = []; L0_all = [];
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
        
        % Saltar ciclos no deseados
        if ismember(ciclo, ciclos_excluir)
            continue;
        end
        
        try
            data = readmatrix(rutaCompleta, 'Range', 'A2');
            if size(data,2) < 3
                error('El archivo no tiene al menos 3 columnas.');
            end
            
            % === FILTRADO DE DATOS (alta frecuencia) ===
            f_corte = 1000000;
            indices_buenos = data(:,1) < f_corte;
            f = data(indices_buenos,1);
            R = data(indices_buenos,2);
            X = data(indices_buenos,3);
            
            if numel(f) < 5
                error('No hay suficientes datos válidos para ajustar.');
            end
            
            % Preparación para ajuste
            R_fit_data = -R;
            X_fit_data = -X;
            f_fit = f;
            R_fit = R_fit_data;
            X_fit = X_fit_data;
            
            w = 2*pi*f_fit;
            Z_exp = R_fit + 1i*X_fit;
            mod_Z = abs(Z_exp) + eps;   % evita división por cero
            
            % ==================== MODELO DE IMPEDANCIA ====================
            z_model = @(x, w) x(1) + x(6)*1i*w + ...
                              x(2)./(1 + 1i*w*x(2)*x(3)) + ...
                              x(4)./(1 + 1i*w*x(4)*x(5));
            
            % ==================== GENETIC ALGORITHM ====================
            % x = [R0, R1, C1, R2, C2, L0]
            [~, idx_R0] = min(abs(X_fit));
            R0_est = R_fit(idx_R0);
            deltaR = max(R_fit) - min(R_fit);

            % Estimación inicial (solo para crear bounds)
            x0 = [R0_est*0.3, deltaR*0.001, 0.01, max(mean(R_fit) - deltaR*0.001, 1e-6), 0.01, 1e-09];
            
            % Bounds (puedes ajustarlos según tus datos)
            lb = [R0_est*0.5, deltaR*0.001, 1e-6, deltaR*0.001, 1e-6, 1e-10];
            ub = [R0_est*1.5, deltaR*2,     10,   deltaR*2,     10,   1e-2];
            
            % Función de fitness (minimiza el error ponderado 1/|Z|^2)
            fitness = @(x) sum( ...
                (real(z_model(x, w)) - real(Z_exp)).^2 ./ mod_Z.^2 + ...
                (imag(z_model(x, w)) - imag(Z_exp)).^2 ./ mod_Z.^2 );
            
            % Opciones del Genetic Algorithm
            options_ga = optimoptions('ga', ...
                'PopulationSize', 500, ...          % más población = mejor exploración
                'MaxGenerations', 400, ...          % generaciones máximas
                'FunctionTolerance', 1e-10, ...
                'ConstraintTolerance', 1e-10, ...
                'CrossoverFraction', 0.85, ...
                'MutationFcn', {@mutationadaptfeasible, 0.15}, ...
                'EliteCount', 25, ...  % 5% de élite
                'Display', 'off', ...
                'PlotFcn', @gaplotbestf);           % descomenta si quieres ver la convergencia
            
            % === EJECUCIÓN DEL ALGORITMO GENÉTICO ===
            [x_opt, resnorm] = ga(fitness, 6, [], [], [], [], lb, ub, [], options_ga);
            
            % Extraer parámetros
            R0 = x_opt(1);
            R1 = x_opt(2);
            C1 = x_opt(3);
            R2 = x_opt(4);
            C2 = x_opt(5);
            L0 = x_opt(6);
            
            % Cálculo de errores (igual que antes)
            Z_fit_final = z_model(x_opt, w);
            rmse = sqrt(mean(abs(Z_fit_final - Z_exp).^2));
            error_relativo = mean(abs(Z_fit_final - Z_exp) ./ (abs(Z_exp) + eps)) * 100;
            
            % Guardar resultados
            ciclos(end+1,1) = ciclo;
            R0_all(end+1,1) = R0;
            R1_all(end+1,1) = R1;
            C1_all(end+1,1) = C1;
            R2_all(end+1,1) = R2;
            C2_all(end+1,1) = C2;
            L0_all(end+1,1) = L0;
            resnorm_all(end+1,1) = resnorm;     % ahora es el fitness final del GA
            rmse_all(end+1,1) = rmse;
            error_rel_all(end+1,1) = error_relativo;
            nombres_archivo{end+1,1} = nombreArchivo;
            
            % === GRÁFICOS ===
            h = plot(-R, X, 'o-', 'LineWidth', 1.2, 'MarkerSize', 4, ...
                     'Color', colores(k,:), 'MarkerFaceColor', colores(k,:));
            h.DataTipTemplate.DataTipRows(end+1) = dataTipTextRow('Archivo', ...
                repmat({nombreArchivo}, length(R), 1));
            
            plot(real(Z_fit_final), -imag(Z_fit_final), '-', ...
                 'LineWidth', 2, 'Color', colores(k,:));
            
            leyenda{end+1} = sprintf('%s exp', nombreArchivo);
            leyenda{end+1} = sprintf('%s GA', nombreArchivo);
            
            % Mostrar resultados en consola
            fprintf('\n--- %s (Genetic Algorithm) ---\n', nombreArchivo);
            fprintf('R0 = %.6f Ohm\n', R0);
            fprintf('R1 = %.6f Ohm\n', R1);
            fprintf('C1 = %.6e F\n', C1);
            fprintf('R2 = %.6f Ohm\n', R2);
            fprintf('C2 = %.6e F\n', C2);
            fprintf('L0 = %.6e H\n', L0);
            fprintf('Fitness (resnorm) = %.6e\n', resnorm);
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
    
    % Tabla final
    tabla_parametros = table(ciclos, R0_all, R1_all, C1_all, R2_all, C2_all, L0_all, ...
                             resnorm_all, rmse_all, error_rel_all, nombres_archivo, ...
        'VariableNames', {'Ciclo','R0','R1','C1','R2','C2','L0','Resnorm_GA','RMSE','ErrorRelativoMedio','Archivo'});
    
    tabla_parametros = sortrows(tabla_parametros, 'Ciclo');
    disp(tabla_parametros);
    
    % Estadísticas
    fprintf('\n=== ESTADÍSTICAS PROMEDIO (Genetic Algorithm) ===\n');
    fprintf('Media de Resnorm (GA) = %.6e\n', mean(tabla_parametros.Resnorm_GA));
    fprintf('Media de RMSE = %.6e\n', mean(tabla_parametros.RMSE));
    fprintf('Media de Error Relativo = %.4f %%\n', mean(tabla_parametros.ErrorRelativoMedio));
    
    % Gráficas de evolución de parámetros
    hacer_grafica_parametro(tabla_parametros.Ciclo, tabla_parametros.R0, 'R0', 'R0 (\Omega)');
    hacer_grafica_parametro(tabla_parametros.Ciclo, tabla_parametros.R1, 'R1', 'R1 (\Omega)');
    hacer_grafica_parametro(tabla_parametros.Ciclo, tabla_parametros.C1, 'C1', 'C1 (F)');
    hacer_grafica_parametro(tabla_parametros.Ciclo, tabla_parametros.R2, 'R2', 'R2 (\Omega)');
    hacer_grafica_parametro(tabla_parametros.Ciclo, tabla_parametros.C2, 'C2', 'C2 (F)');
    hacer_grafica_parametro(tabla_parametros.Ciclo, tabla_parametros.L0, 'L0', 'L0 (H)');
end

% Función auxiliar (sin cambios)
function hacer_grafica_parametro(ciclos, valores, nombreParametro, etiquetaY)
    idx = ~isnan(ciclos) & ~isnan(valores);
    ciclos = ciclos(idx);
    valores = valores(idx);
    figure('Name', ['Evolución de ', nombreParametro, ' (GA)'], 'Color', 'w');
    plot(ciclos, valores, 'o-', 'LineWidth', 1.5, 'MarkerSize', 6, 'MarkerFaceColor', 'auto');
    grid on;
    xlabel('Ciclo');
    ylabel(etiquetaY);
    title(['Evolución de ', nombreParametro, ' por ciclo - Genetic Algorithm']);
end