function Capacities = initial_modelisation_b2(mode_charge, mode_discharge, numCycles)
 
    tic;
    
    % Define the model name
    modelName = 'Battery_model_BEA_L0_11julio';
    
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
    % CycleNumber inicial (necesario antes del primer 'update')
    assignin(modelWS, 'CycleNumber', 0);
 
    % Initialize arrays for Excel export
    excel_Ic_t_mean      = zeros(numCycles, 1);
    excel_C_loss         = zeros(numCycles, 1);
    excel_Ah_accumulated = zeros(numCycles, 1);
 
    % Loop through the cycles
    for cycle = 1:numCycles
        % Actualizar CycleNumber antes de cada simulacion (0-indexed)
        assignin(modelWS, 'CycleNumber', cycle - 1);
        fprintf('Cycle %d: Charging\n', cycle);
        
        % Adaptation of the charging time
        % chargeTime = (1-current_SoC)*3600/I_c;
        
        % Update the model for charging
        set_param(modelName, 'SimulationCommand', 'update'); % Ensure model is updated
        set_param(modelName, 'StopTime', num2str(chargeTime));
 
        configureChargeMode(modelName, mode_charge);
        
 
        % Run the simulation for charging
        simOut = sim(modelName);
        fprintf('Charging completed for cycle %d\n', cycle);
        fprintf('Ah ccumulated %d\n',Ah_accumulated)
        %fprintf('Ah thourgh cycles %d\n',Ah_through_cycles)
        
        
        % Save charging outputs
        charging_out{cycle} = simOut; % Store output in a cell array
        
        % Recuperation of V(t), I(t), and t for the charging phase
        V_t_ch = simOut.V_t_ch.Data;
        I_t_ch = simOut.I_t_ch.Data;
        t = simOut.V_t_ch.Time;
        t = t + offset;
        
        Time(time_length+1:time_length + length(t)) = t;
        V_t(V_length+1:V_length + length(V_t_ch)) = V_t_ch;
        I_t(I_length+1:I_length + length(I_t_ch)) = I_t_ch;
        
        % Update of the lengths of V, I and Time
        V_length = V_length + length(V_t_ch);
        I_length = I_length + length(I_t_ch);
        time_length = time_length + length(t);
        
        % Update of the offset
        offset = t(end);
        
        % Extract the final SoC from charging output
        current_SoC = simOut.SoC_t_ch(end);
        fprintf('Current SoC : %d\n\r', current_SoC);
        %fprintf('Icharge: %d\n\r', I_t_ch);
 
        
        % Recuperation of the Ah through charging
        Ah_ch = simOut.get('Ah_ch');
        %fprintf('Ah charge %d\n', Ah_ch)
        Ah_accumulated = Ah_accumulated + Ah_ch(end);
        
        % Recuperation of the SoC and Tc during the charging phase
        SoC_t_ch = simOut.get('SoC_t_ch');
        Tc_t_ch = simOut.get('Tc_t_ch');
        SoC_t(SoC_length+1:SoC_length + length(SoC_t_ch)) = SoC_t_ch;
        
        % Update of the length of SoC
        SoC_length = SoC_length + length(SoC_t_ch);
        
        % Recuperation of Ts_state and Tc_state
        Ts_state = simOut.Ts_t_ch(end);
        Tc_state = simOut.Tc_t_ch(end);
        
        % Recuperation of V1_state and V2_state
        V1_state = simOut.V1_t_ch(end);
        V2_state = simOut.V2_t_ch(end);
        
        % Updating the values of the parameters in the model Workspace
        for k = 1:length(vars)
            assignin(modelWS, vars{k}, eval(vars{k}));
        end
        
        fprintf('Cycle %d: Discharging\n', cycle);
       
        
        % Adaptation of the discharging time
        % dischargeTime = current_SoC*3600/I_c;
        
        % Update the model for discharging
        set_param(modelName, 'SimulationCommand', 'update'); % Ensure model is updated
        set_param(modelName, 'StopTime', num2str(dischargeTime));
 
        configureDischargeMode(modelName, mode_discharge);
 
       
        % Run the simulation for discharging
        simOut = sim(modelName);
        fprintf('Discharging completed for cycle %d\n', cycle);
        fprintf('Ah ccumulated %d\n',Ah_accumulated)
        %fprintf('Ah thourgh cycles %d\n', Ah_through_cycles)
        
        
        % Save discharging outputs
        discharging_out{cycle} = simOut; % Store output in a cell array
        
        % Recuperation of V(t), I(t), and t
        V_t_dis = simOut.V_t_dis.Data;
        I_t_dis = simOut.I_t_dis.Data;
        t = simOut.V_t_dis.Time;
        t = t + offset;
        
        Time(time_length+1:time_length + length(t)) = t;
        V_t(V_length+1:V_length + length(V_t_dis)) = V_t_dis;
        I_t(I_length+1:I_length + length(I_t_dis)) = I_t_dis;
        
        % Update of the length of V, I and Time
        V_length = V_length + length(V_t_dis);
        I_length = I_length + length(I_t_dis);
        time_length = time_length + length(t);
        
        offset = t(end);
        
        % Extract the final SoC from discharging output
        current_SoC = simOut.SoC_t_dis(end);
        fprintf('Current SoC : %d\n\r', current_SoC);
        %fprintf('Idischarge: %d\n\r', I_t_dis);
        
        % Recuperation of the Ah through discharging
        Ah_dis = simOut.get('Ah_dis');
        Ah_accumulated = Ah_accumulated + Ah_dis(end);
        Ah_through_cycles(cycle+1) = Ah_accumulated;
        %fprintf('Ah dicharge %d\n', Ah_dis)
        
        % Recuperation of Ts_state and Tc_state
        Ts_state = simOut.Ts_t_dis(end);
        Tc_state = simOut.Tc_t_dis(end);
        
        % Recuperation of V1_state and V2_state
        V1_state = simOut.V1_t_dis(end);
        V2_state = simOut.V2_t_dis(end);
        
        for k = 1:length(vars)
            assignin(modelWS, vars{k}, eval(vars{k}));
        end
        
        % Recuperation of the SoC and Tc during the discharging phase
        SoC_t_dis = simOut.get('SoC_t_dis');
        Tc_t_dis = simOut.get('Tc_t_dis');
        SoC_t(SoC_length+1:SoC_length + length(SoC_t_dis)) = SoC_t_dis;
        
        % Update of the length of SoC
        SoC_length = SoC_length + length(SoC_t_dis);
        
        % Concatenation of SoC, Tc and I in order to have 3 arrays with charge and discharge data
        SoC_t_cycle = [SoC_t_ch; SoC_t_dis];
        Tc_t_cycle = [Tc_t_ch; Tc_t_dis];
        I_t_cycle = [I_t_ch; I_t_dis];
        
        % Evaluation of the capacity loss (coges un valor medio)
        Ic_t_mean = mean(3600*I_t_cycle/C_As);
        fprintf(' IC MEAN %d\n ', Ic_t_mean)
        SoC_t_mean = mean(SoC_t_cycle);
        Tc_t_mean = mean(Tc_t_cycle);
        
        if SoC_t_mean < 0.45
            alpha = 169663,05;
            beta = 70821.21;
        else
            alpha = 169663,05;
            beta = 70821.21;
        end
        
        C_loss = (alpha*SoC_t_mean + beta)*exp((-Ea+eta*Ic_t_mean)/(Rg*(Tc_t_mean+273.15)))*Ah_accumulated^z;
        
        Q_loss_through_cycles(cycle+1) = C_loss;
        fprintf("%d\n", C_loss);
        
        % Update of the value of the capacity
        C_As = (1 - C_loss/100)*Cn;
        Capacities(cycle+1) = C_As;
 
        % Store per-cycle values for Excel export
        excel_Ic_t_mean(cycle)      = Ic_t_mean;
        excel_C_loss(cycle)         = C_loss;
        excel_Ah_accumulated(cycle) = Ah_accumulated;
        
        fprintf('Capacity loss : %.4f%% \n', C_loss);
        fprintf('New Capacity : %.2f A.h\n', C_As);
        fprintf('Ah ccumulated %d\n',Ah_accumulated)
        %fprintf('Ah thourgh cycles %d\n', Ah_through_cycles)
        
        Cycles(cycle+1) = cycle;
    end
    
 
    % Cutting of the zeros at the end of the arrays → Ahora en función aparte
    [Time, V_t, I_t, SoC_t] = trimSignals(Time, V_t, I_t, SoC_t);
 
   
    
    createPlots(Cycles, Q_loss_through_cycles, Capacities, Time, V_t, I_t, SoC_t, numCycles);
    
    % Save per-cycle results to Excel
    excel_header = {'Cycle', 'Ic_t_mean (C-rate)', 'C_loss (%)', 'Ah_accumulated (Ah)'};
    cycle_numbers = num2cell((1:numCycles)');
    excel_rows    = [cycle_numbers, num2cell(excel_Ic_t_mean), ...
                     num2cell(excel_C_loss), num2cell(excel_Ah_accumulated)];
    writecell([excel_header; excel_rows], 'cycle_resultsV2_11julio.xlsx', 'Sheet', 1);
    fprintf('Cycle data saved to cycle_results.xlsx\n');
 
    % Close the Simulink model
    close_system(modelName, 0);
    disp('All cycles completed successfully.');
    
    % Save the outputs to a MAT file for later analysis
    save('cycle_results.mat', 'charging_out', 'discharging_out');
    
    toc;
end
 
 
% ====================== FUNCIÓN DE GRÁFICAS  ======================
function createPlots(Cycles, Q_loss_through_cycles, Capacities, Time, V_t, I_t, SoC_t, numCycles)
 
    % Plot of Q loss against number of cycles
    figure;
    plot(Cycles, Q_loss_through_cycles, '-o');
    xlabel('Number of cycles');
    ylabel('Capacity loss after each cycle (%)');
    title('Capacity loss in % against Number of cycles')
    grid on;
 
    % Plot of Capacity after each cycle against number of cycles
    figure;
    plot(Cycles, Capacities, '-o');
    xlabel('Number of cycles');
    ylabel('Capacity after each cycle (mA.h)');
    title('Capacity after each cycle in mA.h against Number of cycles')
    grid on;
 
    %Plot of V(t)
    figure;
    plot(Time, V_t, '-');
    xlabel('Time');
    ylabel('V(t)');
    title(sprintf('V(t) for %d cycles', numCycles));
    grid on;
 
    %Plot of I(t)
    figure;
    plot(Time, I_t, '-');
    xlabel('Time');
    ylabel('I(t)');
    title(sprintf('I(t) for %d cycles', numCycles));
    grid on;
 
    % Plot of SoC(t)
    figure;
    plot(Time, SoC_t, '-');
    xlabel('Time');
    ylabel('SoC(t)');
    title(sprintf('SoC(t) for %d cycles', numCycles));
    grid on;
 
end
 
% ====================== CONFIGURACIÓN DE MODOS ======================
function configureChargeMode(modelName, mode_charge)
    if strcmp(mode_charge,'CC')
        set_param([modelName '/Battery_charge_CC'], 'Commented', 'off');
        set_param([modelName '/Battery_charge_CC_CV'], 'Commented', 'on');
    else
        set_param([modelName '/Battery_charge_CC'], 'Commented', 'on');
        set_param([modelName '/Battery_charge_CC_CV'], 'Commented', 'off');
    end
    % Desactivar descarga
    set_param([modelName '/Battery_discharge_CC'], 'Commented', 'on');
    set_param([modelName '/Battery_discharge_CC_CV'], 'Commented', 'on');
end
 
 
function configureDischargeMode(modelName, mode_discharge)
    if strcmp(mode_discharge,'CC')
        set_param([modelName '/Battery_discharge_CC'], 'Commented', 'off');
        set_param([modelName '/Battery_discharge_CC_CV'], 'Commented', 'on');
    else
        set_param([modelName '/Battery_discharge_CC'], 'Commented', 'on');
        set_param([modelName '/Battery_discharge_CC_CV'], 'Commented', 'off');
    end
    % Desactivar carga
    set_param([modelName '/Battery_charge_CC'], 'Commented', 'on');
    set_param([modelName '/Battery_charge_CC_CV'], 'Commented', 'on');
end
 
% ====================== FUNCIÓN DE RECORTE DE SEÑALES ======================
function [Time, V_t, I_t, SoC_t] = trimSignals(Time, V_t, I_t, SoC_t)
    % Cutting of the zeros at the end of the arrays
    last_idx_Time = find(Time ~= 0, 1, 'last');
    last_idx_I    = find(I_t ~= 0, 1, 'last');
    last_idx_V    = find(V_t ~= 0, 1, 'last');
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
 
    % Define stop time for each charging/discharging simulation
    chargeTime = 10000; % Adjust as needed
    dischargeTime = 10000; % Adjust as needed
    
    % Initialize a variable to track the SoC
    current_SoC = 0; % Initial State of Charge (adjust as needed)
    
    % Initialize the Tc_state and Ts_state
    Tc_state = 25;
    Ts_state = 25;
    
    % Initialize the V1 state, V2 state, Vmax and Vcutoff
    V2_state = 0;
    V1_state = 0;
    V_max = 4.2;
    V_cutoff = 3;
    
    % Define initial capacity that will be updated with cycles
    Cn = 350;
    C_As = Cn;
    
    % Define current rate and the full charge current rate
    I_c = 1;
    I_c_full_charged = 1/30;
    
    % Initialize output storage
    charging_out = cell(numCycles, 1);
    discharging_out = cell(numCycles, 1);
    
    % Initialize empty arrays to stock values
    Ah_through_cycles = zeros(1, numCycles + 1);
    Q_loss_through_cycles = zeros(1, numCycles + 1);
    Cycles = 0:numCycles;
    Capacities = [C_As, zeros(1,numCycles)];
    
    % Initialisation of the Ah accumulated through cycles
    Ah_accumulated = 0;
    
    % Initialisations for the plot of I(t), V(t) and SoC(t)
    I_t = zeros(1,300*2*numCycles);
    V_t = zeros(1,300*2*numCycles);
    SoC_t = zeros(1,300*2*numCycles);
    Time = zeros(1,300*2*numCycles);
    
    % Initialisation of the offset
    offset = 0;
    
    % Initialisation of the lengths of V, I, SoC and Time
    V_length = 0;
    I_length = 0;
    time_length = 0;
    SoC_length = 0;
    
    % Initialize parameters for the capacity loss
    Ea = 31500;
    eta = 6393.72;
    z = 0.6940;
    Rg = 8.314;
end