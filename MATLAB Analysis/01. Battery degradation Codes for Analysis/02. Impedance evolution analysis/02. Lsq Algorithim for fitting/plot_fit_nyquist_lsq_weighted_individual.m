function [tabla_carga, tabla_descarga] = plot_fit_nyquist_lsq_weighted_individual(rutaCarpeta)

    if nargin < 1 || isempty(rutaCarpeta)
        rutaCarpeta = pwd;
    end

    ciclos_excluir = [1, 2, 3, 4, 6, 7, 8, 9, 55, 60, 40,11, 10, 12, 13, 14, 15, 16, 18, 19, 21, 22, 23, 25, 26, 27, 28, 29, 31, 33, 34, 36, 35, 37, 38, 39, 41, 42, 43, 44, 46, 47, 48, 49,50, 51, 52, 53 54, 56, 57, 59, 61, 62, 63, 64, 65, 66, 45,20, 68, 30];

    arch_carga    = dir(fullfile(rutaCarpeta, 'CICLO*_CARGA_*.xlsx'));
    arch_descarga = dir(fullfile(rutaCarpeta, 'CICLO*_DESCARGA_*.xlsx'));

    if isempty(arch_carga) && isempty(arch_descarga)
        error('No se encontraron archivos CICLO*_CARGA_*.xlsx ni CICLO*_DESCARGA_*.xlsx en:\n%s', rutaCarpeta);
    end

    fprintf('Encontrados: %d archivos de CARGA, %d de DESCARGA\n\n', numel(arch_carga), numel(arch_descarga));

    tabla_carga    = procesar_tipo(arch_carga,    rutaCarpeta, 'CARGA',    ciclos_excluir);
    tabla_descarga = procesar_tipo(arch_descarga, rutaCarpeta, 'DESCARGA', ciclos_excluir);

    % Excel con dos hojas
    nombreExcel = fullfile(pwd, 'Parametros_Nyquist_Ajuste_mincuadpond.xlsx');
    if ~isempty(tabla_carga)
        writetable(preparar_tabla_excel(tabla_carga),    nombreExcel, 'Sheet', 'Carga');
    end
    if ~isempty(tabla_descarga)
        writetable(preparar_tabla_excel(tabla_descarga), nombreExcel, 'Sheet', 'Descarga');
    end
    fprintf('\nExcel guardado en: %s\n', nombreExcel);

    % Graficas comparativas CARGA vs DESCARGA por parametro
    if ~isempty(tabla_carga) && ~isempty(tabla_descarga)
        graficar_comparacion(tabla_carga, tabla_descarga, ciclos_excluir);
    elseif ~isempty(tabla_carga)
        graficar_individual(tabla_carga, 'CARGA', ciclos_excluir);
    elseif ~isempty(tabla_descarga)
        graficar_individual(tabla_descarga, 'DESCARGA', ciclos_excluir);
    end
end


% =========================================================================
function tabla = procesar_tipo(archivos, rutaCarpeta, tipo, ciclos_excluir)

    if isempty(archivos)
        tabla = table();
        return;
    end

    ciclos_vistos = [];
    % Antes: colores = hsv(length(archivos)), es decir, el mapa de color se
    % dimensionaba con el numero TOTAL de archivos (todos los ciclos,
    % tipicos y atipicos), pero solo se dibujan unos pocos (los no
    % excluidos). hsv() reparte los tonos linealmente entre 0 y 1 a lo
    % largo de N filas, asi que si N es grande (p.ej. 60 archivos) y solo
    % se cogen las primeras 4-6 filas (plot_idx = 1,2,3,4...), esas filas
    % caen todas muy juntas al principio del espectro (todas rojas/
    % naranjas), que es justo lo que se veia en la grafica. La solucion es
    % dimensionar el mapa de color con el numero de ciclos que se van a
    % DIBUJAR de verdad (n_tipicos), no con el total de archivos, para que
    % los pocos colores usados se repartan por todo el espectro.
    ciclos_detectados = [];
    for kk = 1:length(archivos)
        m = regexp(archivos(kk).name, '\d+', 'match');
        if ~isempty(m)
            c = str2double(m{1});
            if ~ismember(c, ciclos_detectados)
                ciclos_detectados(end+1) = c; %#ok<AGROW>
            end
        end
    end
    n_tipicos = sum(~ismember(ciclos_detectados, ciclos_excluir));
    if n_tipicos < 1, n_tipicos = 1; end
    colores  = hsv(n_tipicos);
    plot_idx = 0;

    % --- 3 figuras de Nyquist por tipo ---
    fig_conjunto = figure('Name', ['Nyquist Conjunto (exp+modelo) — ' tipo], 'Color', 'w');
    hold on; grid on; axis equal;
    xlabel('Z_{real} (\Omega)'); ylabel('-Z_{imag} (\Omega)');
    title(['Nyquist exp + modelo — ' tipo]);

    fig_exp = figure('Name', ['Nyquist Experimental — ' tipo], 'Color', 'w');
    hold on; grid on; axis equal;
    xlabel('Z_{real} (\Omega)'); ylabel('-Z_{imag} (\Omega)');
    title(['Nyquist Experimental — ' tipo]);

    fig_mod = figure('Name', ['Nyquist Modelo — ' tipo], 'Color', 'w');
    hold on; grid on; axis equal;
    xlabel('Z_{real} (\Omega)'); ylabel('-Z_{imag} (\Omega)');
    title(['Nyquist Modelo — ' tipo]);

    ciclos           = [];
    R0_all           = [];
    R1_all           = [];
    C1_all           = [];
    R2_all           = [];
    C2_all           = [];
    L0_all           = [];
    resnorm_all      = [];
    rmse_all         = [];
    error_rel_all    = [];
    nombres_archivo  = {};
    ley_conj = {}; ley_exp = {}; ley_mod = {};

    for k = 1:length(archivos)
        nombreArchivo = archivos(k).name;
        rutaCompleta  = fullfile(rutaCarpeta, nombreArchivo);

        ciclo_match = regexp(nombreArchivo, '\d+', 'match');
        if ~isempty(ciclo_match)
            ciclo = str2double(ciclo_match{1});
        else
            ciclo = NaN;
        end

        if ~isnan(ciclo)
            if ismember(ciclo, ciclos_vistos)
                fprintf('[%s] Omitido "%s": ciclo %d ya procesado.\n', tipo, nombreArchivo, ciclo);
                continue;
            end
            ciclos_vistos(end+1) = ciclo; %#ok<AGROW>
        end

        es_atipico = ismember(ciclo, ciclos_excluir);

        try
            data = readmatrix(rutaCompleta, 'Range', 'A2');
            if size(data,2) < 3, error('Menos de 3 columnas.'); end

            idx_buenos = data(:,1) < 1e6;
            f = data(idx_buenos, 1);
            R = data(idx_buenos, 2);
            X = data(idx_buenos, 3);
            if numel(f) < 5, error('Datos insuficientes.'); end

            R_fit = -R;  X_fit = -X;
            w     = 2*pi*f;
            Z_exp = R_fit + 1i*X_fit;
            mod_Z = abs(Z_exp) + eps;

            z_model = @(x, w) x(1) + x(6)*1i*w + ...
                               x(2)./(1 + 1i*w*x(2)*x(3)) + ...
                               x(4)./(1 + 1i*w*x(4)*x(5));

            fit_func = @(x, w) [ ...
                (real(z_model(x,w)) - real(Z_exp)) ./ (mod_Z.^2); ...
                (imag(z_model(x,w)) - imag(Z_exp)) ./ (mod_Z.^2) ];

            y_data = zeros(2*numel(Z_exp), 1);

            [~, idx_R0] = min(abs(X_fit));
            R0_est = R_fit(idx_R0);
            deltaR = max(R_fit) - R0_est;
            if deltaR <= 0, deltaR = max(R_fit) - min(R_fit); end
            if deltaR <= 0, deltaR = 1e-3; end

            x0 = [R0_est*0.3, deltaR*0.001, 0.01, max(mean(R_fit)-deltaR*0.001,1e-6), 0.01, 1e-09];
            lb = [R0_est, deltaR*0.01, 1e-5, deltaR*0.01, 1e-5, 1e-09];
            ub = [R0_est, deltaR,      1,    deltaR,       1,    1e-01];

            opts = optimoptions('lsqcurvefit', 'Algorithm', 'levenberg-marquardt', ...
                'Display', 'off', 'FunctionTolerance', 1e-15, 'StepTolerance', 1e-15);

            [x_opt, resnorm, ~] = lsqcurvefit(fit_func, x0, w, y_data, lb, ub, opts);

            R0 = x_opt(1); R1 = x_opt(2); C1 = x_opt(3);
            R2 = x_opt(4); C2 = x_opt(5); L0 = x_opt(6);

            Z_fit_final    = z_model(x_opt, w);
            rmse           = sqrt(mean(abs(Z_fit_final - Z_exp).^2));
            error_relativo = mean(abs(Z_fit_final - Z_exp)./(abs(Z_exp)+eps))*100;

            % Curva fina para figura modelo
            % (antes: linspace(min(w), max(w), 500) -> subsampleaba la
            % parte baja del barrido, que es logaritmico, y por eso el
            % segundo arco (R2-C2) salia truncado en "Nyquist Modelo".
            % Con logspace se respeta la distribucion real de frecuencias.)
            w_fino  = logspace(log10(min(w)), log10(max(w)), 500);
            Z_fino  = z_model(x_opt, w_fino);

            ciclos(end+1,1)          = ciclo;
            R0_all(end+1,1)          = R0;
            R1_all(end+1,1)          = R1;
            C1_all(end+1,1)          = C1;
            R2_all(end+1,1)          = R2;
            C2_all(end+1,1)          = C2;
            L0_all(end+1,1)          = L0;
            resnorm_all(end+1,1)     = resnorm;
            rmse_all(end+1,1)        = rmse;
            error_rel_all(end+1,1)   = error_relativo;
            nombres_archivo{end+1,1} = nombreArchivo;

            if ~es_atipico
                plot_idx = plot_idx + 1;
                col  = colores(plot_idx,:);
                etiq = sprintf('Ciclo %d', ciclo);

                % Figura conjunto
                figure(fig_conjunto);
                plot(-R, X, 'o-', 'LineWidth',1.2,'MarkerSize',3,'Color',col,'MarkerFaceColor',col,'DisplayName',[etiq ' exp']);
                plot(real(Z_fit_final), -imag(Z_fit_final), '-', 'LineWidth',2,'Color',col,'DisplayName',[etiq ' fit']);
                ley_conj{end+1} = [etiq ' exp']; %#ok<AGROW>
                ley_conj{end+1} = [etiq ' fit']; %#ok<AGROW>

                % Figura experimental
                figure(fig_exp);
                plot(-R, X, 'o-', 'LineWidth',1.2,'MarkerSize',3,'Color',col,'MarkerFaceColor',col,'DisplayName',etiq);
                ley_exp{end+1} = etiq; %#ok<AGROW>

                % Figura modelo
                figure(fig_mod);
                plot(real(Z_fino), -imag(Z_fino), '-', 'LineWidth',1.8,'Color',col,'DisplayName',etiq);
                ley_mod{end+1} = etiq; %#ok<AGROW>
            end

            fprintf('[%s] Ciclo %2d | R0=%.4f R1=%.4f C1=%.2e R2=%.4f C2=%.2e L0=%.2e | RMSE=%.3e ErrRel=%.2f%%\n', ...
                tipo, ciclo, R0, R1, C1, R2, C2, L0, rmse, error_relativo);

        catch ME
            fprintf('[%s] Error en "%s": %s\n', tipo, nombreArchivo, ME.message);
        end
    end

    figure(fig_conjunto); legend(ley_conj,'Location','best'); hold off;
    figure(fig_exp);      legend(ley_exp, 'Location','best'); hold off;
    figure(fig_mod);      legend(ley_mod, 'Location','best'); hold off;

    if isempty(ciclos)
        tabla = table();
        return;
    end

    tabla = table(ciclos, R0_all, R1_all, C1_all, R2_all, C2_all, L0_all, ...
                  resnorm_all, rmse_all, error_rel_all, nombres_archivo, ...
                  'VariableNames', {'Ciclo','R0','R1','C1','R2','C2','L0', ...
                                    'Resnorm','RMSE','ErrorRelativoMedio','Archivo'});
    tabla = sortrows(tabla, 'Ciclo');

    fprintf('\n=== ESTADISTICAS %s ===\n', tipo);
    fprintf('Media RMSE: %.4e | Media Error Relativo: %.2f%%\n\n', ...
        mean(tabla.RMSE), mean(tabla.ErrorRelativoMedio));
end


% =========================================================================
function t = preparar_tabla_excel(tabla)
    t = table(tabla.Ciclo, tabla.L0, tabla.R0, tabla.R1, tabla.C1, tabla.R2, tabla.C2, ...
              'VariableNames', {'Ciclo','L0_H','R0_Ohm','R1_Ohm','C1_F','R2_Ohm','C2_F'});
end


% =========================================================================
function graficar_comparacion(tabla_c, tabla_d, ciclos_excluir)
    params    = {'R0','R1','C1','R2','C2','L0'};
    etiquetas = {'R0 (\Omega)','R1 (\Omega)','C1 (F)','R2 (\Omega)','C2 (F)','L0 (H)'};
    col_c = [0.00 0.45 0.74];
    col_d = [0.85 0.33 0.10];

    for i = 1:length(params)
        p = params{i};
        idx_c = ~isnan(tabla_c.Ciclo) & ~isnan(tabla_c.(p)) & ~ismember(tabla_c.Ciclo, ciclos_excluir);
        idx_d = ~isnan(tabla_d.Ciclo) & ~isnan(tabla_d.(p)) & ~ismember(tabla_d.Ciclo, ciclos_excluir);

        figure('Name', ['Evolucion ' p ' — Carga vs Descarga'], 'Color', 'w');
        hold on;
        plot(tabla_c.Ciclo(idx_c), tabla_c.(p)(idx_c), 'o-', 'LineWidth',1.5,'MarkerSize',6, ...
            'Color',col_c,'MarkerFaceColor',col_c,'DisplayName','Carga');
        plot(tabla_d.Ciclo(idx_d), tabla_d.(p)(idx_d), 's-', 'LineWidth',1.5,'MarkerSize',6, ...
            'Color',col_d,'MarkerFaceColor',col_d,'DisplayName','Descarga');
        grid on; xlabel('Ciclo'); ylabel(etiquetas{i});
        title(['Evolucion de ' p ' — Carga vs Descarga']);
        legend('Location','best');
        todos = [tabla_c.Ciclo(idx_c); tabla_d.Ciclo(idx_d)];
        if ~isempty(todos), set(gca,'XTick',0:5:max(todos)); end
        hold off;
    end

    % R total
    idx_c = ~ismember(tabla_c.Ciclo, ciclos_excluir);
    idx_d = ~ismember(tabla_d.Ciclo, ciclos_excluir);
    figure('Name','Evolucion R total — Carga vs Descarga','Color','w');
    hold on;
    plot(tabla_c.Ciclo(idx_c), tabla_c.R0(idx_c)+tabla_c.R1(idx_c)+tabla_c.R2(idx_c), 'o-', ...
        'LineWidth',1.5,'MarkerSize',6,'Color',col_c,'MarkerFaceColor',col_c,'DisplayName','Carga');
    plot(tabla_d.Ciclo(idx_d), tabla_d.R0(idx_d)+tabla_d.R1(idx_d)+tabla_d.R2(idx_d), 's-', ...
        'LineWidth',1.5,'MarkerSize',6,'Color',col_d,'MarkerFaceColor',col_d,'DisplayName','Descarga');
    grid on; xlabel('Ciclo'); ylabel('R_{total} (\Omega)');
    title('Evolucion de R total (R0+R1+R2) — Carga vs Descarga');
    legend('Location','best'); hold off;
end


% =========================================================================
function graficar_individual(tabla, tipo, ciclos_excluir)
    params    = {'R0','R1','C1','R2','C2','L0'};
    etiquetas = {'R0 (\Omega)','R1 (\Omega)','C1 (F)','R2 (\Omega)','C2 (F)','L0 (H)'};
    for i = 1:length(params)
        p   = params{i};
        idx = ~isnan(tabla.Ciclo) & ~isnan(tabla.(p)) & ~ismember(tabla.Ciclo, ciclos_excluir);
        figure('Name',['Evolucion ' p ' - ' tipo],'Color','w');
        plot(tabla.Ciclo(idx), tabla.(p)(idx), 'o-','LineWidth',1.5,'MarkerSize',6,'MarkerFaceColor','auto');
        grid on; xlabel('Ciclo'); ylabel(etiquetas{i});
        title(['Evolucion de ' p ' (' tipo ')']);
        if any(idx), set(gca,'XTick',0:5:max(tabla.Ciclo(idx))); end
    end
end