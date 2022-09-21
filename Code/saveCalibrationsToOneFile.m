% Matlab R2022a
% Данный скрипт объединяет файлы с координатами спектральной линии в один
% общий калибровочный файл. для этого надо указать папку, в которой
% находятся текстовые файлы с  оординатами спектральных линий, полученных
% при помощи CalibrationMain.m

function saveCalibrationsToOneFile()

[FileNames,PathName,FilterIndex] = uigetfile('*.txt', 'Выберите файлы, которые нужно объеденить', "MultiSelect","on");
if(~iscell(FileNames))
    return;
end

calibrationBigFile = [];
for i=1:length(FileNames)
    fullPath = [PathName '\' char(FileNames(i))];
    spectralLine = readcell(fullPath);
    calibrationBigFile = [calibrationBigFile, spectralLine];
end
name = 'lineCalibration_all.csv';
namePath = [PathName  name];
writecell(calibrationBigFile, namePath,'Delimiter', ';');
disp(['Сохранено в ' namePath]);