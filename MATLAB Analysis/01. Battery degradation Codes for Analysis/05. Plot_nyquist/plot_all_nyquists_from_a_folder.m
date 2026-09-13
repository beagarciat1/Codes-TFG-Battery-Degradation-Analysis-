function plot_all_nyquists_from_a_folder(rutaCarpeta)

    if nargin < 1 || isempty(rutaCarpeta)
        rutaCarpeta = pwd;
    end

    archivos = dir(fullfile(rutaCarpeta, '*.xlsx'));

    if isempty(archivos)
        error('No se encontraron archivos .xlsx en la carpeta: %s', rutaCarpeta);
    end

    % Ciclos a excluir
    ciclos_excluir = [1, 6, 20, 4, 15];

    colores = lines(length(archivos));

    figure('Name', 'Diagramas de Nyquist', 'Color', 'w');
    hold on;
    grid on;
    axis equal;
    xlabel('Z_{real} (\Omega)');
    ylabel('-Z_{imaginaria} (\Omega)');
    title('Diagramas de Nyquist');

    leyenda = {};

    color_idx = 1;

    for k = 1:length(archivos)
        nombreArchivo = archivos(k).name;

        % Extraer número de ciclo del nombre (asume que hay un número en el nombre)
        ciclo = regexp(nombreArchivo, '\d+', 'match');
        if ~isempty(ciclo)
            ciclo = str2double(ciclo{1});
        else
            ciclo = NaN;
        end

        % Saltar ciclos no deseados
        if ismember(ciclo, ciclos_excluir)
            continue;
        end

        rutaCompleta = fullfile(rutaCarpeta, nombreArchivo);

        try
            data = readmatrix(rutaCompleta, 'Range', 'A2');

            if size(data,2) < 3
                error('El archivo no tiene al menos 3 columnas.');
            end

            f = data(:,1);
            R = data(:,2);
            X = data(:,3);

            idx_validos = ~isnan(f) & ~isnan(R) & ~isnan(X);
            R = R(idx_validos);
            X = X(idx_validos);

            h = plot(-R, X, 'o-', ...
                'LineWidth', 1.5, ...
                'MarkerSize', 5, ...
                'Color', colores(color_idx,:), ...
                'MarkerFaceColor', colores(color_idx,:));

            % DataTip con nombre de archivo
            h.DataTipTemplate.DataTipRows(end+1) = dataTipTextRow('Archivo', ...
                repmat({nombreArchivo}, length(R), 1));

            leyenda{end+1} = nombreArchivo;
            color_idx = color_idx + 1;

        catch ME
            fprintf('Error en "%s": %s\n', nombreArchivo, ME.message);
        end
    end

    if ~isempty(leyenda)
        legend(leyenda, 'Location', 'best');
    end

    hold off;

end