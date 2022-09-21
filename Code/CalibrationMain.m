% Matlab R2022a
% Данный скрипт позволяет открывать снимки, полученные матричными
% спектрометрами, находить спектральные линии и сохранять на диск.
% Эта операция необходима для калибровки матричных спектрометров по длинам
% волн



function Main
close all
global isTestVersion;
%       sel - The amount above surrounding data for a peak to be,
%           identified (default = (max(x0)-min(x0))/4). Larger values mean
%           the algorithm is more selective in finding peaks.
global peakSEL;
%       thresh - A threshold value which peaks must be larger than to be
%           maxima or smaller than to be minima.
global peakTHRESH;
isTestVersion = false; % если false, то загружаем прописанные изображения, без интерфейса открытия
peakSEL = 15;
peakTHRESH = 1;
isNextImage = true;
% цикл по изображениям матриц
while(isNextImage)

    imgStart = loadImg();
    imgWithoutDark = minusDarkChan(imgStart);

    repeatFindingSpectralLine = true;
    spectralLine = [];
    % цикл для поиска линии на одном изображении до тех пор, пока не удовлетворит результат
    while (repeatFindingSpectralLine)
        spectralLine = findSmoothSpectralLine(imgWithoutDark);

        prompt = 'Сохранить спектральную линию? Если да, то введите имя этой линии, если нет - ничего не вводите (Enter):';
        nameLine = input(prompt,"s");
        if(~isempty(nameLine))
            saveLineToProgramDir(spectralLine, nameLine);
        end

        prompt = 'Найти еще одну спектральную линию на изображении? y/n [n]:';
        str = input(prompt,'s');
        if(str == 'y')
            repeatFindingSpectralLine = true;
        else
            repeatFindingSpectralLine = false;
        end
    end
    prompt = 'открыть следующее изображение? y/n [n]:';
    str = input(prompt,'s');
    if(str == 'y')
        isNextImage = true;
    else
        isNextImage = false;
    end
end
disp('Объединение отдельных текстовых калибровочных файлов в один csv-файл. Для этого выделите текстовые калибровочные файлы и нажмите "Открыть"');
saveCalibrationsToOneFile();
disp('Ура, калибровка окончена!');


function smoothDefinedSpectralLine = findSmoothSpectralLine(img)
global peakSEL;
global peakTHRESH;
close all;
image(img);
drawnow;
prompt = 'Применить фильтр Гаусса? Если да, то введите стандартное отклонение для фильтра (начните с единицы), если нет - ничего не вводите (Enter):';
userInput = input(prompt);
if ~isempty(userInput)
    img = imgaussfilt(img,userInput);
end
image(img);
imgOut = img;
prompt = 'Кликните на середину линии поглощения';
disp(prompt);
[approximWaveChan,y,button] = ginputWhite(1);

% centerLinesX = [];
% centerLinesY = [];
% [x,y,button] = ginputWhite(1);
% while (button ~=3)
%     [x,y,button] = ginputWhite(1);
%     hold on;
%     plot (x, y, '+', 'Color', 'cyan');
%     hold off;
%     centerLinesX = [centerLinesX, x];
%     centerLinesY = [centerLinesY, y];
% end
% plot(50,100, 'r+', 'MarkerSize', 30, 'LineWidth', 2);



prompt = 'Кликнете пиксель, ограничивающий область поиска линии поглощения СЛЕВА ';
disp(prompt);
[cordBorderLeft,y,button] = ginputWhite(1);
prompt = 'Кликнете пиксель, ограничивающий область поиска линии поглощения СПРАВА ';
disp(prompt);
[cordBorderRight,y,button] = ginputWhite(1);
redVerticalLine =[]; %= zeros(length(img),2);
red = img(:,:,1);
for i=1:length(img)
    rowSpec = double(red(i, :));
    [peakLoc, peakMag] = peakfinder(rowSpec,peakSEL, peakTHRESH, 1, false, false);
    pair = [];
    delta = 1e99;
    for j  = 1:length(peakLoc)
        peakLocJ = round(peakLoc(j));
        imgOut(i,peakLocJ,1) = 255;
        imgOut(i,peakLocJ,2) = 0;
        imgOut(i,peakLocJ,3) = 0;
        currentDelta = abs(peakLocJ-approximWaveChan);
        if(currentDelta < delta && peakLocJ < cordBorderRight && peakLocJ > cordBorderLeft )
            delta = currentDelta;
            pair = [i peakLocJ];
        end
    end
    redVerticalLine = [redVerticalLine; pair];
end
lineSmooth = smooth( redVerticalLine(:,1), redVerticalLine(:,2), 0.3,'rloess');
pixelsAll = 1:1:length(img);
lineSmoothImgLength = interp1(redVerticalLine(:,1), lineSmooth, pixelsAll, 'spline');
figure;
plot( redVerticalLine(:,1), redVerticalLine(:,2));
hold on;
plot(pixelsAll,lineSmoothImgLength);
for i = 1:length(lineSmoothImgLength)
    if(lineSmoothImgLength(i) == 0)
        lineSmoothImgLength(i) = 1;
    end
    if(lineSmoothImgLength(i) > length(imgOut))
        lineSmoothImgLength(i) = length(imgOut);
    end
    imgOut(i, uint16(lineSmoothImgLength(i)), 1) = 0;
    imgOut(i, uint16(lineSmoothImgLength(i)), 2) = 255;
    imgOut(i, uint16(lineSmoothImgLength(i)), 3) = 0;
end
figure;
image(imgOut);
% это магическое заклинание строит вертикальные полосы. В 2022 матлабе уже
% можно использовать xline
line([cordBorderLeft cordBorderLeft], get(gca, 'ylim'));
line([cordBorderRight cordBorderRight], get(gca, 'ylim'));
smoothDefinedSpectralLine = lineSmoothImgLength;

function  imgLoaded = loadImg()
global isTestVersion;
if(isTestVersion)
    imgLoaded = imread('S:\Users\Anton\Desktop\peak\vss-dk-2021\baumer 0\Hg лампа\0124341818_1\IMG0056.bmp');
    return;
else
    [FileName,PathName,FilterIndex] = uigetfile('*.*');
    s1 = convertCharsToStrings(PathName);
    s2 = convertCharsToStrings(FileName);
    s3 = s1 + s2;
    imgLoaded = imread(convertStringsToChars(s3));
    disp(['Загружено: ' convertStringsToChars(s3) ]);
end


function img = minusDarkChan(imgStart)
global isTestVersion;
if(isTestVersion)
    darkImg = imread('S:\Users\Anton\Desktop\peak\vss-dk-2021\baumer 0\Hg лампа\0124341818_1 темновой\IMG0142.bmp');
    img = imsubtract(imgStart,darkImg);
    return;
else
    prompt = 'Выбрать фотоснимок с темновым сигналом? y/n [n]: ';
    str = input(prompt,'s');
    if isempty(str)
        str = 'n';
    end
    if(str == 'y')
        darkImg = loadImg();
        img = imsubtract(imgStart,darkImg);
    else
        img = imgStart;
        return;
    end
end

function saveLineToProgramDir(spectralLine, name)
folder = 'Lines saved';
if ~exist(folder, 'dir')
    mkdir(folder)
end
nameFile = [folder '\' name '.txt'];
celLine = num2cell(spectralLine,length(spectralLine));
celLine = celLine';
celForSave = [{name}; celLine];
writecell(celForSave,nameFile);
if exist(nameFile,"file")
    disp(['файл сохранен: ' nameFile])
end

