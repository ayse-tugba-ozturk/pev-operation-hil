function par = init_params(varargin)

% simulation parameters
par.sim.starttime = 7;
par.sim.endtime = 22;
par.Ts = 0.25; % timestep, hour -- must decompose 1

% TOU
par.TOU = [0.217*ones(1,34) ...    % 0-8.5
           0.244*ones(1,48-34) ...    % 8.5-12
           0.268*ones(1,72-48) ...      % 12-16
           0.244*ones(1,86-72) ...    % 16-21.5
           0.217*ones(1,96-86)];      % 22-24

% charging station config
par.station.num_poles = 8;                 % number of charging poles
par.eff = 0.89;                             % power efficiency

% dcm params
par.dcm.choices = [{'charging with flexibility'},{'charging asap'},{'leaving without charging'}];
% par.dcm.charging_flex.params = [-2.2 0 0 2]';          % DCM parameters for choice 1 -- charging with flexibility 
% par.dcm.charging_asap.params = [0 -2.2 0 2.5]';          % DCM parameters for choice 2 -- charging as soon as possible
% par.dcm.leaving.params       = [0.01 0.01 1.2 0]';           % DCM parameters for choice 3 -- leaving without charging
par.dcm.charging_flex.params = [-1 0 0 2]';          % DCM parameters for choice 1 -- charging with flexibility 
par.dcm.charging_asap.params = [0 -1 0 2.5]';          % DCM parameters for choice 2 -- charging as soon as possible
par.dcm.leaving.params       = [0.01 0.01 0.01 0]';           % DCM parameters for choice 3 -- leaving without charging
par.THETA = [par.dcm.charging_flex.params';
             par.dcm.charging_asap.params';
             par.dcm.leaving.params'];

% pdfs
par.pdf.visit = [0.1*ones(1,7) ...    % 0-7
                 0.3*ones(1,5) ...    % 7-12
                 0.2*ones(1,2) ...    % 12-14
                 0.2*ones(1,2) ...    % 14-16
                 0.2*ones(1,6) ...    % 16-22
                 0.001*ones(1,2)];    % 22-24

% regularization params
par.lambda.x = 10;
par.lambda.z_c = 10;
par.lambda.z_uc = 0.1;
par.lambda.h_c = 0.01; % TODO: should be average overstay penalty in real data, should move to par
par.lambda.h_uc = 0.01; % TODO: should be average overstay penalty in real data, should move to par
par.mu = 1e4;
par.soft_v_eta = 1e-2; % softening equality constraint for v; to avoid numerical error
par.opt.eps = 1e-4;


% cost function
par.v_dot_h = ['dot([sum((x(prb.N_flex+2:end).*(prb.TOU(1:prb.N_flex) - z(1))).^2)+ par.lambda.h_c * 1/z(3);'...
                   ' sum((par.station.pow_max*(prb.TOU(1:prb.N_asap) - z(2))).^2)+ par.lambda.h_uc * 1/z(3);'...
                   ' 1/3*sum((par.station.pow_max*(prb.TOU(1:prb.N_asap) - 0)).^2)],v)'];
end
