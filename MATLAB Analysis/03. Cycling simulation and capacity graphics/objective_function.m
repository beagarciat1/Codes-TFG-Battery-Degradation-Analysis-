function err = objective_function(x)

%x es un vector de parámetros que queremos ajustar:
%valor del error entre el modelo y el experimento

% x = [alpha, beta, eta, z]
%Son los mismos parámetros que aparecen en la ecuación de degradación dentro de Q_loss_model.
alpha = x(1);
beta = x(2);
eta = x(3);
z = x(4);


%AÑADIR RETURN PARA LIMITAR LOS VALORES DE ALFA, BETA, Y SALIR DEL BUCLE SI HACE COSAS RARAS



% Initialise the number of cycles to compare and the nominal
% capacity(reference)
number_cycles = 550;
C = 130; % mAh - capacidad nominal CC (referencia, no se usa directamente aquí)

fprintf('alpha = %.2f, beta = %.2f, eta = %.2f, z = %.4f\n', alpha, beta, eta, z);

% Extraction of the experimental data and the model prediction data
[Q_loss_real] = analysis_capacity_total_b1();
% Ajuste automático: si hay menos ciclos disponibles que number_cycles, se recorta
number_cycles = min(number_cycles, length(Q_loss_real) - 1);
Q_loss_real = Q_loss_real(1:number_cycles+1);

[Q_loss_pred] = Q_loss_model(alpha,beta,eta,z,number_cycles,'CC','CC');
% Ambos vectores tienen ahora longitud number_cycles+1 (ciclo 0 hasta ciclo N).

% Using the least squares method
err = sum((Q_loss_pred(:) - Q_loss_real(:)).^2);
%calculo de la diferencia por minimos cuadrados

% Guardar historial de CADA evaluación (no solo el mejor vértice)
historial_file = 'historial_optimizacion.mat';
if ~isfile(historial_file)
    historial_params = x(:)';
    historial_error  = err;
else
    loaded = load(historial_file, 'historial_params', 'historial_error');
    historial_params = [loaded.historial_params; x(:)'];
    historial_error  = [loaded.historial_error;  err];
end
save(historial_file, 'historial_params', 'historial_error');
end
