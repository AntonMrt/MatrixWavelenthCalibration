% Данный скрипт позволяет считать изображение матричного спектрометра(с
% искажениями), его калибровку по длинам волн и на их основе создать
% скорректированное изображение с единой калибровкой по длинам волн по всем
% строкам

% загружаются данные, сохраненные в виде текстовых csv матриц из Сигнатуры
slCharacterEncoding('UTF-8')
close all
% изображение
imgLoaded = imread('dataForImageCorrScript/b1.bmp');
monoImg = imgLoaded(:,:,1);
monoImg = imgaussfilt(monoImg,3);

%калибровочные коэффициенты
opts = delimitedTextImportOptions("NumVariables", 3);
opts.DataLines = [1, Inf];
opts.Delimiter = ";";
opts.VariableTypes = ["double", "double", "double"];
opts.ExtraColumnsRule = "ignore";
opts.EmptyLineRule = "read";
waveCalibCoefbaumer = readtable("dataForImageCorrScript/waveCalibCoef_baumer1.csv", opts);
waveCalibCoefbaumer = table2array(waveCalibCoefbaumer);
clear opts

wavesMatrix = zeros(height(monoImg), width(monoImg));
xNew = 380:0.5:950;
matrixCorrect = zeros(height(monoImg), length(xNew));
for i=1:height(monoImg)
    indArray = 0:1:width(monoImg)-1;
    wavesMatrix(i,:) = indArray.*indArray.*waveCalibCoefbaumer(i,1) + indArray.*waveCalibCoefbaumer(i,2) + waveCalibCoefbaumer(i,3);
    x = wavesMatrix(i,:);
    val = double(monoImg(i,:));
    matrixCorrect(i,:) = interp1(x,val,xNew);
end
figure;
imagesc(flip(monoImg,2),"XData",[373 956]);
colormap gray;
% xline([406.8,	446.37, 516.41, 637.69, 435.8328, 546.0735, 892.74, 813.6],"Color",'red', "Alpha", 0.3,"LineWidth", 2);
figure;
imagesc(matrixCorrect,"XData",xNew);
colormap gray;
hold on;
xline([406.8,	446.37, 516.41, 637.69, 892.74, 813.6],"Color",'red', "Alpha", 0.5, "LineWidth", 1,"LineStyle","--");


