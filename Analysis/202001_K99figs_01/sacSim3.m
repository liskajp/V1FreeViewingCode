
Im = imread('office_1.jpg');
Im = mean(Im,3); % grayscale
Im = imresize(Im, 2);
figure(1); clf
imagesc(Im)

%%
seed = 240; %randi(1e3)
rng(seed)

k = 50;
v1Kernel = [0 diff(normpdf(linspace(-5, 7, k)))];

v1Kernel = v1Kernel ./ norm(v1Kernel);

figure(2); clf
plot(v1Kernel); hold on

ori = 45;
sfs = [2 4 8 16];
win = 50*[1 1];
[xx, yy] = meshgrid(linspace(-2, 2, win(1)));

xg = cosd(ori)*xx + sind(ori)*yy;
mag = hanning(win(1))*hanning(win(1))';
nSfs = numel(sfs);

wts = zeros(prod(win), nSfs);
wts2 = zeros(prod(win), nSfs);
figure(1); clf
for iSf = 1:nSfs
    
    tmp = reshape(cos(sfs(iSf)*xg).*mag, [], 1);
    wts(:,iSf) = tmp/norm(tmp);
    
    tmp = reshape(sin(sfs(iSf)*xg).*mag, [], 1);
    wts2(:,iSf) = tmp/norm(tmp);
    
    subplot(2,nSfs,iSf)
    imagesc(reshape(wts(:,iSf), win))
    
    subplot(2,nSfs,nSfs+iSf)
    imagesc(reshape(wts2(:,iSf), win))
end

%% build eye traces
clf

nFix = 400;
maxFixDur = 700;
nFrames = 300*maxFixDur;

ctr = fliplr(dim/2); % start in the center of the screen

ppd = 20;
sacrange = linspace(0, 10*ppd, 100);
pdfSac = normpdf(sacrange, 4*ppd, 3*ppd);
pdfSac = pdfSac / sum(pdfSac);
cdfSac = cumsum(pdfSac);
pdfFix = normpdf(1:maxFixDur, 300, 70).*(1-exp((1:maxFixDur)/-400));

pdfFix = pdfFix./sum(pdfFix);
cdfFix = cumsum(pdfFix);
figure(1); clf
plot(pdfFix)
%%
% plot(sacrange, pdfSac)

eyepos = ones(nFrames, 2).*ctr;
iFrame = 1;

nextSaccade = ceil(interp1(cdfFix, 1:maxFixDur, rand())) + iFrame;
sacTimes = nextSaccade;
sacSizes = [];
for iFix = 1:nFix
%     
    % drift
    while iFrame < nextSaccade
        iFrame = iFrame + 1;
        eyepos(iFrame,:) = eyepos(iFrame-1,:) + 0*randn(1,2); % brownian motion
    end
    
    % saccade
%     sacSize = -sign(eyepos(iFrame,:)-ctr)*40;
    sacSize = interp1(cdfSac, sacrange, rand(1,2));
    if rand < .5
        sacSize = 10.*sign(randn(1,2));
    else
        sacSize = 50.*-sign(eyepos(iFrame,:)-ctr);
    end
    
    while any(isnan(sacSize))
        sacSize = interp1(cdfSac, sacrange, rand(1,2)).*-sign(eyepos(iFrame,:)-ctr);
    end
    eyepos(iFrame,:) = eyepos(iFrame,:) + sacSize;
    nextSaccade = ceil(interp1(cdfFix, 1:maxFixDur, rand())) + iFrame;
    sacTimes = [sacTimes nextSaccade];
    sacSizes = [sacSizes hypot(sacSize(1), sacSize(2))];
end

nFrames = iFrame;
eyepos = eyepos(1:iFrame,:);
eyepos(:,1) = imgaussfilt(eyepos(:,1), 3);
eyepos(:,2) = imgaussfilt(eyepos(:,2), 3);

figure(1); clf
plot(eyepos(:,1), eyepos(:,2), 'k')
xlim([0 dim(2)])
ylim([0 dim(1)])

figure(2); clf
plot(eyepos(:,1))
    


%% process image with V1 RFs of different sf tuning

% clip out eye position
M = zeros(nFrames, prod(win));
for i = 1:nFrames
    rect = [eyepos(i,:) win-1];
    try
        tmp = imcrop(im, rect);
        M(i,:) = tmp(:);
    end
end
   
% spatial filter
Ms = M*wts;
Ms2 = M*wts2;


%% temporal filter
k = 50;
xax = linspace(0, 10, k);
x = normpdf(xax, 5, .51);

v1Kernel = [0 diff(x)];
v1Kernel = v1Kernel ./ norm(v1Kernel);

figure(2); clf
plot(v1Kernel); hold on

% x = max(Ms,0);
x = Ms;
x = x./std(x);
Mst = filter(v1Kernel, 1, x);

Mst2 = filter(v1Kernel, 1, Ms2./std(Ms2));

%%
figure(2); clf
plot(Mst)

%%

figure(1); clf
levels = quantile(sacSizes, [0 .1 .9 1]);
ss = unique(sacSizes);
ss = ss([2 4]);
cmap = lines;

for i = 1:nSfs
    subplot(1,nSfs,i)
    for j = 1:numel(ss)
%         ix = sacSizes > levels(j) & sacSizes < levels(j+1);
        ix = sacSizes == ss(j);
%       
        x = Mst(:,i);
%         x = max(Mst(:,i),0);
        m = eventTriggeredAverage(x, sacTimes(ix)', 50*[-1 1]);
        plot(m, '-', 'Color', cmap(j,:)); hold on
        
        x = Mst2(:,i);
%         x = max(Mst(:,i),0);
        m = eventTriggeredAverage(x, sacTimes(ix)', 50*[-1 1]);
        plot(m, '--', 'Color', cmap(j,:)); hold on
    end
%     ylim([-50 50])
end

%%
