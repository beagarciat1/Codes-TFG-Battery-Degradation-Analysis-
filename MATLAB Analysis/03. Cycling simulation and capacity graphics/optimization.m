function opt_pms = optimization(x0,number_cycles,max_iter)
% opt_pms=vector con los parámetros optimizados que mejor ajustan el modelo a los datos experimentales.
% Initialisation of a Cycles_list array for the plots
Cycles_list = 0:number_cycles;

% Choosing the options for the minimization function
options = optimset('MaxIter', max_iter, 'Display', 'off', 'OutputFcn', @iter_progress);

% Borrar historial previo para empezar limpio
if isfile('historial_optimizacion.mat')
    delete('historial_optimizacion.mat');
end

% Returning the optimal parameters
opt_pms = fminsearch(@objective_function, x0, options);

% Experimental data (from analysis_capacity_total_b1, recortado a number_cycles+1)
Q_loss_real_full = analysis_capacity_total_b1();
Q_loss_real = Q_loss_real_full(1:number_cycles+1);

% Plot of the experimental data, the initial model prediction data and the optimized model prediction data
figure;
hold on;
plot(Cycles_list, Q_loss_model(opt_pms(1),opt_pms(2),opt_pms(3),opt_pms(4),number_cycles,'CC','CC'), '-o','Color','b');
plot(Cycles_list, Q_loss_model(x0(1),x0(2),x0(3),x0(4),number_cycles,'CC','CC'), '-o','Color','r');
plot(Cycles_list, Q_loss_real, '-o','Color','g');
xlabel('Número de ciclos');
ylabel('Capacidad tras cada ciclo (mAh)');
legend(sprintf('Modelo optimizado (%d iter)', max_iter), 'Modelo inicial (x0)', 'Datos experimentales');
title('Capacidad por ciclo: modelo vs experimento');

end


% ---- Función de progreso (llamada una vez por iteración del optimizador) ----
function stop = iter_progress(x, optimValues, state)
    stop = false;
    if strcmp(state, 'iter')
        iter = optimValues.iteration;
        err  = optimValues.fval;
        fprintf('>>> Iteración %d | Error: %.6f\n', iter, err);

        % (el historial se guarda en objective_function en cada evaluación)
    end
end