% Matlab R2022a
% Данный скрипт позволяет открывать снимки, полученные матричными
% спектрометрами, находить спектральные линии и сохранять на диск.
% Эта операция необходима для калибровки матричных спектрометров по длинам
% волн

function Main
% close all
global isTestVersion;
isTestVersion = false; % если false, то загружаем прописанные изображения, без интерфейса открытия
%       sel - The amount above surrounding data for a peak to be,
%           identified (default = (max(x0)-min(x0))/4). Larger values mean
%           the algorithm is more selective in finding peaks.
%       thresh - A threshold value which peaks must be larger than to be
%           maxima or smaller than to be minima.
%       isSmoothPeaks - If true quadratic interpolation will be performed
%           around each extrema to estimate the magnitude and the
%           position of the peak in terms of fractional indicies
peakSEL = 15;
peakTHRESH = 1;
isSmoothPeaks = false; %true может быть полезным при зашкале линии, когда образуется плато с зашкальными значениями. В остальных случаях не рекомендую 
isNextImage = true;
% цикл по изображениям матриц
while(isNextImage)

    imgStart = loadImg();
    img = minusDarkChan(imgStart);
    repeatFindingSpectralLine = true;
    spectralLine = [];
    % цикл для поиска линии на одном изображении до тех пор, пока не удовлетворит результат
    while (repeatFindingSpectralLine)
        [spectralLine imageFigHandler] = findSmoothSpectralLine(img, peakSEL, peakTHRESH, isSmoothPeaks);

        prompt = 'Сохранить спектральную линию? Если да, то введите имя этой линии, если нет - ничего не вводите (Enter):';
        nameLine = input(prompt,"s");
        if(~isempty(nameLine))
            saveLineToProgramDir(spectralLine, nameLine);
            saveImageToProgramDir(imageFigHandler,nameLine);
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


function [smoothDefinedSpectralLine imageFigHandler] = findSmoothSpectralLine(img, peakSEL, peakTHRESH,isSmoothPeaks)
% close all;
image(img);
drawnow;
prompt = 'Применить фильтр Гаусса? Если да, то введите стандартное отклонение для фильтра (начните с единицы), если нет - ничего не вводите (Enter):';
userInput = input(prompt);
if ~isempty(userInput)
    img = imgaussfilt(img,userInput);
end
image(img);
imgOut = img;
prompt = 'Кликните на середину линии поглощения в ключевых точках (Если линия изогнутая, то вверху, всередине и внизу). В конце нажмите правую клавишу мыши.';
disp(prompt);
centerLinesX = [];
centerLinesY = [];
isRightclicked = false;
while (~isRightclicked)
    [x,y,button] = ginputColor(1, 'cyan');
    if(button == 3)
        isRightclicked = true;
    else
        hold on;
        plot (x, y, '+', 'Color', 'cyan');
        hold off;
        centerLinesX = [centerLinesX, x];
        centerLinesY = [centerLinesY, y];
    end
end

prompt = 'Кликнете пиксель, ограничивающий область поиска линии поглощения СЛЕВА ';
disp(prompt);
[cordBorderLeft,y,button] = ginputColor(1, 'cyan');
prompt = 'Кликнете пиксель, ограничивающий область поиска линии поглощения СПРАВА ';
disp(prompt);
[cordBorderRight,y,button] = ginputColor(1, 'cyan');
correctPeaks =[]; %= zeros(length(img),2);
red = img(:,:,1);
for i=1:length(img)
    rowSpec = double(red(i, :));
    [peakLoc, peakMag] = peakfinder(rowSpec,peakSEL, peakTHRESH, 1, false, isSmoothPeaks);

    %отрисовка всех найденных пиков на изображении
    for j=1:length(peakLoc)
        imgOut(i, round(peakLoc(j)), 1) = 255;
        imgOut(i, round(peakLoc(j)), 2) = 0;
        imgOut(i, round(peakLoc(j)), 3) = 0;
    end

    peakX = findCorrectPeak(peakLoc, i, centerLinesX, centerLinesY, cordBorderLeft, cordBorderRight);
    %отрисовка только корректных пиков на изображении
    imgOut(i, round(peakX), 1) = 0;
    imgOut(i, round(peakX), 2) = 180;
    imgOut(i, round(peakX), 3) = 0;
    pair = [];
    if(~isempty(peakX))
        pair = [i, peakX];
        correctPeaks = [correctPeaks; pair];
    end
end    
lineSmooth = smooth( correctPeaks(:,1), correctPeaks(:,2), 0.3,'rloess');
pixelsAll = 1:1:length(img);
lineSmoothImgLength = interp1(correctPeaks(:,1), lineSmooth, pixelsAll, 'spline');
figure;
plot( correctPeaks(:,1), correctPeaks(:,2));
hold on;
plot(pixelsAll,lineSmoothImgLength);
for i = 1:length(lineSmoothImgLength)
    if(lineSmoothImgLength(i) == 0)
        lineSmoothImgLength(i) = 1;
    end
    if(lineSmoothImgLength(i) > length(imgOut))
        lineSmoothImgLength(i) = length(imgOut);
    end
%     imgOut(i, uint16(lineSmoothImgLength(i)), 1) = 0;
%     imgOut(i, uint16(lineSmoothImgLength(i)), 2) = 255;
%     imgOut(i, uint16(lineSmoothImgLength(i)), 3) = 0;
end
imageFigHandler = figure;
image(imgOut);
xTemp = 1:1:length(lineSmoothImgLength);
hold on;
plot(lineSmoothImgLength, xTemp, 'Color','cyan','LineWidth',0.2);
hold off;
% это магическое заклинание строит вертикальные полосы. В 2022 матлабе уже
% можно использовать xline
line([cordBorderLeft cordBorderLeft], get(gca, 'ylim'));
line([cordBorderRight cordBorderRight], get(gca, 'ylim'));
hold on;
plot(centerLinesX, centerLinesY, '+', 'Color', 'cyan');
hold off;
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

function saveImageToProgramDir(imageFigHandler, name)
folder = 'Lines saved';
if ~exist(folder, 'dir')
    mkdir(folder)
end
nameFile = [folder '\' name '.png'];
position = get(imageFigHandler,'Position'); % эти операции для того, чтобы сохранить всю картинку независимо от того, насколько ее зумили и трансформировали
zoom(1e-99);
set(imageFigHandler,'Position',[100 100 500 500]);
exportgraphics(imageFigHandler,nameFile,'Resolution',600 );
set(imageFigHandler,'Position',position);
drawnow();
if exist(nameFile,"file")
    disp(['файл сохранен: ' nameFile])
end


% функция findCorrectPeak принимает список найденных пиков для одной строки и по
% дополнительным параметрам выбирает наиболее подходящий из них
%   peaksVector - массив с координатами (номер их колонки в изображении) пиков
%   currentRowIndex - номер строки, в которой происходит анализ пиков
%   anchorPointsX - координаты X выбранных пользователем центров линий
%   anchorPointsY - координаты Y выбранных пользователем центров линий
%   cordBorderLeft и cordBorderRight - левая и правая граница по оси X на
%   изображении внутри которой выбираются пики
%   return bestPeak - координата (номер столбца изображения) найденного лучшего пика из списка пиков
function bestPeak = findCorrectPeak(peaksVector, currentRowIndex, anchorPointsX, anchorPointsY, cordBorderLeft, cordBorderRight)
bestPeak = [];
if(isempty(peaksVector) || isempty(anchorPointsX) || isempty(anchorPointsY))
    return;
end
targetSpectralLineX = -1; 
deltaCurrentYAndUserY = 1e999;

for i = 1:length(anchorPointsY)
    tempDelta = abs(anchorPointsY(i) - currentRowIndex);
    if(tempDelta < deltaCurrentYAndUserY)
        deltaCurrentYAndUserY = tempDelta;
        targetSpectralLineX = anchorPointsX(i);
    end
end
delta = 1e999;
for i  = 1:length(peaksVector)
    tempDelta = abs(peaksVector(i) - targetSpectralLineX);
    if(tempDelta < delta && peaksVector(i) < cordBorderRight && peaksVector(i) > cordBorderLeft)
        delta = tempDelta;
        bestPeak = peaksVector(i);
    end
end
