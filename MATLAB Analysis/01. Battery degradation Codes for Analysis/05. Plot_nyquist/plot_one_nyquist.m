function plot_one_nyquist(nombreArchivo)
    % GRAFICAR_NYQUIST Carga datos de un Excel y dibuja el diagrama de Nyquist.
    % Uso: graficar_nyquist('30%.xlsx')
    
    % 1. Verificar si el nombre tiene la extensión .xlsx, si no, añadirla
    if ~contains(nombreArchivo, '.xlsx')
        nombreArchivo = [nombreArchivo, '.xlsx'];
    end

    % 2. Intentar leer el archivo
    try
        data = readtable(nombreArchivo);
        
        % Asignamos las columnas (asegúrate que se llamen f, R y X en el Excel)
        f = data(:,1);
        R = data(:,2);
        X = data(:,3);

        % 3. Crear el gráfico
        figure('Name', ['Nyquist - ' nombreArchivo], 'Color', 'w');
        plot(-R, X, 'o-', 'LineWidth', 1.5, 'MarkerFaceColor', 'b');
        
        grid on;
        axis equal;
        xlabel('Z_{real} (\Omega)');
        ylabel('-Z_{imaginaria} (\Omega)');
        title(['Diagrama de Nyquist: ', nombreArchivo]);

        disp(['Gráfico generado con éxito para: ', nombreArchivo]);


    catch ME
        fprintf('Error: No se pudo leer el archivo "%s".\n', nombreArchivo);
        fprintf('Detalle: %s\n', ME.message);
    end
end
