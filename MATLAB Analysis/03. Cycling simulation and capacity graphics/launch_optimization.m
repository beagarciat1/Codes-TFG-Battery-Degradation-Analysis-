% =========================================================
% lanzar_optimizacion.m
%
% Script de lanzamiento de la optimización de parámetros.
% Modifica aquí x0, number_cycles y max_iter y ejecuta
% este archivo (F5 o Run) para lanzar la optimización.
% =========================================================

% ---- Punto de partida para [alpha, beta, eta, z] ----
%
%   alpha : coeficiente del SoC en el factor preexponencial
%   beta  : término constante del factor preexponencial
%   eta   : efecto de la C-rate sobre la energía de activación (J/mol)
%   z     : exponente de la ley de potencia sobre Ah acumulados (~0.5)
%
x0 = [155000, 78000, 7000, 0.5];

% ---- Número de ciclos a comparar con el modelo ----
number_cycles = 550;

% ---- Máximo de iteraciones del optimizador ----
max_iter = 500;

% ---- Lanzar optimización ----
opt_pms = optimization(x0, number_cycles, max_iter);

% ---- Mostrar resultado ----
fprintf('\n--- Parámetros optimizados ---\n');
fprintf('  alpha = %.4f\n', opt_pms(1));
fprintf('  beta  = %.4f\n', opt_pms(2));
fprintf('  eta   = %.4f\n', opt_pms(3));
fprintf('  z     = %.4f\n', opt_pms(4));
