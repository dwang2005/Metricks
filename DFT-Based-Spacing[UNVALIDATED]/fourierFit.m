function [spacing, predictions, R_sq_adj, fitParams] = fourierFit(fourierProfile, prior)

doplots = true;


%% Set up initial guess for fit parameters

% Remove any nan and inf.
fourierProfile = fourierProfile(~isnan(fourierProfile));
fourierProfile = fourierProfile(~isinf(fourierProfile));
fourierProfile = fourierProfile-min(fourierProfile);
timeBase = 0:(length(fourierProfile)-1);

%% Start plot
if doplots
    thePlot = figure(1); clf; hold on
    set(gca,'FontName','Helvetica','FontSize',14);
    plot(fourierProfile,'k');
end

if isempty(prior)
    
    fitParams.shift = fourierFit_v2(fourierProfile);
    % Make initial guesses
    fitParams.scale1 = 1;
    fitParams.decay1 = (fourierProfile(1)*.36) /...
                        (fitParams.shift-1);
    fitParams.offset1 = max(fourierProfile)-fitParams.scale1;
    fitParams.scale2 =  fitParams.offset1*.3679;
    fitParams.decay2 = (fourierProfile(fitParams.shift)*.36) /...
                        (length(fourierProfile)-fitParams.shift);
        
else
    fitParams = prior;
end

% Add initial guess to the plot
predictions0 = ComputeModelPreds(fitParams,timeBase);
if doplots
    figure(thePlot); hold on; plot(timeBase,predictions0,'k','LineWidth',2); hold off;
end

%% Fit

% Set fmincon options
options = optimset('fmincon');
options = optimset(options,'Diagnostics','off','Display','off','LargeScale','off','Algorithm','interior-point');

x1 = ParamsToX(fitParams);

vlb = [0.5 0.001 0.01 0.001  0.001  1];
vub = [5 0.5   15   15     0.5    length(fourierProfile)-2];

x = fmincon(@(x)FitModelErrorFunction(x,timeBase,fourierProfile,fitParams),x1,[],[],[],[],vlb,vub,[],options);

% Extract fit parameters
fitParams = XToParams(x,fitParams);

% Add final fit to plot
predictions = ComputeModelPreds(fitParams,timeBase);

if doplots
    figure(thePlot); hold on; plot(timeBase,predictions,'g','LineWidth',2);
    axis([0 150 0 5]);
end


residuals = fourierProfile-predictions;
spacing = ceil(fitParams.shift);
residuals = medfilt1(residuals,3);

preval = residuals(spacing-1)-residuals(spacing);
figure(2);
plot(spacing, residuals(spacing),'b*');

for i=spacing-1:-1:2
   
    thisval = residuals(i-1)-residuals(i);
    
    if preval>=0 && thisval>=0 % It should only be increasing or flat- if it isn't anymore and heads down, kick out.
        spacing=i; 

    elseif thisval<0.07
        if doplots
            figure(thePlot); 
            plot(spacing, fourierProfile(spacing),'r*')
        end
        break;
    end
    preval = thisval;
end

% [pks, locs]= findpeaks( residuals(1:ceil(spacing)) );
% 
% % If the last point is rising, then take add it to our list.
% if residuals(ceil(spacing))-residuals(ceil(spacing-1)) > 0
%     pks = [pks residuals(ceil(spacing))];
%     locs = ceil(spacing);
% end
% 
% if ~isempty(locs)
%     
%     pks = fliplr(pks);
%     locs = fliplr(locs);
%     if doplots
%         plot(locs(1), fourierProfile(locs(1)),'r*')
%     end
%     spacing = locs(1);
% end

% Coefficient of determination
SSres = sum(residuals.^2);
SStot = sum( (fourierProfile - mean(fourierProfile)).^2 );
n = length(fourierProfile);
p = length(x)-1;

R_sq_adj = 1 - ( (SSres./(n-p-1)) ./ (SStot./(n-1)) );

if doplots
    hold off;drawnow;
    figure(2);hold on; plot(residuals); hold on; plot(spacing, residuals(spacing),'r*');
    hold off;
    figure(1); title([' Adjusted R squared: ' num2str(R_sq_adj) ]);
end


end

% f = FitModelErrorFunction(x,timeBase,theResponse,fitParams)
%
% Search error function
function f = FitModelErrorFunction(x,timeBase,theResponse,fitParams)

% Extract parameters into meaningful structure
fitParams = XToParams(x,fitParams);

% Make predictions
preds = ComputeModelPreds(fitParams,timeBase);

% Compute fit error as RMSE
nPoints = length(theResponse);
theDiff2 = (theResponse-preds).^2;
f = 100*sqrt(sum(theDiff2)/nPoints);
% figure(333); hold on; plot(f,'.'); hold off;
end

% x = ParamsToX(params)
%
% Convert parameter structure to vector of parameters to search over
function x = ParamsToX(params)
    x = [params.scale1 params.decay1 params.offset1 params.scale2 params.decay2 params.shift];
end


% fitParams = XToParams(x,params)
%
% Convert search params and base structure to filled in structure.
function params = XToParams(x,params)
params.scale1 = x(1);
params.decay1 = x(2);
params.offset1 = x(3);
params.scale2 = x(4);
params.decay2 = x(5);
params.shift = x(6);
end

% preds =  ComputeModelPreds(params,t)
%
% Compute the predictions of the model
function fullExp = ComputeModelPreds(params,freqBase)

fullExp = params.offset1 + params.scale1*exp( -params.decay1 * freqBase );

bottomExpLoc = find(freqBase>params.shift);
bottomExpTime = freqBase(bottomExpLoc);

% The exponential must always line up with the other exponential function's
% value!   
maxmatch = fullExp(bottomExpTime(1))-params.scale2;

fullExp(bottomExpLoc) = maxmatch + params.scale2*exp( -params.decay2 * (bottomExpTime-bottomExpTime(1)) );

end
