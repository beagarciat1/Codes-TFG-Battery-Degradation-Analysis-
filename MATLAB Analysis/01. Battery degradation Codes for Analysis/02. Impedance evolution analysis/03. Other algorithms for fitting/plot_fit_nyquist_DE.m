function tabla_parametros = plot_fit_nyquist_DE(rutaCarpeta)
    if nargin < 1 || isempty(rutaCarpeta)
        rutaCarpeta = pwd;
    end

    archivos = dir(fullfile(rutaCarpeta, '*.xlsx'));
    if isempty(archivos)
        error('No se encontraron archivos .xlsx en la carpeta: %s', rutaCarpeta);
    end

    ciclos_excluir = 7;
    colores = lines(length(archivos));

    figure('Name', 'Nyquist + DE', 'Color', 'w', 'Position', [100 100 900 700]);
    hold on; grid on; axis equal;
    xlabel('Z_{real} (\Omega)');
    ylabel('-Z_{imaginaria} (\Omega)');
    title('Ajuste con Differential Evolution');

    ciclos = [];
    R0_all = []; R1_all = []; C1_all = [];
    R2_all = []; C2_all = []; L0_all = [];
    resnorm_all = []; rmse_all = []; error_rel_all = [];
    nombres_archivo = {};
    leyenda = {};                    % ← Nueva: para la leyenda con ciclos

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
            f = data(:,1);
            R = data(:,2);
            X = data(:,3);

            % Filtrado básico
            idx = ~isnan(f) & ~isnan(R) & ~isnan(X) & f < 1e5;
            f = f(idx);
            R = R(idx);
            X = X(idx);

            if numel(f) < 10
                fprintf('Saltando %s: pocos puntos válidos\n', nombreArchivo);
                continue;
            end

            R_plot = -R;
            X_plot = -X;
            w = 2*pi*f;
            Z_exp = R_plot + 1i*X_plot;

            % ===== ESTIMACIONES INICIALES =====
            [~, idx_R0] = min(abs(X_plot));
            R0_est = R_plot(idx_R0);
            deltaR = max(R_plot) - R0_est;
            if deltaR <= 0
                deltaR = max(R_plot) - min(R_plot);
            end
            if deltaR <= 0
                deltaR = 1e-3;
            end

            % ===== LÍMITES MEJORADOS =====
            lb = [R0_est*0.5, deltaR*0.005, 1e-8, deltaR*0.005, 1e-8, 5e-8];
            ub = [R0_est*1.8, deltaR*1.5, 5, deltaR*1.5, 5, 8e-5]; % L0 hasta ~80 µH

            % ===== MODELO =====
            z_model = @(x,w) x(1) + x(6)*1i*w + ...
                             x(2)./(1 + 1i*w*x(2)*x(3)) + ...
                             x(4)./(1 + 1i*w*x(4)*x(5));

            % Función objetivo con peso en altas frecuencias
            objective = @(x) sum( abs(z_model(x,w) - Z_exp).^2 .* (w / max(w)).^0.8 );

            % ===== DIFFERENTIAL EVOLUTION =====
            D = 6;
            NP = 120;
            F = 0.75;
            CR = 0.85;
            Gmax = 350;

            pop = repmat(lb, NP, 1) + rand(NP, D) .* repmat(ub - lb, NP, 1);
            fitness = zeros(NP, 1);
            for i = 1:NP
                fitness(i) = objective(pop(i,:));
            end

            for g = 1:Gmax
                for i = 1:NP
                    idxs = randperm(NP, 3);
                    while any(idxs == i)
                        idxs = randperm(NP, 3);
                    end
                    a = pop(idxs(1),:);
                    b = pop(idxs(2),:);
                    c = pop(idxs(3),:);

                    v = a + F * (b - c);
                    v = max(v, lb);
                    v = min(v, ub);

                    u = pop(i,:);
                    jrand = randi(D);
                    for j = 1:D
                        if rand <= CR || j == jrand
                            u(j) = v(j);
                        end
                    end
                    u = max(u, lb);
                    u = min(u, ub);

                    fu = objective(u);
                    if fu < fitness(i)
                        pop(i,:) = u;
                        fitness(i) = fu;
                    end
                end
            end

            [~, best_idx] = min(fitness);
            x_opt = pop(best_idx, :);

            % ===== CÁLCULO DE RESULTADOS =====
            Z_fit = z_model(x_opt, w);
            residual = [real(Z_exp) - real(Z_fit); imag(Z_exp) - imag(Z_fit)];
            resnorm = sum(residual.^2);
            rmse = sqrt(resnorm / length(Z_exp));
            error_rel = mean(abs(residual) ./ (abs([real(Z_exp); imag(Z_exp)]) + eps)) * 100;

            R0 = x_opt(1); R1 = x_opt(2); C1 = x_opt(3);
            R2 = x_opt(4); C2 = x_opt(5); L0 = x_opt(6);

            % Guardar resultados
            ciclos(end+1,1) = ciclo;
            R0_all(end+1,1) = R0;
            R1_all(end+1,1) = R1;
            C1_all(end+1,1) = C1;
            R2_all(end+1,1) = R2;
            C2_all(end+1,1) = C2;
            L0_all(end+1,1) = L0;
            resnorm_all(end+1,1) = resnorm;
            rmse_all(end+1,1) = rmse;
            error_rel_all(end+1,1) = error_rel;
            nombres_archivo{end+1,1} = nombreArchivo;

            % ===== GRÁFICA CON LEYENDA Y DATATIPS MEJORADOS =====
            color_actual = colores(k,:);

            % Datos experimentales
            h_exp = plot(-R, X, 'o-', 'LineWidth', 1.2, 'MarkerSize', 4, ...
                         'Color', color_actual, 'MarkerFaceColor', color_actual);
            
            % Añadir DataTip con información del ciclo
            h_exp.DataTipTemplate.DataTipRows(end+1) = dataTipTextRow('Archivo', ...
                repmat({nombreArchivo}, length(R), 1));
            h_exp.DataTipTemplate.DataTipRows(end+1) = dataTipTextRow('Ciclo', ...
                repmat({ciclo}, length(R), 1));

            % Ajuste (fit)
            h_fit = plot(real(Z_fit), -imag(Z_fit), '-', 'LineWidth', 2.2, ...
                         'Color', color_actual);

            h_fit.DataTipTemplate.DataTipRows(end+1) = dataTipTextRow('Archivo', ...
                repmat({nombreArchivo}, length(Z_fit), 1));
            h_fit.DataTipTemplate.DataTipRows(end+1) = dataTipTextRow('Ciclo', ...
                repmat({ciclo}, length(Z_fit), 1));
            h_fit.DataTipTemplate.DataTipRows(end+1) = dataTipTextRow('Tipo', ...
                repmat({'Ajuste DE'}, length(Z_fit), 1));

            % Preparar leyenda
            leyenda{end+1} = sprintf('Ciclo %d - Exp', ciclo);
            leyenda{end+1} = sprintf('Ciclo %d - Fit (DE)', ciclo);

            fprintf('✓ Ciclo %d | %s | RMSE: %.4e | L0: %.2e H | Error rel: %.2f%%\n', ...
                    ciclo, nombreArchivo, rmse, L0, error_rel);

        catch ME
            fprintf('Error en "%s": %s\n', nombreArchivo, ME.message);
        end
    end

    % Leyenda final
    if ~isempty(leyenda)
        legend(leyenda, 'Location', 'best', 'FontSize', 9, 'Interpreter', 'none');
    end

    hold off;

    % ===== TABLA DE RESULTADOS =====
    tabla_parametros = table(ciclos, R0_all, R1_all, C1_all, R2_all, C2_all, L0_all, ...
        resnorm_all, rmse_all, error_rel_all, nombres_archivo, ...
        'VariableNames', {'Ciclo','R0','R1','C1','R2','C2','L0','Resnorm','RMSE','ErrorRelativoMedio','Archivo'});

    tabla_parametros = sortrows(tabla_parametros, 'Ciclo');
    disp(tabla_parametros);

    % Estadísticas promedio
    fprintf('\n=== ESTADÍSTICAS PROMEDIO ===\n');
    fprintf('Media de Resnorm = %.6e\n', mean(tabla_parametros.Resnorm));
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