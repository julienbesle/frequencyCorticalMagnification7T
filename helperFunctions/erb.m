
% Human "cochlear" ERB (in kHz) at given frequency f (in kHz)
% after either Glasberg & Moore 1990 or Oxenham & Sheera (2003)

function erb = erb(f,equation)

if ~exist('equation','var') || isempty(equation)
  equation = 'G&M90';
end

switch(equation)
  case 'G&M90'
    A = 0.0247;
    B = 4.37;
    erb = A*(B*f + 1);
    
  case 'O&S03'
    a = 0.27;
    b = 11.1;
    erb = f.^(1-a) / b;
    
  otherwise
    error('(erb) Unknown equation ''%s''\n',equation);
    
end
