% 여기서는 SDE를 실행한다.
% 정상적으로 실행되는지 확인한다.
% configuration

nsamps = 10;
num_tvec = 1000;

tvec = linspace(0, 10, num_tvec);
tvecSize = size(tvec, 2);
ivalues = hello_ivalues();
rates = hello_rates();

ratesArray = ones(nsamps, 1)*rates;
% ratesArray = rand(nsamps, size(rates,2));
ivaluesArray = ones(nsamps, 1)*ivalues;

tic
[y, yf, flag] = hello_L(tvec, ivaluesArray, ratesArray);

fprintf('%d sde equations executed in %fsec (%f #/sec)\n', ...
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
