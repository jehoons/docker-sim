% configuration
nsamps = 1000;
num_tvec = 20;

tvec = linspace(0, 10, num_tvec);
tvecSize = size(tvec, 2);
ivalues = hello_ivalues();
rates = hello_rates();

%ratesArray = ones(nsamps, 1)*rates;
ratesArray = rand(nsamps, size(rates,2));
ivaluesArray = ones(nsamps, 1)*ivalues;

tic
[y, yf, flag] = hello(tvec, ivaluesArray, ratesArray);

fprintf('%d ode equations executed in %fsec (%f #/sec)\n', ...
    nsamps, toc, nsamps/toc);

idx = reshape(ones(num_tvec,1) * [1:nsamps], [nsamps*num_tvec,1]);

y_with_idx = [idx y];

figure()

for i = 1: nsamps
    y_this = y( idx == i, :);
    plot(tvec, y_this, 'color', rand(1,3)); hold on
end

hold off

print('-dpng','-r300','output.png')
