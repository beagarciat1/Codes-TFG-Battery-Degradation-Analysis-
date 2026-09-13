function tabla_parametros = plot_fit_nyquist_lsq_weighted(rutaCarpeta)

    if nargin < 1 || isempty(rutaCarpeta)
        rutaCarpeta = pwd;
    end

    % Solo se procesan los archivos de datos de ciclo (evita coger por error
    % archivos de resultados/salida como Errores_Nyquist_Modelo.xlsx,
    % Resultados_Ciclos.xlsx, Resultados_Parametros_Nyquist.xlsx o el propio
    % Excel que genera este script, que antes se mezclaban y daban filas
    % con Ciclo = NaN y valores sin sentido).
    archivos = dir(fullfile(rutaCarpeta, 'CICLO*.xlsx'));

    if isempty(archivos)
        error('No se encontraron archivos CICLO*.xlsx en la carpeta: %s', rutaCarpeta);
    end

    ciclos_excluir = [175]; % ciclo 7 × 25 = 175 (medida anómala, se muestra como atípico)
    ciclos_vistos = [];   % para detectar y omitir archivos duplicados del mismo ciclo

    colores = lines(length(archivos));

    figure('Name', 'Diagramas de Nyquist con ajuste', 'Color', 'w');
    hold on;
    grid on;
    axis equal;
    xlabel('Z_{real} (\Omega)');
    ylabel('-Z_{imaginaria} (\Omega)');
    title('Diagramas de Nyquist con ajuste');

    ciclos = [];
    R0_all = [];
    R1_all = [];
    C1_all = [];
    R2_all = [];
    C2_all = [];
    L0_all = [];
    resnorm_all = [];
    rmse_all = [];
    error_rel_all = [];
    nombres_archivo = {};
    leyenda = {};

    for k = 1:length(archivos)
        nombreArchivo = archivos(k).name;
        rutaCompleta = fullfile(rutaCarpeta, nombreArchivo);
        ciclo_match = regexp(nombreArchivo, '\d+', 'match');

if ~isempty(ciclo_match)
    ciclo = str2double(ciclo_match{1}) * 25;
else
    ciclo = NaN;
end

% ==================== OMITIR ARCHIVOS DUPLICADOS DEL MISMO CICLO ====================
if ~isnan(ciclo)
    if ismember(ciclo, ciclos_vistos)
        fprintf('Archivo "%s" omitido: el ciclo %d ya fue procesado con otro archivo.\n', nombreArchivo, ciclo);
        continue;
    end
    ciclos_vistos(end+1) = ciclo; %#ok<AGROW>
end
% ======================================================================================

es_atipico = ismember(ciclo, ciclos_excluir);

        try
            data = readmatrix(rutaCompleta, 'Range', 'A2');

            if size(data,2) < 3
                error('El archivo no tiene al menos 3 columnas.');
            end

            f_corte=1000000;
        
        % Mantener solo datos de alta frecuencia (antes de la rama) 
        %ESTO DE LA FRECUENCIA LO HE HECHO VARIAS VECES, LO TENGO QUE
        %REVISAR Y ACORTAR
        indices_buenos = data(:,1) < f_corte;

            f = data(:,1);
            R = data(:,2);
            X = data(:,3);

            %idx_validos = ~isnan(f) & ~isnan(R) & ~isnan(X) & (f > 0);
            f = f( indices_buenos);
            R = R( indices_buenos);
            X = X( indices_buenos);

            if numel(f) < 5
                error('No hay suficientes datos válidos para ajustar.');
            end

            R_fit_data = -R;
            X_fit_data = -X;

            f_corte = 1000000;
            indices_buenos = f < f_corte;

            f_fit = f(indices_buenos);
            R_fit = R_fit_data(indices_buenos);
            X_fit = X_fit_data(indices_buenos);

            if numel(f_fit) < 5
                error('No hay suficientes datos tras el filtrado para ajustar.');
            end

             w = 2*pi*f_fit;
            Z_exp = R_fit + 1i*X_fit;

            mod_Z = abs(Z_exp) + eps;   % evita división por 0

            z_model = @(x, w) x(1) + x(6)*1i*w + ...
                              x(2)./(1 + 1i*w*x(2)*x(3)) + ...
                              x(4)./(1 + 1i*w*x(4)*x(5));

            % ==================== PONDERACIÓN ====================


            fit_func = @(x, w) [ ...
            (real(z_model(x, w)) - real(Z_exp)) ./ (mod_Z.^2); ...
            (imag(z_model(x, w)) - imag(Z_exp)) ./ (mod_Z.^2) ...
            ];

            y_data = zeros(2*numel(Z_exp),1);

            

            [~, idx_R0] = min(abs(X_fit));
            R0_est = R_fit(idx_R0);

            deltaR = max(R_fit) - R0_est;
            if deltaR <= 0
                deltaR = max(R_fit) - min(R_fit);
            end
            if deltaR <= 0
                deltaR = 1e-3;
            end
            %AQUI INDICO LA SEMILLA Y LOS LÍMITES PARA CADA VALOR, ESTO ES
            %LO QUE MÁS HAY QUE AJUSTAR
             x0 = [R0_est*0.3, deltaR*0.001, 0.01, max(mean(R_fit) - deltaR*0.001, 1e-6), 0.01, 1e-09];
            lb = [R0_est, deltaR*0.01, 1e-5, deltaR*0.01, 1e-5, 1e-09];
            ub = [R0_est, deltaR, 1, deltaR, 1, 1e-01];

            options = optimoptions('lsqcurvefit', ...
                'Algorithm', 'levenberg-marquardt', ...
                'Display', 'off', ...
                'FunctionTolerance', 1e-15, ...
                'StepTolerance', 1e-15);

            [x_opt, resnorm, residual] = lsqcurvefit(fit_func, x0, w, y_data, lb, ub, options);

R0 = x_opt(1);
R1 = x_opt(2);
C1 = x_opt(3);
R2 = x_opt(4);
C2 = x_opt(5);
L0 = x_opt(6);



%  Error real (sin ponderación)
Z_fit_final = z_model(x_opt, w);
rmse = sqrt(mean(abs(Z_fit_final - Z_exp).^2));
error_relativo = mean(abs(Z_fit_final - Z_exp) ./ (abs(Z_exp) + eps)) * 100;
            ciclos(end+1,1) = ciclo;
            R0_all(end+1,1)=R0;
            R1_all(end+1,1) = R1;
            C1_all(end+1,1) = C1;
            R2_all(end+1,1) = R2;
            C2_all(end+1,1) = C2;
            L0_all(end+1,1) = L0;
            resnorm_all(end+1,1) = resnorm;
            rmse_all(end+1,1) = rmse;
            error_rel_all(end+1,1) = error_relativo;
            nombres_archivo{end+1,1} = nombreArchivo;
            if ~es_atipico
                h = plot(-R, X, 'o-', 'LineWidth', 1.2, 'MarkerSize', 4, 'Color', colores(k,:), 'MarkerFaceColor', colores(k,:));
                h.DataTipTemplate.DataTipRows(end+1) = dataTipTextRow('Archivo', ...
                    repmat({nombreArchivo}, length(R), 1));
                Z_fit = z_model(x_opt, w);
                n = plot(real(Z_fit), -imag(Z_fit), '-', 'LineWidth', 2, 'Color', colores(k,:));
                n.DataTipTemplate.DataTipRows(end+1) = dataTipTextRow('Archivo', ...
                    repmat({nombreArchivo}, length(R), 1));
                leyenda{end+1} = sprintf('%s exp', nombreArchivo);
                leyenda{end+1} = sprintf('%s fit', nombreArchivo);
            end

            fprintf('\n--- %s ---\n', nombreArchivo);
            fprintf('R0 = %.6f Ohm\n', R0);
            fprintf('R1 = %.6f Ohm\n', R1);
            fprintf('C1 = %.6e F\n', C1);
            fprintf('R2 = %.6f Ohm\n', R2);
            fprintf('C2 = %.6e F\n', C2);
            fprintf('L0 = %.6e H\n', L0);
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

    % ==================== EXCEL EN CARPETA ACTUAL (pwd) ====================
    tabla_excel = table(tabla_parametros.Ciclo, ...
                        tabla_parametros.L0, ...
                        tabla_parametros.R0, ...
                        tabla_parametros.R1, ...
                        tabla_parametros.C1, ...
                        tabla_parametros.R2, ...
                        tabla_parametros.C2, ...
                        'VariableNames', {'Ciclo','L0_H','R0_Ohm','R1_Ohm','C1_F','R2_Ohm','C2_F'});

    % Guardar en la carpeta actual de trabajo (pwd), NO en rutaCarpeta
    nombreExcel = fullfile(pwd, 'Parametros_Nyquist_Ajuste_mincuadpond_NEW.xlsx');
    writetable(tabla_excel, nombreExcel);
    
    % =====================================================================
    
    %writetable(tabla_parametros, fullfile(rutaCarpeta, 'parametros_ajuste.xlsx')); % (comentado como antes)

    
% ==================== MEDIAS AÑADIDAS ====================
    fprintf('\n=== ESTADÍSTICAS PROMEDIO ===\n');
    fprintf('Media de Resnorm          = %.6e\n', mean(tabla_parametros.Resnorm));
    fprintf('Media de RMSE             = %.6e\n', mean(tabla_parametros.RMSE));
    fprintf('Media de Error Relativo   = %.4f %%\n', mean(tabla_parametros.ErrorRelativoMedio));
    % ======================================================
    
    % Graficas de parámetros
    hacer_grafica_parametro(tabla_parametros.Ciclo, tabla_parametros.R0, 'R0', 'R0 (\Omega)', ciclos_excluir);
    hacer_grafica_parametro(tabla_parametros.Ciclo, tabla_parametros.R1, 'R1', 'R1 (\Omega)', ciclos_excluir);
    hacer_grafica_parametro(tabla_parametros.Ciclo, tabla_parametros.C1, 'C1', 'C1 (F)',      ciclos_excluir);
    hacer_grafica_parametro(tabla_parametros.Ciclo, tabla_parametros.R2, 'R2', 'R2 (\Omega)', ciclos_excluir);
    hacer_grafica_parametro(tabla_parametros.Ciclo, tabla_parametros.C2, 'C2', 'C2 (F)',      ciclos_excluir);
    hacer_grafica_parametro(tabla_parametros.Ciclo, tabla_parametros.L0, 'L0', 'L0 (H)',      ciclos_excluir);
    R_total = tabla_parametros.R0 + tabla_parametros.R1 + tabla_parametros.R2;
    hacer_grafica_parametro(tabla_parametros.Ciclo, R_total, 'R (R0+R1+R2)', 'R total (\Omega)', ciclos_excluir);

end

function hacer_grafica_parametro(ciclos, valores, nombreParametro, etiquetaY, ciclos_excluir)

    idx = ~isnan(ciclos) & ~isnan(valores) & ~ismember(ciclos, ciclos_excluir);
    ciclos = ciclos(idx);
    valores = valores(idx);

    figure('Name', ['Evolución de ', nombreParametro], 'Color', 'w');
    plot(ciclos, valores, 'o-', 'LineWidth', 1.5, 'MarkerSize', 6, 'MarkerFaceColor', 'auto');
    grid on;
    xlabel('Ciclo');
    ylabel(etiquetaY);
    title(['Evolución de ', nombreParametro, ' por ciclo']);
    set(gca, 'XTick', 25:25:max(ciclos));

end