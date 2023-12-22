% Matlab R2022a
% Данный скрипт позволяет открывать снимки, полученные матричными
% спектрометрами, находить спектральные линии и сохранять на диск.
% Эта операция необходима для калибровки матричных спектрометров по длинам
% волн

function Main
% close all
global isTestVersion;
isTestVersion = false; % если true, то загружаем прописанные изображения, без интерфейса открытия
%       sel - The amount above surrounding data for a peak to be,
%           identified (default = (max(x0)-min(x0))/4). Larger values mean
%           the algorithm is more selective in finding peaks.
%       thresh - A threshold value which peaks must be larger than to be
%           maxima or smaller than to be minima.
%       isSmoothPeaks - If true quadratic interpolation will be performed
%           around each extrema to estimate the magnitude and the
%           position of the peak in terms of fractional indicies

peakSEL = 0.02;
peakTHRESH = 0.02;
isSmoothPeaks = false; %true может быть полезным при зашкале линии, когда образуется плато с зашкальными значениями. В остальных случаях не рекомендую
isNextImage = true; % true - будет предложено выбрать следующее изображение матрицы
isMultiImageComposite = false; % false - оперируем только с одним изображением. True - загружаем серию снимков на разных экспозициях и складываем из них одну матрицу
prompt = 'использовать набор одинаковых изображений с разными экспозициями? y/n [n]:';
str = input(prompt,'s');
if(str == 'y')
    isMultiImageComposite = true;
else
    isMultiImageComposite = false;
end

% цикл по изображениям матриц
while(isNextImage)

    if(isMultiImageComposite)
        % создаем double композит изображений
        doubleImg = loadImagesAsComposite();
        small = doubleImg(400:700,:,1);
        img = doubleImg;
    else
        imgStart = loadImg();
        smallOne = imgStart(400:700,:,1);
        img = minusDarkChan(imgStart);
        img = double(img);
    end

    
    %тут делаем функцию построчного сглаживания изображения при помощи
    %сплайнов, получаем сглаженное изображение (один его канал) и передаем его в функцию findSmoothSpectralLine
    prompt = 'Введите коэффициент аппроксимации сплайна. (B0: 1e-3, B1: 2e-2, B2: 5e-4): ';
    koefVal = input(prompt);
    JOIN_ROWS_NUM = 5;
    if(~isempty(koefVal))
         splineMatrix = fitMatrixLinesWithSpline(img(:,:,1), koefVal, JOIN_ROWS_NUM);
    else
        splineMatrix = fitMatrixLinesWithSpline(img(:,:,1), 1e-3, JOIN_ROWS_NUM);
        disp('Использован параметр по умолчанию 1е-3 для сплайнов');
    end
    repeatFindingSpectralLine = true;
    spectralLine = [];
    % цикл для поиска линии на одном изображении до тех пор, пока не удовлетворит результат
    while (repeatFindingSpectralLine)
       %[spectralLine spectralLineByValue imageFigHandler] = findSmoothSpectralLine(splineMatrix, peakSEL, peakTHRESH, isSmoothPeaks);
       [spectralLine, spectralLineByValue, spectralLineByValueSpline, imageFigHandler]...
           = findSmoothSpectralLine(img(:,:,1), peakSEL, peakTHRESH, isSmoothPeaks, splineMatrix);

        prompt = 'Сохранить спектральную линию? Если да, то введите имя этой линии, если нет - ничего не вводите (Enter):';
        nameLine = input(prompt,"s");
        if(~isempty(nameLine))
            prompt = 'Сохранить красную(1), зеленую(2) или черную(3) линии (разные алгоритма поиска)? Введите № цвета линии: ';
            str = input(prompt,"s");
            if(str == '1')
                disp('сохраняем красную линию');
                saveLineToProgramDir(spectralLine, nameLine);
            elseif(str == '2')
                disp('сохраняем зеленую линию');
                saveLineToProgramDir(spectralLineByValue, nameLine);
            elseif(str == '3')
                disp('сохраняем черную линию');
                saveLineToProgramDir(spectralLineByValueSpline, nameLine);
            else
                disp('Сохранение отменено');
            end
            saveImageToProgramDir(imageFigHandler,nameLine);
        else
            disp('матлаб тупит с вводом.');
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


function [smoothDefinedSpectralLine, smoothDefinedSpectralLineByValue, smoothDefinedSpectralLineByValueSpline, imageFigHandler]...
    = findSmoothSpectralLine(matrix, peakSEL, peakTHRESH,isSmoothPeaks, splineMatrix)

%нормализуем от 0 до 1
minMat = min(matrix(:));
maxMat = max(matrix(:));
normM = (matrix - minMat)./(maxMat - minMat);

imagesc(normM);
drawnow;
prompt = 'Применить фильтр Гаусса? Если да, то введите стандартное отклонение для фильтра (начните с единицы), если нет - ничего не вводите (Enter):';
userInput = input(prompt);
if ~isempty(userInput)
    normM = imgaussfilt(normM,userInput);
end
imagesc(normM);

% изображение, на котором будем рисовать найденные линии
map = colormap("parula");
minv = min(normM(:));
maxv = max(normM(:));
ncol = size(map,1);
s = round(1+(ncol-1)*(normM-minv)/(maxv-minv));
imgOut = ind2rgb(s,map);

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
if(cordBorderRight < cordBorderLeft)
    [cordBorderRight  cordBorderLeft] = deal(cordBorderLeft, cordBorderRight);
end
correctPeaks =[]; 
correctPeaksByValue =[];
correctPeaksByValueSpline = [];
for i=1:size(normM,1)
    rowSpec = double(normM(i, :));
    %                     ПОИСК БЛИЖАЙШИХ К ОПОРНЫМ ТОЧКАХ ПИКОВ
    [peakLoc, peakMag] = peakfinder(rowSpec,peakSEL, peakTHRESH, 1, false, isSmoothPeaks);
    
    peakX = findCorrectPeak(peakLoc, i, centerLinesX, centerLinesY, cordBorderLeft, cordBorderRight); 
    %отрисовка только корректных пиков на изображении
    imgOut(i, round(peakX), 1) = 255;
    imgOut(i, round(peakX), 2) = 255;
    imgOut(i, round(peakX), 3) = 255;
    pair = [];
    if(~isempty(peakX))
        pair = [i, peakX];
        correctPeaks = [correctPeaks; pair];
    end

    %                     ПОИСК ПИКОВ ПО МАКСИМАЛЬНОМУ ЗНАЧЕНИЮ
    peakXbyValue = findCorrectPeakByValue(rowSpec,peakLoc, cordBorderLeft, cordBorderRight);
    if(~isempty(peakXbyValue))
        if(imgOut(i, round(peakXbyValue), 1) == 255) %те пиксели, что найдены обоими методами красим зеленым
            imgOut(i, round(peakXbyValue), 1) = 0;
            imgOut(i, round(peakXbyValue), 2) = 160;
            imgOut(i, round(peakXbyValue), 3) = 0;
        else
            imgOut(i, round(peakXbyValue), 1) = 160; % остальные желтым
            imgOut(i, round(peakXbyValue), 2) = 160;
            imgOut(i, round(peakXbyValue), 3) = 0;
        end
    end
    pairByValue = [];
    if(~isempty(peakXbyValue))
        pairByValue = [i, peakXbyValue];
        correctPeaksByValue = [correctPeaksByValue; pairByValue];
    end

    %                    ПОИСК ПИКОВ ПРИ ПОМОЩИ ПРЕДВАРИТЕЛЬНОГО
    %                    СГЛАЖИВАНИЯ СПЛАЙНОМ СПЕКТРА (А ПОТОМ ПО ЗНАЧЕНИЮ)
    rowSpecSpline = double(splineMatrix(i, :));
    [peakLocSpline, peakMagS] = peakfinder(rowSpecSpline,peakSEL, peakTHRESH, 1, false, isSmoothPeaks);
    peakXbyValueSpline = findCorrectPeakByValue(rowSpecSpline,peakLoc, cordBorderLeft, cordBorderRight);
    % красный цвет для найденных пикселей
    if(~isempty(peakXbyValueSpline))
            imgOut(i, round(peakXbyValueSpline), 1) = 255;
            imgOut(i, round(peakXbyValueSpline), 2) = 0;
            imgOut(i, round(peakXbyValueSpline), 3) = 0;
    end
    pairByValueSpline = [];
    if(~isempty(peakXbyValueSpline))
        pairByValueSpline = [i, peakXbyValueSpline];
        correctPeaksByValueSpline = [correctPeaksByValueSpline; pairByValueSpline];
    end
end
lineSmooth = smooth( correctPeaks(:,1), correctPeaks(:,2), 0.3,'rloess');
lineSmoothByValue = smooth( correctPeaksByValue(:,1), correctPeaksByValue(:,2), 0.3,'rloess');
lineSmoothByValueSpline = smooth( correctPeaksByValueSpline(:,1), correctPeaksByValueSpline(:,2), 0.3,'rloess');
pixelsAll = 1:1:length(normM);
lineSmoothImgLength = interp1(correctPeaks(:,1), lineSmooth, pixelsAll, 'spline');
lineSmoothImgLengthByValue = interp1(correctPeaksByValue(:,1), lineSmoothByValue, pixelsAll, 'spline');
lineSmoothImgLengthByValueSpline = interp1(correctPeaksByValueSpline(:,1), lineSmoothByValueSpline, pixelsAll, 'spline');


figure;
hold on;
plot( correctPeaks(:,1), correctPeaks(:,2), 'magenta');
plot( correctPeaksByValue(:,1), correctPeaksByValue(:,2),'yellow');
plot(pixelsAll,lineSmoothImgLength, 'red');
plot(pixelsAll,lineSmoothImgLengthByValue, 'green');
plot(pixelsAll,lineSmoothImgLengthByValueSpline, 'black');
for z = 1:length(lineSmoothImgLength)
    if(lineSmoothImgLength(z) == 0)
        lineSmoothImgLength(z) = 1;
    end
    if(lineSmoothImgLength(z) > length(imgOut))
        lineSmoothImgLength(z) = length(imgOut);
    end
end
for z = 1:length(lineSmoothImgLengthByValue)
    if(lineSmoothImgLengthByValue(z) == 0)
        lineSmoothImgLengthByValue(z) = 1;
    end
    if(lineSmoothImgLengthByValue(z) > length(imgOut))
        lineSmoothImgLengthByValue(z) = length(imgOut);
    end
end
for z = 1:length(lineSmoothImgLengthByValueSpline)
    if(lineSmoothImgLengthByValueSpline(z) == 0)
        lineSmoothImgLengthByValueSpline(z) = 1;
    end
    if(lineSmoothImgLengthByValueSpline(z) > length(imgOut))
        lineSmoothImgLengthByValueSpline(z) = length(imgOut);
    end
end
imageFigHandler = figure;
imagesc(imgOut);
xTemp = 1:1:length(lineSmoothImgLength);
xTempByValue = 1:1:length(lineSmoothImgLengthByValue);
xTempByValueSpline = 1:1:length(lineSmoothImgLengthByValue);
hold on;
plot(lineSmoothImgLength, xTemp, 'Color','red','LineWidth',0.2);
plot(lineSmoothImgLengthByValue, xTempByValue, 'Color','green','LineWidth',0.2);
plot(lineSmoothImgLengthByValueSpline, xTempByValueSpline, 'Color','black','LineWidth',0.2);
hold off;
% это магическое заклинание строит вертикальные полосы. В 2022 матлабе уже
% можно использовать xline
line([cordBorderLeft cordBorderLeft], get(gca, 'ylim'));
line([cordBorderRight cordBorderRight], get(gca, 'ylim'));
hold on;
plot(centerLinesX, centerLinesY, '+', 'Color', 'cyan');
hold off;
smoothDefinedSpectralLine = lineSmoothImgLength;
smoothDefinedSpectralLineByValue = lineSmoothImgLengthByValue;
smoothDefinedSpectralLineByValueSpline = lineSmoothImgLengthByValueSpline;

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

function doubleCompositeImg = loadImagesAsComposite()
[FileName,PathName,FilterIndex] = uigetfile('*.*','MultiSelect','on');
s1 = convertCharsToStrings(PathName);
s2 = convertCharsToStrings(FileName);
nFiles = length(s2);
for i=1:nFiles
    s3 = s1 + s2(i);
    imgLoaded = imread(convertStringsToChars(s3));
    if(i==1)
        doubleCompositeImg = double(imgLoaded);
    end
    disp(['Загружено: ' convertStringsToChars(s3) ]);

    doubleCompositeImg = doubleCompositeImg + double(imgLoaded);
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

function bestPeak = findCorrectPeakByValue(matrixLine, peaksVector, cordBorderLeft, cordBorderRight)
bestPeak = [];
if(isempty(peaksVector) || isempty(matrixLine) )
    disp('пустые данные на входе findCorrectPeakByValue')
    return;
end

% выбор максимального пика внутри области
peaksLocationsInsideBrdrs = [];
for j=1:length(peaksVector)
    if(peaksVector(j) > cordBorderLeft && peaksVector(j) < cordBorderRight)
        peaksLocationsInsideBrdrs = [peaksLocationsInsideBrdrs peaksVector(j)];
    end
end
if(~isempty(peaksLocationsInsideBrdrs))
    peakValsInsideBrdrs = zeros(length(peaksLocationsInsideBrdrs), 1);
    for j=1:length(peakValsInsideBrdrs)
        peakValsInsideBrdrs(j) = matrixLine(peaksLocationsInsideBrdrs(j));
    end
    [maxPeakVal, maxPeakInd] = max(peakValsInsideBrdrs); 
    bestPeak = peaksLocationsInsideBrdrs(maxPeakInd);
end

% fittedMatrix - матрица со сглаженными строками спайном с параметром filtParam
% для ускорения быстродействия рассчитываем сплайн не для каждой строки, а
% для числа строк joinRowsNum. Эти строки усредняются и для них
% расчитывается сплайн.
function fittedMatrix = fitMatrixLinesWithSpline(matrix, filtParam, joinRowsNum)
hw = waitbar(0,'Smooth','Name','Filtering...',...
    'CreateCancelBtn','setappdata(gcbf,''canceling'',1)');
setappdata(hw,'canceling',0);

ft = fittype( 'smoothingspline' );
opts = fitoptions( 'Method', 'SmoothingSpline' );
opts.SmoothingParam = filtParam;

compressedMatrix = blockproc(matrix, [joinRowsNum 1], @(x) mean(x.data, 'all'));
fitobjectsForRows = cell(1, size(compressedMatrix,1));
for i = 1:size(compressedMatrix,1)
    if getappdata(hw,'canceling')
        break;
    end
    waitbar(i/size(compressedMatrix,1));
    [xData, yData] = prepareCurveData( [], compressedMatrix(i,:) );
    fitobjectsForRows{i} = fit(xData, yData, ft, opts);
end
close(hw);
delete(hw);
x = 1:size(matrix,2);
fittedMatrix = zeros(size(matrix,1),size(matrix,2));
for i = 1:size(matrix,1)
    fittedMatrix(i,:) = feval(fitobjectsForRows{ceil(i / joinRowsNum)}, x)';
end
disp('сглаживание сплайном завершено');

    

