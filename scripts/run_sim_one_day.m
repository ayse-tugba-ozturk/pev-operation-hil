function varargout = run_sim_one_day(varargin)
% This script is to simulate EV charging station operations where the
% charging tariff is determined real-time with taking account into EV
% drivers' behaviors. The overall objective of the tariff control is to
% minimize the operation cost of the system operater. 
%
% There are three choices that each EV driver can make at arrival:
% (i) charging with flexibility, (ii) charging as soon as possible, and
% (iii) leaving without charging.
%
% At each arrival of EV driver, user specific parameters, e.g., battery
% capacity, desired parking durations, initial SOC, and needed SOC level
% (for next mobility demand) are randomly sampled from an empirical
% probability distribution function that is generated with TELD dataset 
% [X].
%
% THIS WORK IS A PART OF EE227C COURSE PROJECT AT UC BERKELEY.
% last modified, Sept 2019 - Teng
%
% Contributors: Sangjae Bae, Teng Zeng, Bertrand Travacca.

% clear

%% Initialization
% fprintf('[%s INIT] initializing...\n',datetime('now'));
if nargin == 0
    par = set_glob_par(init_params());
    events = gen_events_one_day(par);
elseif nargin == 1
    par = varargin{1};
    events = gen_events_one_day(par);
elseif nargin == 2
    par = varargin{1};
    events = varargin{2};
else
    error(sprintf('[%s ERROR] too many input arguments',datetime('now')));
end

if par.VIS_DETAIL
    fprintf('[%s INIT] INITIALIZATION DONE\n',datetime('now'));
end

%% Simulation
t = par.sim.starttime:par.Ts:par.sim.endtime; i_k = 0; i_event = 0;
sim = init_sim(t); % simulation result
station = containers.Map; % station monitor
station('num_occupied_pole') = 0; 
station('num_empty_pole') = par.station.num_poles;
sim.events = events;

for k = par.sim.starttime:par.Ts:par.sim.endtime
    i_k = i_k + 1;
    % check visit
    if i_event <= length(events.time)
        if any(round(events.time/par.Ts)*par.Ts == k)
            inds_events_k = find(round(events.time/par.Ts)*par.Ts == k);
            for j = 1:length(inds_events_k)
                i_event = i_event + 1; % number of investigated events
                if events.inp{inds_events_k(j)}.duration <= par.sim.endtime - k ...
                        && station('num_empty_pole') > 0
                   sim.tot_decision = sim.tot_decision + 1; % number of decisions
                   sim.events.triggered(i_event) = true; % this event is triggered
                    
                   set_glob_prb(init_prb(events.inp{inds_events_k(j)}));

                   % find optimal tariff
                   opt = run_opt();
                   sim.opts{i_event} = opt;

                   % driver makes choice
                   rc = rand;
                   if rc <= opt.prob.flex
                       opt.choice = 0; % charging with flexibility
                       opt.time.end = opt.time.end_flex;
                       opt.powers = opt.flex.powers;
                       opt.price = opt.tariff.flex;
                   elseif rc <= opt.prob.flex + opt.prob.asap
                       opt.choice = 1; % charging as soon as possible
                       opt.time.end = opt.time.end_asap;
                       opt.powers = opt.asap.powers;
                       opt.price = opt.tariff.asap;
                   else
                       opt.choice = 2; % leaving without charging
                   end
                   sim.choice_probs(i_event,:) = opt.v;
                   sim.choice(i_event) = opt.choice;
                   sim.control(i_event,:) = opt.z(1:3);
                   if par.VIS_DETAIL
                    fprintf('[%s EVENT] time = %.2f, CHOICE = %s\n',datetime('now'),k,par.dcm.choices{opt.choice+1});
                   end

                   % if the driver chooses to charge EV
                   if opt.choice <= 1
                       [opt.time.leave, duration] = get_rand_os_duration(opt);
                       sim.overstay_duration(i_k) = sim.overstay_duration(i_k) + duration;
                       sim.num_service(i_k) = sim.num_service(i_k) + 1;
                       station('num_occupied_pole') = station('num_occupied_pole') + 1;
                       station('num_empty_pole') = station('num_empty_pole') - 1;
                       station(['EV' num2str(sim.tot_decision)]) = opt;
                   end 
                else
                    if par.VIS_DETAIL
                        if station('num_empty_pole') == 0
                            fprintf('[%s EVENT] SKIPPED (event %d) due to full occupancy\n',datetime('now'),i_event);
                        else
                            fprintf('[%s EVENT] SKIPPED (event %d) due to violating operationg hours\n',datetime('now'),i_event);
                        end
                    end
                end
            end
        end
    end
    
    % update agg
    keys = station.keys();
    if ~isempty(keys)
        for ev = keys
            if contains(ev{1},'EV')
                if  k < station(ev{1}).time.end % is charging duration
%                     TOU = interp1(0:0.25:24-0.25,par.TOU,k,'nearest');
%                     if length(station(ev{1}).powers) > 1
%                         power = interp1(linspace(station(ev{1}).time.start, ...
%                                             station(ev{1}).time.end,...
%                                             length(station(ev{1}).powers)), ...
%                                             station(ev{1}).powers, k);
%                     elseif length(station(ev{1}).powers) == 1
%                         power = station(ev{1}).powers;
%                     end
                    TOU = interp1(0:0.25:24-0.25,par.TOU,k,'nearest');
                    % add actual power record to user
                    opt = station(ev{1});
%                     power = station(ev{1}).powers(no_event_counter);
                    dur = opt.time.start:par.Ts:opt.time.end-par.Ts;
                    if length(dur) > 1 && length(opt.powers) > 1
                        power = interp1(dur,opt.powers,k);
                    else
                        power = opt.powers(1);
                    end
%                     if power == opt.prb.station.pow_max % hyperthetically when power is max power it's the  uncontrol charging
                    if opt.choice == 1 % asap charging
                        sim.profit_charging_uc(i_k) = sim.profit_charging_uc(i_k) + par.Ts * power * (station(ev{1}).price - TOU);
                    else % flexible charging
                        sim.profit_charging_c(i_k) = sim.profit_charging_c(i_k) + par.Ts * power * (station(ev{1}).price - TOU);
                    end
                    sim.power(i_k) = sim.power(i_k) + power;
%                     sim.profit_charging(i_k) = sim.profit_charging(i_k) + par.Ts * power * (station(ev{1}).price - TOU);
                    sim.occ.charging(i_k) = sim.occ.charging(i_k) + 1;
                else % is overstaying
                    if k < station(ev{1}).time.leave 
                        sim.profit_overstay(i_k) = sim.profit_overstay(i_k) + par.Ts * station(ev{1}).tariff.overstay;
                        sim.occ.overstay(i_k) = sim.occ.overstay(i_k) + 1;
%                         sim.overstay_duration(i_k) = sim.overstay_duration(i_k) + par.Ts;
                    else
                        station.remove(ev{1});
                        station('num_occupied_pole') = station('num_occupied_pole') - 1;
                        station('num_empty_pole') = station('num_empty_pole') + 1;
                    end 
                end
            elseif contains(ev{1},'occ')
                sim.occ.total(i_k) = station('num_occupied_pole');
                sim.occ.empty(i_k) = station('num_empty_pole');
            end
        end
    end
end

sim.par = par;

varargout = {};
varargout{1} = sim;

%% Visualization
if nargout == 0
    options = vis_sim_one_day(); % options: display, temporals, choices
    options.temporals = true;
    vis_sim_one_day(sim,options);
end

end