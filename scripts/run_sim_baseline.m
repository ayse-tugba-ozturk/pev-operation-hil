function varargout = run_sim_baseline(varargin)
% This script is to simulate the total profit and overstay duration of the
% operation of EV charging station without tariff & optimal charging
% controller. The simulation result (without controller) is used as a 
% baseline which will be compared to the simulation result with controller.

%% Initailize
if nargin == 0
    [fname, fpath] = uigetfile;
    data = load(fullfile(fpath,fname));
    sim_results = data.sim_results; 
    num_sim = length(sim_results);
elseif nargin == 1
    sim_results = varargin{1}.sim_results;
    num_sim = length(sim_results);
else
    fprintf('[%s ERROR] invalid number of inputs',datetime('now'));
end
par = sim_results{1}.par;
isFixedEventSequence = par.sim.isFixedEventSequence;
% true -- simulation with infinite number of poles, with fixed sequence of
%         events. This case, the baseline is a constant value.
% false -- simulation with constrained number of poles, with random
%         sequence of events. This case, the baseline has a distribution of
%         values (each value per sequence).


%% Run simulation

if isFixedEventSequence
    sim_results_baseline = {};
    sim_results_baseline{1} = run_sim_one_day_baseline(sim_results{1});
else
    sim_results_baseline = cell(num_sim,1);
    for i = 1:length(sim_results)
        % initialize
        sim_c = sim_results{i};
        sim_results_baseline{i} = run_sim_one_day_baseline(sim_c);
    end
end
if nargout == 1
    varargout = {};
    varargout{1} = sim_results_baseline;
end


%% Visualization
if nargin == 0
    vis_sim_monte(sim_results,sim_results_baseline);
end
end