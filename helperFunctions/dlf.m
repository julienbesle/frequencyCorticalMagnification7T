
% Human frequency discrimination thresholds at given frequency f (in kHz)
% after either Nelson et al. (1983) or Micheyl et al. (2012)

function dlf = dlf(fkHz,equation,level,duration)

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
    a = 0.0214;
    m = 5.056;
    k = -0.15;
    fHz = 1000*fkHz; %convert from kHz to Hz
%     dlf = 10.^(a * sqrt(fHz) + m * (1/level) + k) / 1000; % we divide by 1000 because we want the result in kHz
%     dlf = 10.^(a * sqrt(fHz) + m/level + k - 3);
    c = m/level + k - 3;  % put everything that does not depend on f in a constant
    dlf = 10.^(a * sqrt(fHz) + c);
    
%     % note that this equation is a special case of Micheyl et al's (2012) equation
%     % without the duration term and with the following constants:
%     Bf = a*10*sqrt(10);
%     Gf = 0.5; % i.e. sqrt
%     Bs = m/10;
%     Gs = -1; % i.e. 1/x
%     A = k;
% %     dlf = 10.^(Bf * fkHz.^Gf + Bs * (level/10).^Gs + A) / 1000;
% %     dlf = 10.^(Bf * fkHz.^Gf + Bs * (level/10).^Gs + A - 3);
%     c = Bs * (level/10).^Gs + A - 3; % put everything that does not depend on f in a constant
%     dlf = 10.^(Bf * fkHz.^Gf + c);
    
  case 'M12'
    Bf = 0.38;
    Gf = 0.82;  % exponent for frequency
    Bs = 0.37;
    Gs = -1.09; % exponent for stimulus level
    Bd = 0.42;
    Gd = -0.42; % exponent for stimulus duration
    A = -0.38;
%     dlf = 10.^(Bf * fkHz.^Gf + Bs * (level/10).^Gs + Bd * (duration/100).^Gd + A) / 1000;
%     dlf = 10.^(Bf * fkHz.^Gf + Bs * (level/10).^Gs + Bd * (duration/100).^Gd + A - 3);
    c = Bs * (level/10).^Gs + Bd * (duration/100).^Gd + A - 3; % put everything that does not depend on f in a constant
    dlf = 10.^(Bf * fkHz.^Gf + c);
    
  otherwise
    error('(dlf) Unknown equation ''%s''\n',equation);
    
end
