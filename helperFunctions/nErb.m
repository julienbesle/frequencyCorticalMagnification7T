
% Number of cochlear ERBs fitting between 0 and f kHz 
% either according to Glasberg & Moore 1990, or
% derived from Oxenham & Sheera (2003)'s revised ERB(f)

function nerb = nErb(f,equation)

if ~exist('equation','var') || isempty(equation)
  equation = 'G&M90old';
end

switch(equation)
  
  case 'G&M90old'
    nerb = 21.4*log10(max(4.37*f+1,0)); % this is the equation given in the paper, but there is a rounding error (see below)
    % this is kept as default because I used it like this in both the tonotopy and adaptation papers
    
  case 'G&M90'
    % This is found by integrating the reciprocal of ERB(f) = A*(B*f + 1) over [0 f], where
    A = 0.0247;
    B = 4.37;
    % this can be done using integration by substitution to obtain
    nerb = log(B*f+1)/(A*B);
%     % or:
%     nerb = log10(B*f+1)/(A*B*log10(exp(1)))
%     % (A*B*log10(exp(1))) approximates to 21.3323, not sure why the published equation uses 21.4

  case 'O&S03'
    % This is found by integrating  the reciprocal of ERB(f) = f^(1-a) / b
    % (which is derived from  equation 5 in Oxenham & Sheera (2003): Q_ERB = f / ERB(f) = b * f^a)
    % where:
    a = 0.27;
    b = 11.1;
    % The solution (found using an integral calculator (https://www.integral-calculator.com/) is:
    nerb = b * f.^a / a;
    
  otherwise
    error('(nErb) Unknown equation ''%s''\n',equation);
    
end
