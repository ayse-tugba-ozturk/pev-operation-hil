function events = gen_events_one_day(scenario, num_events)
% -- scenario=0 for baseline information; num_events could be anything
% arbitrary
% -- scenario=1 for randomly generates a sequence of events; need to specify
% num_events
par = get_glob_par(); 

if scenario == 0
    % baseline
    act_data = readtable('real_act_data_1day.csv');
    num_events = height(act_data);
    event_idx = linspace(1, num_events, num_events);
elseif scenario == 1
    % random sample sequence of events
    act_data = readtable('real_act_data.csv');
% rng(1)

    event_idx = sort(randi([1 height(act_data)], 1, num_events));
end
par.num_events = num_events; set_glob_par(par);
events.inp = cell(num_events,1);
events.time = zeros(num_events,1);
events.triggered = false*ones(num_events,1); % triggered event flag

% test data -- to be removed
% test_times = [0:0.5:num_events] + 12;


for i = 1:num_events
    n = event_idx(i); % specify event index 
    if act_data{n, 6} < 0.3
        continue
    end
    event.time = act_data{n, 2}; 
    event.SOC_init = act_data{n, 3};
    event.SOC_need = act_data{n, 4}; % add infeasible scenario
    event.batt_cap = act_data{n, 5};
    event.duration = act_data{n, 6}; % hours
    event.overstay_duration = act_data{n, 7};
    event.pow_max = act_data{n, 8};
    event.pow_min = 0;
    
    events.inp{i} = event;
    events.time(i) = event.time;
end

end