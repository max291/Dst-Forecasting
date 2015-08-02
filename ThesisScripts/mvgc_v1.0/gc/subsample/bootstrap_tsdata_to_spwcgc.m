%% bootstrap_tsdata_to_spwcgc
%
% Calculate sampling distribution for pairwise-conditional frequency-domain MVGCs
% from time series data, based on a nonparametric bootstrap
%
% <matlab:open('bootstrap_tsdata_to_spwcgc.m') code>
%
%% Syntax
%
%     fB = bootstrap_tsdata_to_spwcgc(U,p,fres,nsamps,acmaxlags,acdectol)
%
%% Arguments
%
% See also <mvgchelp.html#4 Common variable names and data structures>.
%
% _input_
%
%     U          multi-trial time series data
%     p          model order (number of lags)
%     fres       frequency resolution (default: automatic)
%     nsamps     number of bootstrap samples
%     acmaxlags  maximum autocovariance lags  (default as for 'var_to_autocov')
%     acdectol   autocovariance decay tolerance (default as for 'var_to_autocov')
%
% _output_
%
%     fB         bootstrap spectral Granger causalities (empirical distribution)
%
%% Description
%
% Returns |nsamps| samples from the empirical sampling distribution of the
% pairwise-conditional frequency-domain MVGCs from the time series data |U|. The
% bootstrap randomly samples (with replacement) residuals of the full
% autoregression of |U| on its own lags; the subsampled residuals are then added
% back to the corresponding predictors to form surrogate time series [2]. |p| is
% the model order; for other parameters see <var_to_autocov.html
% |var_to_autocov|>.
%
% The first dimension of the returned matrix |fP| indexes samples, the second
% indexes the target (causee) variable, the third the source (causal)
% variable and the fourth frequency.
%
% Spectral causality is calculated up to the Nyqvist frequency at a
% resolution |fres|. If |fres| is not supplied it is calculated optimally
% as the number of autocovariance lags. Call |freqs =
% <sfreqs.html sfreqs>(fres,fs)|, where |fs| is the sampling
% rate, to get a corresponding vector |freqs| of frequencies on |[0,fs/2]|.
%
%% References
%
% [1] L. Barnett and A. K. Seth,
% <http://www.sciencedirect.com/science/article/pii/S0165027013003701 The MVGC
%     Multivariate Granger Causality Toolbox: A New Approach to Granger-causal
% Inference>, _J. Neurosci. Methods_ 223, 2014
% [ <matlab:open('mvgc_preprint.pdf') preprint> ].
%
% [2] D. A. Freedman, Bootstrapping regression models, _Ann. Stats._ 9(6), 1981.
%
%% See also
%
% <mvgc_demo_bootstrap.html |mvgc_demo_bootstrap|> |
% <bootstrap_tsdata_to_mvgc.html |bootstrap_tsdata_to_mvgc|> |
% <bootstrap_tsdata_to_pwcgc.html |bootstrap_tsdata_to_pwcgc|> |
% <bootstrap_tsdata_to_smvgc.html |bootstrap_tsdata_to_smvgc|> |
% <var_to_autocov.html |var_to_autocov|> |
% <autocov_to_spwcgc.html |autocov_to_spwcgc|> |
% <sfreqs.html |sfreqs|>.
%
% (C) Lionel Barnett and Anil K. Seth, 2012. See file license.txt in
% installation directory for licensing terms.
%
%%

function fB = bootstrap_tsdata_to_spwcgc(U,p,fres,nsamps,acmaxlags,acdectol)

if nargin < 5, acmaxlags = []; end % ensure default
if nargin < 6, acdectol  = []; end % ensure default

[n,m,N] = size(U);
assert(m > p,'too many lags');
p1 = p+1;
M = N*(m-p);
np = n*p;

h = fres+1;

fB = nan(nsamps,n,n,h);

% estimate VAR coefficients

U = demean(U);                 % no constant term
U0 = reshape(U(:,p1:m,:),n,M); % concatenate trials for unlagged observations
UL = zeros(n,p,M);
for k = 1:p
    UL(:,k,:) = reshape(U(:,p1-k:m-k,:),n,M); % concatenate trials for k-lagged observations
end
UL = reshape(UL,np,M);         % stack lags
A = U0/UL;                     % OLS using QR decomposition
if isbad(A), return; end       % something went badly wrong

% calculate predictions and residuals

m   = m-p;                     % we lose p observations
UP  = A*UL;                    % predictions
E   = U0-UP;                   % residuals: so U0 = UP + E
E   = reshape(E,n,m,N);        % put residuals back into per-trial form

EB = zeros(n,m,N);
for s = 1:nsamps
    fprintf('spectral PWCGC, bootstrap sample %d of %d',s,nsamps);
    
    % generate bootstrap time series
    
    for r = 1:N
        EB(:,:,r) = E(:,randi(m,1,m),r); % per-trial subsample residuals with replacement
    end
    UB = UP + reshape(EB,n,M); % the bootstrap: add subsampled residuals to predictions
    
    % estimate bootstrap VAR parameters
    
    AB = UB/UL;                % OLS using QR decomposition
    if isbad(AB), fprintf(' *** VAR estimation failed\n'); continue; end % something went badly wrong
    EE = UB-AB*UL;             % bootstrap residuals (recalculate)
    AB = reshape(AB,n,n,p);    % bootstrap VAR coefficients
    SIGB = (EE*EE')/(M-1);     % bootstrap residuals covariance matrix
    
    % calculate bootstrap PWCGC
    
    [G,res] = var_to_autocov(AB,SIGB,acmaxlags,acdectol);
    if res.error, fprintf(' *** bad VAR: %s\n',res.errmsg); continue; end
    
    fB(s,:,:,:) = autocov_to_spwcgc(G,fres);
    
    fprintf('\n');
end
