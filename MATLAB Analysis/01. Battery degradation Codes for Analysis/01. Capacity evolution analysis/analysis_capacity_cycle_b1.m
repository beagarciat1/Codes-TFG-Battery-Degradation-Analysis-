% =========================================================
%  ANÁLISIS DE CICLOS DE BATERÍA
%  Extrae filas por rango de Valor_VDC y guarda en tablas
% =========================================================

% --- RUTA DEL ARCHIVO (modifica esta línea) ---
ruta_archivo = 'C:\your_route\your_file.txt';

% --- UMBRALES DE VOLTAJE (en las mismas unidades que el archivo) ---
VDC_alto_umbral = 4200;   % primer valor ESTRICTAMENTE por encima de este
VDC_bajo_umbral = 3000;   % primer valor ESTRICTAMENTE por debajo de este

% =========================================================
%  LECTURA Y PARSEO
% =========================================================
fid = fopen(ruta_archivo, 'r');
if fid == -1
    error('No se pudo abrir el archivo: %s', ruta_archivo);
end

% Preasignar arrays
Ciclo_alto = [];  State_alto = [];  VDC_alto = [];  Carga_alto = [];
Ciclo_bajo = [];  State_bajo = [];  VDC_bajo = [];  Carga_bajo = [];

% Conjuntos de ciclos ya registrados (para guardar solo el primero)
ciclos_alto_vistos = [];
ciclos_bajo_vistos = [];

linea = fgetl(fid);
n_linea = 0;

while ischar(linea)
    n_linea = n_linea + 1;

    % Separar por comas y limpiar espacios
    partes = strtrim(strsplit(linea, ','));

    % Localizar etiquetas
    idx_ciclo = find(strcmp(partes, 'Ciclo'),     1);
    idx_state = find(strcmp(partes, 'State'),     1);
    idx_vdc   = find(strcmp(partes, 'Valor_VDC'), 1);
    idx_carga = find(strcmp(partes, 'Carga_mAh'), 1);

    % Solo procesar si se encuentran todas las etiquetas
    if ~isempty(idx_ciclo) && ~isempty(idx_state) && ...
       ~isempty(idx_vdc)   && ~isempty(idx_carga)

        ciclo = str2double(partes{idx_ciclo + 1});
        state = str2double(partes{idx_state + 1});
        vdc   = str2double(partes{idx_vdc   + 1});
        carga = str2double(partes{idx_carga  + 1});

        % Comprobar que la conversión fue válida
        if ~any(isnan([ciclo, state, vdc, carga]))

            if vdc > VDC_alto_umbral
                % Primer valor estrictamente por encima de 4200 para este ciclo
                if ~ismember(ciclo, ciclos_alto_vistos)
                    ciclos_alto_vistos(end+1) = ciclo;
                    Ciclo_alto(end+1,1) = ciclo;
                    State_alto(end+1,1) = state;
                    VDC_alto(end+1,1)   = vdc;
                    Carga_alto(end+1,1) = carga;
                end

            elseif vdc < VDC_bajo_umbral
                % Primer valor estrictamente por debajo de 3000 para este ciclo
                if ~ismember(ciclo, ciclos_bajo_vistos)
                    ciclos_bajo_vistos(end+1) = ciclo;
                    Ciclo_bajo(end+1,1) = ciclo;
                    State_bajo(end+1,1) = state;
                    VDC_bajo(end+1,1)   = vdc;
                    Carga_bajo(end+1,1) = carga;
                end
            end
        end
    end

    linea = fgetl(fid);
end
fclose(fid);

fprintf('Líneas procesadas: %d\n', n_linea);

% =========================================================
%  CREAR TABLAS
% =========================================================
Tabla_VDC_alto = table(Ciclo_alto, State_alto, VDC_alto, Carga_alto, ...
    'VariableNames', {'Ciclo', 'State', 'Valor_VDC', 'Carga_mAh'});

Tabla_VDC_bajo = table(Ciclo_bajo, State_bajo, VDC_bajo, Carga_bajo, ...
    'VariableNames', {'Ciclo', 'State', 'Valor_VDC', 'Carga_mAh'});

% =========================================================
%  TABLAS CARGA Y DESCARGA
% =========================================================

% Límites para detección de valores atípicos
ATIPICO_MAX = 140;
ATIPICO_MIN = 100;

% -- CARGA: alto(ciclo N) - bajo(ciclo N-1) --
Ciclo_carga  = {};
Delta_carga  = [];

for i = 1:height(Tabla_VDC_alto)
    ciclo_actual   = Tabla_VDC_alto.Ciclo(i);
    ciclo_anterior = ciclo_actual - 1;
    idx_bajo = find(Tabla_VDC_bajo.Ciclo == ciclo_anterior, 1);
    if ~isempty(idx_bajo)
        valor = Tabla_VDC_alto.Carga_mAh(i) - Tabla_VDC_bajo.Carga_mAh(idx_bajo);
        if valor > ATIPICO_MAX || valor < ATIPICO_MIN
            Ciclo_carga{end+1,1} = [num2str(ciclo_actual) '*'];
            Delta_carga(end+1,1) = 0;
        else
            Ciclo_carga{end+1,1} = num2str(ciclo_actual);
            Delta_carga(end+1,1) = valor;
        end
    end
end

Tabla_CARGA = table(Ciclo_carga, Delta_carga, ...
    'VariableNames', {'Ciclo', 'Carga_mAh'});

% -- DESCARGA: alto(ciclo N) - bajo(ciclo N) --
Ciclo_descarga = {};
Delta_descarga = [];

for i = 1:height(Tabla_VDC_alto)
    ciclo_actual = Tabla_VDC_alto.Ciclo(i);
    idx_bajo = find(Tabla_VDC_bajo.Ciclo == ciclo_actual, 1);
    if ~isempty(idx_bajo)
        valor = Tabla_VDC_alto.Carga_mAh(i) - Tabla_VDC_bajo.Carga_mAh(idx_bajo);
        if valor > ATIPICO_MAX || valor < ATIPICO_MIN
            Ciclo_descarga{end+1,1} = [num2str(ciclo_actual) '*'];
            Delta_descarga(end+1,1) = 0;
        else
            Ciclo_descarga{end+1,1} = num2str(ciclo_actual);
            Delta_descarga(end+1,1) = valor;
        end
    end
end

Tabla_DESCARGA = table(Ciclo_descarga, Delta_descarga, ...
    'VariableNames', {'Ciclo', 'Carga_mAh'});

% Añadir fila extra al final con ciclo 25 y valor 0
fila_extra = {'25*', 0};
Tabla_DESCARGA = [Tabla_DESCARGA; fila_extra];

% =========================================================
%  MOSTRAR RESULTADOS EN CONSOLA
% =========================================================
fprintf('\n=== TABLA VOLTAJE ALTO  (primer valor > %.0f por ciclo)  (%d filas) ===\n', ...
    VDC_alto_umbral, height(Tabla_VDC_alto));
disp(Tabla_VDC_alto);

fprintf('\n=== TABLA VOLTAJE BAJO  (primer valor < %.0f por ciclo)  (%d filas) ===\n', ...
    VDC_bajo_umbral, height(Tabla_VDC_bajo));
disp(Tabla_VDC_bajo);

fprintf('\n=== TABLA CARGA  (%d filas) ===\n', height(Tabla_CARGA));
disp(Tabla_CARGA);

fprintf('\n=== TABLA DESCARGA  (%d filas) ===\n', height(Tabla_DESCARGA));
disp(Tabla_DESCARGA);

% =========================================================
%  EXPORTAR A EXCEL (misma carpeta que el archivo de datos)
% =========================================================
[carpeta, nombre_archivo] = fileparts(ruta_archivo);

% Captura "cicloX", "cicloX,Y" o "cicloX_Y" (ej: ciclo4,1 o ciclo4_1 → "4,1")
token = regexp(nombre_archivo, '(?i)ciclo(\d+(?:[,_]\d(?!\d))?)', 'tokens', 'once');
if ~isempty(token)
    num_ciclo = strrep(token{1}, '_', ',');
else
    num_ciclo = 'X';  % fallback si no se encuentra
    warning('No se encontró "cicloX" en el nombre del archivo. Se usará "X".');
end

nombre_cargas    = sprintf('CICLO%s_CARGAS.xlsx',    num_ciclo);
nombre_descargas = sprintf('CICLO%s_DESCARGAS.xlsx', num_ciclo);

writetable(Tabla_CARGA,    fullfile(carpeta, nombre_cargas));
writetable(Tabla_DESCARGA, fullfile(carpeta, nombre_descargas));

fprintf('\nArchivos guardados en: %s\n', carpeta);
fprintf('  -> %s\n', nombre_cargas);
fprintf('  -> %s\n', nombre_descargas);
