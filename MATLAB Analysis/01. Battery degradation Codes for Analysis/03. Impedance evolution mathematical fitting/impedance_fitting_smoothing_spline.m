%% ==================== SMOOTHING SPLINE + POLINOMIOS CÚBICOS (VERSIÓN FIJA) ====================
clear; clc; close all;

filename = 'Resultados_Parametros_Nyquist.xlsx';
data = readtable(filename);

ciclos = data.Ciclo;
parametros = {'L0_H', 'R0_Ohm', 'R1_Ohm', 'C1_F', 'R2_Ohm', 'C2_F'};
nombres = {'L0 (H)', 'R0 (Ω)', 'R1 (Ω)', 'C1 (F)', 'R2 (Ω)', 'C2 (F)'};

outputFolder = 'Fits_SmoothingSpline';
if ~exist(outputFolder, 'dir')
    mkdir(outputFolder);
end

fprintf('=== SMOOTHING SPLINE - COEFICIENTES EN COMMAND WINDOW ===\n\n');

for i = 1:length(parametros)
    var_name = parametros{i};
    y = data.(var_name);
    p = 0.985;                    % Cambia este valor si quieres más o menos suavidad
    
    pp = csaps(ciclos, y, p);
    
    breaks = pp.breaks;
    coefs  = pp.coefs;            % Matriz con los coeficientes [a b c d]
    
    fprintf('══════════════════════════════════════════════════════\n');
    fprintf('PARÁMETRO: %s   (Suavidad p = %.3f)\n', nombres{i}, p);
    fprintf('Número de tramos: %d\n', length(breaks)-1);
    fprintf('══════════════════════════════════════════════════════\n\n');
    
    for j = 1:size(coefs,1)
        a = coefs(j,1);
        b = coefs(j,2);
        c = coefs(j,3);
        d = coefs(j,4);
        
        fprintf('Tramo %d:  %.1f  ≤  Ciclo  <  %.1f\n', j, breaks(j), breaks(j+1));
        fprintf('   y = %.6e x³  +  %.6e x²  +  %.6e x  +  %.6e\n\n', a, b, c, d);
    end
    
    % ==================== GRÁFICA ====================
    x_fino = linspace(min(ciclos), max(ciclos), 500);
    y_fino = fnval(pp, x_fino);
    
    figure('Position',[100 100 950 580]);
    plot(ciclos, y, 'o', 'MarkerSize',9, 'LineWidth',1.8, 'DisplayName','Datos Experimentales');
    hold on;
    plot(x_fino, y_fino, 'r-', 'LineWidth',2.8, 'DisplayName','Smoothing Spline');
    title(['Smoothing Spline - ' nombres{i}], 'FontSize',15);
    xlabel('Ciclo', 'FontSize',13);
    ylabel(nombres{i}, 'FontSize',13);
    grid on;
    legend('Location','best');
    
    saveas(gcf, fullfile(outputFolder, ['Spline_' var_name '.png']));
    fprintf('✓ Gráfica guardada para %s\n\n', nombres{i});
end

disp('✅ Proceso finalizado. Todos los coeficientes se han mostrado en Command Window.');