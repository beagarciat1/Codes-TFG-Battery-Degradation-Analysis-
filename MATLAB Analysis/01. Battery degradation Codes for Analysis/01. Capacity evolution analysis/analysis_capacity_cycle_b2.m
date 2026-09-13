% =========================================================
%  ANÁLISIS DE CAPACIDAD DE BATERÍA - TIPO 2
%  Máxima carga (State 1) y máxima descarga (State 2) por ciclo
% =========================================================

% --- RUTA DEL ARCHIVO (modifica esta línea) ---
ruta_archivo = 'C:\your_route\your_file.txt';

% =========================================================
%  LECTURA Y PARSEO
% =========================================================
fid = fopen(ruta_archivo, 'r');
if fid == -1
    error('No se pudo abrir el archivo: %s', ruta_archivo);
end

% Diccionarios: clave = ciclo, valor = max/min acumulado
carga_max  = containers.Map('KeyType','int32','ValueType','double');
descarga_min = containers.Map('KeyType','int32','ValueType','double');

linea = fgetl(fid);
n_linea = 0;

while ischar(linea)
    n_linea = n_linea + 1;
    partes = strtrim(strsplit(linea, ','));

    idx_ciclo = find(strcmp(partes, 'Ciclo'),     1);
    idx_state = find(strcmp(partes, 'State'),     1);
    idx_carga = find(strcmp(partes, 'Carga_mAh'), 1);

    if ~isempty(idx_ciclo) && ~isempty(idx_state) && ~isempty(idx_carga)
        ciclo = int32(str2double(partes{idx_ciclo + 1}));
        state = str2double(partes{idx_state + 1});
        carga = str2double(partes{idx_carga  + 1});

        if ~any(isnan([double(ciclo), state, carga]))

            % State 1 = carga → guardar máximo por ciclo
            if state == 1
                if isKey(carga_max, ciclo)
                    if carga > carga_max(ciclo)
                        carga_max(ciclo) = carga;
                    end
                else
                    carga_max(ciclo) = carga;
                end
            end

            % State 2 = descarga → guardar mínimo por ciclo
            if state == 2
                if isKey(descarga_min, ciclo)
                    if carga < descarga_min(ciclo)
                        descarga_min(ciclo) = carga;
                    end
                else
                    descarga_min(ciclo) = carga;
                end
            end

        end
    end

    linea = fgetl(fid);
end
fclose(fid);

fprintf('Líneas procesadas: %d\n', n_linea);

% =========================================================
%  CONSTRUIR TABLAS
% =========================================================

% --- TABLA CARGA ---
ciclos_c = sort(cell2mat(keys(carga_max)));
Ciclo_carga = zeros(numel(ciclos_c),1,'int32');
Max_carga   = zeros(numel(ciclos_c),1);
for i = 1:numel(ciclos_c)
    Ciclo_carga(i) = ciclos_c(i);
    Max_carga(i)   = carga_max(ciclos_c(i));
end
Tabla_CARGA = table(double(Ciclo_carga), Max_carga, ...
    'VariableNames', {'Ciclo', 'Carga_mAh'});

% --- TABLA DESCARGA ---
ciclos_d = sort(cell2mat(keys(descarga_min)));
Ciclo_descarga = zeros(numel(ciclos_d),1,'int32');
Min_descarga   = zeros(numel(ciclos_d),1);
for i = 1:numel(ciclos_d)
    Ciclo_descarga(i) = ciclos_d(i);
    Min_descarga(i)   = descarga_min(ciclos_d(i));
end
Tabla_DESCARGA = table(double(Ciclo_descarga), abs(Min_descarga), ...
    'VariableNames', {'Ciclo', 'Carga_mAh'});


% =========================================================
%  MOSTRAR TABLAS
% =========================================================
fprintf('\n=== TABLA CARGA  (máx Carga_mAh por ciclo, State 1)  (%d filas) ===\n', height(Tabla_CARGA));
disp(Tabla_CARGA);

fprintf('\n=== TABLA DESCARGA  (mín Carga_mAh por ciclo, State 2)  (%d filas) ===\n', height(Tabla_DESCARGA));
disp(Tabla_DESCARGA);

% =========================================================
%  EXPORTAR A EXCEL
% =========================================================
[carpeta, nombre_archivo] = fileparts(ruta_archivo);

% Captura "cicloX", "cicloX,Y" o "cicloX_Y" (ej: ciclo4,1 o ciclo4_1 → "4,1")
token = regexp(nombre_archivo, '(?i)ciclo(\d+(?:[,_]\d(?!\d))?)', 'tokens', 'once');
if ~isempty(token)
    num_ciclo = strrep(token{1}, '_', ',');
else
    num_ciclo = 'X';
    warning('No se encontró "cicloX" en el nombre del archivo. Se usará "X".');
end

nombre_cargas    = sprintf('CICLO%s_CARGAS.xlsx',    num_ciclo);
nombre_descargas = sprintf('CICLO%s_DESCARGAS.xlsx', num_ciclo);

writetable(Tabla_CARGA,    fullfile(carpeta, nombre_cargas));
writetable(Tabla_DESCARGA, fullfile(carpeta, nombre_descargas));

fprintf('\nArchivos guardados en: %s\n', carpeta);
fprintf('  -> %s\n', nombre_cargas);
fprintf('  -> %s\n', nombre_descargas);
