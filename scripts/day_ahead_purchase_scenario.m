% load data
clear;clc
% potentially be more than one scenario
demands = readtable('../../market_participation/aggregate_model/output_data/minute_demand_scenario.csv');
par.p_max = table2array(demands(:,2)); par.p_min = table2array(demands(:,3));
par.e_max = table2array(demands(:,4)); par.e_min = table2array(demands(:,5));
par.day_length = 192;
par.num_scenario = length(par.p_max)/par.day_length;
par.scen_prob = table2array(demands(1:par.num_scenario,6));

% reshape demands
par.p_max = reshape(par.p_max, par.day_length, par.num_scenario);
par.p_min = reshape(par.p_min, par.day_length, par.num_scenario);
par.e_max = reshape(par.e_max, par.day_length, par.num_scenario);
par.e_min = reshape(par.e_min, par.day_length, par.num_scenario);

% convert from kW to MW
par.to_MW = true;
%% get average / get one scenario

% par.p_max = mean(par.p_max,2);
% par.p_min = mean(par.p_min,2);
% par.e_max = mean(par.e_max,2);
% par.e_min = mean(par.e_min,2);
 
par.scen_idx = 8;
par.p_max = par.p_max(:,par.scen_idx); par.p_min = par.p_min(:,par.scen_idx);
par.e_max = par.e_max(:,par.scen_idx); par.e_min = par.e_min(:,par.scen_idx);

par.scen_prob = [1];
par.num_scenario = 1;
%% specify params

% day ahead TOU
par.TOU_DA = [0.217*ones(1,8) ...    % 0-8
              0.244*ones(1,12-8) ...    % 8-12
              0.268*ones(1,16-12) ...      % 12-16
              0.244*ones(1,21-16) ...    % 16-21
              0.217*ones(1,24-21)];      % 21-24
par.TOU_DA = [par.TOU_DA par.TOU_DA];      

% real time TOU
% par.TOU_RT = [0.217*ones(1,34) ...    % 0-8.5
%               0.244*ones(1,48-34) ...    % 8.5-12
%               0.268*ones(1,72-48) ...      % 12-16
%               0.244*ones(1,86-72) ...    % 16-21.5
%               0.217*ones(1,96-86)];      % 22-24
par.TOU_RT = par.TOU_DA + 0.01;  % TODO: threshold 0.185-ish

% charging station config
par.eff = 0.92;                             % power efficiency

% environment misc params
par.N = par.day_length/2/24; % number of sub-hour intervals in one hour
par.delta_t = 1 / par.N; % sub-hour interval duration

% energy market misc params
par.dev_thres = 0.01; % allowable energy deviation
par.pnlt_energy_plus = 10; % price penalty for over-consumed energy
par.pnlt_energy_minus = 10; % price penalty for under-consumed energy
par.pnlt_power_aux = 1e5; % penalty param for auxillary variable P_aux

if par.to_MW 
    par.p_max = par.p_max / 1000; par.p_min = par.p_min / 1000;
    par.e_max = par.e_max / 1000; par.e_min = par.e_min / 1000;
    par.TOU_DA = par.TOU_DA * 1000;
    par.TOU_RT = par.TOU_RT * 1000;
    par.pnlt_energy_plus = par.pnlt_energy_plus * 1000;
    par.pnlt_energy_minus = par.pnlt_energy_minus * 1000;
    par.pnlt_power_aux = par.pnlt_power_aux * 1000;
end

%% define variables
E_DA = sdpvar(48,1,'full');
E_deviation = sdpvar(48,1,par.num_scenario,'full');
P = sdpvar(par.day_length,1,par.num_scenario,'full');
P_aux = sdpvar(par.day_length,1,par.num_scenario,'full'); % handle data error

E_deviation_plus = sdpvar(48,1,par.num_scenario,'full');
E_deviation_minus = sdpvar(48,1,par.num_scenario,'full');
U_plus = sdpvar(48,1,par.num_scenario,'full');
U_minus = sdpvar(48,1,par.num_scenario,'full');
%% define constraints

% power constraint
constraints_power = [P_aux >= 0];
for i = 1:par.num_scenario
    constraints_power = [constraints_power; ...
                         par.p_min(:,i) <= P(:,1,i) <= par.p_max(:,i)+P_aux(:,1,i)];
end

% energy constraint
constraints_energy = [];
for i = 1:par.num_scenario
    for t = 1:par.day_length
        energy_delivered = sum(P(1:t,1,i))*par.delta_t;
        constraints_energy = [constraints_energy; ...
                              par.e_min(t,i) <= energy_delivered <= par.e_max(t,i)];
    end
end

% energy deviation
constraints_dev = [E_DA >= 0];
for i = 1:par.num_scenario
    for t = 1:48
        energy_delivered_hourly = sum(P((t-1)*par.N+1:t*par.N,1,i))*par.delta_t;
        constraints_dev = [constraints_dev; ...
                           E_deviation(t,1,i) == energy_delivered_hourly - E_DA(t,1)];
    end
end

% energy deviation for over and under consumption
constraints_dev = [constraints_dev; ...
                   E_deviation == E_deviation_plus - E_deviation_minus; ...
                   E_deviation_plus >= 0; E_deviation_minus >= 0];

% deviation penalty
constraints_dev_pnlty = [];
for i = 1:par.num_scenario
    constraints_dev_pnlty = [constraints_dev_pnlty; ...
                             U_plus(:,1,i) == par.pnlt_energy_plus * (E_deviation_plus(:,1,i) - par.dev_thres * E_DA)];
    constraints_dev_pnlty = [constraints_dev_pnlty; ...
                             U_minus(:,1,i) == par.pnlt_energy_minus * (E_deviation_minus(:,1,i) - par.dev_thres * E_DA)];
end
%% solve
objective = par.TOU_DA * E_DA;
for i = 1:par.num_scenario
    scen_deviation = par.TOU_RT * max(E_deviation(:,1,i),0) + sum(max(U_plus(:,1,i),0)) + sum(max(U_minus(:,1,i),0));
    scen_pnalty = par.pnlt_power_aux * norm(P_aux(:,1,i));
    objective = objective + par.scen_prob(i) * (scen_deviation + scen_pnalty);
end

ops = sdpsettings('savesolverinput',1,'savesolveroutput',1);
constraints = [constraints_power; constraints_energy; constraints_dev; constraints_dev_pnlty];

Sol = solvesdp(constraints, objective, ops);
errorCode = Sol.problem;

if errorCode~=0
        fprintf('errorCode = %d \n', errorCode);
else
    
    time_YALMIP = Sol.yalmiptime
    time_solver = Sol.solvertime
    
    optSol.obj = value(objective);
    optSol.E_DA = value(E_DA);
    optSol.E_deviation = value(E_deviation);
    optSol.P = value(P);
    optSol.P_aux = value(P_aux);
    optSol.E_deviation_plus = value(E_deviation_plus);
    optSol.E_deviation_minus = value(E_deviation_minus);
    optSol.U_plus = value(U_plus);
    optSol.U_minus = value(U_minus);
    fprintf('\n****************Objective Value*************\n');
    optObjValue = optSol.obj
end
%% plot results - RT energy trajectory
figure(1)
plot(par.e_max,'LineWidth', 2)
hold on 
plot(par.e_min,'LineWidth', 2)
hold on
plot(1:par.day_length, reshape(cumsum(optSol.P)*par.delta_t,par.day_length,[]), '-.', 'LineWidth', 2)
hold off


xlim([1,120])
xlabel('Time of Day')
ylabel('Energy Consumption (kWh)')
if par.to_MW
    ylabel('Energy Consumption (MWh)')
end
title('Optimal Energy Trajectory')
legend('Energy UB', 'Energy LB', 'Cum Power',  'location', 'best')
set(gca,'FontSize',16) 

%% plot results - DA energy trajectory
figure(2)
% plot(reshape(sum(reshape(par.e_max,4,[],par.num_scenario))*par.delta_t, 48,[]),'LineWidth', 2)
% hold on 
% plot(reshape(sum(reshape(par.e_min,4,[],par.num_scenario))*par.delta_t, 48,[]),'LineWidth', 2)
% hold on
plot(par.delta_t:par.delta_t:48, par.e_max,'LineWidth', 2)
hold on
plot(par.delta_t:par.delta_t:48, par.e_min,'LineWidth', 2)
hold on
plot(cumsum(optSol.E_DA), '-.', 'LineWidth', 2)
hold on
plot(cumsum(reshape(sum(reshape(optSol.P,4,[],par.num_scenario))*par.delta_t, 48,[])), '-.', 'LineWidth', 2)
hold off


xlim([1,48])
xlabel('Time of Day')
ylabel('Energy Consumption (kWh)')
if par.to_MW
    ylabel('Energy Consumption (MWh)')
end

if par.num_scenario == 1
    title(['Scenario ', num2str(par.scen_idx), ': Optimal Energy Trajectory'])
else
    title('Optimal Energy Trajectory')
end

legend('Energy UB', 'Energy LB', 'Cum E-DA', 'Cum P', 'location', 'best')
set(gca,'FontSize',16)

%% plot results - power profile
figure(3)
is_hourly = true;

if is_hourly
    yyaxis left
    plot(mean(reshape(optSol.P, 4, [])), 'LineWidth', 2)
    hold on 
    plot(mean(reshape(par.p_max, 4, [])), 'LineWidth', 2)
    hold on 
    ylabel('Power (kW)')
    if par.to_MW
        ylabel('Power (MW)')
    end
    yyaxis right
    plot(par.TOU_DA, 'LineWidth', 2)
    hold on
    plot(par.TOU_RT, 'LineWidth', 2)
    ylabel('Unit Cost ($/kWh)')
    if par.to_MW
        ylabel('Unit Cost ($/MWh)')
    end
    xlim([1,30])
else
    yyaxis left
    plot(reshape(optSol.P,par.day_length,[]), 'Color','k', 'LineWidth', 2)
    hold on 
    plot(par.p_max(1:par.day_length), 'Color','b', 'LineWidth', 2)
    hold on 
    ylabel('Power (kW)')
    if par.to_MW
        ylabel('Power (MW)')
    end
    yyaxis right
    plot(repelem(par.TOU_DA,par.N), 'LineWidth', 2)
    hold on 
    plot(repelem(par.TOU_RT,par.N), 'LineWidth', 2)
    ylabel('Unit Cost ($/kWh)')
    if par.to_MW
        ylabel('Unit Cost ($/MWh)')
    end
    xlim([1,120])
end
hold off
xlabel('Time of Day')
title('Power Profile')
legend('Power', 'Power UB', 'TOU DA', 'TOU RT')
set(gca,'FontSize',16) 








