function tabla_comparacion = comparison_fitting_methods(rutaCarpeta, ruta_csv_bode, ciclo_elegido)
% COMPARAR_NYQUIST_METODOS  Compara, para UN único ciclo (elegido al azar
%   si no se indica), el diagrama de Nyquist experimental frente a los
%   ajustes obtenidos con 4 algoritmos de optimización ponderados y frente
%   a la reconstrucción directa a partir de los parámetros que da el
%   equipo Bode 100 (sin ajuste en MATLAB). Todo se dibuja en una única
%   gráfica con leyenda clara.
%
%   Combina los métodos de:
%     - dibujo_fit_nyquist_conjunto_seleccion_ponderado.m      (LM)
%     - dibujo_fit_nyquist_conjunto_seleccion_ponderado_PSO.m  (PSO)
%     - dibujo_fit_nyquist_conjunto_seleccion_ponderado_DE.m   (DE)
%     - dibujo_fit_nyquist_conjunto_seleccion_ponderado_GA.m   (GA)
%     - plot_nyquist_tabs_mejorado.m                           (Bode 100)
%
%   USO:
%     tabla = comparison_fitting_methods()
%     tabla = comparison_fitting_methods(rutaCarpeta)
%     tabla = comparison_fitting_methods(rutaCarpeta, ruta_csv_bode)
%     tabla = comparison_fitting_methods(rutaCarpeta, ruta_csv_bode, ciclo_elegido)
%
%   ENTRADAS (todas opcionales):
%     rutaCarpeta   : carpeta con los archivos CICLO*.xlsx crudos (default: pwd)
%     ruta_csv_bode : ruta al CSV de parámetros del Bode 100, con columnas
%                     Ciclo;Archivo;L0_H;R0_Ohm;R1_Ohm;C1_F;R2_Ohm;C2_F
%                     (default: Beatriz\BATERÍA 1 CARGAS LARGAS\Ciclos con bode\output_CARGAS.csv)
%     ciclo_elegido : índice de ciclo a comparar (el mismo número que
%                     aparece en el nombre CICLOx...). Si se omite, se
%                     elige al azar entre los ciclos disponibles a la vez
%                     en la carpeta y en el CSV.
%
%   SALIDA:
%     tabla_comparacion : tabla con parámetros (R0,R1,C1,R2,C2,L0), RMSE y
%                          error relativo medio de cada método.

    if nargin < 1 || isempty(rutaCarpeta)
        rutaCarpeta = pwd;
    end
    if nargin < 2 || isempty(ruta_csv_bode)
        ruta_csv_bode = 'C:\your_route\your_file.csv';
    end
    if nargin < 3
        ciclo_elegido = [];
    end

    %% ==================== 1. LOCALIZAR CICLO A COMPARAR ====================
    archivos = dir(fullfile(rutaCarpeta, 'CICLO*.xlsx'));
    archivos = archivos(~contains({archivos.name}, {'Parametros', 'Errores', 'Resultados'}));
    if isempty(archivos)
        error('No se encontraron archivos CICLO*.xlsx en: %s', rutaCarpeta);
    end

    T_bode = readtable(ruta_csv_bode, 'Delimiter', ';');
    % Por si las columnas numéricas se leyeron como texto (locale con coma decimal)
    varNames = T_bode.Properties.VariableNames;
    for vi = 1:numel(varNames)
        col = T_bode.(varNames{vi});
        if iscell(col)
            numCol = str2double(strrep(col, ',', '.'));
            if ~all(isnan(numCol))
                T_bode.(varNames{vi}) = numCol;
            end
        end
    end
    ciclos_csv = T_bode.Ciclo;

    ciclos_disponibles = [];
    nombre_por_ciclo = containers.Map('KeyType', 'double', 'ValueType', 'char');
    for k = 1:numel(archivos)
        tok = regexp(archivos(k).name, '\d+', 'match');
        if isempty(tok)
            continue;
        end
        c = str2double(tok{1});
        if ismember(c, ciclos_csv)
            ciclos_disponibles(end+1) = c; %#ok<AGROW>
            nombre_por_ciclo(c) = archivos(k).name;
        end
    end
    ciclos_disponibles = unique(ciclos_disponibles);

    if isempty(ciclos_disponibles)
        error('Ningún archivo CICLO*.xlsx de "%s" tiene su ciclo correspondiente en el CSV del Bode 100.', rutaCarpeta);
    end

    if isempty(ciclo_elegido)
        ciclo_elegido = ciclos_disponibles(randi(numel(ciclos_disponibles)));
        fprintf('Ciclo elegido aleatoriamente: %d\n', ciclo_elegido);
    elseif ~ismember(ciclo_elegido, ciclos_disponibles)
        error('El ciclo %d no está disponible a la vez en la carpeta y en el CSV.', ciclo_elegido);
    end

    nombreArchivo = nombre_por_ciclo(ciclo_elegido);
    rutaCompleta  = fullfile(rutaCarpeta, nombreArchivo);
    fprintf('Archivo de datos experimentales: %s\n', nombreArchivo);

    %% ==================== 2. DATOS EXPERIMENTALES CRUDOS ====================
    data = readmatrix(rutaCompleta, 'Range', 'A2');
    if size(data, 2) < 3
        error('El archivo "%s" no tiene al menos 3 columnas.', nombreArchivo);
    end
    f_raw = data(:,1);
    R_raw = data(:,2);
    X_raw = data(:,3);
    idx_val = ~isnan(f_raw) & ~isnan(R_raw) & ~isnan(X_raw);
    f_raw = f_raw(idx_val);
    R_raw = R_raw(idx_val);
    X_raw = X_raw(idx_val);

    % Puntos experimentales que se muestran en la gráfica (corte estándar 1 MHz)
    idx_exp = f_raw < 1e6;
    f_exp = f_raw(idx_exp);
    R_exp = R_raw(idx_exp);
    X_exp = X_raw(idx_exp);

    %% ==================== 3. MODELO DE CIRCUITO EQUIVALENTE ====================
    % x = [R0, R1, C1, R2, C2, L0]
    z_model = @(x, w) x(1) + x(6)*1i*w + ...
                      x(2)./(1 + 1i*w*x(2)*x(3)) + ...
                      x(4)./(1 + 1i*w*x(4)*x(5));

    %% ==================== 4-7. AJUSTES CON LOS 4 ALGORITMOS ====================
    fprintf('\nAjustando con LM...\n');
    [x_LM, rmse_LM, err_LM] = ajustar_LM(f_raw, R_raw, X_raw, z_model);

    fprintf('Ajustando con PSO...\n');
    [x_PSO, rmse_PSO, err_PSO] = ajustar_PSO(f_raw, R_raw, X_raw, z_model);

    fprintf('Ajustando con DE...\n');
    [x_DE, rmse_DE, err_DE] = ajustar_DE(f_raw, R_raw, X_raw, z_model);

    fprintf('Ajustando con GA...\n');
    [x_GA, rmse_GA, err_GA] = ajustar_GA(f_raw, R_raw, X_raw, z_model);

    %% ==================== 8. PARÁMETROS DEL BODE 100 (SIN AJUSTE) ====================
    fila_bode = T_bode(T_bode.Ciclo == ciclo_elegido, :);
    if height(fila_bode) > 1
        fila_bode = fila_bode(1,:);
    end
    x_Bode = [fila_bode.R0_Ohm, fila_bode.R1_Ohm, fila_bode.C1_F, ...
              fila_bode.R2_Ohm, fila_bode.C2_F, fila_bode.L0_H];

    w_plot = 2*pi*f_exp;
    Z_exp_ref = (-R_exp) + 1i*(-X_exp);   % misma convención de signos que los 4 ajustes

    Z_Bode = z_model(x_Bode, w_plot);
    rmse_Bode = sqrt(mean(abs(Z_Bode - Z_exp_ref).^2));
    err_Bode  = mean(abs(Z_Bode - Z_exp_ref) ./ (abs(Z_exp_ref) + eps)) * 100;

    %% ==================== 9. GRÁFICA CONJUNTA ====================
    Z_LM  = z_model(x_LM,  w_plot);
    Z_PSO = z_model(x_PSO, w_plot);
    Z_DE  = z_model(x_DE,  w_plot);
    Z_GA  = z_model(x_GA,  w_plot);

    figure('Name', sprintf('Comparación de métodos - Ciclo %d', ciclo_elegido), ...
           'Color', 'w', 'Position', [100 100 900 750]);
    hold on; grid on; box on; axis equal;
    xlabel('Z_{real} (\Omega)');
    ylabel('-Z_{imaginaria} (\Omega)');
    title(sprintf('Diagrama de Nyquist - Comparación de métodos (Ciclo %d)', ciclo_elegido));

    plot(-R_exp, X_exp, 'ko', 'MarkerSize', 5, 'MarkerFaceColor', 'k', ...
         'DisplayName', 'Datos experimentales');

    plot(real(Z_LM),  -imag(Z_LM),  '-',  'LineWidth', 2,   'Color', [0.000 0.447 0.741], 'DisplayName', 'Ajuste LM (ponderado)');
    plot(real(Z_PSO), -imag(Z_PSO), '--', 'LineWidth', 2,   'Color', [0.850 0.325 0.098], 'DisplayName', 'Ajuste PSO (ponderado)');
    plot(real(Z_DE),  -imag(Z_DE),  '-.', 'LineWidth', 2,   'Color', [0.466 0.674 0.188], 'DisplayName', 'Ajuste DE (ponderado)');
    plot(real(Z_GA),  -imag(Z_GA),  ':',  'LineWidth', 2.5, 'Color', [0.494 0.184 0.556], 'DisplayName', 'Ajuste GA (ponderado)');
    plot(real(Z_Bode), -imag(Z_Bode), '-', 'LineWidth', 2,  'Color', [0.929 0.694 0.125], 'DisplayName', 'Bode 100 (parámetros del equipo)');

    legend('Location', 'best');
    hold off;

    %% ==================== 10. TABLA RESUMEN ====================
    Metodo = {'LM (ponderado)'; 'PSO (ponderado)'; 'DE (ponderado)'; 'GA (ponderado)'; 'Bode 100'};
    R0 = [x_LM(1); x_PSO(1); x_DE(1); x_GA(1); x_Bode(1)];
    R1 = [x_LM(2); x_PSO(2); x_DE(2); x_GA(2); x_Bode(2)];
    C1 = [x_LM(3); x_PSO(3); x_DE(3); x_GA(3); x_Bode(3)];
    R2 = [x_LM(4); x_PSO(4); x_DE(4); x_GA(4); x_Bode(4)];
    C2 = [x_LM(5); x_PSO(5); x_DE(5); x_GA(5); x_Bode(5)];
    L0 = [x_LM(6); x_PSO(6); x_DE(6); x_GA(6); x_Bode(6)];
    RMSE = [rmse_LM; rmse_PSO; rmse_DE; rmse_GA; rmse_Bode];
    ErrorRelativoMedio = [err_LM; err_PSO; err_DE; err_GA; err_Bode];

    tabla_comparacion = table(Metodo, R0, R1, C1, R2, C2, L0, RMSE, ErrorRelativoMedio);
    fprintf('\n=== COMPARACIÓN DE MÉTODOS - CICLO %d ===\n', ciclo_elegido);
    disp(tabla_comparacion);

end


% ==================== AJUSTE LM PONDERADO ====================
% (idéntico a dibujo_fit_nyquist_conjunto_seleccion_ponderado.m)
function [x_opt, rmse, error_relativo] = ajustar_LM(f_raw, R_raw, X_raw, z_model)
    f_corte = 1000000;
    idx = f_raw < f_corte;
    f_fit = f_raw(idx);
    R_fit = -R_raw(idx);
    X_fit = -X_raw(idx);

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

    Z_fit_final = z_model(x_opt, w);
    rmse = sqrt(mean(abs(Z_fit_final - Z_exp).^2));
    error_relativo = mean(abs(Z_fit_final - Z_exp) ./ (abs(Z_exp) + eps)) * 100;
end


% ==================== AJUSTE PSO PONDERADO ====================
% (idéntico a dibujo_fit_nyquist_conjunto_seleccion_ponderado_PSO.m)
function [x_opt, rmse, error_relativo] = ajustar_PSO(f_raw, R_raw, X_raw, z_model)
    f_corte = 1000000;
    idx = f_raw < f_corte;
    f_fit = f_raw(idx);
    R_fit = -R_raw(idx);
    X_fit = -X_raw(idx);

    w = 2*pi*f_fit;
    Z_exp = R_fit + 1i*X_fit;
    mod_Z = abs(Z_exp) + eps;

    objective = @(x) sum( abs( z_model(x, w) - Z_exp ).^2 ./ mod_Z.^2 );

    [~, idx_R0] = min(abs(X_fit));
    R0_est = R_fit(idx_R0);
    deltaR = max(R_fit) - R0_est;
    if deltaR <= 0
        deltaR = max(R_fit) - min(R_fit);
    end
    if deltaR <= 0
        deltaR = 1e-3;
    end

    lb = [R0_est*0.8, deltaR*0.01, 1e-5, deltaR*0.01, 1e-5, 6e-08];
    ub = [R0_est*1.2, deltaR,       1,    deltaR,       1,    1   ];

    options = optimoptions('particleswarm', ...
        'Display',             'off', ...
        'SwarmSize',           150, ...
        'MaxIterations',       400, ...
        'FunctionTolerance',   1e-9, ...
        'UseParallel',         false);

    x_opt = particleswarm(objective, 6, lb, ub, options);

    Z_fit = z_model(x_opt, w);
    residual = [real(Z_exp) - real(Z_fit); imag(Z_exp) - imag(Z_fit)];
    resnorm = sum(residual.^2);
    rmse = sqrt(resnorm / length(Z_exp));
    error_relativo = mean(abs(residual) ./ (abs([real(Z_exp); imag(Z_exp)]) + eps)) * 100;
end


% ==================== AJUSTE DE PONDERADO ====================
% (idéntico a dibujo_fit_nyquist_conjunto_seleccion_ponderado_DE.m,
%  incluido su corte de frecuencia propio de 100 kHz)
function [x_opt, rmse, error_relativo] = ajustar_DE(f_raw, R_raw, X_raw, z_model)
    idx = f_raw < 1e5;
    f_fit = f_raw(idx);
    R_plot = -R_raw(idx);
    X_plot = -X_raw(idx);

    w = 2*pi*f_fit;
    Z_exp = R_plot + 1i*X_plot;
    mod_Z = abs(Z_exp) + eps;

    [~, idx_R0] = min(abs(X_plot));
    R0_est = R_plot(idx_R0);
    deltaR = max(R_plot) - R0_est;
    if deltaR <= 0
        deltaR = max(R_plot) - min(R_plot);
    end
    if deltaR <= 0
        deltaR = 1e-3;
    end

    lb = [R0_est*0.5, deltaR*0.005, 1e-8, deltaR*0.005, 1e-8, 5e-8];
    ub = [R0_est*1.8, deltaR*1.5,   5,    deltaR*1.5,   5,    8e-5];

    objective = @(x) sum( abs(z_model(x, w) - Z_exp).^2 ./ mod_Z.^2 );

    D = 6; NP = 120; F = 0.75; CR = 0.85; Gmax = 350;

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

    Z_fit = z_model(x_opt, w);
    residual = [real(Z_exp) - real(Z_fit); imag(Z_exp) - imag(Z_fit)];
    resnorm = sum(residual.^2);
    rmse = sqrt(resnorm / length(Z_exp));
    error_relativo = mean(abs(residual) ./ (abs([real(Z_exp); imag(Z_exp)]) + eps)) * 100;
end


% ==================== AJUSTE GA PONDERADO ====================
% (idéntico a dibujo_fit_nyquist_conjunto_seleccion_ponderado_GA.m)
function [x_opt, rmse, error_relativo] = ajustar_GA(f_raw, R_raw, X_raw, z_model)
    f_corte = 1000000;
    idx = f_raw < f_corte;
    f_fit = f_raw(idx);
    R_fit = -R_raw(idx);
    X_fit = -X_raw(idx);

    w = 2*pi*f_fit;
    Z_exp = R_fit + 1i*X_fit;
    mod_Z = abs(Z_exp) + eps;

    [~, idx_R0] = min(abs(X_fit));
    R0_est = R_fit(idx_R0);
    deltaR = max(R_fit) - min(R_fit);

    lb = [R0_est*0.5, deltaR*0.001, 1e-6, deltaR*0.001, 1e-6, 1e-10];
    ub = [R0_est*1.5, deltaR*2,     10,   deltaR*2,     10,   1e-2];

    fitness = @(x) sum( ...
        (real(z_model(x, w)) - real(Z_exp)).^2 ./ mod_Z.^2 + ...
        (imag(z_model(x, w)) - imag(Z_exp)).^2 ./ mod_Z.^2 );

    options_ga = optimoptions('ga', ...
        'PopulationSize', 500, ...
        'MaxGenerations', 400, ...
        'FunctionTolerance', 1e-10, ...
        'ConstraintTolerance', 1e-10, ...
        'CrossoverFraction', 0.85, ...
        'MutationFcn', {@mutationadaptfeasible, 0.15}, ...
        'EliteCount', 25, ...
        'Display', 'off', ...
        'PlotFcn', @gaplotbestf);

    x_opt = ga(fitness, 6, [], [], [], [], lb, ub, [], options_ga);

    Z_fit_final = z_model(x_opt, w);
    rmse = sqrt(mean(abs(Z_fit_final - Z_exp).^2));
    error_relativo = mean(abs(Z_fit_final - Z_exp) ./ (abs(Z_exp) + eps)) * 100;
end
