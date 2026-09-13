function plot_zexp_vs_soc_from_bode100()
    %% ====================== CONFIGURACIÓN ======================
    filename = 'C:\your_route\your_file.xlsx';
    data = readcell(filename, 'Sheet', 'Hoja1');
    
    %% ====================== EXTRAER DATOS ======================
    % CARGAS
    soc_c1 = cell2mat(data(4:15,1));   r0_c1 = cell2mat(data(4:15,2));  l0_c1 = cell2mat(data(4:15,3));
    r1_c1 = cell2mat(data(4:15,4));    c1_c1 = cell2mat(data(4:15,5));
    r2_c1 = cell2mat(data(4:15,6));    c2_c1 = cell2mat(data(4:15,7));
    
    soc_c2 = cell2mat(data(32:40,1));  r0_c2 = cell2mat(data(32:40,2)); l0_c2 = cell2mat(data(32:40,3));
    r1_c2 = cell2mat(data(32:40,4));   c1_c2 = cell2mat(data(32:40,5));
    r2_c2 = cell2mat(data(32:40,6));   c2_c2 = cell2mat(data(32:40,7));
    
    soc_c3 = cell2mat(data(61:70,1));  r0_c3 = cell2mat(data(61:70,2)); l0_c3 = cell2mat(data(61:70,3));
    r1_c3 = cell2mat(data(61:70,4));   c1_c3 = cell2mat(data(61:70,5));
    r2_c3 = cell2mat(data(61:70,6));   c2_c3 = cell2mat(data(61:70,7));
    
    % DESCARGAS (completas)
    soc_d1 = cell2mat(data(20:27,1));  r0_d1 = cell2mat(data(20:27,2)); l0_d1 = cell2mat(data(20:27,3));
    r1_d1 = cell2mat(data(20:27,4));   c1_d1 = cell2mat(data(20:27,5));
    r2_d1 = cell2mat(data(20:27,6));   c2_d1 = cell2mat(data(20:27,7));
    
    soc_d2 = cell2mat(data(45:53,1));  r0_d2 = cell2mat(data(45:53,2)); l0_d2 = cell2mat(data(45:53,3));
    r1_d2 = cell2mat(data(45:53,4));   c1_d2 = cell2mat(data(45:53,5));
    r2_d2 = cell2mat(data(45:53,6));   c2_d2 = cell2mat(data(45:53,7));
    
    soc_d3 = cell2mat(data(75:83,1));  r0_d3 = cell2mat(data(75:83,2)); l0_d3 = cell2mat(data(75:83,3));
    r1_d3 = cell2mat(data(75:83,4));   c1_d3 = cell2mat(data(75:83,5));
    r2_d3 = cell2mat(data(75:83,6));   c2_d3 = cell2mat(data(75:83,7));
    
    %% ====================== ATÍPICOS CORRECTOS ======================
    idx_out_c1 = [9, 10];   % ← Puntos clave entre SoC 0.75 y 0.83 (los que bajan fuerte)
    
    %% ====================== VERSIONES LIMPIAS PARA MEDIA ======================
    soc_c1_clean = soc_c1; 
    r0_c1_clean = r0_c1; l0_c1_clean = l0_c1; r1_c1_clean = r1_c1;
    c1_c1_clean = c1_c1; r2_c1_clean = r2_c1; c2_c1_clean = c2_c1;
    
    soc_c1_clean(idx_out_c1) = [];
    r0_c1_clean(idx_out_c1) = []; l0_c1_clean(idx_out_c1) = []; r1_c1_clean(idx_out_c1) = [];
    c1_c1_clean(idx_out_c1) = []; r2_c1_clean(idx_out_c1) = []; c2_c1_clean(idx_out_c1) = [];
    
    %% ====================== FUNCIÓN MEDIA ======================
    function [soc_mean, val_mean] = calcular_media(s1,v1,s2,v2,s3,v3)
        soc_grid = linspace(0,1,200)';
        v1i = interp1(s1,v1,soc_grid,'pchip',NaN);
        v2i = interp1(s2,v2,soc_grid,'pchip',NaN);
        v3i = interp1(s3,v3,soc_grid,'pchip',NaN);
        val_mean = mean([v1i v2i v3i], 2);
        soc_mean = soc_grid;
    end
    
    col = lines(3);

    param_names = {'R0','L0','R1','C1','R2','C2'};
    units       = {'(m\Omega)','(nH)','(m\Omega)','(mF)','(m\Omega)','(mF)'};

    % Datos de cargas y descargas agrupados por parámetro
    cargas_v  = { {r0_c1,r0_c1_clean,r0_c2,r0_c3}, {l0_c1,l0_c1_clean,l0_c2,l0_c3}, ...
                  {r1_c1,r1_c1_clean,r1_c2,r1_c3}, {c1_c1,c1_c1_clean,c1_c2,c1_c3}, ...
                  {r2_c1,r2_c1_clean,r2_c2,r2_c3}, {c2_c1,c2_c1_clean,c2_c2,c2_c3} };
    descargas_v = { {r0_d1,r0_d2,r0_d3}, {l0_d1,l0_d2,l0_d3}, ...
                    {r1_d1,r1_d2,r1_d3}, {c1_d1,c1_d2,c1_d3}, ...
                    {r2_d1,r2_d2,r2_d3}, {c2_d1,c2_d2,c2_d3} };

    %% ====================== 6 FIGURAS (una por parámetro) ======================
    for i = 1:6
        figure('Name', param_names{i}, 'Color', 'w', 'Position', [100 100 1100 420]);

        % --- Cargas ---
        ax1 = subplot(1,2,1); hold(ax1,'on'); grid(ax1,'on');
        vc_all = cargas_v{i};
        plot(soc_c1, vc_all{1}, 'o-', 'LineWidth', 2.0, 'Color', col(1,:), 'DisplayName','Carga 1');
        plot(soc_c2, vc_all{3}, 'o-', 'LineWidth', 2.0, 'Color', col(2,:), 'DisplayName','Carga 2');
        plot(soc_c3, vc_all{4}, 'o-', 'LineWidth', 2.0, 'Color', col(3,:), 'DisplayName','Carga 3');
        [sm, vm] = calcular_media(soc_c1_clean, vc_all{2}, soc_c2, vc_all{3}, soc_c3, vc_all{4});
        plot(sm, vm, '-', 'Color', [0.2 0.6 0.2], 'LineWidth', 3.375, 'DisplayName','Media');
        set(ax1,'FontSize',12);
        xlabel(ax1,'SoC','FontSize',12); ylabel(ax1,[param_names{i} ' ' units{i}],'FontSize',12);
        title(ax1,[param_names{i} ' vs SoC (Cargas)'],'FontSize',13);
        legend(ax1,'Location','northoutside','FontSize',10,'Orientation','horizontal'); xlim(ax1,[0 1]); xticks(ax1,0:0.2:1);

        % --- Descargas ---
        ax2 = subplot(1,2,2); hold(ax2,'on'); grid(ax2,'on');
        vd_all = descargas_v{i};
        plot(soc_d1, vd_all{1}, 'o-', 'LineWidth', 2.0, 'Color', col(1,:), 'DisplayName','Descarga 1');
        plot(soc_d2, vd_all{2}, 'o-', 'LineWidth', 2.0, 'Color', col(2,:), 'DisplayName','Descarga 2');
        plot(soc_d3, vd_all{3}, 'o-', 'LineWidth', 2.0, 'Color', col(3,:), 'DisplayName','Descarga 3');
        [sm, vm] = calcular_media(soc_d1, vd_all{1}, soc_d2, vd_all{2}, soc_d3, vd_all{3});
        plot(sm, vm, '-', 'Color', [0.2 0.6 0.2], 'LineWidth', 3.375, 'DisplayName','Media');
        set(ax2,'FontSize',12);
        xlabel(ax2,'SoC','FontSize',12); ylabel(ax2,[param_names{i} ' ' units{i}],'FontSize',12);
        title(ax2,[param_names{i} ' vs SoC (Descargas)'],'FontSize',13);
        legend(ax2,'Location','northoutside','FontSize',10,'Orientation','horizontal'); xlim(ax2,[0 1]); xticks(ax2,0:0.2:1);

        carpeta_out = fullfile(pwd, 'Figuras_SoC');
        if ~exist(carpeta_out, 'dir'), mkdir(carpeta_out); end
        exportgraphics(gcf, fullfile(carpeta_out, ['PARAMS_', param_names{i}, '.png']), 'Resolution', 150);
    end

    fprintf('Listo.\n');
end
