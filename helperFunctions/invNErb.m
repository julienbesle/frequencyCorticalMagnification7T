
% returns frequency (in kHz) corresponding to a number of cochlear ERBs above 0 kHz
% either after Glasberg & Moore (1990) or Oxenham & Sheera (2003) (see nErb.m for explanations)

function f = invNErb(nerb,equation)

if ~exist('equation','var') || isempty(equation)
  equation = 'G&M90';
end


switch(equation)
  case 'G&M90'
    f = 1/4.37*(10.^(nerb/21.4)-1);
    
  case 'O&S03'
    a = 0.27;
    b = 11.1;
    f = (a/b*nerb).^(1/a);
    
  otherwise
    error('(invNErb) Unknown equation ''%s''\n',equation);
end
