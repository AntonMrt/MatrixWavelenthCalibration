% Matlab R2022a
% Данный скрипт позволяет открывать снимки, полученные матричными
% спектрометрами, находить спектральные линии и сохранять на диск.
% Эта операция необходима для калибровки матричных спектрометров по длинам
% волн

function CalibrationMain

%%  -- ПЕРЕМЕННЫЕ КАПСОМ ЗАДАЕТ ПОЛЬЗОВАТЕЛЬ СКРИПТА --

%       sel - The amount above surrounding data for a peak to be,
%           identified (default = (max(x0)-min(x0))/4). Larger values mean
%           the algorithm is more selective in finding peaks.
PEAK_SEL = 0.02;

%       thresh - A threshold value which peaks must be larger than to be
%           maxima or smaller than to be minima.
PEAK_THRESH = 0.02;

%       IS_SMOOTH_PEAKS - If true quadratic interpolation will be performed
%           around each extrema to estimate the magnitude and the
%           position of the peak in terms of fractional indicies
IS_SMOOTH_PEAKS = false; %true может быть полезным при зашкале линии, когда образуется плато с зашкальными значениями. В остальных случаях не рекомендую

IS_NEED_TRANSPOSE = false; % ставим false, если по оси X длины волн, true - когда пространственная координата
%%
fprintf(['Здравствуй, друг! Твои настройки: \n' ...
    'PEAK_SEL: %d \n' ...
    'PEAK_THRESH: %d \n' ...
    'IS_SMOOTH_PEAKS: %s \n' ...
    'IS_NEED_TRANSPOSE: %s \n'], PEAK_SEL, PEAK_THRESH, string(IS_SMOOTH_PEAKS), string(IS_NEED_TRANSPOSE));



isNextImage = true; % true - будет предложено выбрать следующее изображение матрицы
prompt = 'использовать набор одинаковых изображений с разными экспозициями? y/n [n]:';
str = input(prompt,'s');
if(str == 'y') % false - оперируем только с одним изображением. True - загружаем серию снимков на разных экспозициях и складываем из них одну матрицу
    isMultiImageComposite = true;
else
    isMultiImageComposite = false;
end

% цикл по изображениям матриц
while(isNextImage)

    if(isMultiImageComposite)
        % создаем double композит изображений
        [doubleImg, ~, ~] = loadImagesAsComposite();
        img = doubleImg;
    else
        imgStart = loadImg();
        img = minusDarkChan(imgStart);
        img = double(img);
    end
    if size(img, 3) == 3 % иногда может загриться в моно, иногда в rgb
        img = img(:,:,1);
    end
    if(IS_NEED_TRANSPOSE)
        img = img';
    end

    repeatFindingSpectralLine = true;
    % цикл для поиска линии на одном изображении до тех пор, пока не удовлетворит результат
    while (repeatFindingSpectralLine)
        [spectralLine, spectralLineByValue, imageFigHandler] = findSmoothSpectralLine(img, PEAK_SEL, PEAK_THRESH, IS_SMOOTH_PEAKS);
        prompt = 'Сохранить спектральную линию? Если да, то введите имя этой линии, если нет - ничего не вводите (Enter):';
        nameLine = input(prompt,"s");
        if(~isempty(nameLine))
            prompt = 'Сохранить красную(1) или зеленую(2) линии (разные алгоритма поиска)? Введите № цвета линии: ';
            str = input(prompt,"s");
            if(str == '1')
                disp('сохраняем красную линию');
                saveLineToProgramDir(spectralLine, nameLine);
            elseif(str == '2')
                disp('сохраняем зеленую линию');
                saveLineToProgramDir(spectralLineByValue, nameLine);
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


function [smoothDefinedSpectralLine, smoothDefinedSpectralLineByValue, imageFigHandler] = findSmoothSpectralLine(matrix, PEAL_SEL, PEAK_THRESH,IS_SMOOTH_PEAKS)
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
ncolols = size(map,1);
s = round(1+(ncolols-1)*(normM-minv)/(maxv-minv));
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
[cordBorderLeft,~,~] = ginputColor(1, 'cyan');
prompt = 'Кликнете пиксель, ограничивающий область поиска линии поглощения СПРАВА ';
disp(prompt);
[cordBorderRight,~,~] = ginputColor(1, 'cyan');
if(cordBorderRight < cordBorderLeft)
    [cordBorderRight,  cordBorderLeft] = deal(cordBorderLeft, cordBorderRight);
end
correctPeaks =[];
correctPeaksByValue =[];
colorLightRed = [255, 150, 150]/255;
colorLightGreen = [180, 255, 180]/255;
for i=1:size(normM,1)
    rowSpec = double(normM(i, :));
    %                     ПОИСК БЛИЖАЙШИХ К ОПОРНЫМ ТОЧКАХ ПИКОВ
    [peakLoc, ~] = peakfinder(rowSpec,PEAL_SEL, PEAK_THRESH, 1, false, IS_SMOOTH_PEAKS);
    peakX = findCorrectPeak(peakLoc, i, centerLinesX, centerLinesY, cordBorderLeft, cordBorderRight);
    %отрисовка только корректных пиков на изображении

    imgOut(i, round(peakX), 1) = colorLightRed(1);
    imgOut(i, round(peakX), 2) = colorLightRed(2);
    imgOut(i, round(peakX), 3) = colorLightRed(3);
    if(~isempty(peakX))
        pair = [i, peakX];
        correctPeaks = [correctPeaks; pair];
    end

    %                     ПОИСК ПИКОВ ПО МАКСИМАЛЬНОМУ ЗНАЧЕНИЮ
    peakXbyValue = findCorrectPeakByValue(rowSpec,peakLoc, cordBorderLeft, cordBorderRight);
    if(~isempty(peakXbyValue))
        if(imgOut(i, round(peakXbyValue), 1) == colorLightRed(1)) %те пиксели, что найдены обоими методами красим желтым
            imgOut(i, round(peakXbyValue), 1) = 1;
            imgOut(i, round(peakXbyValue), 2) = 1;
            imgOut(i, round(peakXbyValue), 3) = 1;
        else
            imgOut(i, round(peakXbyValue), 1) = colorLightGreen(1); % остальные зеленым
            imgOut(i, round(peakXbyValue), 2) = colorLightGreen(2);
            imgOut(i, round(peakXbyValue), 3) = colorLightGreen(3);
        end
    end
    if(~isempty(peakXbyValue))
        pairByValue = [i, peakXbyValue];
        correctPeaksByValue = [correctPeaksByValue; pairByValue];
    end
end

lineSmooth = smooth( correctPeaks(:,1), correctPeaks(:,2), 0.3,'rloess');
lineSmoothByValue = smooth( correctPeaksByValue(:,1), correctPeaksByValue(:,2), 0.3,'rloess');
pixelsAll = 1:1:size(normM,1);
lineSmoothImgLength = interp1(correctPeaks(:,1), lineSmooth, pixelsAll, 'spline');
lineSmoothImgLengthByValue = interp1(correctPeaksByValue(:,1), lineSmoothByValue, pixelsAll, 'spline');


figure;
hold on;
plot( correctPeaks(:,1), correctPeaks(:,2), 'Color', colorLightRed);
plot( correctPeaksByValue(:,1), correctPeaksByValue(:,2),'Color', colorLightGreen);
plot(pixelsAll,lineSmoothImgLength, 'red');
plot(pixelsAll,lineSmoothImgLengthByValue, 'green');
for z = 1:length(lineSmoothImgLength)
    if(lineSmoothImgLength(z) == 0)
        lineSmoothImgLength(z) = 1;
    end
    if(lineSmoothImgLength(z) > size(imgOut,2))
        lineSmoothImgLength(z) = size(imgOut,2);
    end
end
for z = 1:length(lineSmoothImgLengthByValue)
    if(lineSmoothImgLengthByValue(z) == 0)
        lineSmoothImgLengthByValue(z) = 1;
    end
    if(lineSmoothImgLengthByValue(z) > size(imgOut,2))
        lineSmoothImgLengthByValue(z) = size(imgOut,2);
    end
end

imageFigHandler = figure;
imagesc(imgOut);
xTemp = 1:1:length(lineSmoothImgLength);
xTempByValue = 1:1:length(lineSmoothImgLengthByValue);
hold on;
plot(lineSmoothImgLength, xTemp, 'Color','red','LineWidth',0.2);
plot(lineSmoothImgLengthByValue, xTempByValue, 'Color','green','LineWidth',0.2);
hold off;
% это магическое заклинание строит вертикальные полосы. В 2022 матлабе уже
% можно использовать xline
line([cordBorderLeft cordBorderLeft], get(gca, 'ylim'), 'Color', 'cyan');
line([cordBorderRight cordBorderRight], get(gca, 'ylim'), 'Color', 'cyan');
hold on;
plot(centerLinesX, centerLinesY, '+', 'Color', 'cyan');
hold off;
smoothDefinedSpectralLine = lineSmoothImgLength;
smoothDefinedSpectralLineByValue = lineSmoothImgLengthByValue;


function  imgLoaded = loadImg()
[imgLoaded, ~, ~] = loadSingleFrame();
if isempty(imgLoaded)
    error('Файл не выбран.');
end



function img = minusDarkChan(imgStart)
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
    [~, maxPeakInd] = max(peakValsInsideBrdrs);
    bestPeak = peaksLocationsInsideBrdrs(maxPeakInd);
end


function [imgLoaded, xAxis, meta] = loadInstrumentTxt(fullName)
fid = fopen(fullName, 'r');
if fid == -1
    error('Не удалось открыть файл: %s', fullName);
end

meta = struct();
dataLines = {};
isDataBlock = false;

while ~feof(fid)
    line = fgetl(fid);

    if ~ischar(line)
        continue;
    end

    line = strtrim(line);

    if isempty(line)
        continue;
    end

    nums = sscanf(line, '%f').';

    if ~isDataBlock
        if numel(nums) >= 2
            isDataBlock = true;
            dataLines{end + 1} = line;
        else
            parts = split(line, ':');

            if numel(parts) >= 2
                key = matlab.lang.makeValidName(strtrim(parts{1}));
                value = strtrim(strjoin(parts(2:end), ':'));
                meta.(key) = value;
            end
        end
    else
        dataLines{end + 1} = line;
    end
end

fclose(fid);

if isempty(dataLines)
    error('В файле %s не найдена числовая таблица.', fullName);
end

firstRow = sscanf(dataLines{1}, '%f').';
nRows = numel(dataLines);
nCols = numel(firstRow);

A = zeros(nRows, nCols);
A(1, :) = firstRow;

for i = 2:nRows
    row = sscanf(dataLines{i}, '%f').';

    if numel(row) ~= nCols
        error('В файле %s строка %d имеет %d столбцов, ожидалось %d.', ...
            fullName, i, numel(row), nCols);
    end

    A(i, :) = row;
end

xAxis = A(:, 1);
imgLoaded = A(:, 2:end);
imgLoaded = double(imgLoaded);


function [imgLoaded, xAxis, meta] = loadSingleFrame()
[FileName, PathName, ~] = uigetfile( ...
    {'*.txt;*.png;*.jpg;*.jpeg;*.bmp;*.tif;*.tiff', ...
    'Supported files (*.txt, *.png, *.jpg, *.jpeg, *.bmp, *.tif, *.tiff)'}, ...
    'Выберите файл');

imgLoaded = [];
xAxis = [];
meta = struct();

if isequal(FileName, 0)
    return;
end

fullName = fullfile(PathName, FileName);
[~, ~, ext] = fileparts(fullName);
ext = lower(ext);

switch ext
    case '.txt'
        [imgLoaded, xAxis, meta] = loadInstrumentTxt(fullName);
    otherwise
        imgLoaded = imread(fullName);
        if size(imgLoaded, 3) == 3
            imgLoaded = rgb2gray(imgLoaded);
        end
        imgLoaded = double(imgLoaded);
end

disp(['Загружено: ' fullName]);



function [doubleCompositeImg, xAxis, metaList] = loadImagesAsComposite()
[FileName, PathName, ~] = uigetfile( ...
    {'*.txt;*.png;*.jpg;*.jpeg;*.bmp;*.tif;*.tiff', ...
    'Supported files (*.txt, *.png, *.jpg, *.jpeg, *.bmp, *.tif, *.tiff)'}, ...
    'Выберите файлы', ...
    'MultiSelect', 'on');

doubleCompositeImg = [];
xAxis = [];
metaList = {};

if isequal(FileName, 0)
    return;
end

FileName = cellstr(FileName);
nFiles = numel(FileName);

for i = 1:nFiles
    fullName = fullfile(PathName, FileName{i});
    [~, ~, ext] = fileparts(fullName);
    ext = lower(ext);

    currentXAxis = [];
    currentMeta = struct();

    switch ext
        case '.txt'
            [imgLoaded, currentXAxis, currentMeta] = loadInstrumentTxt(fullName);

        otherwise
            imgLoaded = imread(fullName);

            if size(imgLoaded, 3) == 3
                imgLoaded = rgb2gray(imgLoaded);
            end

            imgLoaded = double(imgLoaded);
    end

    if i == 1
        doubleCompositeImg = imgLoaded;
        refSize = size(imgLoaded);
        xAxis = currentXAxis;
    else
        if ~isequal(size(imgLoaded), refSize)
            error('Размер файла %s не совпадает с размером первого массива.', fullName);
        end

        if ~isempty(currentXAxis) && ~isempty(xAxis)
            if numel(currentXAxis) ~= numel(xAxis) || any(currentXAxis ~= xAxis)
                error('Ось первого столбца в файле %s не совпадает с первым файлом.', fullName);
            end
        end

        doubleCompositeImg = doubleCompositeImg + imgLoaded;
    end

    metaList{i} = currentMeta;
    disp(['Загружено: ' fullName]);
end
