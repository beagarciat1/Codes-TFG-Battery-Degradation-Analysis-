function tabla = Check_RMSE_BODE(rutaCarpeta, rutaCSV)
% Check_RMSE_BODE  Calcula el RMSE del ajuste de Bode (Método 1) comparando los
%            parámetros del circuito equivalente (del CSV de Bode100) con
%            los datos experimentales de EIS (archivos CICLO*.xlsx).
%
% USO:
%   tabla = Check_RMSE_BODE()
%   tabla = Check_RMSE_BODE(rutaCarpeta, rutaCSV)
%
% ENTRADAS (opcionales):
%   rutaCarpeta : carpeta con los archivos CICLO*.xlsx  (default: pwd)
%   rutaCSV     : ruta al archivo output_CARGAS.csv     (default: busca en rutaCarpeta)

    if nargin < 1 || isempty(rutaCarpeta)
        rutaCarpeta = pwd;
    end
    if nargin < 2 || isempty(rutaCSV)
        % Busca el CSV en la misma carpeta
        posibles = dir(fullfile(rutaCarpeta, '*CARGAS*.csv'));
        if isempty(posibles)
            posibles = dir(fullfile(rutaCarpeta, '*.csv'));
        end
        if isempty(posibles)
            error('No se encontró ningún CSV. Especifica la ruta con rutaCSV.');
        end
        rutaCSV = fullfile(rutaCarpeta, posibles(1).name);
    end

    % =====================================================================
    % 1. Leer CSV de parámetros Bode
    % =====================================================================
    fprintf('Leyendo CSV: %s\n', rutaCSV);
    T_params = readtable(rutaCSV, 'Delimiter', ';');

    % Si las columnas numéricas se leyeron como texto (por locale), convertirlas
    varNames = T_params.Properties.VariableNames;
    for vi = 1:length(varNames)
        col = T_params.(varNames{vi});
        if iscell(col)
            numCol = str2double(strrep(col, ',', '.'));
            if ~all(isnan(numCol))
                T_params.(varNames{vi}) = numCol;
            end
        end
    end

    % Nombres esperados de columnas
    % Ciclo ; Archivo ; L0_H ; R0_Ohm ; R1_Ohm ; C1_F ; R2_Ohm ; C2_F
    ciclos_bode  = T_params.Ciclo;
    L0_vec = T_params.L0_H;
    R0_vec = T_params.R0_Ohm;
    R1_vec = T_params.R1_Ohm;
    C1_vec = T_params.C1_F;
    R2_vec = T_params.R2_Ohm;
    C2_vec = T_params.C2_F;

    % =====================================================================
    % 2. Buscar archivos CICLO*.xlsx en la carpeta
    % =====================================================================
    archivos_xlsx = dir(fullfile(rutaCarpeta, '*.xlsx'));
    % Excluir archivos de resultados (no son datos crudos)
    excluir_patron = {'Parametros', 'Resultados', 'MEDIA', 'RMSE'};
    mask = true(length(archivos_xlsx), 1);
    for i = 1:length(archivos_xlsx)
        for p = excluir_patron
            if contains(archivos_xlsx(i).name, p{1})
                mask(i) = false;
            end
        end
    end
    archivos_xlsx = archivos_xlsx(mask);

    if isempty(archivos_xlsx)
        error('No se encontraron archivos CICLO*.xlsx en: %s', rutaCarpeta);
    end

    % =====================================================================
    % 3. Modelo de circuito equivalente (igual que PSO/DE/LM)
    % =====================================================================
    z_model = @(x, w) x(1) + x(6)*1i*w + ...
                      x(2)./(1 + 1i*w*x(2)*x(3)) + ...
                      x(4)./(1 + 1i*w*x(4)*x(5));
    % x = [R0, R1, C1, R2, C2, L0]

    ciclos_excluir = [7];

    % =====================================================================
    % 4. Iterar ciclos del CSV
    % =====================================================================
    ciclos_out  = [];
    rmse_out    = [];
    errrel_out  = [];
    nombres_out = {};

    for idx = 1:length(ciclos_bode)
        n_ciclo = ciclos_bode(idx);

        if ismember(n_ciclo, ciclos_excluir)
            fprintf('Ciclo %d omitido (excluido)\n', n_ciclo);
            continue;
        end

        % Parámetros del ajuste Bode para este ciclo
        x_opt = [R0_vec(idx), R1_vec(idx), C1_vec(idx), ...
                 R2_vec(idx), C2_vec(idx), L0_vec(idx)];

        % Buscar el Excel correspondiente (contiene el número de ciclo)
        archivo_encontrado = '';
        for j = 1:length(archivos_xlsx)
            nums = regexp(archivos_xlsx(j).name, '\d+', 'match');
            if ~isempty(nums) && str2double(nums{1}) == n_ciclo
                archivo_encontrado = fullfile(rutaCarpeta, archivos_xlsx(j).name);
                break;
            end
        end

        if isempty(archivo_encontrado)
            fprintf('Ciclo %d: no se encontró archivo Excel. Saltando.\n', n_ciclo);
            continue;
        end

        try
            % Intentar leer sin rango fijo para ver la estructura real
            data = readmatrix(archivo_encontrado, 'UseExcel', false);

            % Eliminar filas con NaN
            data = data(~any(isnan(data), 2), :);

            fprintf('  [DEBUG] Ciclo %d: %d filas x %d cols leídas\n', n_ciclo, size(data,1), size(data,2));
            fprintf('  [DEBUG] Fila 1 completa: '); fprintf('%.6g  ', data(1,:)); fprintf('\n');
            fprintf('  [DEBUG] Col1(f): %.4g  Col2: %.6g  Col3: %.6g\n', data(1,1), data(1,2), data(1,3));

            f = data(:,1);
            R = data(:,2);
            X = data(:,3);

            idx_val = ~isnan(f) & ~isnan(R) & ~isnan(X) & f < 1e6;
            f = f(idx_val);
            R = R(idx_val);
            X = X(idx_val);

            if numel(f) < 5
                fprintf('Ciclo %d: pocos puntos válidos. Saltando.\n', n_ciclo);
                continue;
            end

            % Convención de signos (igual que PSO/DE/LM)
            R_fit = -R;
            X_fit = -X;
            w = 2*pi*f;
            Z_exp = R_fit + 1i*X_fit;

            % Impedancia del modelo con parámetros Bode
            Z_mod = z_model(x_opt, w);

            % RMSE (misma fórmula que los otros algoritmos)
            residual = [real(Z_exp) - real(Z_mod); imag(Z_exp) - imag(Z_mod)];
            resnorm  = sum(residual.^2);
            rmse     = sqrt(resnorm / length(Z_exp));
            err_rel  = mean(abs(residual) ./ (abs([real(Z_exp); imag(Z_exp)]) + eps)) * 100;

            ciclos_out(end+1,1)  = n_ciclo;
            rmse_out(end+1,1)    = rmse;
            errrel_out(end+1,1)  = err_rel;
            nombres_out{end+1,1} = archivos_xlsx(j).name;

            fprintf('✓ Ciclo %2d | RMSE: %.5f Ohm | Error rel: %.4f %%\n', ...
                    n_ciclo, rmse, err_rel);

        catch ME
            fprintf('ERROR ciclo %d:\n  Archivo: %s\n  Mensaje: %s\n', n_ciclo, archivo_encontrado, ME.message);
        end
    end

    % =====================================================================
    % 5. Tabla y estadísticas
    % =====================================================================
    tabla = table(ciclos_out, rmse_out, errrel_out, nombres_out, ...
        'VariableNames', {'Ciclo', 'RMSE', 'ErrorRelativoMedio', 'Archivo'});
    tabla = sortrows(tabla, 'Ciclo');

    disp(' ');
    disp(tabla);

    fprintf('\n=== ESTADÍSTICAS PROMEDIO (Método 1 - Bode) ===\n');
    fprintf('Media de RMSE             = %.5f Ohm\n', mean(tabla.RMSE));
    fprintf('Media de Error Relativo   = %.4f %%\n',  mean(tabla.ErrorRelativoMedio));

end
