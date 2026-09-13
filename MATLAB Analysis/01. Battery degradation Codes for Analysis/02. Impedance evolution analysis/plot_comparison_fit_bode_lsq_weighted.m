function plot_comparison_fit_bode_lsq_weighted(rutaCarpetaCiclos)
% Compara parametros del ajuste Bode (metodo 1) vs MATLAB (metodo 2)
% y además grafica los diagramas de Nyquist (experimental y ajuste)
% a partir de los archivos .xlsx de una carpeta de ciclos.
%
% Uso:
%   plot_comparison_fit_bode_lsq_weighted()                  % usa pwd como carpeta de ciclos
%   plot_comparison_fit_bode_lsq_weighted('C:\ruta\a\ciclos') % carpeta de ciclos indicada

    if nargin < 1 || isempty(rutaCarpetaCiclos)
        rutaCarpetaCiclos = pwd;
    end

    ruta_csv_bode     = 'C:\your_route\your_file.csv';
    ruta_excel_matlab = 'C:\your_route\your_file.xlsx';

    ciclos_excluir_bode = [7];    % indices a excluir del CSV Bode (antes de x25)
    ciclos_excluir_mat  = [175];  % ciclos a excluir del Excel MATLAB (ya en x25)

    %% -- METODO 1: Bode (CSV) --
    T_bode = readtable(ruta_csv_bode, 'Delimiter', ';');
    T_bode = T_bode(~ismember(T_bode.Ciclo, ciclos_excluir_bode), :);

    ciclos_bode = T_bode.Ciclo * 25;
    R0_b = T_bode.R0_Ohm;
    R1_b = T_bode.R1_Ohm;
    C1_b = T_bode.C1_F;
    R2_b = T_bode.R2_Ohm;
    C2_b = T_bode.C2_F;
    L0_b = T_bode.L0_H;

    %% -- METODO 2: MATLAB (Excel) --
    T_mat = readtable(ruta_excel_matlab);
    T_mat = T_mat(~ismember(T_mat.Ciclo, ciclos_excluir_mat), :);

    ciclos_mat = T_mat.Ciclo;
    R0_m = T_mat.R0_Ohm;
    R1_m = T_mat.R1_Ohm;
    C1_m = T_mat.C1_F;
    R2_m = T_mat.R2_Ohm;
    C2_m = T_mat.C2_F;
    L0_m = T_mat.L0_H;

    %% -- GRAFICAS --
    R_b = R0_b + R1_b + R2_b;
    R_m = R0_m + R1_m + R2_m;

    params = { ...
        ciclos_bode, R0_b, ciclos_mat, R0_m, 'R0', 'R0 (Ohm)'; ...
        ciclos_bode, R1_b, ciclos_mat, R1_m, 'R1', 'R1 (Ohm)'; ...
        ciclos_bode, R2_b, ciclos_mat, R2_m, 'R2', 'R2 (Ohm)'; ...
        ciclos_bode, C1_b*1e6, ciclos_mat, C1_m*1e6, 'C1', 'C1 (uF)'; ...
        ciclos_bode, C2_b*1e6, ciclos_mat, C2_m*1e6, 'C2', 'C2 (uF)'; ...
        ciclos_bode, L0_b*1e9, ciclos_mat, L0_m*1e9, 'L0', 'L0 (nH)'; ...
        ciclos_bode, R_b,      ciclos_mat, R_m,       'R (R0+R1+R2)', 'R total (Ohm)'; ...
    };

    xticks_v   = 25:25:375;
    color_bode = [0 0.447 0.741];
    color_mat  = [0.929 0.694 0.125];

    for i = 1:size(params, 1)
        x_b  = params{i,1};  y_b  = params{i,2};
        x_m  = params{i,3};  y_m  = params{i,4};
        nom  = params{i,5};  etiq = params{i,6};

        figure('Name', ['Comparacion ', nom], 'Color', 'w');
        hold on;
        plot(x_b, y_b, 'o-',  'LineWidth', 1.8, 'MarkerSize', 6, ...
            'Color', color_bode, 'DisplayName', 'Metodo 1 (Bode)');
        plot(x_m, y_m, 's-', 'LineWidth', 1.8, 'MarkerSize', 6, ...
            'Color', color_mat,  'DisplayName', 'Metodo 2 (MATLAB)');
        hold off;
        grid on;
        xlabel('Ciclo');
        ylabel(etiq);
        title(['Evolucion de ', nom]);
        set(gca, 'XTick', xticks_v);
        legend('Location', 'best');
    end

    %% -- NYQUIST DESDE LOS ARCHIVOS .xlsx DE LA CARPETA (SOLO NYQUIST) --
    % Ciclos a excluir de las gráficas de Nyquist (editar aquí a mano):
    ciclos_excluir_nyquist = [25, 50, 75, 125, 150, 225, 250, 275, 325, 350, 175];

    graficar_nyquist_exp_y_ajuste(rutaCarpetaCiclos, ciclos_excluir_nyquist);

    %% -- FIGURA 3: NYQUIST A PARTIR DEL METODO 2 (MATLAB, Excel ya cargado en T_mat) --
    graficar_nyquist_metodo2(ciclos_mat, L0_m, R0_m, R1_m, C1_m, R2_m, C2_m, ciclos_excluir_nyquist, color_mat);

end

% ==================== FUNCION AUXILIAR: NYQUIST DEL METODO 2 (MATLAB/EXCEL) ====================
function graficar_nyquist_metodo2(ciclos, L0, R0, R1, C1, R2, C2, ciclos_excluir, ~)
% Reconstruye Z(f) = sL0 + R0 + R1/(1+sR1C1) + R2/(1+sR2C2) para cada
% ciclo del Metodo 2 (parametros ya cargados desde el Excel, T_mat) y
% dibuja todos los ciclos juntos en un unico diagrama de Nyquist, con un
% color distinto por ciclo (mismo esquema de colores que en las figuras
% de Nyquist experimental/ajuste: lines()).

    f = logspace(-2, 6, 400);     % 0.01 Hz a 1 MHz
    s = 1j * 2 * pi * f;

    figure('Name', 'Nyquist - Metodo 2 (MATLAB/Excel)', 'Color', 'w');
    hold on; grid on; box on; axis equal;
    xlabel('Z_{real} (\Omega)');
    ylabel('-Z_{imaginaria} (\Omega)');
    title('Diagrama de Nyquist - Metodo 2 (MATLAB/Excel)');

    leyenda = {};
    ciclos_ya_graficados = [];   % evita duplicados (mismo ciclo repetido en la tabla)

    for c = 1:numel(ciclos)
        ciclo = ciclos(c);

        if ismember(ciclo, ciclos_excluir)
            continue;
        end

        if ismember(ciclo, ciclos_ya_graficados)
            continue;   % ciclo duplicado en T_mat: se omite
        end

        Z_L  = s * L0(c);
        Z_R0 = R0(c) * ones(size(s));

        Z_RC1 = zeros(size(s));
        if abs(R1(c)) > 1e-12 && abs(C1(c)) > 1e-12
            Z_RC1 = R1(c) ./ (1 + s .* R1(c) .* C1(c));
        end

        Z_RC2 = zeros(size(s));
        if abs(R2(c)) > 1e-12 && abs(C2(c)) > 1e-12
            Z_RC2 = R2(c) ./ (1 + s .* R2(c) .* C2(c));
        end

        Z = Z_L + Z_R0 + Z_RC1 + Z_RC2;

        color_ciclo = obtener_color_ciclo(ciclo);
        plot(real(Z), -imag(Z), '-', 'LineWidth', 1.8, 'Color', color_ciclo);
        leyenda{end+1} = sprintf('CICLO %d', ciclo); %#ok<AGROW>
        ciclos_ya_graficados(end+1) = ciclo; %#ok<AGROW>
    end

    if ~isempty(leyenda)
        legend(leyenda, 'Location', 'best');
    end
    hold off;

end

% ==================== FUNCION AUXILIAR: COLOR FIJO POR CICLO ====================
function colore = obtener_color_ciclo(ciclo)
% Asigna un color fijo segun el numero de ciclo, para que el mismo
% ciclo siempre tenga el mismo color (amarillo=100, rosa=200, morado=300).
    switch ciclo
        case 100
            colore = [0.929 0.694 0.125];   % amarillo
        case 200
            colore = [0.780 0.082 0.522];   % rosa oscuro (mediumvioletred)
        case 300
            colore = [0.494 0.184 0.556];   % morado
        otherwise
            colore = [0.500 0.500 0.500];   % gris (por si hay otro ciclo no previsto)
    end
end

% ==================== FUNCION AUXILIAR: NYQUIST EXPERIMENTAL + AJUSTE ====================
function graficar_nyquist_exp_y_ajuste(rutaCarpeta, ciclos_excluir)
% Para cada archivo .xlsx de rutaCarpeta (mismo formato y mismo ajuste
% ponderado que en dibujo_fit_nyquist_conjunto_seleccion_ponderado),
% dibuja DOS figuras separadas:
%   Figura 1: Nyquist EXPERIMENTAL (R, X directamente del Excel)
%   Figura 2: Nyquist del AJUSTE (modelo L0-R0-(R1//C1)-(R2//C2))
% Los ciclos incluidos en ciclos_excluir no se grafican en ninguna de
% las dos figuras.

    archivos = dir(fullfile(rutaCarpeta, '*.xlsx'));
    if isempty(archivos)
        error('No se encontraron archivos .xlsx en la carpeta: %s', rutaCarpeta);
    end

    colores = lines(length(archivos));

    % -- Figura 1: Nyquist experimental --
    fig_exp = figure('Name', 'Nyquist experimental (datos .xlsx)', 'Color', 'w');
    ax_exp = axes(fig_exp);
    hold(ax_exp, 'on'); grid(ax_exp, 'on'); axis(ax_exp, 'equal');
    xlabel(ax_exp, 'Z_{real} (\Omega)');
    ylabel(ax_exp, '-Z_{imaginaria} (\Omega)');
    title(ax_exp, 'Diagrama de Nyquist experimental');
    leyenda_exp = {};

    % -- Figura 2: Nyquist del ajuste --
    fig_fit = figure('Name', 'Nyquist del ajuste', 'Color', 'w');
    ax_fit = axes(fig_fit);
    hold(ax_fit, 'on'); grid(ax_fit, 'on'); axis(ax_fit, 'equal');
    xlabel(ax_fit, 'Z_{real} (\Omega)');
    ylabel(ax_fit, '-Z_{imaginaria} (\Omega)');
    title(ax_fit, 'Diagrama de Nyquist del ajuste');
    leyenda_fit = {};
    ciclos_ya_graficados = [];   % evita duplicados (mismo ciclo en dos archivos distintos)

    for k = 1:length(archivos)
        nombreArchivo = archivos(k).name;
        rutaCompleta = fullfile(rutaCarpeta, nombreArchivo);
        ciclo_match = regexp(nombreArchivo, '\d+', 'match');

        if ~isempty(ciclo_match)
            ciclo = str2double(ciclo_match{1}) * 25;
        else
            ciclo = NaN;
        end

        if ismember(ciclo, ciclos_excluir)
            continue;   % ciclo excluido: no se ajusta ni se grafica
        end

        if ismember(ciclo, ciclos_ya_graficados)
            fprintf('Aviso: "%s" corresponde al ciclo %d, que ya se ha graficado con otro archivo. Se omite.\n', ...
                nombreArchivo, ciclo);
            continue;   % ciclo duplicado (otro archivo con el mismo numero de ciclo): se omite
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

            % Semilla y límites para cada parámetro (ajustar si hace falta)
            x0 = [R0_est*0.3, deltaR*0.001, 0.01, max(mean(R_fit) - deltaR*0.001, 1e-6), 0.01, 1e-09];
            lb = [R0_est, deltaR*0.01, 1e-5, deltaR*0.01, 1e-5, 1e-09];
            ub = [R0_est, deltaR, 1, deltaR, 1, 1e-01];

            options = optimoptions('lsqcurvefit', ...
                'Algorithm', 'levenberg-marquardt', ...
                'Display', 'off', ...
                'FunctionTolerance', 1e-15, ...
                'StepTolerance', 1e-15);

            [x_opt, ~, ~] = lsqcurvefit(fit_func, x0, w, y_data, lb, ub, options);

            Z_fit = z_model(x_opt, w);

            etiqueta_ciclo = sprintf('CICLO %d', ciclo);

            % -- Plot experimental (figura 1) --
            h_exp = plot(ax_exp, -R, X, 'o-', 'LineWidth', 1.2, 'MarkerSize', 4, ...
                'Color', colores(k,:), 'MarkerFaceColor', colores(k,:));
            h_exp.DataTipTemplate.DataTipRows(end+1) = dataTipTextRow('Archivo', ...
                repmat({nombreArchivo}, length(R), 1));
            leyenda_exp{end+1} = etiqueta_ciclo; %#ok<AGROW>

            % -- Plot ajuste (figura 2) --
            h_fit = plot(ax_fit, real(Z_fit), -imag(Z_fit), '-', 'LineWidth', 2, ...
                'Color', colores(k,:));
            h_fit.DataTipTemplate.DataTipRows(end+1) = dataTipTextRow('Archivo', ...
                repmat({nombreArchivo}, length(R_fit), 1));
            leyenda_fit{end+1} = etiqueta_ciclo; %#ok<AGROW>

            ciclos_ya_graficados(end+1) = ciclo; %#ok<AGROW>

        catch ME
            fprintf('Error en "%s": %s\n', nombreArchivo, ME.message);
        end
    end

    if ~isempty(leyenda_exp)
        legend(ax_exp, leyenda_exp, 'Location', 'best');
    end
    if ~isempty(leyenda_fit)
        legend(ax_fit, leyenda_fit, 'Location', 'best');
    end

    hold(ax_exp, 'off');
    hold(ax_fit, 'off');

end
