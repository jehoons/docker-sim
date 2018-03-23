% configuration 
nsamps = 1000000;
num_tvec = 50;

tvec = linspace(0, 1, num_tvec);
tvecSize = size(tvec, 2); 
ivalues = g4n_ivalues();
rates = g4n_rates(); 

%ratesArray = ones(nsamps, 1)*rates; 
ratesArray = rand(nsamps, size(rates,2));  
ivaluesArray = ones(nsamps, 1)*ivalues; 

tic
[y, yf, flag] = g4n(tvec, ivaluesArray, ratesArray);

fprintf('%d ode equations executed in %fsec (%f #/sec)\n', ...
    nsamps, toc, nsamps/toc); 

idx = reshape(ones(num_tvec,1) * [1:nsamps], [nsamps*num_tvec,1]);

y_with_idx = [idx y]; 

%for i = 1: nsamps  
%    y_this = y( idx( idx == i ) , :);
%    y_this
%end
