function Capacities = initial_modelisation_b1(mode_charge, mode_discharge, numCycles)
    tic;
% Define the model name
    modelName = 'Battery_model_BEA_L0';
% Validación básica de entradas
if nargin < 3
        error('Se requieren 3 argumentos: mode_charge, mode_discharge, numCycles');
end
% Load the Simulink model
    load_system(modelName);
    [chargeTime, dischargeTime, current_SoC, Tc_state, Ts_state, V1_state, V2_state, ...
     V_max, V_cutoff, Cn, C_As, I_c, I_c_full_charged, charging_out, discharging_out, ...
     Ah_through_cycles, Q_loss_through_cycles, Cycles, Capacities, Ah_accumulated, ...
     I_t, V_t, SoC_t, Time, offset, V_length, I_length, time_length, SoC_length, ...
     Ea, eta, z, Rg] = setup(numCycles);
% Recuperation of the ModelWorkspace
    modelWS = get_param(modelName,'ModelWorkspace');
% Initialize the parameters in the model Workspace
    vars = {'current_SoC','V1_state','V2_state','Tc_state','Ts_state','Cn','I_c','I_c_full_charged','V_max','V_cutoff','C_As'};
for k = 1:length(vars)
        assignin(modelWS, vars{k}, eval(vars{k}));
end
% CycleNumber inicial = 0
% La LUT 3D (Tc x SoC x CycleNumber) interpola automaticamente en las 3 dims
    assignin(modelWS, 'CycleNumber', 0);

% Loop through the cycles
for cycle = 1:numCycles

        % Actualizar CycleNumber antes de cada simulacion
        % (0-indexed: ciclo 1 → CycleNumber=0, ciclo 2 → 1, ...)
        % La LUT 3D interpola automaticamente entre los breakpoints de bp_Cycle
        assignin(modelWS, 'CycleNumber', cycle - 1);

        fprintf('Cycle %d: Charging (CycleNumber = %d)\n', cycle, cycle - 1);
% Update the model for charging
        set_param(modelName, 'SimulationCommand', 'update');
        set_param(modelName, 'StopTime', num2str(chargeTime));
        configureChargeMode(modelName, mode_charge);
% Run the simulation for charging
        simOut = sim(modelName);
        fprintf('Charging completed for cycle %d\n', cycle);
% Save charging outputs
        charging_out{cycle} = simOut;
% Recuperation of V(t), I(t), and t for the charging phase
        V_t_ch = simOut.V_t_ch.Data;
        I_t_ch = simOut.I_t_ch.Data;
        t = simOut.V_t_ch.Time;
        t = t + offset;
        Time(time_length+1:time_length + length(t)) = t;
        V_t(V_length+1:V_length + length(V_t_ch)) = V_t_ch;
        I_t(I_length+1:I_length + length(I_t_ch)) = I_t_ch;
        V_length    = V_length    + length(V_t_ch);
        I_length    = I_length    + length(I_t_ch);
        time_length = time_length + length(t);
        offset = t(end);
% Extract the final SoC from charging output
        current_SoC = simOut.SoC_t_ch(end);
        fprintf('Current SoC : %.4f\n', current_SoC);
% Recuperation of the Ah through charging
        Ah_ch = simOut.get('Ah_ch');
        Ah_accumulated = Ah_accumulated + Ah_ch(end);
% Recuperation of the SoC and Tc during the charging phase
        SoC_t_ch = simOut.get('SoC_t_ch');
        Tc_t_ch  = simOut.get('Tc_t_ch');
        SoC_t(SoC_length+1:SoC_length + length(SoC_t_ch)) = SoC_t_ch;
        SoC_length = SoC_length + length(SoC_t_ch);
% Recuperation of Ts_state, Tc_state, V1_state, V2_state
        Ts_state = simOut.Ts_t_ch(end);
        Tc_state = simOut.Tc_t_ch(end);
        V1_state = simOut.V1_t_ch(end);
        V2_state = simOut.V2_t_ch(end);
% Updating the values of the parameters in the model Workspace
for k = 1:length(vars)
            assignin(modelWS, vars{k}, eval(vars{k}));
end

        fprintf('Cycle %d: Discharging (CycleNumber = %d)\n', cycle, cycle - 1);
% Update the model for discharging
        set_param(modelName, 'SimulationCommand', 'update');
        set_param(modelName, 'StopTime', num2str(dischargeTime));
        configureDischargeMode(modelName, mode_discharge);
% Run the simulation for discharging
        simOut = sim(modelName);
        fprintf('Discharging completed for cycle %d\n', cycle);
% Save discharging outputs
        discharging_out{cycle} = simOut;
% Recuperation of V(t), I(t), and t
        V_t_dis = simOut.V_t_dis.Data;
        I_t_dis = simOut.I_t_dis.Data;
        t = simOut.V_t_dis.Time;
        t = t + offset;
        Time(time_length+1:time_length + length(t)) = t;
        V_t(V_length+1:V_length + length(V_t_dis)) = V_t_dis;
        I_t(I_length+1:I_length + length(I_t_dis)) = I_t_dis;
        V_length    = V_length    + length(V_t_dis);
        I_length    = I_length    + length(I_t_dis);
        time_length = time_length + length(t);
        offset = t(end);
% Extract the final SoC from discharging output
        current_SoC = simOut.SoC_t_dis(end);
        fprintf('Current SoC : %.4f\n', current_SoC);
% Recuperation of the Ah through discharging
        Ah_dis = simOut.get('Ah_dis');
        Ah_accumulated = Ah_accumulated + Ah_dis(end);
        Ah_through_cycles(cycle+1) = Ah_accumulated;
% Recuperation of Ts_state, Tc_state, V1_state, V2_state
        Ts_state = simOut.Ts_t_dis(end);
        Tc_state = simOut.Tc_t_dis(end);
        V1_state = simOut.V1_t_dis(end);
        V2_state = simOut.V2_t_dis(end);
for k = 1:length(vars)
            assignin(modelWS, vars{k}, eval(vars{k}));
end
% Recuperation of the SoC and Tc during the discharging phase
        SoC_t_dis = simOut.get('SoC_t_dis');
        Tc_t_dis  = simOut.get('Tc_t_dis');
        SoC_t(SoC_length+1:SoC_length + length(SoC_t_dis)) = SoC_t_dis;
        SoC_length = SoC_length + length(SoC_t_dis);
% Concatenation of SoC, Tc and I for charge + discharge
        SoC_t_cycle = [SoC_t_ch; SoC_t_dis];
        Tc_t_cycle  = [Tc_t_ch;  Tc_t_dis];
        I_t_cycle   = [I_t_ch;   I_t_dis];
% Evaluation of the capacity loss
        Ic_t_mean  = mean(3600*I_t_cycle/C_As);
        SoC_t_mean = mean(SoC_t_cycle);
        Tc_t_mean  = mean(Tc_t_cycle);
if SoC_t_mean < 0.45
            alpha = 223387.56;
            beta  = 96789.91;
else
            alpha = 223387.56;
            beta  = 96789.91;
end
        C_loss = (alpha*SoC_t_mean + beta)*exp((-Ea+eta*Ic_t_mean)/(Rg*(Tc_t_mean+273.15)))*Ah_accumulated^z;
        Q_loss_through_cycles(cycle+1) = C_loss;
        C_As = (1 - C_loss/100)*Cn;
        Capacities(cycle+1) = C_As;
        fprintf('Capacity loss : %.4f%%\n', C_loss);
        fprintf('New Capacity  : %.2f A.h\n', C_As);
        Cycles(cycle+1) = cycle;
end
% Trim trailing zeros and plot
    [Time, V_t, I_t, SoC_t] = trimSignals(Time, V_t, I_t, SoC_t);
   
    createPlots(Cycles, Q_loss_through_cycles, Capacities, Time, V_t, I_t, SoC_t, numCycles);
    close_system(modelName, 0);
    disp('All cycles completed successfully.');
    save('cycle_results.mat', 'charging_out', 'discharging_out');
    toc;
end

% ====================== FUNCIÓN DE GRÁFICAS ======================
function createPlots(Cycles, Q_loss_through_cycles, Capacities, Time, V_t, I_t, SoC_t, numCycles)
    figure;
    plot(Cycles, Q_loss_through_cycles, '-o');
    xlabel('Number of cycles'); ylabel('Capacity loss after each cycle (%)');
    title('Capacity loss in % against Number of cycles'); grid on;

    figure;
    plot(Cycles, Capacities, '-o');
    xlabel('Number of cycles'); ylabel('Capacity after each cycle (mA.h)');
    title('Capacity after each cycle in mA.h against Number of cycles'); grid on;

    figure;
    plot(Time, V_t, '-');
    xlabel('Time'); ylabel('V(t)');
    title(sprintf('V(t) for %d cycles', numCycles)); grid on;

    figure;
    plot(Time, I_t, '-');
    xlabel('Time'); ylabel('I(t)');
    title(sprintf('I(t) for %d cycles', numCycles)); grid on;

    figure;
    plot(Time, SoC_t, '-');
    xlabel('Time'); ylabel('SoC(t)');
    title(sprintf('SoC(t) for %d cycles', numCycles)); grid on;
end

% ====================== CONFIGURACIÓN DE MODOS ======================
function configureChargeMode(modelName, mode_charge)
if strcmp(mode_charge,'CC')
        set_param([modelName '/Battery_charge_CC'],    'Commented', 'off');
        set_param([modelName '/Battery_charge_CC_CV'], 'Commented', 'on');
else
        set_param([modelName '/Battery_charge_CC'],    'Commented', 'on');
        set_param([modelName '/Battery_charge_CC_CV'], 'Commented', 'off');
end
    set_param([modelName '/Battery_discharge_CC'],    'Commented', 'on');
    set_param([modelName '/Battery_discharge_CC_CV'], 'Commented', 'on');
end

function configureDischargeMode(modelName, mode_discharge)
if strcmp(mode_discharge,'CC')
        set_param([modelName '/Battery_discharge_CC'],    'Commented', 'off');
        set_param([modelName '/Battery_discharge_CC_CV'], 'Commented', 'on');
else
        set_param([modelName '/Battery_discharge_CC'],    'Commented', 'on');
        set_param([modelName '/Battery_discharge_CC_CV'], 'Commented', 'off');
end
    set_param([modelName '/Battery_charge_CC'],    'Commented', 'on');
    set_param([modelName '/Battery_charge_CC_CV'], 'Commented', 'on');
end

% ====================== FUNCIÓN DE RECORTE DE SEÑALES ======================
function [Time, V_t, I_t, SoC_t] = trimSignals(Time, V_t, I_t, SoC_t)
    last_idx_Time = find(Time  ~= 0, 1, 'last');
    last_idx_I    = find(I_t   ~= 0, 1, 'last');
    last_idx_V    = find(V_t   ~= 0, 1, 'last');
    last_idx_SoC  = find(SoC_t ~= 0, 1, 'last');
    Time  = Time(1:last_idx_Time);
    I_t   = I_t(1:last_idx_I);
    V_t   = V_t(1:last_idx_V);
    SoC_t = SoC_t(1:last_idx_SoC);
end

% ====================== FUNCIÓN SETUP ======================
function [chargeTime, dischargeTime, current_SoC, Tc_state, Ts_state, V1_state, V2_state, ...
          V_max, V_cutoff, Cn, C_As, I_c, I_c_full_charged, charging_out, discharging_out, ...
          Ah_through_cycles, Q_loss_through_cycles, Cycles, Capacities, Ah_accumulated, ...
          I_t, V_t, SoC_t, Time, offset, V_length, I_length, time_length, SoC_length, ...
          Ea, eta, z, Rg] = setup(numCycles)
    chargeTime    = 10000;
    dischargeTime = 10000;
    current_SoC   = 0;
    Tc_state = 25; Ts_state = 25;
    V2_state = 0;  V1_state = 0;
    V_max = 4.2;   V_cutoff = 3;
    Cn   = 130;    C_As = Cn;
    I_c  = 1;      I_c_full_charged = 1/30;
    charging_out    = cell(numCycles, 1);
    discharging_out = cell(numCycles, 1);
    Ah_through_cycles     = zeros(1, numCycles + 1);
    Q_loss_through_cycles = zeros(1, numCycles + 1);
    Cycles     = 0:numCycles;
    Capacities = [C_As, zeros(1, numCycles)];
    Ah_accumulated = 0;
    I_t   = zeros(1, 300*2*numCycles);
    V_t   = zeros(1, 300*2*numCycles);
    SoC_t = zeros(1, 300*2*numCycles);
    Time  = zeros(1, 300*2*numCycles);
    offset      = 0;
    V_length    = 0; I_length    = 0;
    time_length = 0; SoC_length  = 0;
    Ea = 31500; eta = 4042.56; z = 0.6762; Rg = 8.314;
end
