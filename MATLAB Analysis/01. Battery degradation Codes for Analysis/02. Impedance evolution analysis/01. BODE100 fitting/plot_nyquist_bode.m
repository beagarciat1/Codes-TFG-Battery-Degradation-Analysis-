function plot_nyquist_bode(ruta_csv)
% PLOT_NYQUIST_TABS_MEJORADo

    %% ==================== CONFIGURACIÓN ====================
    % === AQUÍ INDICAS LOS CICLOS QUE QUIERES EXCLUIR ===
    ciclos_excluir = [7]; % índice de medida 7 = ciclo 175 (medida anómala)

    %% 1. Leer y procesar datos
    T = readtable(ruta_csv, 'Delimiter', ';');

    % Separar normales y atípicos
    mask_out = ismember(T.Ciclo, ciclos_excluir);
    T_out    = T(mask_out,  :);
    T        = T(~mask_out, :);

    ciclos = T.Ciclo;
    L0 = T.L0_H;   R0 = T.R0_Ohm;  R1 = T.R1_Ohm;
    C1 = T.C1_F;   R2 = T.R2_Ohm;  C2 = T.C2_F;

    % Atípicos (para marcar en las gráficas de parámetros)
    ciclos_out_num = T_out.Ciclo * 25;
    R0_out = T_out.R0_Ohm;  R1_out = T_out.R1_Ohm;  C1_out = T_out.C1_F;
    R2_out = T_out.R2_Ohm;  C2_out = T_out.C2_F;    L0_out = T_out.L0_H;

    n_ciclos = height(T);
    ciclos_num = ciclos * 25;   % número de ciclo real (25, 50, ..., 375)

    fprintf('Procesando %d ciclos (se excluyeron %d ciclos)\n', ...
        n_ciclos, length(ciclos_excluir));

    %% 2. Guardar los parámetros en Excel

    excel_filename = 'Resultados_Parametros_Nyquist.xlsx';

    T_principal = table(ciclos, L0, R0, R1, C1, R2, C2, ...
        'VariableNames', {'Ciclo', 'L0_H', 'R0_Ohm', 'R1_Ohm', 'C1_F', 'R2_Ohm', 'C2_F'});

    
    writetable(T_principal, excel_filename, 'Sheet', 'Parametros_Principales');
  

    fprintf('✅ Archivo Excel guardado: %s\n', excel_filename);

    %% 3. Crear figura con pestañas
    fig = figure('Position', [80 80 1200 780], ...
        'Name', 'Análisis de Ciclos - Nyquist y Evoluciones Individuales', ...
        'NumberTitle', 'off');

    tabGroup = uitabgroup('Parent', fig, 'Position', [0 0 1 1]);

    
    %% ====================== PESTAÑA 1: NYQUIST ======================
    tabNyq = uitab(tabGroup, 'Title', 'Nyquist Interactivo');
    axNyq = axes('Parent', tabNyq, 'Position', [0.08 0.08 0.85 0.82]);
    hold(axNyq, 'on'); grid(axNyq, 'on'); box(axNyq, 'on');
    colores = lines(n_ciclos);

    for i = 1:n_ciclos
        c = ciclos(i);   % ciclo real
        f = logspace(-2, 6, 200);
        s = 1j * 2*pi * f;
        Z_L = s * L0(i);
        Z_R0 = R0(i) * ones(size(s));
        Z_RC1 = R1(i) ./ (1 + s*R1(i)*C1(i)) .* (abs(R1(i))>1e-12 & abs(C1(i))>1e-12);
        Z_RC2 = R2(i) ./ (1 + s*R2(i)*C2(i)) .* (abs(R2(i))>1e-12 & abs(C2(i))>1e-12);
        Z = Z_L + Z_R0 + Z_RC1 + Z_RC2;

        plot(axNyq, real(Z), -imag(Z), '-', ...
            'LineWidth', 2.8, ...
            'Color', colores(i,:), ...
            'DisplayName', sprintf('Ciclo %d', c*25), ...
            'Tag', sprintf('Ciclo %d', c*25));
    end

    xlabel(axNyq, 'Z_{real} (\Omega)');
    ylabel(axNyq, '-Z_{imag} (\Omega)');
    title(axNyq, 'Diagrama de Nyquist - Ciclos seleccionados (Interactivo)');
    legend(axNyq, 'Location', 'southeast', 'FontSize', 10);
    axis(axNyq, 'equal');

    dcm = datacursormode(fig);
    set(dcm, 'Enable', 'on', 'UpdateFcn', @customDataCursor);

    %% ====================== PESTAÑAS INDIVIDUALES ======================
    xticks_ciclos = 25:25:max(ciclos_num);


    % R0
    tabR0 = uitab(tabGroup, 'Title', 'Evolución R0');
    ax = axes('Parent', tabR0);
    plot(ax, ciclos_num, R0, 'o-', 'LineWidth', 2, 'Color', [0 0.447 0.741]);
    grid on; title('Evolución de R0'); xlabel('Ciclo'); ylabel('R0 (\Omega)');
    set(ax, 'XTick', xticks_ciclos);

    % R1
    tabR1 = uitab(tabGroup, 'Title', 'Evolución R1');
    ax = axes('Parent', tabR1);
    plot(ax, ciclos_num, R1, 'o-', 'LineWidth', 2, 'Color', [0.85 0.325 0.098]);
    grid on; title('Evolución de R1'); xlabel('Ciclo'); ylabel('R1 (\Omega)');
    set(ax, 'XTick', xticks_ciclos);

    % R2
    tabR2 = uitab(tabGroup, 'Title', 'Evolución R2');
    ax = axes('Parent', tabR2);
    plot(ax, ciclos_num, R2, 'o-', 'LineWidth', 2, 'Color', [0.929 0.694 0.125]);
    grid on; title('Evolución de R2'); xlabel('Ciclo'); ylabel('R2 (\Omega)');
    set(ax, 'XTick', xticks_ciclos);

    % L0 (nH)
    tabL0 = uitab(tabGroup, 'Title', 'Evolución L0');
    ax = axes('Parent', tabL0);
    plot(ax, ciclos_num, L0*1e9, 'o-', 'LineWidth', 2, 'Color', [0.494 0.184 0.556]);
    grid on; title('Evolución de L0'); xlabel('Ciclo'); ylabel('L0 (nH)');
    set(ax, 'XTick', xticks_ciclos);

    % C1 (µF)
    tabC1 = uitab(tabGroup, 'Title', 'Evolución C1');
    ax = axes('Parent', tabC1);
    plot(ax, ciclos_num, C1*1e6, 'o-', 'LineWidth', 2, 'Color', [0.466 0.674 0.188]);
    grid on; title('Evolución de C1'); xlabel('Ciclo'); ylabel('C1 (\muF)');
    set(ax, 'XTick', xticks_ciclos);

    % C2 (µF)
    tabC2 = uitab(tabGroup, 'Title', 'Evolución C2');
    ax = axes('Parent', tabC2);
    plot(ax, ciclos_num, C2*1e6, 'o-', 'LineWidth', 2, 'Color', [0.301 0.745 0.933]);
    grid on; title('Evolución de C2'); xlabel('Ciclo'); ylabel('C2 (\muF)');
    set(ax, 'XTick', xticks_ciclos);

    % R total = R0 + R1 + R2
    tabR = uitab(tabGroup, 'Title', 'Evolución R total');
    ax = axes('Parent', tabR);
    plot(ax, ciclos_num, R0+R1+R2, 'o-', 'LineWidth', 2, 'Color', [0.635 0.078 0.184]);
    grid on; title('Evolución de R total (R0+R1+R2)'); xlabel('Ciclo'); ylabel('R total (\Omega)');
    set(ax, 'XTick', xticks_ciclos);

    %% Mensaje final
    fprintf('\n Análisis completado con %d ciclos (se excluyeron %d).\n', ...
        n_ciclos, length(ciclos_excluir));
    fprintf(' → Archivo Excel generado con 3 hojas.\n\n');

end


%% ====================== FUNCIÓN DEL DATA CURSOR ======================
function txt = customDataCursor(~, event_obj)
    pos = get(event_obj, 'Position');
    obj = get(event_obj, 'Target');
    ciclo_str = get(obj, 'Tag');
   % if isempty(ciclo_str)
        %ciclo_str = 'Ciclo desconocido';
    %end
    txt = {ciclo_str, ...
           ['ciclo' num2str(pos(1), '%.5f') ' Ω'], ...
           ['-Z_{imag} = ' num2str(pos(2), '%.5f') ' Ω']};
end