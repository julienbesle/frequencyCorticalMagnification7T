
% Number of DLFs fitting between 0 and f (in kHz)
% after either Nelson et al. (1983) or Micheyl et al. (2012)

function ndlf = nDlf(fkHz,equation,level,duration)

if ~exist('equation','var') || isempty(equation)
  equation = 'M12';
end
if ~exist('level','var') || isempty(level)
  level = 40;  % stimulus level in dB SL
end
if ~exist('duration','var') || isempty(duration)
  duration = 200;  % stimulus duration in ms
end

switch(equation)
  case 'N83'
    % this is obtained by integration of the reciprocal of Nelson et al (1983)'s dlf(f) function (see dlf.m)
    a = 0.0214;
    m = 5.056;
    k = -0.15;
    
    % version of the integral from Ben's thesis (from www.wolframalpha.com) with input frequency in Hz [ dlf = 10.^(a * sqrt(f) + m * (1/level) + k), see dlf.m ]
    fHz = fkHz*1000; %convert frequency to Hz
%     ndlf = -( (a*sqrt(fHz) * log(10) + 1) .* 2 .^ ( -a*sqrt(fHz) - m/level - k + 1) .* 5.^ (-a*sqrt(fHz) - m/level - k) ) / (a^2 * log(10)^2) ...
%            +( 2 .^ (- m/level - k + 1) .* 5.^ (- m/level - k) ) / (a^2 * log(10)^2); % but adding a constant to ensure that ndlf(0) = 0
%     ndlf = 2 * ( 10 .^ (- m/level - k) - ( (a*sqrt(fHz) * log(10) + 1) .* 10 .^ ( -a*sqrt(fHz) - m/level - k) ) ) / (a^2 * log(10)^2); % slightly simplified version
    c = m/level + k; % put everything that does not depend on f in a constant
    ndlf = 2 * ( 10 .^ -c - ( (a*sqrt(fHz) * log(10) + 1) .* 10 .^ ( -a*sqrt(fHz) - c ) ) ) / (a^2 * log(10)^2); % slightly simplified version

%     % version from integral-calculator.com with input frequency in kHz [ dlf = 10.^(a * sqrt(1000*fkHz) + c, where c = m/level + k - 3) ]
%     c = m/level + k - 3; % put everything that does not depend on f in a constant
%     ndlf = -( (10^(3/2) * a*log(10)*sqrt(fkHz) + 1) .* 10.^( -10^(3/2) * a*sqrt(fkHz) - c - 2) ) / (5 * a^2 * log(10)^2) ...
%            +( 10.^( - c - 2) ) / (5 * a^2 * log(10)^2);
%     ndlf = ( ( 10.^( - c - 2) ) - ( (10^(3/2) * a*log(10)*sqrt(fkHz) + 1) .* 10.^( -10^(3/2) * a*sqrt(fkHz) - c - 2) ) ) / (5 * a^2 * log(10)^2); % simplified version
    
%     % note that these equations are a special case of the ones derived from Micheyl et al (2012)'s DLF equation
%     % without the duration term, with f in kHz and with the following constants:
%     Bf = a*10*sqrt(10);
%     Gf = 0.5; % i.e. sqrt
%     Bs = m/10;
%     Gs = -1; % i.e. 1/x
%     A = k;
%     ndlf = -( (Bf*fkHz.^Gf * log(10) + 1) .* 2 .^ ( -Bf*fkHz.^Gf - Bs*(level/10).^Gs - A + 1) .* 5.^ (-Bf*fkHz.^Gf - Bs*(level/10).^Gs - A) ) / ( Bf^2 * log(10)^2 ) * 1000 ...
%            +( 2 .^ (- Bs*(level/10).^Gs - A + 1) .* 5.^ (- Bs*(level/10).^Gs - A) ) / ( Bf^2 * log(10)^2 ) * 1000;
%     ndlf = 2 * ( 10 .^ (- Bs*(level/10).^Gs - A) - ( (Bf*fkHz.^Gf * log(10) + 1) .* 10 .^ ( -Bf*fkHz.^Gf - Bs*(level/10).^Gs - A) ) ) / ( Bf^2 * log(10)^2 ) * 1000 ;
%     c = Bs*(level/10).^Gs + A; % put everything that does not depend on f in a constant
%     ndlf = 2 * ( 10 .^ -c - ( (Bf*fkHz.^Gf * log(10) + 1) .* 10 .^ (-Bf*fkHz.^Gf - c) ) ) / ( Bf^2 * log(10)^2 ) * 1000 ;
%     % for the equation that takes the input frequency in kHz, we have:
%     Bf = a;
%     c = Bs * (level/10).^Gs + A - 3; % put everything that does not depend on f in a constant
%     ndlf = ( ( 10.^( - c - 2) ) - ( (10^(3/2) * Bf*log(10)*fkHz.^Gf + 1) .* 10.^( -10^(3/2) * Bf*fkHz.^Gf - c - 2) ) ) / (5 * Bf^2 * log(10)^2); % simplified version

  case 'M12'
    % this is obtained by integrating the reciprocal of Micheyl et al. (2012)'s dlf(f) function (see dlf.m)
    Bf = 0.38;
    Gf = 0.82;  % exponent for frequency
    Bs = 0.37;
    Gs = -1.09; % exponent for stimulus level
    Bd = 0.42;
    Gd = -0.42; % exponent for stimulus duration
    A = -0.38;
    c = Bs * (level/10).^Gs + Bd * (duration/100).^Gd + A - 3; % put everything that does not depend on f in a constant
%     ndlf = -( gammainc( log(10)*Bf*fkHz.^Gf, 1/Gf, 'upper' ).*fkHz ) ./ ( log(10)^(1/Gf) * 10^c * Gf * (Bf*fkHz.^Gf).^(1/Gf) ) + ...% version from www.integral-calculator.com
%     ( gammainc( log(10)*Bf*eps^Gf, 1/Gf, 'upper' )*eps ) / ( log(10)^(1/Gf) * 10^c * Gf * (Bf*eps^Gf)^(1/Gf) ); % with constant set such that nDlf(0)=0; (using eps instead of 0, because we have a 0/0 situation otherwise)
    ndlf = -( 10^(-c) * fkHz * log(10).^(-1/Gf) .* (Bf * fkHz.^Gf).^(-1/Gf) .* gammainc( Bf * fkHz.^Gf * log(10), 1/Gf, 'upper' ) ) / Gf + ... % version from https://www.wolframalpha.com
    ( 10^(-c) * eps * log(10).^(-1/Gf) * (Bf * eps.^Gf)^(-1/Gf) * gammainc( Bf * eps^Gf * log(10), 1/Gf, 'upper' ) ) / Gf; % with constant set such that nDlf(0)=0 (using eps instead of 0, because we have a 0/0 situation otherwise)
    % somehow, numerically deriving both of the above functions differ from computing 1/dlf by a factor
    ndlf = ndlf / 1.09502198635; % applying empirically-determined correcting factor (by comparison with results obatined with integral.m)
    %     ndlf = +( 10^(-c) * fkHz * expint((Gf - 1)/Gf) .* (Bf * fkHz.^Gf * log(10) ))/Gf; % alternate version from https://www.wolframalpha.com, gives a complex result because Gf-1 is negative
    ndlf(fkHz==0) = 0; % at fkHz = 0 , we get 0/0 = NaN, so setting to 0
    
  otherwise
    error('(dlf) Unknown equation ''%s''\n',equation);
    
end

% % alternatively, numerically integrate the reciprocal of dlf.m (much slower)
% ndlf = nan(size(fkHz));
% for i = 1:length(fkHz)
%   ndlf(i) = integral(@(f)1./dlf(f,equation),0,fkHz(i));
% end
