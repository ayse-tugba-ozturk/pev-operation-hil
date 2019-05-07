function vis_sim_monte(varargin)
close all;
% visualizes monte carlo simulation results

if nargin == 0
    [fname, fpath] = uigetfile;
    data = load(fullfile(fpath,fname));
    sim_results = data.sim_results;
    num_sim = data.num_sim;
elseif nargin == 1
    sim_results = varargin{1};
    num_sim = length(sim_results);
end


%% Postprocessing
fprintf('[%s SIM] post-processing...\n',datetime('now')); tic;
overstay_mean = zeros(num_sim,1);
overstay_penalty_mean = zeros(num_sim,1);
overstay_tot = zeros(num_sim,1);
profit = zeros(num_sim,1);
service_tot = zeros(num_sim,1);
for n = 1:num_sim
    overstay_mean(n) = mean(sim_results{n}.overstay_duration(sim_results{n}.overstay_duration~=0));
    overstay_penalty_mean(n) = mean(sim_results{n}.control(sim_results{n}.control(:,3)~=0,3));
    overstay_tot(n) = sum(sim_results{n}.overstay_duration);
    profit(n) = sum(sim_results{n}.profit);
    service_tot(n) = sum(sim_results{n}.num_service);
end
fprintf('[%s SIM] post-processing... DONE (%.2f sec)\n',datetime('now'),toc);


%% Visualization
% TODO: pareto chart overstay duration vs. profits with different reg params for overstaying
fprintf('[%s SIM] visualizing...\n',datetime('now')); tic;
% (1) distributions
% overstay histogram
figure; num_bins = 10; 
vals_to_vis = {'overstay_mean','profit','service_tot'};
baselines = [mean(overstay_mean)*1.2, mean(profit)*0.8, mean(service_tot)*0.8];
xlabels = {'mean overstay duration (hour)','net profit ($)','service provide (#)'};
ylabels = {'probability [0,1]'};
num_subplot = length(vals_to_vis);
for i = 1:num_subplot
    subplot(eval([num2str(num_subplot) '1' num2str(i)]));
    eval(['vals=' vals_to_vis{i}]); baseline = baselines(i);
    h = histogram(vals,num_bins,'Normalization','probability'); hold on;
    s1 = stem(mean(vals),1,'b','linewidth',3, 'markersize',eps); 
    s2 = stem(baseline,1,'r','linewidth',3,'markersize',eps); hold off;
    ylim([0 max(h.BinCounts/sum(h.BinCounts))+0.05]);
    text(mean(vals),max(h.BinCounts/sum(h.BinCounts))+0.04, ...
        sprintf(' mean: %.1f (%+.2f%%)',mean(vals),(mean(vals)/baseline-1)*100),...
        'fontsize',15);
    grid on; xlabel(xlabels{i}); ylabel('probability [0,1]');
    set(gca,'fontsize',15);
    if i == 1
        legend([s1 s2],{'mean w/ control','mean w/o control'},'location','northwest');
    end
end
saveas(gcf,'recent-visualization/hist.png');
saveas(gcf,'recent-visualization/hist.fig');
saveas(gcf,'recent-visualization/hist','epsc');


% (2) one day simulation results
% visualize temporal trajectories and choices
day = randi(length(sim_results));
vis_sim_one_day(sim_results{day});


% (3) pareto charts
% mean overstay penalty vs. profits
figure; 
subplot(121);scatter(overstay_penalty_mean,profit,'filled'); grid on; set(gca,'fontsize',15);
xlabel('mean overstay penalty ($)'); ylabel('profit ($)');

% mean overstay penalty vs. mean overstay duration
subplot(122);scatter(overstay_penalty_mean,overstay_mean,'filled'); grid on; set(gca,'fontsize',15);
xlabel('mean overstay penalty ($)'); ylabel('mean overstay duration (hour)');
sgtitle([{'Pareto Chart'},{sprintf('(total number of simulations: %d)',length(sim_results))}],'fontsize',18);
saveas(gcf,'recent-visualization/pareto.png');
saveas(gcf,'recent-visualization/pareto.fig');
saveas(gcf,'recent-visualization/pareto','epsc');

% (4) convergence rate of BCD
ind_events = find(~isnan(sim_results{day}.choice));
max_num_iter = 0; ind_max_num_iter=0;
for e = 1:length(ind_events)
    if sim_results{day}.opts{ind_events(e)}.num_iter > max_num_iter
        max_num_iter = sim_results{day}.opts{ind_events(e)}.num_iter;
        ind_max_num_iter = ind_events(e);
    end
end
vis_sim_one_event(sim_results{day}.opts{ind_max_num_iter});

fprintf('[%s SIM] visualizing... DONE (%.2f sec)\n',datetime('now'),toc);
end