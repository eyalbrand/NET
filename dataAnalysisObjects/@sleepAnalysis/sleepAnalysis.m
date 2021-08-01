classdef sleepAnalysis < recAnalysis
    properties
        filt
    end
    
    methods
        %% class constructor
        function obj=sleepAnalysis(xlsFile)
            if nargin==0
                xlsFile='Y:\brainStates.xlsx';
            end
            obj=obj@recAnalysis(xlsFile);
        end
        
                %% plotLizardMovementDB
        function hOut=plotLizardMovementDB(obj,varargin)
            %% parameter and settings
            obj.checkFileRecording;
            
            parseObj = inputParser;
            parseObj.FunctionName='sleepAnalysis\plotLizardMovementDB';
            addParameter(parseObj,'ch',obj.recTable.defaulLFPCh(obj.currentPRec),@isnumeric);
            addParameter(parseObj,'accCh',obj.recTable.accelerometerCh(obj.currentPRec),@isnumeric);
          
            addParameter(parseObj,'saveFigures',1,@isnumeric);
            addParameter(parseObj,'nBins',18,@isnumeric);
            addParameter(parseObj,'rLim4Rose',[],@isnumeric);
            addParameter(parseObj,'RoseAlpha',0.9,@isnumeric);
            addParameter(parseObj,'noBackground',0,@isnumeric);
            addParameter(parseObj,'printLocalCopy',0,@isnumeric);
            addParameter(parseObj,'h',0,@ishandle);
            addParameter(parseObj,'inputParams',false,@isnumeric);
            addParameter(parseObj,'plotRandomDist',1,@isnumeric);
            parseObj.parse(varargin{:});
            if parseObj.Results.inputParams
                disp(parseObj.Results);
                return;
            end
            
            %evaluate all input parameters in workspace
            for i=1:numel(parseObj.Parameters)
                eval([parseObj.Parameters{i} '=' 'parseObj.Results.(parseObj.Parameters{i});']);
            end
            
            %make parameter structure
            parPlotLizardMovementDB=parseObj.Results;
            
            lizardMovement=[obj.currentAnalysisFolder filesep 'lizMov.mat'];
            obj.checkFileRecording(lizardMovement,'Lizard movement analysis missing, please first run getLizardMovements');
            load(lizardMovement); %load data
            
            dbRatioFile=[obj.currentAnalysisFolder filesep 'dbRatio_ch' num2str(ch) '.mat'];
            obj.checkFileRecording(dbRatioFile,'delta to beta file missing, please first run getDBRatio');
            load(dbRatioFile); %load data
            
            slowCyclesFile=[obj.currentAnalysisFolder filesep 'slowCycles_ch' num2str(ch) '.mat'];
            obj.checkFileRecording(slowCyclesFile,'slow cycles file missing, please first run getSlowCycles');
            load(slowCyclesFile); %load data
            
            %calculate phase in db
            for i=1:numel(TcycleOnset)
                cycleDuration=TcycleOffset(i)-TcycleOnset(i);
                pTmp=find(t_mov_ms>(TcycleMid(i)-cycleDuration/2) & t_mov_ms<(TcycleMid(i)+cycleDuration/2));
                phaseAll{i}=(t_mov_ms(pTmp)-(TcycleMid(i)-cycleDuration/2))/cycleDuration;
                
                shufTimes=rand(1,numel(pTmp))*cycleDuration;
                phaseAllRand{i}=shufTimes/cycleDuration;
                
                pTmp=find(t_ms>(TcycleMid(i)-cycleDuration/2) & t_ms<(TcycleMid(i)+cycleDuration/2));
                resampledTemplate(i,:) = interp1((0:(numel(pTmp)-1))./(numel(pTmp)-1),bufferedDelta2BetaRatio(pTmp)',(0:(nBins-1))/(nBins-1),'spline');
            end
            mResampledTemplate=mean(resampledTemplate);

            phaseMov=cell2mat(phaseAll);
            phaseRand=cell2mat(phaseAllRand);
            
            mPhaseMov=angle(mean(exp(1i*phaseMov*2*pi))); %Mean of circular quantities - wiki
            binCenters=(0:(nBins))/(nBins);binCenters=(binCenters(1:end-1)+binCenters(2:end))/2;
            mPhaseDB=angle(mean(mean(resampledTemplate).*exp(1i.*binCenters*2*pi))); %Mean of circular quantities - wiki

            if nargout>0
                hOut.phaseMov=phaseMov;
                hOut.phaseRand=phaseRand;
                hOut.mPhaseMov=mPhaseMov;
                hOut.mPhaseDB = mPhaseDB;
            end
            
            if h==0
                fH=figure;
                h=axes;
            else
                saveFigures=0;
                axes(h);
            end
            cMap=lines(8);
            
            if ~isempty(rLim4Rose)
                hTmp = polarTight(0, rLim4Rose);
                delete(hTmp)
                set(h, 'Nextplot','add');hold on;
            end

            hOut.hRose=rose(phaseMov*2*pi-mPhaseDB,nBins);
            hOut.hRose.Color=[0.9 0.078 0.184];
            XdataRose = get(hOut.hRose,'Xdata');XdataRose=reshape(XdataRose,[4,numel(XdataRose)/4]);
            YdataRose = get(hOut.hRose,'Ydata');YdataRose=reshape(YdataRose,[4,numel(YdataRose)/4]);
            hOut.hPatch=patch(XdataRose,YdataRose,[0.9 0.078 0.184]);
            set(hOut.hPatch,'FaceAlpha',RoseAlpha);
            %set(h,'color','k');
            maxSamplesInBin=max(max(sqrt(XdataRose.^2+YdataRose.^2)));hold on;
            
            hOut.hPolar=polar([0 (1:nBins)/nBins]*pi*2-mPhaseDB,[mResampledTemplate(end) mResampledTemplate]/(max(mResampledTemplate/maxSamplesInBin)));
            hOut.hPolar.LineWidth=2;
            hOut.hPolar.Color=cMap(1,:,:);
            
            uistack(hOut.hPatch, 'top');
            
            delete(findall(h, 'String', '30', '-or','String','60', '-or','String','120', '-or','String','150', '-or','String','210', '-or','String','240', '-or','String','300', '-or','String','330'));
            
            if plotRandomDist
                hOut.hRose2=rose(phaseRand*2*pi-mPhaseDB,nBins);
                hOut.hRose2.Color=[0.5 0.5 0.5];
                hOut.l=legend([hOut.hRose hOut.hPolar hOut.hRose2],'SWC','OF','shuffled');
            else
                hOut.l=legend([hOut.hRose hOut.hPolar],'SWC','OF');
            end
            hOut.l.Color=[1 1 1];
            hOut.l.Box='off';
            hOut.l.Position=[0.7133    0.8317    0.1786    0.1190];
            
            %if ~isempty(rLim4Rose)
            %    set(h_fake,'Visible','off');
            %end
            
            if saveFigures
                set(fH,'PaperPositionMode','auto');
                fileName=[obj.currentPlotFolder filesep 'lizardMovementDB'];
                print(fileName,'-djpeg',['-r' num2str(obj.figResJPG)]);
                if printLocalCopy
                    fileName=[cd filesep obj.recTable.Animal{obj.currentPRec} '_Rec' num2str(obj.currentPRec) '_lizardMovementDB_' videoFileName];
                    print(fileName,'-djpeg',['-r' num2str(obj.figResJPG)]);
                end
            end
            
        end
        
        
        %% getLizardMovements
        function data=getLizardMovements(obj,varargin)
            obj.checkFileRecording;
            
            parseObj = inputParser;
            addParameter(parseObj,'ch',obj.recTable.defaulLFPCh(obj.currentPRec),@isnumeric);
            addParameter(parseObj,'accCh',obj.recTable.accelerometerCh(obj.currentPRec),@isnumeric);
            addParameter(parseObj,'envelopWindow',15,@isnumeric); %max freq. to examine
            addParameter(parseObj,'kurtosisNoiseThreshold',3,@isnumeric); %Spike detection - the threshold on the kurtosis value that differentiates noise samples from data
            addParameter(parseObj,'eventDetectionThresholdStd',4,@isnumeric);%Spike detection - number of standard deviations above the noise level for event detection
            addParameter(parseObj,'movLongWin',1000*60*30,@isnumeric); %max freq. to examine
            
            addParameter(parseObj,'movWin',10000,@isnumeric);
            addParameter(parseObj,'movOLWin',9000,@isnumeric);
            addParameter(parseObj,'tStart',0,@isnumeric);
            addParameter(parseObj,'win',0,@isnumeric); %if 0 uses the whole recording duration
            addParameter(parseObj,'applyNotch',0,@isnumeric);
            addParameter(parseObj,'overwrite',0,@isnumeric);
            addParameter(parseObj,'inputParams',false,@isnumeric);
            parseObj.parse(varargin{:});
            if parseObj.Results.inputParams
                disp(parseObj.Results);
                return;
            end
            
            %evaluate all input parameters in workspace
            for i=1:numel(parseObj.Parameters)
                eval([parseObj.Parameters{i} '=' 'parseObj.Results.(parseObj.Parameters{i});']);
            end
            
            %make parameter structure
            parLizMov=parseObj.Results;
            
            if isnan(ch)
                disp('Error: no reference channel for Delta 2 Beta extraction');
                return;
            end
            if ~iscell(accCh)
                disp('Error: no accelerometer channels provided for movement analysis');
                return;
            else
                accCh=str2num(cell2mat(split(accCh{1},','))); %get accelerometer channel numbers as numerics
            end
            
            if strcmp(class(obj.currentDataObj),'OERecording')
                readFromAnalogCh=1;
            else
                readFromAnalogCh=0;
            end
            
            %check if analysis was already done done
            obj.files.lizMov=[obj.currentAnalysisFolder filesep 'lizMov.mat'];
            if exist(obj.files.lizMov,'file') & ~overwrite
                if nargout==1
                    data=load(obj.files.lizMov);
                else
                    disp('accelerometer movement analysis already exists for this recording');
                end
                return;
            end
            obj.getFilters;
            
            movWinSamples=movWin/1000*obj.filt.FFs;%obj.filt.FFs in Hz, movWin in samples
            movOLWinSamples=movOLWin/1000*obj.filt.FFs;
            timeBin=(movWin-movOLWin); %ms
            
            if win==0
                win=obj.currentDataObj.recordingDuration_ms-tStart;
                endTime=obj.currentDataObj.recordingDuration_ms;
            else
                endTime=min(win+tStart,obj.currentDataObj.recordingDuration_ms);
            end
            startTimes=tStart:(movLongWin-movOLWin):endTime;
            
            nChunks=numel(startTimes);
            t_mov_ms=cell(1,nChunks);
            movAll=cell(1,nChunks);
            
            if applyNotch
                obj.filt.FN=filterData(obj.currentDataObj.samplingFrequency(1));
                obj.filt.FN.filterDesign='cheby1';
                obj.filt.FN.padding=true;
                obj.filt.FN=obj.filt.FN.designNotch;
            end
            
            fprintf('\nAccelerometer data extraction (%d chunks)-',nChunks);
            for i=1:nChunks
                fprintf('%d,',i);
                if readFromAnalogCh
                    MLong=obj.currentDataObj.getAnalogData(accCh,startTimes(i),movLongWin);
                else
                    MLong=obj.currentDataObj.getData(accCh,startTimes(i),movLongWin);
                end
                
                %plot(squeeze(bsxfun(@minus,MLong,mean(MLong,3)))')
                if applyNotch
                    MLong=obj.filt.FN.getFilteredData(MLong); %for 50Hz noise
                end
                [FMLong,t_ms]=obj.filt.F.getFilteredData(MLong);
                %plot(squeeze(bsxfun(@minus,FMLong,mean(FMLong,3)))')
                %y = hilbert(squeeze(FMLong)');
                
                %envelop should be able to work with matrices but for some reasdon upper and lower get the same value when using matrix
                [yupper1,ylower1] = envelope(squeeze(FMLong(1,1,:)),envelopWindow,'peak');
                [yupper2,ylower2] = envelope(squeeze(FMLong(2,1,:)),envelopWindow,'peak');
                [yupper3,ylower3] = envelope(squeeze(FMLong(3,1,:)),envelopWindow,'peak');
                %plot(squeeze(FMLong(1,:,:)));hold on;plot(yupper1-ylower1);
                
                allAxes=yupper1-ylower1+yupper2-ylower2+yupper3-ylower3;
                %allAxes2=max([yupper1-ylower1 yupper2-ylower2 yupper3-ylower3],[],2);
                
                bufferedEnv=buffer(allAxes,500,0,'nodelay');

                noiseSamples=bufferedEnv(:,kurtosis(bufferedEnv,0)<kurtosisNoiseThreshold);
                noiseStd=std(noiseSamples(:));
                noiseMean=mean(noiseSamples(:));
                Th=noiseMean+eventDetectionThresholdStd*noiseStd;

                t_mov_ms{i}=startTimes(i)+t_ms(allAxes>Th);
                movAll{i}=allAxes(allAxes>Th)';
            end
            
            fprintf('\n');
            
            t_mov_ms=cell2mat(t_mov_ms);
            movAll=cell2mat(movAll);

            save(obj.files.lizMov,'t_mov_ms','movAll','parLizMov');
        end 
        
        
        %% getDayTimeInRecTime
        function data=getSleepVsLights(obj,varargin)
            %% parameter and settings
            obj.checkFileRecording;
            
            parseObj = inputParser;
            addParameter(parseObj,'referenceClock','19:00:00'); %reference for lights on/off
            addParameter(parseObj,'ch',obj.recTable.defaulLFPCh(obj.currentPRec),@isnumeric);
            addParameter(parseObj,'clockStartTime',[]); %cell array with the format 'HH:MM:SS'
            addParameter(parseObj,'overwrite',false,@isnumeric);
            addParameter(parseObj,'inputParams',false,@isnumeric);
            parseObj.parse(varargin{:});
            if parseObj.Results.inputParams
                disp(parseObj.Results);
                return;
            end
            %evaluate all input parameters in workspace
            for i=1:numel(parseObj.Parameters)
                eval([parseObj.Parameters{i} '=' 'parseObj.Results.(parseObj.Parameters{i});']);
            end
            
            %make parameter structure
            parDayTimeOnRecTime=parseObj.Results;
            
            %check if analysis was already done done
            obj.files.dayTimeOnRecTime=[obj.currentAnalysisFolder filesep 'dayTimeOnRecTime.mat'];
            if exist(obj.files.dayTimeOnRecTime,'file') & ~overwrite
                if nargout==1
                    data=load(obj.files.dayTimeOnRecTime);
                else
                    disp('dayTimeOnRecTime file already exists');
                end
                return;
            end
            
            dbRatioFile=[obj.currentAnalysisFolder filesep 'dbRatio_ch' num2str(ch) '.mat'];
            obj.checkFileRecording(dbRatioFile,'Delta to beta analysis missing, please first run getDBRatio');
            dataDB=load(dbRatioFile,'t_ms'); %load data 
            
            dbAutocorrFile=[obj.currentAnalysisFolder filesep 'dbAutocorr_ch' num2str(ch) '.mat'];
            obj.checkFileRecording(dbAutocorrFile,'Delta to beta autocorr analysis missing, please first run getDBRatioAC');
            dataAC=load(dbAutocorrFile,'pSleepDBRatio','period'); %load data

            if strcmp(obj.currentDataObj.startDate(1),'(m/d/y):')
                obj.currentDataObj=obj.currentDataObj.getStartRecordingTime;
            end
            recordingStartTimeClock=obj.currentDataObj.startDate;
            
            pStartSleep=find(dataAC.pSleepDBRatio==1,1,'first');
            pEndSleep=find(dataAC.pSleepDBRatio(pStartSleep:end)==0,1,'first')+pStartSleep;

            if pStartSleep==1
                sleepStartEnd=[0 dataDB.t_ms(pEndSleep)];
            else
                sleepStartEnd=dataDB.t_ms([pStartSleep pEndSleep]);
            end
            
            if exist([obj.currentAnalysisFolder filesep 'light.mat'],'file')
                l=load([obj.currentAnalysisFolder filesep 'light.mat']);
                startSleepFromRef_h=(sleepStartEnd-l.light(1))/1000/60/60;
                manualLightAnnotation=true;
            else
                manualLightAnnotation=false;
                tmpDV=datevec(datenum(referenceClock,'HH:MM:SS')-datenum(recordingStartTimeClock,'HH:MM:SS') );
                if tmpDV(1)<0
                    startSleepFromRef_h=sleepStartEnd/1000/60/60+(24-tmpDV(:,4)+(60-tmpDV(:,5))/60+(60-tmpDV(:,6))/3600);
                    disp('Interval between start recording and reference time was too large -> assuming recording started after reference time');
                else
                    startSleepFromRef_h=sleepStartEnd/1000/60/60-(tmpDV(:,4)+tmpDV(:,5)/60+tmpDV(:,6)/3600);
                end
            end
            
            save(obj.files.dayTimeOnRecTime,'sleepStartEnd','recordingStartTimeClock','referenceClock','startSleepFromRef_h','parDayTimeOnRecTime','manualLightAnnotation');
        end
        
        %% getSpikeSTAs
        function data=getSpikeSTAs(obj,varargin)
            %% parameter and settings
            obj.checkFileRecording;
            
            parseObj = inputParser;
            addParameter(parseObj,'ch',obj.recTable.defaulLFPCh(obj.currentPRec),@isnumeric);
            addParameter(parseObj,'nCycles',10,@isnumeric); 
            addParameter(parseObj,'cycleSelection','first',@(x) any(strcmp(x,{'first','rand'})));
            addParameter(parseObj,'binSW',10,@isnumeric);
            addParameter(parseObj,'preSW',1000,@isnumeric);
            addParameter(parseObj,'winSW',2000,@isnumeric);
            addParameter(parseObj,'binSO',1000,@isnumeric);
            addParameter(parseObj,'preSO',40000,@isnumeric);
            addParameter(parseObj,'winSO',80000,@isnumeric);
            addParameter(parseObj,'minSpikeRate',0.05,@isnumeric);
            addParameter(parseObj,'overwrite',false,@isnumeric);
            addParameter(parseObj,'inputParams',false,@isnumeric);
            parseObj.parse(varargin{:});
            if parseObj.Results.inputParams
                disp(parseObj.Results);
                return;
            end
            %evaluate all input parameters in workspace
            for i=1:numel(parseObj.Parameters)
                eval([parseObj.Parameters{i} '=' 'parseObj.Results.(parseObj.Parameters{i});']);
            end
            
            %make parameter structure
            parSpikeSTA=parseObj.Results;
            
            %check if analysis was already done done
            obj.files.spikeSTA=[obj.currentAnalysisFolder filesep 'spikeSTA.mat'];
            if exist(obj.files.spikeSTA,'file') & ~overwrite
                if nargout==1
                    data=load(obj.files.spikeSTA);
                else
                    disp('Spike STA file already exists');
                end
                return;
            end
            
            slowCyclesFile=[obj.currentAnalysisFolder filesep 'slowCycles_ch' num2str(ch) '.mat'];
            obj.checkFileRecording(slowCyclesFile,'slow cycles file missing, please first run getSlowCycles');
            load(slowCyclesFile,'TcycleMid','TcycleOffset','TcycleOnset'); %load data
            
            sharpWavesFile=[obj.currentAnalysisFolder filesep 'sharpWaves_ch' num2str(ch) '.mat'];
            obj.checkFileRecording(sharpWavesFile,'Sharp wave file missing, please run getSharpWaves');
            load(sharpWavesFile);
            
            AIfile=[obj.currentAnalysisFolder filesep 'AI_2ms_4std.mat'];
            obj.checkFileRecording(sharpWavesFile,'AI file missing, please run getAI');
            load(AIfile);
            
            nNeurons=size(icA,2);
            if strcmp(cycleSelection,'first')
                pCycles=1:nCycles;
            elseif strcmp(cycleSelection,'rand')
                pCycles=randperm(numel(TcycleMid),nCycles);
            end
            
            %get high freq channel correlation matrix
            C=zeros(nCycles,nNeurons,nNeurons);
            for i=1:nCycles
                MSW=squeeze(BuildBurstMatrixA(icA,round(tA/2),IA,round(TcycleMid(pCycles(i))/2),round(TcycleOffset(pCycles(i))/2)))';
                tmpC=corrcoef(MSW);
                C(i,:,:)=tmpC;
            end
            ch=icA(1,:);
            avgCrossChCorr=squeeze(mean(C,1));
            clear IA tA icA;
            
            %cluster high freq channel correlation matrix
            [~,orderCtxDVR,ctxDVRClass]=DendrogramMatrix(avgCrossChCorr,'toPlotBinaryTree',0,'linkMethod','average','linkMetric','spearman','maxClusters',2);
            
            if mean(find(ctxDVRClass==1))<mean(find(ctxDVRClass==2))
                disp('Warning: cortex and DVR possition flipped in clustering, flipping position');
                ctxDVRClass(ctxDVRClass==1)=0;
                ctxDVRClass(ctxDVRClass==2)=1;
                ctxDVRClass(ctxDVRClass==0)=2;
            end
            %load spike sorting data
            load([obj.currentDataObj.recordingDir filesep obj.currentDataObj.recordingName '_spikeSort' filesep 'spikeSorting.mat']);

            MSO=BuildBurstMatrix(ic,round(t/binSO),round((TcycleOnset-preSO)/binSO),round(winSO/binSO));
            firingRateSO=squeeze(mean(MSO,1))';
            tMSO=(-preSO+binSO/2):binSO:(winSO-preSO+binSO/2);
            
            MSW=BuildBurstMatrix(ic,round(t/binSW),round((tSW'-preSW)/binSW),round(winSW/binSW));
            tMSW=(-preSW+binSW/2):binSW:(winSW-preSW-binSW/2);
            firingRateSW=squeeze(mean(MSW,1))';

            if numel(manQual)==size(ic,2)
                MUALabel=manQual;
            else
                MUALabel=2*ones(1,size(ic,2));
            end

            avg.CtxSWSU=[];
            avg.CtxSOSU=[];
            avg.CtxSWMU=[];
            avg.CtxSOMU=[];
            avg.DvrSWSU=[];
            avg.DvrSOSU=[];
            avg.DvrSWMU=[];
            avg.DvrSOMU=[];
            for i=1:numel(MUALabel)
                neuSpikeTemp=squeeze(allWaveforms(:,i,:));
                minV=min(neuSpikeTemp);
                [~,peakElec(i)]=min(minV);
                
                if ctxDVRClass(peakElec(i))==2
                    if MUALabel(i)==1
                        avg.CtxSWSU=[avg.CtxSWSU firingRateSW(:,i)];
                        avg.CtxSOSU=[avg.CtxSOSU firingRateSO(:,i)];
                    elseif MUALabel(i)==2
                        avg.CtxSWMU=[avg.CtxSWMU firingRateSW(:,i)];
                        avg.CtxSOMU=[avg.CtxSOMU firingRateSO(:,i)];
                    end
                else
                    if MUALabel(i)==1
                        avg.DvrSWSU=[avg.DvrSWSU firingRateSW(:,i)];
                        avg.DvrSOSU=[avg.DvrSOSU firingRateSO(:,i)];
                    elseif MUALabel(i)==2
                        avg.DvrSWMU=[avg.DvrSWMU firingRateSW(:,i)];
                        avg.DvrSOMU=[avg.DvrSOMU firingRateSO(:,i)];
                    end
                end
            end

            save(obj.files.spikeSTA,'parSpikeSTA','ctxDVRClass','avg','avgCrossChCorr','ch','orderCtxDVR','tMSW','tMSO','MUALabel');
        end
        
        %% getAI
        function data=getAI(obj,varargin)
            %% parameter and settings
            obj.checkFileRecording;
            
            parseObj = inputParser;
            addParameter(parseObj,'selectedChannels',obj.currentDataObj.channelNumbers,@isnumeric);
            addParameter(parseObj,'stdAbsNoiseConstant',4,@isnumeric);
            addParameter(parseObj,'bin_ms',2,@isnumeric);
            addParameter(parseObj,'overwrite',false,@isnumeric);
            addParameter(parseObj,'inputParams',false,@isnumeric);
            parseObj.parse(varargin{:});
            if parseObj.Results.inputParams
                disp(parseObj.Results);
                return;
            end
            %evaluate all input parameters in workspace
            for i=1:numel(parseObj.Parameters)
                eval([parseObj.Parameters{i} '=' 'parseObj.Results.(parseObj.Parameters{i});']);
            end
            
            %make parameter structure
            parAI=parseObj.Results;
            
            %check if analysis was already done done
            obj.files.AIfile=[obj.currentAnalysisFolder filesep 'AI_' num2str(bin_ms) 'ms_' num2str(stdAbsNoiseConstant) 'std.mat'];
            if exist(obj.files.AIfile,'file') & ~overwrite
                if nargout==1
                    data=load(obj.files.AIfile);
                else
                    disp('AI file already exists');
                end
                return;
            end

            [IA,tA,icA]=mcdIntensityExtractorUnfiltered(obj.currentDataObj,'Bin_ms',bin_ms,'SelectedChannels',selectedChannels,'StdAbsNoiseConstant',stdAbsNoiseConstant);
            
            save(obj.files.AIfile,'IA','tA','icA','parAI');
        end
        
        %% getHPSegments 
        function data=getHPSegments(obj,varargin)
            %% parameter and settings
            obj.checkFileRecording;
            
            parseObj = inputParser;
            addParameter(parseObj,'ch',obj.recTable.defaulLFPCh(obj.currentPRec),@isnumeric);
            addParameter(parseObj,'win',80*1000,@isnumeric); %median filter window for extracting optic flow baseline
            addParameter(parseObj,'bin',1000,@isnumeric); %MAD (std) threshold for
            addParameter(parseObj,'artifactTreshHP',500,@isnumeric); %threshold in uV
            addParameter(parseObj,'maxSegments',500,@isnumeric); %MAD (std) threshold for
            addParameter(parseObj,'overwrite',false,@isnumeric);
            addParameter(parseObj,'saveFileName',[]);
            addParameter(parseObj,'inputParams',false,@isnumeric);
            parseObj.parse(varargin{:});
            if parseObj.Results.inputParams
                disp(parseObj.Results);
                return;
            end
            %evaluate all input parameters in workspace
            for i=1:numel(parseObj.Parameters)
                eval([parseObj.Parameters{i} '=' 'parseObj.Results.(parseObj.Parameters{i});']);
            end
            
            %make parameter structure
            parHPSegments=parseObj.Results;
            
            %check if analysis was already done done
            if isempty(saveFileName)
                obj.files.HPSegments=[obj.currentAnalysisFolder filesep 'HPSegments_ch' num2str(ch) '.mat'];
            else
                obj.files.HPSegments=saveFileName;
            end
            if exist(obj.files.HPSegments,'file') & ~overwrite
                if nargout==1
                    data=load(obj.files.HPSegments);
                else
                    disp(['High pass segments file already exists']);
                end
                return;
            end
            
            animalStates=strsplit(obj.recTable.AnimalState{obj.currentPRec},'/');
            awakeStartTimeSec=obj.recTable.tStartAwake{obj.currentPRec};
            
            downSamplingFactor=obj.currentDataObj.samplingFrequency(1)*(bin/1000);
            for i=1:numel(animalStates)
                if strcmp(animalStates{i},'Awake') || strcmp(animalStates{i},'Running') || strcmp(animalStates{i},'Resting')
                    recDuration=obj.currentDataObj.recordingDuration_ms;
                    if ~isnan(awakeStartTimeSec)
                        allSegments=(awakeStartTimeSec*1000+win/2):win:(recDuration-win/2);
                    else
                        allSegments=(win/2):win:(recDuration-win/2);
                    end
                    nSeg=numel(allSegments);
                    tSeg=sort(allSegments(randperm(nSeg,min(maxSegments,nSeg))));
                    
                elseif strcmp(animalStates{i},'Sleep')
                    slowCyclesFile=[obj.currentAnalysisFolder filesep 'slowCycles_ch' num2str(ch) '.mat'];
                    obj.checkFileRecording(slowCyclesFile,'slow cycles file missing, please first run getSlowCycles');
                    load(slowCyclesFile); %load data
                    
                    tSeg=TcycleOnset;
                    nSeg=numel(tSeg);
                    tSeg=sort(tSeg(randperm(nSeg,min(maxSegments,nSeg))));
                end
                allAI{i}=zeros(numel(tSeg),win/bin);
                for j=1:numel(tSeg)
                    MF=obj.filt.FH2.getFilteredData(obj.currentDataObj.getData(ch,tSeg(j)-win/2,win));
                    if all(abs(MF)<artifactTreshHP)
                        AI=squeeze(mean(abs(reshape(MF,[downSamplingFactor  size(MF,3)/downSamplingFactor 1])),1))';
                        allAI{i}(j,:)=AI;
                    else
                        allAI{i}(j,:)=NaN;
                    end
                end
                allSeg{i}=tSeg;
                allStates{i}=animalStates{i};
            end
            
            save(obj.files.HPSegments,'allAI','allSeg','allStates','parHPSegments');
        end
        
        
        %% getHeartRateDBCorr
        function data=getHeartRateDBCorr(obj,varargin)
            %% parameter and settings
            obj.checkFileRecording;
            
            parseObj = inputParser;
            addParameter(parseObj,'ch',obj.recTable.defaulLFPCh(obj.currentPRec),@isnumeric);
            addParameter(parseObj,'heartRateFile',[obj.currentAnalysisFolder filesep 'HR.mat'],@(x) exist(x,'file'));
            addParameter(parseObj,'interpTimeBin',1000);
            addParameter(parseObj,'stdWin',30*1000,@isnumeric); %median filter window for extracting optic flow baseline
            addParameter(parseObj,'plotWin',200*1000,@isnumeric); %MAD (std) threshold for 
            addParameter(parseObj,'plotBin',2*1000,@isnumeric);
            addParameter(parseObj,'InterpSmoothness',0.9,@isnumeric);
            addParameter(parseObj,'plotResults',[],@isnumeric);
            addParameter(parseObj,'hAxes',[],@isnumeric);
            addParameter(parseObj,'overwrite',false,@isnumeric);
            addParameter(parseObj,'inputParams',false,@isnumeric);
            parseObj.parse(varargin{:});
            if parseObj.Results.inputParams
                disp(parseObj.Results);
                return;
            end
            %evaluate all input parameters in workspace
            for i=1:numel(parseObj.Parameters)
                eval([parseObj.Parameters{i} '=' 'parseObj.Results.(parseObj.Parameters{i});']);
            end
            
            %make parameter structure
            parheartRate=parseObj.Results;
            
            %check if analysis was already done done
            obj.files.heartRateAnal=[obj.currentAnalysisFolder filesep 'heartRateAnal.mat'];
            if exist(obj.files.heartRateAnal,'file') & ~overwrite
                if nargout==1
                    data=load(obj.files.heartRateAnal);
                else
                    disp(['Syncing DB with heart rate file already exists']);
                end
                return;
            end
            
            dbRatioFile=[obj.currentAnalysisFolder filesep 'dbRatio_ch' num2str(ch) '.mat'];
            obj.checkFileRecording(dbRatioFile,'delta to beta file missing, please first run getDBRatio');
            load(dbRatioFile); %load data
            
            slowCyclesFile=[obj.currentAnalysisFolder filesep 'slowCycles_ch' num2str(ch) '.mat'];
            obj.checkFileRecording(slowCyclesFile,'slow cycles file missing, please first run getSlowCycles');
            load(slowCyclesFile); %load data
            
            tStart=TcycleOnset(1);
            tEnd=TcycleOnset(end);
            
            tInterp=tStart:interpTimeBin:tEnd;
            
            HR=load([obj.currentAnalysisFolder filesep 'HR.mat']);
           
            %Playing with locking on the single cell level.
            %{
            M=obj.currentDataObj.getData(ch,HR.time-5000,10000);
            H=hilbert(squeeze(M(1,1:15000,:))');
            figure;plot(mean(abs(H),2));line([size(M,3)/2 size(M,3)/2],ylim,'color','r');
            for j=1:1000
                
                %[~,f,t,ps] = spectrogram(squeeze(M(1,j+3000,:)),2^15,round(2^15*0.8),[0:5:500],obj.currentDataObj.samplingFrequency(1),'yaxis');
                PSA(j,:,:)=ps;
            end
            imagesc(t,f,squeeze(log10(mean(PSA))));set(gca,'YDir','normal')
            %}
            
            interHR=csaps(HR.time,HR.bpm,InterpSmoothness,tInterp);
            interDB=csaps(t_ms,bufferedDelta2BetaRatio,InterpSmoothness,tInterp);
            interpStdHR = movingstd(interHR,stdWin/interpTimeBin);
            %plot(tInterp,interHR);hold on;plot(HR.time,HR.bpm,'r')
            
            HRStdRaster=BuildBurstMatrixA([1;1;1;numel(tInterp)],tInterp/plotBin,interpSxtdHR,(TcycleOnset-(plotWin/2))/plotBin,plotWin/plotBin);
            HRRaster=BuildBurstMatrixA([1;1;1;numel(tInterp)],tInterp/plotBin,interHR,(TcycleOnset-(plotWin/2))/plotBin,plotWin/plotBin);

            DBRaster=BuildBurstMatrixA([1;1;1;numel(tInterp)],tInterp/plotBin,interDB,(TcycleOnset-(plotWin/2))/plotBin,plotWin/plotBin);
            tRaster=(-plotWin/2+plotBin/2):plotBin:(plotWin/2);
            
            [~,pSmallRates]=sort(max(abs(HRStdRaster),[],3)); %sort according to hr ampitude
            nEvents=round(numel(pSmallRates)/3); %take only a third of events
            
            save(obj.files.heartRateAnal,'HRStdRaster','DBRaster','tRaster','tInterp','interHR','interDB','interpStdHR','parheartRate');

            if plotResults
                f=figure;
                if isempty(hAxes)
                    hAxes(1)=subaxis(f,2,2,1,'S',0.01,'MR',0.2);
                    hAxes(2)=subaxis(f,2,2,2,'S',0.01,'MR',0.2);
                    hAxes(3)=subaxis(f,2,2,3,'S',0.01,'MR',0.2);
                    hAxes(4)=subaxis(f,2,2,4,'S',0.01,'MR',0.2);
                    hold(hAxes(1),'on');
                    hold(hAxes(3),'on');
                end
                
                plot(tRaster/1000,normZeroOne(mean(squeeze(HRStdRaster))),'Parent',hAxes(1));
                plot(tRaster/1000,normZeroOne(mean(squeeze(DBRaster))),'r','Parent',hAxes(1));
                [hl,hO]=legend(hAxes(1),{'norm. HR variability','norm. \delta/\beta'},'Box','off');
                horizontalLegend(hO);
                hl.Position=[0.4887    0.8825    0.2875    0.0905];
                line([0 0],[0 1],'color',[0.8 0.8 0.8],'Parent',hAxes(1));
                
                plot(tRaster/1000,normZeroOne(mean(squeeze(HRStdRaster(pSmallRates(1:nEvents),1,:)))),'Parent',hAxes(3));
                plot(tRaster/1000,normZeroOne(mean(squeeze(DBRaster(pSmallRates(1:nEvents),1,:)))),'r','Parent',hAxes(3));
                [hl,hO]=legend(hAxes(3),{'norm. HR variability','norm. \delta/\beta'},'Box','off');
                horizontalLegend(hO);
                hl.Position=[0.4887    0.8825    0.2875    0.0905];
                line([0 0],[0 1],'color',[0.8 0.8 0.8],'Parent',hAxes(3));
                
                imagesc(tRaster/1000,1:size(DBRaster(pSmallRates(1:nEvents),1,:),1),squeeze(DBRaster(pSmallRates(1:nEvents),1,:)),'Parent',hAxes(2));
                ylabel('Cycle #','Parent',hAxes(2));
                set(hAxes(2),'XTickLabel',[]);
                xlabel('Time [s]');
                
                imagesc(tRaster/1000,1:size(HRStdRaster(pSmallRates(1:nEvents),1,:),1),squeeze(HRStdRaster(pSmallRates(1:nEvents),1,:)),'Parent',hAxes(4));
                ylabel('Cycle #','Parent',hAxes(4));
                set(hAxes(4),'XTickLabel',[]);
                xlabel('Time [s]');
                
                f=figure;
                if isempty(hAxes)
                    hAxes(1)=subaxis(f,2,2,1,'S',0.01,'MR',0.2);
                    hAxes(2)=subaxis(f,2,2,2,'S',0.01,'MR',0.2);
                    hAxes(3)=subaxis(f,2,2,3,'S',0.01,'MR',0.2);
                    hAxes(4)=subaxis(f,2,2,4,'S',0.01,'MR',0.2);
                    hold(hAxes(1),'on');
                    hold(hAxes(3),'on');
                end
                
                plot(tRaster/1000,normZeroOne(mean(squeeze(HRRaster))),'Parent',hAxes(1));
                plot(tRaster/1000,normZeroOne(mean(squeeze(DBRaster))),'r','Parent',hAxes(1));
                [hl,hO]=legend(hAxes(1),{'norm. HR ','norm. \delta/\beta'},'Box','off');
                horizontalLegend(hO);
                hl.Position=[0.4887    0.8825    0.2875    0.0905];
                line([0 0],[0 1],'color',[0.8 0.8 0.8],'Parent',hAxes(1));
                
                plot(tRaster/1000,normZeroOne(mean(squeeze(HRRaster(pSmallRates(1:nEvents),1,:)))),'Parent',hAxes(3));
                plot(tRaster/1000,normZeroOne(mean(squeeze(DBRaster(pSmallRates(1:nEvents),1,:)))),'r','Parent',hAxes(3));
                [hl,hO]=legend(hAxes(3),{'norm. HR','norm. \delta/\beta'},'Box','off');
                horizontalLegend(hO);
                hl.Position=[0.4887    0.8825    0.2875    0.0905];
                line([0 0],[0 1],'color',[0.8 0.8 0.8],'Parent',hAxes(3));
                
                imagesc(tRaster/1000,1:size(DBRaster(pSmallRates(1:nEvents),1,:),1),squeeze(DBRaster(pSmallRates(1:nEvents),1,:)),'Parent',hAxes(2));
                ylabel('Cycle #','Parent',hAxes(2));
                set(hAxes(2),'XTickLabel',[]);
                xlabel('Time [s]');
                
                imagesc(tRaster/1000,1:size(HRRaster(pSmallRates(1:nEvents),1,:),1),squeeze(HRRaster(pSmallRates(1:nEvents),1,:)),'Parent',hAxes(4));
                ylabel('Cycle #','Parent',hAxes(4));
                set(hAxes(4),'XTickLabel',[]);
                xlabel('Time [s]');
                
                %subplot(2,2,2);crosscorr(interHR,mStdHR,500);
            end
            
        end
        
        %% plotSyncedDBEyeMovements
        function hOut=plotSyncedDBEyeMovements(obj,varargin)
            %% parameter and settings
            obj.checkFileRecording;
            
            parseObj = inputParser;
            parseObj.FunctionName='sleepAnalysis\plotSyncedDBEyeMovements';
            addParameter(parseObj,'ch',obj.recTable.defaulLFPCh(obj.currentPRec),@isnumeric);
            addParameter(parseObj,'videoFile',[obj.recTable.VideoFiles{obj.currentPRec}],@(x) exist(x,'file'));
            addParameter(parseObj,'saveFigures',1,@isnumeric);
            addParameter(parseObj,'rLim4Rose',[],@isnumeric);
            addParameter(parseObj,'RoseAlpha',0.9,@isnumeric);
            addParameter(parseObj,'noBackground',0,@isnumeric);
            addParameter(parseObj,'printLocalCopy',0,@isnumeric);
            addParameter(parseObj,'h',0,@ishandle);
            addParameter(parseObj,'inputParams',false,@isnumeric);
            addParameter(parseObj,'plotRandomDist',1,@isnumeric);
            parseObj.parse(varargin{:});
            if parseObj.Results.inputParams
                disp(parseObj.Results);
                return;
            end
            
            %evaluate all input parameters in workspace
            for i=1:numel(parseObj.Parameters)
                eval([parseObj.Parameters{i} '=' 'parseObj.Results.(parseObj.Parameters{i});']);
            end
            
            %make parameter structure
            parPlotSyncDBEye=parseObj.Results;
            
            [~,videoFileName]=fileparts(videoFile);

            syncDBEyeFile=[obj.currentAnalysisFolder filesep 'syncDBEye_' videoFileName '.mat'];
            obj.checkFileRecording(syncDBEyeFile,'Eye sync analysis missing, please first run getSyncedDBEyeMovements');
            load(syncDBEyeFile); %load data
            
            mResampledTemplate=mean(resampledTemplate);
            
            if h==0
                fH=figure;
                h=axes;
            else
                saveFigures=0;
                axes(h);
            end
            cMap=lines(8);
            
            if ~isempty(rLim4Rose)
                hTmp = polarTight(0, rLim4Rose);
                delete(hTmp)
                set(h, 'Nextplot','add');hold on;
            end

            hOut.hRose=rose(phaseMov*2*pi-mPhaseDB,parSyncDBEye.nBins);
            hOut.hRose.Color=[0.9 0.078 0.184];
            XdataRose = get(hOut.hRose,'Xdata');XdataRose=reshape(XdataRose,[4,numel(XdataRose)/4]);
            YdataRose = get(hOut.hRose,'Ydata');YdataRose=reshape(YdataRose,[4,numel(YdataRose)/4]);
            hOut.hPatch=patch(XdataRose,YdataRose,[0.9 0.078 0.184]);
            set(hOut.hPatch,'FaceAlpha',RoseAlpha);
            %set(h,'color','k');
            maxSamplesInBin=max(max(sqrt(XdataRose.^2+YdataRose.^2)));hold on;
            
            hOut.hPolar=polar([0 (1:parSyncDBEye.nBins)/parSyncDBEye.nBins]*pi*2-mPhaseDB,[mResampledTemplate(end) mResampledTemplate]/(max(mResampledTemplate/maxSamplesInBin)));
            hOut.hPolar.LineWidth=2;
            hOut.hPolar.Color=cMap(1,:,:);
            
            uistack(hOut.hPatch, 'top');
            
            delete(findall(h, 'String', '30', '-or','String','60', '-or','String','120', '-or','String','150', '-or','String','210', '-or','String','240', '-or','String','300', '-or','String','330'));
            
            hOut.l=legend([hOut.hRose hOut.hPolar],'SWC','OF');
            hOut.l.Color=[1 1 1];
            hOut.l.Box='off';
                        
            if plotRandomDist
                hOut.hRose2=rose(phaseRand*2*pi-mPhaseDB,parSyncDBEye.nBins);
                hOut.hRose2.Color=[0.5 0.5 0.5];
            end
            
            %if ~isempty(rLim4Rose)
            %    set(h_fake,'Visible','off');
            %end
            
            if saveFigures
                set(fH,'PaperPositionMode','auto');
                fileName=[obj.currentPlotFolder filesep 'syncEye_' videoFileName];
                print(fileName,'-djpeg',['-r' num2str(obj.figResJPG)]);
                if printLocalCopy
                    fileName=[cd filesep obj.recTable.Animal{obj.currentPRec} '_Rec' num2str(obj.currentPRec) '_syncEyeDB_' videoFileName];
                    print(fileName,'-djpeg',['-r' num2str(obj.figResJPG)]);
                end
            end
            
        end
        
        %% plotSyncedDBEyeMovementsRaster
        function hOut=plotSyncedDBEyeMovementsRaster(obj,varargin)
            %% parameter and settings
            hOut=[];
            obj.checkFileRecording;
            
            parseObj = inputParser;
            parseObj.FunctionName='sleepAnalysis\plotSyncedDBEyeMovementsRaster';
            addParameter(parseObj,'ch',obj.recTable.defaulLFPCh(obj.currentPRec),@isnumeric);
            addParameter(parseObj,'videoFile',[obj.recTable.VideoFiles{obj.currentPRec}],@(x) exist(x,'file'));
            addParameter(parseObj,'saveFigures',1,@isnumeric);
            addParameter(parseObj,'printLocalCopy',0,@isnumeric);
            addParameter(parseObj,'h',0,@ishandle);
            addParameter(parseObj,'inputParams',false,@isnumeric);
            parseObj.parse(varargin{:});
            if parseObj.Results.inputParams
                disp(parseObj.Results);
                return;
            end
            
            %evaluate all input parameters in workspace
            for i=1:numel(parseObj.Parameters)
                eval([parseObj.Parameters{i} '=' 'parseObj.Results.(parseObj.Parameters{i});']);
            end
            
            %make parameter structure
            parPlotSyncDBEye=parseObj.Results;
            
            [~,videoFileName]=fileparts(videoFile);

            syncDBEyeFile=[obj.currentAnalysisFolder filesep 'syncDBEye_' videoFileName '.mat'];
            obj.checkFileRecording(syncDBEyeFile,'Eye sync analysis missing, please first run getSyncedDBEyeMovements');
            load(syncDBEyeFile); %load data
            
            if h==0
                fH=figure;
                h(1)=subaxis(fH,4,2,1,1,1,3,'S',0.01);
                h(2)=subaxis(fH,4,2,1,4,1,1,'S',0.01);
                h(3)=subaxis(fH,4,2,2,1,1,3,'S',0.01);
                h(4)=subaxis(fH,4,2,2,4,1,1,'S',0.01);
            else
                saveFigures=0;
            end
            
            if numel(h)>=1
                edges=(0:parSyncDBEye.nBins)/(parSyncDBEye.nBins-0.0000001);
                middles=(edges(1:end-1)+edges(2:end))/2;
                
                axes(h(1));
                hOut.imagesc=imagesc(0:parSyncDBEye.nBins,1:size(resampledTemplate,1),resampledTemplate);hold on;
                set(h(1),'XTickLabel',[]);
                ylabel('# cycle');
                p=cell2mat(cellfun(@(x) ~isempty(x),phaseAll,'UniformOutput',0));
                for i=find(p)
                    hOut.hP(i)=plot(phaseAll{i}*parSyncDBEye.nBins,i*ones(size(phaseAll{i})),'.r');
                end

                I=histc(phaseMov,edges);
                
                if numel(h)==1
                    xlabel('Phase');
                    set(h,'XTick',[-0.5 parSyncDBEye.nBins+0.5],'XTickLabel',{'0','2\pi'});
                    xlim([-0.5 parSyncDBEye.nBins+0.5])
                end
            end
            
            if numel(h)>=2
                axes(h(2));
                hOut.p1=plot(middles,normZeroOne(mean(resampledTemplate)),'lineWidth',2);hold on;
                hOut.p2=plot(middles,normZeroOne(I(1:end-1)),'r','lineWidth',2);
                xlim([0 1]);
                xlabel('Phase');
                set(h(2),'XTick',[0 1],'XTickLabel',{'0','2\pi'});
                hOut.l=legend('norm. \delta/\beta','norm. OF counts');
                hOut.l.Box='off';
                hOut.l.Position=[0.6434    0.9061    0.2596    0.0812];
            end
            
            if numel(h)>=3
                axes(h(3));
                imagesc(resampledTemplate);hold on;
                set(h(3),'YTickLabel',[],'XTickLabel',[]);
                p=cell2mat(cellfun(@(x) ~isempty(x),phaseAllRand,'UniformOutput',0));
                for i=find(p)
                    plot(phaseAllRand{i}*parSyncDBEye.nBins,i*ones(size(phaseAllRand{i})),'*r');
                end
                I=histc(phaseRand,edges);
            end
            
            if numel(h)>=4
                axes(h(4));
                hOut.p3=plot(middles,normZeroOne(mean(resampledTemplate)),'lineWidth',2);hold on;
                hOut.p4=plot(middles,normZeroOne(I(1:end-1)),'r','lineWidth',2);
                xlim([0 1]);
                xlabel('Phase');
                set(h(4),'XTick',[0 1],'XTickLabel',{'0','2\pi'},'YTickLabel',[])
            end
            
            if saveFigures
                set(fH,'PaperPositionMode','auto');
                fileName=[obj.currentPlotFolder filesep 'syncEyeDBRaster_' videoFileName];
                print(fileName,'-djpeg',['-r' num2str(obj.figResJPG)]);
                if printLocalCopy
                    fileName=[cd filesep obj.recTable.Animal{obj.currentPRec} '_Rec' num2str(obj.currentPRec) '_syncEyeDBRaster_' videoFileName];
                    print(fileName,'-djpeg',['-r' num2str(obj.figResJPG)]);
                end
            end
            
        end
        
        %timeBinDB=(parDBRatio.movWin-parDBRatio.movOLWin);

            %{
            figure;
            subplot(1,2,1);
            imagesc(resampledTemplate);hold on;
            p=cell2mat(cellfun(@(x) ~isempty(x),phaseAll,'UniformOutput',0));
            for i=find(p)
                plot(phaseAll{i}*nBins,i*ones(size(phaseAll{i})),'or');
            end
            
            subplot(1,2,2);
            imagesc(resampledTemplate);hold on;
            p=cell2mat(cellfun(@(x) ~isempty(x),phaseAllRand,'UniformOutput',0));
            for i=find(p)
                plot(phaseAllRand{i}*nBins,i*ones(size(phaseAllRand{i})),'or');
            end
            %}
            
        %% plotEyeVideoOFDB
        function obj=plotEyeVideoOFDB(obj,varargin)
            obj.checkFileRecording;
            
            parseObj = inputParser;
            addParameter(parseObj,'overwrite',false,@isnumeric);
            addParameter(parseObj,'winFrame',100,@isnumeric);
            addParameter(parseObj,'tStart',[],@isnumeric);
            addParameter(parseObj,'tEnd',[],@isnumeric);
            addParameter(parseObj,'outputVideo',[]);
            addParameter(parseObj,'outputFrameRate',10);
            addParameter(parseObj,'opticFlowFile',[]);
            addParameter(parseObj,'OFlineColor','black');
            addParameter(parseObj,'ampOFLine',50);
            addParameter(parseObj,'showOnlyEye',true);
            addParameter(parseObj,'videoCompressor','DV Video Encoder');
            addParameter(parseObj,'saveVideo',false,@isnumeric);
            addParameter(parseObj,'ch',obj.recTable.defaulLFPCh(obj.currentPRec),@isnumeric);
            addParameter(parseObj,'videoFile',[obj.recTable.VideoFiles{obj.currentPRec}],@(x) exist(x,'file'));
            addParameter(parseObj,'inputParams',false,@isnumeric);
            parseObj.parse(varargin{:});
            if parseObj.Results.inputParams
                disp(parseObj.Results);
                return;
            end
            
            %evaluate all input parameters in workspace
            for i=1:numel(parseObj.Parameters)
                eval([parseObj.Parameters{i} '=' 'parseObj.Results.(parseObj.Parameters{i});']);
            end
                            
            dbRatioFile=[obj.currentAnalysisFolder filesep 'dbRatio_ch' num2str(ch) '.mat'];
            obj.checkFileRecording(dbRatioFile,'delta to beta file missing, please first run getDBRatio');
            DB=load(dbRatioFile); %load data
            
            [~,videoFileName]=fileparts(videoFile);
            eyeTrackingFile=[obj.currentAnalysisFolder filesep 'eyeTracking_' videoFileName '.mat'];
            obj.checkFileRecording(eyeTrackingFile,'Eye tracking analysis missing, please first run getEyeMovement');
            ET=load(eyeTrackingFile,'parEyeTracking','pFrames','mOF','pbboxUpdate','bboxCenterAll'); %load data
            
            syncDBEyeFile=[obj.currentAnalysisFolder filesep 'syncDBEye_' videoFileName '.mat'];
            obj.checkFileRecording(syncDBEyeFile,'sync eye to beta 2 delta file missing, please first run getSyncedDBEyeMovements');
            sync=load(syncDBEyeFile); %load data
            
            if ~showOnlyEye
                videoReader = VideoReader(videoFile); %initiate video obj since number of frames was already read (not allowed by matlab)
            end
            %videoPlayer  = vision.VideoPlayer('Position',[100 100 [videoReader.Width, videoReader.Height]+30]);
            if saveVideo
                if isempty(outputVideo)
                    outputVideo=[obj.currentAnalysisFolder filesep videoFileName 'OFDB.avi'];
                end
                videoWriter = vision.VideoFileWriter([outputVideo '.avi'],'FrameRate',outputFrameRate);
                videoWriter.VideoCompressor=videoCompressor;
            end
            
            cMapLines=lines(8);
            dPix=5;
            if ~isempty(opticFlowFile)
                OF=load(opticFlowFile);
                tFramesOF=sync.tVideoFrames(OF.pFrames);
                plotFlowField=true;
                
                rX=round(dPix/2):dPix:size(OF.allOF,2)-round(dPix/2);
                rY=round(dPix/2):dPix:size(OF.allOF,1)-round(dPix/2);
                [Y, X] = meshgrid(rX,rY);
                if ~showOnlyEye
                    X=X+OF.initialFrameSubregion(2);
                    Y=Y+OF.initialFrameSubregion(1);
                end
                
                shapes = vision.ShapeInserter;
                shapes.Shape = 'Lines';
                shapes.BorderColor = OFlineColor;
            else
                plotFlowField=false;
            end
            
            
            smoothDB=2e-11;
            interpDBOF=csaps(DB.t_ms,DB.bufferedDelta2BetaRatio,smoothDB,tFramesOF);

            %plot(tAllFrames(pFrames),interpOF);hold on;plot(tAnalyzedFrames,validmOF);
            if isempty(tStart)
                tStart=tFramesOF(1);
            end
            if isempty(tEnd)
                tEnd=tFramesOF(end);
            end
            
            pFrames=find(tFramesOF>=tStart & tFramesOF<=tEnd);
            tFrames=OF.pFrames(pFrames);
            
            interpDB=interpDBOF(pFrames);
            interpOF=OF.mOF(pFrames);
            pFramesOrig=OF.pFrames(pFrames);
            %plot(normZeroOne(interpDB));hold on;plot(normZeroOne(interpOF));
            
            eInterpDB=[zeros(1,winFrame) interpDB zeros(1,winFrame)]./std([zeros(1,winFrame) interpDB zeros(1,winFrame)]);
            eInterpOF=[zeros(1,winFrame) interpOF zeros(1,winFrame)]./2/std([zeros(1,winFrame) interpOF zeros(1,winFrame)]);
            %plot(eInterpDB);hold on;plot(eInterpOF)
            %plot(tAllFrames(pFrames),interpDB);hold on;plot(t_ms,bufferedDelta2BetaRatio);xlim([16027110.8963877          18570778.2072246])
            %plot(tAllFrames(pFrames),interpOF);hold on;plot(tAnalyzedFrames,validmOF);xlim([16027110.8963877          18570778.2072246])

            %set scaling parameters for curves
            if showOnlyEye
                f=figure('position',[100 100 350 600]);
                set(gcf,'PaperPositionMode','auto');
                
                videoFrame=squeeze(OF.allIm(:,:,1));
                h(1)=subaxis(f,2,1,1,'M',0.03,'S',0.07);
                h(2)=subaxis(f,2,1,2,'M',0.03,'S',0.07);
                axis(h(1),'off');
                xlim(h(1),[0 2*winFrame]);
                yl=[0 4];
                ylim(h(1),yl);
                imshow(videoFrame,'Parent',h(2));
                set(h(2),'nextplot','replacechildren');
                hold(h(1),'on');
                pH=[];
            else
                f=figure('position',[100 100 500 500]);
                videoFrame=rgb2gray(videoReader.read(pFramesOrig(i))); %read will be replaced by readFrame in future versions but it is not possible to skip frames with readframes
                
                W=videoReader.Width;
                H=videoReader.Height;
                pX=(1:(2*winFrame+1))/(2*winFrame+1)*W;
                yStartPixDB=H*0.4; %from top down
                yPixDB=H*0.05;
                yStartPixOF=H*0.5;
                yPixOF=H*0.05;
                ylineLim=H*0.55;
                imshow(videoFrame);
                set(gca,'nextplot','replacechildren');
            end
            set(f,'Renderer','zbuffer');
            
            for i=1:numel(pFramesOrig)
                tmpDB=eInterpDB(i:i+2*winFrame);
                tmpOF=eInterpOF(i:i+2*winFrame);
                
                if showOnlyEye
                    videoFrame=squeeze(OF.allIm(:,:,pFrames(i)));
                else
                    videoFrame=rgb2gray(videoReader.read(pFramesOrig(i))); %read will be replaced by readFrame in future versions but it is not possible to skip frames with readframes
                end

                if plotFlowField
                    currentFrame=squeeze(OF.allOF(:,:,pFrames(i)));
                    currentFrame=currentFrame(rY,rX);
                    Hor = imag(currentFrame)*ampOFLine;
                    Ver = real(currentFrame)*ampOFLine;
                    
                    OFlines = [Y(:)'; X(:)'; Y(:)'+Ver(:)'; X(:)'+Hor(:)'];
                    videoFrame = step(shapes, videoFrame,  int32(OFlines)');
                    % Draw lines on top of image
                    %pHL=line([X(:) X(:)+Hor(:)]',[Y(:) Y(:)+Ver(:)]','color',OFlineColor);
                end
                
                if showOnlyEye
                    delete(pH);
                    imshow(videoFrame,'Parent',h(2));
                    pH(1)=plot(h(1),tmpDB,'lineWidth',1,'color',cMapLines(1,:));
                    pH(2)=plot(h(1),tmpOF,'lineWidth',1,'color',cMapLines(2,:));
                    pH(3)=line([winFrame+1 winFrame+1],yl,'color',cMapLines(5,:),'Parent',h(1));
                    %pH(4)=text(170,-0.4,[num2str(i-1) 's'],'Parent',h(1),'FontSize',16,'FontWeight','Bold');
                else
                    imshow(videoFrame);hold on;
                    pH(1)=plot(pX,-tmpDB*yPixDB+yStartPixDB,'lineWidth',3,'color',cMapLines(1,:));
                    pH(2)=plot(pX,-tmpOF*yPixOF+yStartPixOF,'lineWidth',3,'color',cMapLines(2,:));
                    pH(3)=line([pX(winFrame+1) pX(winFrame+1)],[ylineLim 0],'color',cMapLines(5,:));
                end
                
                if saveVideo %save tracked video
                    frame=getframe(f);
                    step(videoWriter, frame.cdata);
                end
                
            end
            
            if saveVideo
                release(videoWriter);
            end
            if ~showOnlyEye
                delete(videoReader);
            end
            delete(f);
            
        end
        
        %% getSyncedDBEyeMovements
        function data=getSyncedDBEyeMovements(obj,varargin)
            %% parameter and settings
            obj.checkFileRecording;
            
            parseObj = inputParser;
            addParameter(parseObj,'ch',obj.recTable.defaulLFPCh(obj.currentPRec),@isnumeric);
            addParameter(parseObj,'videoFile',[obj.recTable.VideoFiles{obj.currentPRec}],@(x) exist(x,'file'));
            addParameter(parseObj,'matroxTrigScheme',obj.recTable.MatroxTrigScheme{obj.currentPRec});
            addParameter(parseObj,'win',180*1000,@isnumeric); %median filter window for extracting optic flow baseline
            addParameter(parseObj,'nStd',6,@isnumeric); %MAD (std) threshold for 
            addParameter(parseObj,'nBins',18,@isnumeric);
            addParameter(parseObj,'pixelMoveThresh',10,@isnumeric);
            addParameter(parseObj,'overwrite',false,@isnumeric);
            addParameter(parseObj,'nFramesRemoveAfterROIShift',3,@isnumeric);
            addParameter(parseObj,'inputParams',false,@isnumeric);
            parseObj.parse(varargin{:});
            if parseObj.Results.inputParams
                disp(parseObj.Results);
                return;
            end
            %evaluate all input parameters in workspace
            for i=1:numel(parseObj.Parameters)
                eval([parseObj.Parameters{i} '=' 'parseObj.Results.(parseObj.Parameters{i});']);
            end
            
            %make parameter structure
            parSyncDBEye=parseObj.Results;
            
            [~,videoFileName]=fileparts(videoFile);
            %check if analysis was already done done
            obj.files.syncDBEye=[obj.currentAnalysisFolder filesep 'syncDBEye_' videoFileName '.mat'];
            if exist(obj.files.syncDBEye,'file') & ~overwrite
                if nargout==1
                    data=load(obj.files.syncDBEye);
                else
                    disp(['Syncing DB with eye tracking file for video: ' videoFileName ' already exists']);
                end
                return;
            end
            
            eyeTrackingFile=[obj.currentAnalysisFolder filesep 'eyeTracking_' videoFileName '.mat'];
            obj.checkFileRecording(eyeTrackingFile,'Eye tracking analysis missing, please first run getEyeMovement');
            load(eyeTrackingFile,'parEyeTracking','pFrames','mOF','pbboxUpdate','bboxCenterAll'); %load data
            
            digiTrigFile=[obj.currentAnalysisFolder filesep 'getDigitalTriggers.mat'];
            obj.checkFileRecording(digiTrigFile,'digital trigger file missing, please first run getDigitalTriggers');
            load(digiTrigFile); %load data
            
            dbRatioFile=[obj.currentAnalysisFolder filesep 'dbRatio_ch' num2str(ch) '.mat'];
            obj.checkFileRecording(dbRatioFile,'delta to beta file missing, please first run getDBRatio');
            load(dbRatioFile); %load data
            
            slowCyclesFile=[obj.currentAnalysisFolder filesep 'slowCycles_ch' num2str(ch) '.mat'];
            obj.checkFileRecording(slowCyclesFile,'slow cycles file missing, please first run getSlowCycles');
            load(slowCyclesFile); %load data
            
            %remove frames that are close to a ROI shift and frames with large shifts
            p2RemoveShifts=find(sqrt(diff(bboxCenterAll(:,1)).^2+diff(bboxCenterAll(:,2)).^2)>pixelMoveThresh)+1;
            pFramesValid=pFrames;
            validmOF=mOF;
            if ~isempty(pbboxUpdate) || ~isempty(p2RemoveShifts)
                p2Remove=union(p2RemoveShifts,pbboxUpdate)';
                p2Remove=bsxfun(@plus,p2Remove,(0:nFramesRemoveAfterROIShift-1)');
                p2Remove=unique(p2Remove(:));
                
                validmOF(p2Remove)=[];
                pFramesValid(p2Remove)=[];
                bboxCenterAll(p2Remove,:)=[];
            end

            startFrameInVideo=cellfun(@(x) str2num(x),strsplit(obj.recTable.FrameRange{obj.currentPRec},'-'),'UniformOutput', 1);
            if strcmp(matroxTrigScheme,'startD2FramesD1NoEndNoMissed') %correct start trigger (on digi ch 2), no stop trigger, no missed frames (on digi ch 1)
                pMatrox=1;
                pStart=2;
                tAllFrames=tTrig{pMatrox}(1:2:end);
                tAllFrames(tAllFrames<tTrig{pStart}(1))=[];
                nFrames=pFramesValid(end);
                tAllFrames=tAllFrames(1:nFrames);
                tVideoFrames=tAllFrames(startFrameInVideo(1):startFrameInVideo(2));
                tAnalyzedFrames=tAllFrames(pFramesValid+startFrameInVideo(1)-1);
            elseif strcmp(matroxTrigScheme,'D10FromMatroxNoMissed')
                pMatrox=1;
                pMatrox10=10;
                tAllFrames=tTrig{pMatrox}(1:2:end);
                tAllFrames(tAllFrames<tTrig{pMatrox10}(1))=[];
                lastStr=strsplit(tTrig_string{pMatrox10}{end},';');
                lastFrameFromStr=str2num(lastStr{1}(8:end));
                trigNumDiff=find(tAllFrames<tTrig{pMatrox10}(end),1,'last')~=lastFrameFromStr;
                if trigNumDiff~=0
                    warning(['Number of triggers in T1 differs by ' num2str(trigNumDiff) ' trig than what is found from 10 strings-check for missed frames!!!!']);
                end
                tVideoFrames=tAllFrames(startFrameInVideo(1):startFrameInVideo(2));
                tAnalyzedFrames=tAllFrames(pFramesValid+startFrameInVideo(1)-1);
            elseif strcmp(matroxTrigScheme(1:11),'Lizard4Case')
                stringNames=tTrig_string{10};
                tmp=cellfun(@(x) x(8:15),stringNames,'Uniformoutput',0);
                tmp1=cellfun(@(x) find(x==';'),tmp,'Uniformoutput',0);
                frameNumber=cell2mat(cellfun(@(x,y) str2double(x(1:(y-1))),tmp,tmp1,'Uniformoutput',0));
                pStartFrame=find(frameNumber==0);
                pEndFrame=pStartFrame(3)-1;
                pStartFrame=pStartFrame(2);
                tAllFrames=interp1(frameNumber(pStartFrame:pEndFrame),tTrig{10}(pStartFrame:pEndFrame),0:frameNumber(pEndFrame),'linear');
                tVideoFrames=tAllFrames(startFrameInVideo(1):startFrameInVideo(2));
                tAnalyzedFrames=tAllFrames(pFramesValid+startFrameInVideo(1)-1);
            elseif strcmp(matroxTrigScheme,'interpFrom10')
                stringNames=tTrig_string{10};
                tmp=cellfun(@(x) x(8:15),stringNames,'Uniformoutput',0);
                tmp1=cellfun(@(x) find(x==';'),tmp,'Uniformoutput',0);
                frameNumber=cell2mat(cellfun(@(x,y) str2double(x(1:(y-1))),tmp,tmp1,'Uniformoutput',0));
                tAllFrames=interp1(frameNumber,tTrig{10},0:frameNumber(end),'linear');
                tVideoFrames=tAllFrames(startFrameInVideo(1):startFrameInVideo(2));
                tAnalyzedFrames=tAllFrames(pFramesValid+startFrameInVideo(1)-1);
            elseif strcmp(matroxTrigScheme,'xxxx')
                
                pCameraStart=tTrig{10}(1);
                pCameraLast=tTrig{10}(end);
                
                frameNumberStartString=tTrig_string{10}{1};
                frameNumberEndString=tTrig_string{10}{end};
                
                frameNumberStart=str2num(frameNumberStartString(8:find(frameNumberStartString==';',1,'first')-1));
                frameNumberEnd=str2num(frameNumberEndString(8:find(frameNumberEndString==';',1,'first')-1));
                
                frameShutterTimes=tTrig{1}(find(tTrig{1}>pCameraStart & tTrig{1}<pCameraLast));
                frameShutterTimes(diff(frameShutterTimes)<2)=[]; %remove off trigger - every trigger is 1ms long and is recorded twice (once for on and once for off)
                
                frameShutterTimesAfterLastTrigger=Ts{1}(find(Ts{1}>pCameraLast));
                frameShutterTimesAfterLastTrigger(diff(frameShutterTimesAfterLastTrigger)<2)=[]; %remove off trigger - every trigger is 1ms long and is recorded twice (once for on and once for off)
                frameShutterTimesAfterLastTrigger=frameShutterTimesAfterLastTrigger(1:(nFrames-frameNumberEnd));
                frameShutterTimes=[frameShutterTimes frameShutterTimesAfterLastTrigger];
            end
            %plot(tAnalyzedFrames/3600000,normZeroOne(validmOF));hold on;plot(tAnalyzedFrames/3600000,normZeroOne(bboxCenterAll));
            winSamples=round(win/1000*(parEyeTracking.frameRate/parEyeTracking.skipFrames));
            mOFmed=fastmedfilt1d(validmOF,winSamples)';
            mOFMAD=fastmedfilt1d(abs(validmOF-mOFmed),winSamples)'*1.4826;
            tMovement=tAnalyzedFrames(validmOF>(mOFmed+nStd*mOFMAD));
            %plot(tAnalyzedFrames/3600000,validmOF);hold on;plot(tAnalyzedFrames/3600000,mOFmed+nStd*mOFMAD);
            for i=1:numel(TcycleOnset)
                cycleDuration=TcycleOffset(i)-TcycleOnset(i);
                pTmp=find(tMovement>(TcycleMid(i)-cycleDuration/2) & tMovement<(TcycleMid(i)+cycleDuration/2));
                phaseAll{i}=(tMovement(pTmp)-(TcycleMid(i)-cycleDuration/2))/cycleDuration;
                
                shufTimes=rand(1,numel(pTmp))*cycleDuration;
                phaseAllRand{i}=shufTimes/cycleDuration;
                
                pTmp=find(t_ms>(TcycleMid(i)-cycleDuration/2) & t_ms<(TcycleMid(i)+cycleDuration/2));
                resampledTemplate(i,:) = interp1((0:(numel(pTmp)-1))./(numel(pTmp)-1),bufferedDelta2BetaRatio(pTmp)',(0:(nBins-1))/(nBins-1),'spline');

                %{
                cycleDuration=TcycleOffset(i)-TcycleOnset(i);
                pTmp=find(tMovement>TcycleOnset(i) & tMovement<TcycleOffset(i));
                phaseAll{i}=(tMovement(pTmp)-TcycleOffset(i))/(TcycleOffset(i)-TcycleOnset(i));
                
                shufTimes=rand(1,numel(pTmp))*(TcycleOffset(i)-TcycleOnset(i));
                phaseAllRand{i}=shufTimes/(TcycleOffset(i)-TcycleOnset(i));
                
                pTmp=find(t_ms>TcycleOnset(i) & t_ms<TcycleOffset(i));
                resampledTemplate(i,:) = interp1((0:(numel(pTmp)-1))./(numel(pTmp)-1),bufferedDelta2BetaRatio(pTmp)',(0:(nBins-1))/(nBins-1),'spline');

                %}
            end
            phaseMov=cell2mat(phaseAll);
            phaseRand=cell2mat(phaseAllRand);
            
            mPhaseMov=angle(mean(exp(1i*phaseMov*2*pi))); %Mean of circular quantities - wiki
            binCenters=(0:(nBins))/(nBins);binCenters=(binCenters(1:end-1)+binCenters(2:end))/2;
            mPhaseDB=angle(mean(mean(resampledTemplate).*exp(1i.*binCenters*2*pi))); %Mean of circular quantities - wiki
            
            save(obj.files.syncDBEye,'phaseMov','mPhaseDB','mPhaseMov','phaseAll','phaseAllRand','phaseRand','resampledTemplate','validmOF','tAnalyzedFrames','tVideoFrames','tAllFrames','tMovement','parSyncDBEye','pFramesValid','mOFmed','mOFMAD');
           
        end
        
        %% getEyeMovements
        function [data]=getEyeMovements(obj,varargin)
            %% parameter and settings
            obj.checkFileRecording;
            
            parseObj = inputParser;
            addParameter(parseObj,'videoFile',[obj.recTable.VideoFiles{obj.currentPRec}],@(x) exist(x,'file'));
            addParameter(parseObj,'nFramesVideo',[],@isnumeric);
            addParameter(parseObj,'startTime',0,@isnumeric); %in seconds
            addParameter(parseObj,'endTime',Inf,@isnumeric); %in seconds
            addParameter(parseObj,'initialFrameSubregion',[],@isnumeric);
            addParameter(parseObj,'frameForEyePosExtraction',[],@isnumeric);
            addParameter(parseObj,'fractionOfBoxJumpThreshold',0.25,@isnumeric);
            addParameter(parseObj,'manuallyUpdatePoints',true,@isnumeric);
            addParameter(parseObj,'saveFullOFMatrices',false,@isnumeric);
            addParameter(parseObj,'loadInitialConditions',true,@isnumeric);
            addParameter(parseObj,'skipFramesBoundingBox',30,@isnumeric);
            addParameter(parseObj,'removeBorderOF',true);
            addParameter(parseObj,'borderPix',5);
            addParameter(parseObj,'skipFrames',10,@isnumeric);
            addParameter(parseObj,'plotTracking',false,@isnumeric);
            addParameter(parseObj,'saveTrackingVideo',false,@isnumeric);
            addParameter(parseObj,'overwrite',false,@isnumeric);
            addParameter(parseObj,'savedFileName',[]);
            addParameter(parseObj,'minTrackingPoints',40,@isnumeric);
            addParameter(parseObj,'inputParams',false,@isnumeric);
            parseObj.parse(varargin{:});
            if parseObj.Results.inputParams
                disp(parseObj.Results);
                return;
            end
            
            %evaluate all input parameters in workspace
            for i=1:numel(parseObj.Parameters)
                eval([parseObj.Parameters{i} '=' 'parseObj.Results.(parseObj.Parameters{i});']);
            end

            %make parameter structure
            parEyeTracking=parseObj.Results;
            
            [~,videoFileName]=fileparts(videoFile);
            if isempty(savedFileName)
                obj.files.eyeTracking=[obj.currentAnalysisFolder filesep 'eyeTracking_' videoFileName '.mat'];
                trackingFileName=[obj.currentAnalysisFolder filesep videoFileName '_EyeTracking.avi'];
            else
                obj.files.eyeTracking=[savedFileName '.mat'];
                trackingFileName=[savedFileName '_EyeTracking.avi'];
            end
            
            %check if analysis was already done done
            if exist(obj.files.eyeTracking,'file') & ~overwrite
                if nargout==1
                    data=load(obj.files.eyeTracking);
                else
                    disp(['Eye tracking file for video: ' videoFileName 'already exists']);
                end
                return;
            end
            
            if exist(obj.files.eyeTracking,'file') & loadInitialConditions
                load(obj.files.eyeTracking,'parEyeTracking');
                startTime=parEyeTracking.startTime;
                initialFrameSubregion=parEyeTracking.initialFrameSubregion;
                parEyeTracking.startTime=startTime;
                parEyeTracking.initialFrameSubregion=initialFrameSubregion;
            end
            
            if saveTrackingVideo
                plotTracking=1;
            end
            %% Pre processing
            videoReader = VideoReader(videoFile); %initiate video obj
            frameWidth=videoReader.Width;
            frameHeight=videoReader.Height;
            frameRate=videoReader.FrameRate;
            videoDuration=videoReader.Duration;
            nFramesVideo=videoDuration*frameRate;
            
            
            parEyeTracking.frameWidth=frameWidth;
            parEyeTracking.frameHeight=frameHeight;
            parEyeTracking.frameRate=frameRate;
            parEyeTracking.nFramesVideo=nFramesVideo;
            parEyeTracking.videoDuration=videoDuration;
            parEyeTracking.startFrame=startTime*frameRate;

            
            %get initial eye location for tacking
            if isempty(frameForEyePosExtraction)
                frameForEyePosExtraction=parEyeTracking.startFrame;
            end
            
            if startTime~=0 % this is much faster!!!
                videoReader.CurrentTime = startTime; 
                initFrame = rgb2gray(videoReader.readFrame);
                startFrame = videoReader.FrameRate*videoReader.CurrentTime;
            end
            
            if isempty(initialFrameSubregion) %to manually select region for extracting eye movements
                f=figure('position',[100 100 1200 600]);
                subplot(1,3,1:2);imshow(initFrame);
                h = imrect(gca);
                initialFrameSubregion=h.getPosition;
                xInd=round(initialFrameSubregion(1):(initialFrameSubregion(1)+initialFrameSubregion(3)));
                yInd=round(initialFrameSubregion(2):(initialFrameSubregion(2)+initialFrameSubregion(4)));
                subplot(1,3,3);imshow(initFrame(yInd,xInd,:));
                title('Selected region - press any key');
                pause;
                close(f);
                initialFrameSubregion=round(initialFrameSubregion);
            else
                xInd=round(initialFrameSubregion(1):(initialFrameSubregion(1)+initialFrameSubregion(3)));
                yInd=round(initialFrameSubregion(2):(initialFrameSubregion(2)+initialFrameSubregion(4)));
            end
            
            if isinf(endTime) %analyze the complete video
                endTime=videoDuration;
            end
            endFrame=round((endTime/videoDuration)*nFramesVideo);
            pFrames=startFrame:skipFrames:endFrame;
            nFrames=numel(pFrames);
            delete(videoReader);
            
            parEyeTracking.initialFrameSubregion=initialFrameSubregion;
            

            %determine the position of border pixels to remove from OF analysis
            if removeBorderOF
                tmp=zeros([numel(yInd),numel(xInd)]);
                tmp(:)=1:numel(tmp);
                pSizeBorder=tmp([1:borderPix end-borderPix+1:end],:);
                pUpDownBorder=tmp(:,[1:borderPix end-borderPix+1:end]);
                pBorder=unique([pSizeBorder(:);pUpDownBorder(:)]);
            end
            
            %defition of optic flow and video reader/converter objects
            if skipFrames~=1 || pFrames(1)>1
                videoReader = VideoReader(videoFile); %initiate video obj since number of frames was already read (not allowed by matlab)
                %videoReader.CurrentTime=(1/videoReader.FrameRate)*(pFrames(1)-1);
                nonConsecutiveVideo=true;
            else
                videoReader = vision.VideoFileReader(videoFile,'ImageColorSpace','Intensity','VideoOutputDataType','uint8'); % create required video objects
                nonConsecutiveVideo=false;
            end
            videoReader.CurrentTime = startTime; 

            % optic flow definitions
            opticFlow = opticalFlowLK;
            
            bboxPoints=[initialFrameSubregion(1) initialFrameSubregion(2);initialFrameSubregion(1) initialFrameSubregion(2)+initialFrameSubregion(4);initialFrameSubregion(1)+initialFrameSubregion(3) initialFrameSubregion(2)+initialFrameSubregion(4);initialFrameSubregion(1)+initialFrameSubregion(3) initialFrameSubregion(2)];                
            bboxCenter=[(bboxPoints(3,1)+bboxPoints(1,1))/2 (bboxPoints(3,2)+bboxPoints(1,2))/2];
            bboxCenterOld=[(bboxPoints(3,1)+bboxPoints(1,1))/2 (bboxPoints(3,2)+bboxPoints(1,2))/2]; 
            bboxPointsOld=bboxPoints;
            OFBox=bboxPointsOld;

            bboxShiftDistanceThreshold=round(min(initialFrameSubregion(3)*fractionOfBoxJumpThreshold,initialFrameSubregion(4)*fractionOfBoxJumpThreshold));
            
            % Detect feature points in the face region.
            points = detectMinEigenFeatures(initFrame, 'ROI', round(initialFrameSubregion));

            %Display the detected points.
            %figure, imshow(videoFrame), hold on, title('Detected features');
            %plot(points);

            % Create a point tracker and enable the bidirectional error constraint to make it more robust in the presence of noise and clutter.
            pointTracker = vision.PointTracker('MaxBidirectionalError', 2);

            % Initialize the tracker with the initial point locations and the initial video frame.
            points = points.Location;
            initialize(pointTracker, points, initFrame);
            
            if plotTracking
                videoPlayer  = vision.VideoPlayer('Position',[100 100 [size(initFrame, 2), size(initFrame, 1)]+30]);
            end
            if saveTrackingVideo
               videoWriter = vision.VideoFileWriter(trackingFileName,'FrameRate',30);
            end
            %savePlottedTracking
            
            % Make a copy of the points to be used for computing the geometric transformation between the points in the previous and the current frames
            oldPoints = points;

            if saveFullOFMatrices %if to save all optic flow data
                allOF=zeros(numel(yInd),numel(xInd),nFrames,'like',complex(zeros(1,'single'),zeros(1,'single')));
                allIm=zeros(numel(yInd),numel(xInd),nFrames,'single');
            else
                allOF=[];
                allIm=[];
            end
            
            %% main loop
            pbboxUpdate=[];
            bboxCenterAll=zeros(nFrames,2);
            mOF=zeros(1,nFrames);
            skipBoundingBoxInSkip=round(skipFramesBoundingBox/skipFrames);
            parEyeTracking.skipBoundingBoxInSkip=skipBoundingBoxInSkip;
            
            hWB=waitbar(0,'Calculating optic flow');
            for i=1:nFrames
                %frame = step(videoReader); this is faster but cant start from an arbitrary frame or jump frames
                if nonConsecutiveVideo
                    videoReader.CurrentTime = (pFrames(i)/nFramesVideo)*videoDuration;
                    videoFrame = rgb2gray(videoReader.readFrame);
                else
                    videoFrame = step(videoReader);
                    for j=1:numel(pFrames(i+1)-pFrames(i)-1)
                        step(videoReader);
                    end
                end
                %{
                figure;imshow(videoFrame);hold on;plot(bboxCenter(1),bboxCenter(2),'or','markersize',20,'linewidth',3);plot(bboxPoints(:,1),bboxPoints(:,2),'.g','markersize',10);plot(points(:,1),points(:,2),'*b')
                %}
                if mod(i,skipBoundingBoxInSkip)==0
                    waitbar(i/nFrames,hWB);
                    
                    % Track the points. Note that some points may be lost.
                    [points, isFound] = step(pointTracker, videoFrame);
                    visiblePoints = points(isFound, :);
                    oldInliers = oldPoints(isFound, :);
                    
                    if size(visiblePoints, 1) >= 2 % need at least 2 points to ensure we are still reliably tracking the object
                        
                        % Estimate the geometric transformation between the old points and the new points and eliminate outliers
                        [xform, oldInliers, visiblePoints] = estimateGeometricTransform(oldInliers, visiblePoints, 'similarity', 'MaxDistance', 4);
                        
                        % Apply the transformation to the bounding box points
                        bboxPoints = transformPointsForward(xform, bboxPoints);
                        
                        % Reset the points
                        if size(oldInliers,1)<minTrackingPoints
                            contourBox=round([min(bboxPoints(:,1)) min(bboxPoints(:,2))  max(bboxPoints(:,1))-min(bboxPoints(:,1)) max(bboxPoints(:,2))-min(bboxPoints(:,2))]);
                            newPoints = detectMinEigenFeatures(videoFrame, 'ROI', contourBox ); %this function can not receive a polygon only a rectangle along the main axes
                            newPoints = newPoints.Location;
                            in = inpolygon(newPoints(:,1),newPoints(:,2),bboxPoints(:,1),bboxPoints(:,2));
                            points=newPoints(in,:);
                            setPoints(pointTracker,points);
                            %initialize(pointTracker, points, initFrame);
                            oldPoints = points; %all new added points are tracked
                            visiblePoints = points; %all new added points are tracked
                        else
                            oldPoints = visiblePoints;
                            setPoints(pointTracker, oldPoints);
                        end
                        %update Bounding box - check if box position was moved considerably and update accordingly
                        bboxCenter=[(bboxPoints(3,1)+bboxPoints(1,1))/2 (bboxPoints(3,2)+bboxPoints(1,2))/2]; %calculate center
                        if sqrt((bboxCenter(1)-bboxCenterOld(1)).^2+(bboxCenter(2)-bboxCenterOld(2)).^2) > bboxShiftDistanceThreshold %check if box moved too much such that its position should be updated
                            bboxPointsOld=bboxPoints; %update old (current) box to new box
                            %update the indices to be used for optic flow extraction
                            bboxCenterOld=bboxCenter; %update old box center
                            pbboxUpdate=[pbboxUpdate i];
                            [xInd,yInd,OFBox]=obj.recalculateSampledImageArea4OpticFlow(xInd,yInd,bboxCenter,frameWidth,frameHeight);
                            %opticFlow.reset;
                        end
                        
                        if plotTracking
                            % Insert a bounding box around the object being tracked
                            bboxPolygon = reshape(bboxPoints', 1, []);
                            bboxPolygonOld = reshape(bboxPointsOld', 1, []);
                            OFboxPolygon = reshape(OFBox', 1, []);
                            
                            videoFramePlot = insertShape(videoFrame, 'Polygon', bboxPolygon,'LineWidth', 2);
                            videoFramePlot = insertShape(videoFramePlot, 'Polygon', bboxPolygonOld,'LineWidth', 2,'color','r');
                            videoFramePlot = insertShape(videoFramePlot, 'Polygon', OFboxPolygon,'LineWidth', 2,'color','g');
                            
                            % Display tracked points
                            videoFramePlot = insertMarker(videoFramePlot, visiblePoints, '+','Color', 'white');
                            
                            % Display the annotated video frame using the video player object
                            step(videoPlayer, videoFramePlot);
                            
                            if saveTrackingVideo %save tracked video
                                step(videoWriter, videoFramePlot);
                            end
                        end
                    else
                        if manuallyUpdatePoints
                            f=figure('position',[100 100 1200 600]);
                            subplot(1,3,1:2);imshow(videoFrame);
                            [xi, yi] = ginput(1);
                            
                            %recalculate the area of the bounding box accroding to the center defined by the user.
                            bboxCenter=[xi,yi]; %bboxCenter=[bboxCenter(1)-xi,bboxCenter(2)-yi];
                            
                            bboxPointsOld=bboxPoints;
                            bboxCenterOld=bboxCenter;
                            pbboxUpdate=[pbboxUpdate i];
                            %recalculate position of rectangle
                            [xInd,yInd,OFBox]=obj.recalculateSampledImageArea4OpticFlow(xInd,yInd,bboxCenter,frameWidth,frameHeight);
                            %opticFlow.reset;
                            
                            contourBox=round([min(bboxPoints(:,1)) min(bboxPoints(:,2))  max(bboxPoints(:,1))-min(bboxPoints(:,1)) max(bboxPoints(:,2))-min(bboxPoints(:,2))]);
                            newPoints = detectMinEigenFeatures(videoFrame, 'ROI', contourBox ); %this function can not receive a polygon only a rectangle along the main axes
                            newPoints = newPoints.Location;
                            in = inpolygon(newPoints(:,1),newPoints(:,2),bboxPoints(:,1),bboxPoints(:,2));
                            points=newPoints(in,:);
                            setPoints(pointTracker,points);
                            %initialize(pointTracker, points, initFrame);
                            oldPoints = points; %all new added points are tracked
                            visiblePoints = points; %all new added points are tracked
                            
                            subplot(1,3,3);imshow(videoFrame(yInd,xInd,:));
                            title('Points lost. Selected region - press any key');
                            pause;
                            close(f);

                        else
                            disp(['Tracking analysis stopped at ' num2str(i) '/' num2str(nFrames) ' since all tracking points were lost']);
                            parEyeTracking.pStopDue2LostPoints=i;
                            mOF(i:end)=[];
                            bboxCenterAll(i:end,:)=[];
                            pFrames(i:end)=[];
                            break; %stop for loop
                        end
                    end
                    
                end
                im = videoFrame(yInd,xInd);
                tmpOF=opticFlow.estimateFlow(im);
                tmpOFM=tmpOF.Magnitude;
                if removeBorderOF
                    tmpOFM(pBorder)=0;
                end
                
                if saveFullOFMatrices
                    allOF(:,:,i) = tmpOFM;
                    allIm(:,:,i) = im;
                end
                
                mOF(i)=mean(mean(abs(tmpOFM))); %mean velocity for every pixel
                bboxCenterAll(i,:)=bboxCenter;
                
            end
            close(hWB);
            
            save(obj.files.eyeTracking,'mOF','allOF','allIm','pbboxUpdate','parEyeTracking','pFrames','bboxCenterAll','initialFrameSubregion','frameRate','nFramesVideo');
            
            % Clean uprelease(videoReader);
            release(pointTracker);
            if nonConsecutiveVideo
                delete(videoReader);
            else
                release(videoReader);
            end
            
            if saveTrackingVideo %save tracked video
                release(videoWriter);
            end
            if plotTracking
                release(videoPlayer);
            end
            
        end

         %% getRespirationMovements
        function [data]=getRespirationMovements(obj,varargin)
            %% parameter and settings
            obj.checkFileRecording;
            
            parseObj = inputParser;
            addParameter(parseObj,'videoFile',[obj.recTable.VideoFiles{obj.currentPRec}],@(x) exist(x,'file'));
            addParameter(parseObj,'nFramesVideo',[],@isnumeric);
            addParameter(parseObj,'startTime',0,@isnumeric); %in seconds
            addParameter(parseObj,'endTime',Inf,@isnumeric); %in seconds
            addParameter(parseObj,'initialFrameSubregion',[],@isnumeric);
            addParameter(parseObj,'frameForChestPosExtraction',[],@isnumeric);
            addParameter(parseObj,'fractionOfBoxJumpThreshold',0.25,@isnumeric);
            addParameter(parseObj,'manuallyUpdatePoints',true,@isnumeric);
            addParameter(parseObj,'saveFullOFMatrices',false,@isnumeric);
            addParameter(parseObj,'loadInitialConditions',true,@isnumeric);
            addParameter(parseObj,'skipFramesBoundingBox',10,@isnumeric);
            addParameter(parseObj,'removeBorderOF',true);
            addParameter(parseObj,'borderPix',5);
            addParameter(parseObj,'skipFrames',10,@isnumeric);
            addParameter(parseObj,'plotTracking',false,@isnumeric);
            addParameter(parseObj,'saveTrackingVideo',false,@isnumeric);
            addParameter(parseObj,'overwrite',false,@isnumeric);
            addParameter(parseObj,'savedFileName',[]);
            addParameter(parseObj,'minTrackingPoints',40,@isnumeric);
            addParameter(parseObj,'inputParams',false,@isnumeric);
            parseObj.parse(varargin{:});
            if parseObj.Results.inputParams
                disp(parseObj.Results);
                return;
            end
            
            %evaluate all input parameters in workspace
            for i=1:numel(parseObj.Parameters)
                eval([parseObj.Parameters{i} '=' 'parseObj.Results.(parseObj.Parameters{i});']);
            end

            %make parameter structure
            parChestTracking=parseObj.Results;
            
            [~,videoFileName]=fileparts(videoFile);
            if isempty(savedFileName)
                obj.files.chestTracking=[obj.currentAnalysisFolder filesep 'chestTracking_' videoFileName '.mat'];
                trackingFileName=[obj.currentAnalysisFolder filesep videoFileName '_ChestTracking.avi'];
            else
                obj.files.chestTracking=[savedFileName '.mat'];
                trackingFileName=[savedFileName '_ChestTracking.avi'];
            end
            
            %check if analysis was already done done
            if exist(obj.files.chestTracking,'file') & ~overwrite
                if nargout==1
                    data=load(obj.files.chestTracking);
                else
                    disp(['Chest tracking file for video: ' videoFileName 'already exists']);
                end
                return;
            end
            
            if exist(obj.files.chestTracking,'file') & loadInitialConditions
                load(obj.files.chestTracking,'parChestTracking');
                startTime=parChestTracking.startTime;
                initialFrameSubregion=parChestTracking.initialFrameSubregion;
                parChestTracking.startTime=startTime;
                parChestTracking.initialFrameSubregion=initialFrameSubregion;
            end
            
            if saveTrackingVideo
                plotTracking=1;
            end
            %% Pre processing
            videoReader = VideoReader(videoFile); %initiate video obj
            frameWidth=videoReader.Width;
            frameHeight=videoReader.Height;
            frameRate=videoReader.FrameRate;
            videoDuration=videoReader.Duration;
            nFramesVideo=round(videoDuration*frameRate);
            
            parChestTracking.frameWidth=frameWidth;
            parChestTracking.frameHeight=frameHeight;
            parChestTracking.frameRate=frameRate;
            parChestTracking.nFramesVideo=nFramesVideo;
            parChestTracking.videoDuration=videoDuration;
            parChestTracking.startFrame=startTime*frameRate;
            
            %get initial chest location for tacking
            if isempty(frameForChestPosExtraction)
                frameForChestPosExtraction=parChestTracking.startFrame;
            end
            
            if startTime~=0 % this is much faster!!!
                videoReader.CurrentTime = startTime; 
                initFrame = rgb2gray(videoReader.readFrame);
                startFrame = videoReader.FrameRate*videoReader.CurrentTime;
            end
            
            if isempty(initialFrameSubregion) %to manually select region for extracting chest movements
                f=figure('position',[100 100 1200 600]);
                subplot(1,3,1:2);imshow(initFrame);
                h = imrect(gca);
                initialFrameSubregion=h.getPosition;
                xInd=round(initialFrameSubregion(1):(initialFrameSubregion(1)+initialFrameSubregion(3)));
                yInd=round(initialFrameSubregion(2):(initialFrameSubregion(2)+initialFrameSubregion(4)));
                subplot(1,3,3);imshow(initFrame(yInd,xInd,:));
                title('Selected region - press any key');
                pause;
                close(f);
                initialFrameSubregion=round(initialFrameSubregion);
            else
                xInd=round(initialFrameSubregion(1):(initialFrameSubregion(1)+initialFrameSubregion(3)));
                yInd=round(initialFrameSubregion(2):(initialFrameSubregion(2)+initialFrameSubregion(4)));
            end
            
            if isinf(endTime) %analyze the complete video
                endTime=videoDuration;
            end
            endFrame=round((endTime/videoDuration)*nFramesVideo);
            pFrames=startFrame:skipFrames:endFrame;
            nFrames=numel(pFrames);
            delete(videoReader);
            
            parChestTracking.initialFrameSubregion=initialFrameSubregion;
            

            %determine the position of border pixels to remove from OF analysis
            if removeBorderOF
                tmp=zeros([numel(yInd),numel(xInd)]);
                tmp(:)=1:numel(tmp);
                pSizeBorder=tmp([1:borderPix end-borderPix+1:end],:);
                pUpDownBorder=tmp(:,[1:borderPix end-borderPix+1:end]);
                pBorder=unique([pSizeBorder(:);pUpDownBorder(:)]);
            end
            
            %defition of optic flow and video reader/converter objects
            if skipFrames~=1 || pFrames(1)>1
                videoReader = VideoReader(videoFile); %initiate video obj since number of frames was already read (not allowed by matlab)
                %videoReader.CurrentTime=(1/videoReader.FrameRate)*(pFrames(1)-1);
                nonConsecutiveVideo=true;
            else
                videoReader = vision.VideoFileReader(videoFile,'ImageColorSpace','Intensity','VideoOutputDataType','uint8'); % create required video objects
                nonConsecutiveVideo=false;
            end
            videoReader.CurrentTime = startTime; 

            % optic flow definitions
            opticFlow = opticalFlowLK;
            
            bboxPoints=[initialFrameSubregion(1) initialFrameSubregion(2);initialFrameSubregion(1) initialFrameSubregion(2)+initialFrameSubregion(4);initialFrameSubregion(1)+initialFrameSubregion(3) initialFrameSubregion(2)+initialFrameSubregion(4);initialFrameSubregion(1)+initialFrameSubregion(3) initialFrameSubregion(2)];                
            bboxCenter=[(bboxPoints(3,1)+bboxPoints(1,1))/2 (bboxPoints(3,2)+bboxPoints(1,2))/2];
            bboxCenterOld=[(bboxPoints(3,1)+bboxPoints(1,1))/2 (bboxPoints(3,2)+bboxPoints(1,2))/2]; 
            bboxPointsOld=bboxPoints;
            OFBox=bboxPointsOld;

            bboxShiftDistanceThreshold=round(min(initialFrameSubregion(3)*fractionOfBoxJumpThreshold,initialFrameSubregion(4)*fractionOfBoxJumpThreshold));
            
            % Detect feature points in the face region.
            points = detectMinEigenFeatures(initFrame, 'ROI', round(initialFrameSubregion));

            %Display the detected points.
            %figure, imshow(videoFrame), hold on, title('Detected features');
            %plot(points);

            % Create a point tracker and enable the bidirectional error constraint to make it more robust in the presence of noise and clutter.
            pointTracker = vision.PointTracker('MaxBidirectionalError', 2);

            % Initialize the tracker with the initial point locations and the initial video frame.
            points = points.Location;
            initialize(pointTracker, points, initFrame);
            
            if plotTracking
                videoPlayer  = vision.VideoPlayer('Position',[100 100 [size(initFrame, 2), size(initFrame, 1)]+30]);
            end
            if saveTrackingVideo
               videoWriter = vision.VideoFileWriter(trackingFileName,'FrameRate',30);
            end
            %savePlottedTracking
            
            % Make a copy of the points to be used for computing the geometric transformation between the points in the previous and the current frames
            oldPoints = points;
            
            if saveFullOFMatrices %if to save all optic flow data
                allVx=zeros(numel(yInd),numel(xInd),nFrames,'single');
                allVy=zeros(numel(yInd),numel(xInd),nFrames,'single');
                allIm=zeros(numel(yInd),numel(xInd),nFrames,'single');
            else
                allVx=[];
                allVy=[];
                allIm=[];
            end
            
            %% main loop
            pbboxUpdate=[];
            bboxCenterAll=zeros(nFrames,2);
            mAngle=zeros(1,nFrames);
            skipBoundingBoxInSkip=round(skipFramesBoundingBox/skipFrames);
            parChestTracking.skipBoundingBoxInSkip=skipBoundingBoxInSkip;
            allATrans=zeros(3,3,ceil(nFrames/skipBoundingBoxInSkip),'single');
            
            hWB=waitbar(0,'Calculating optic flow');
            for i=1:nFrames
                %frame = step(videoReader); this is faster but cant start from an arbitrary frame or jump frames
                if nonConsecutiveVideo
                    videoReader.CurrentTime = (pFrames(i)/nFramesVideo)*videoDuration;
                    videoFrame = rgb2gray(videoReader.readFrame);
                else
                    videoFrame = step(videoReader);
                    for j=1:numel(pFrames(i+1)-pFrames(i)-1)
                        step(videoReader);
                    end
                end
                %{
                figure;imshow(videoFrame);hold on;plot(bboxCenter(1),bboxCenter(2),'or','markersize',20,'linewidth',3);plot(bboxPoints(:,1),bboxPoints(:,2),'.g','markersize',10);plot(points(:,1),points(:,2),'*b')
                %}
                if mod(i,skipBoundingBoxInSkip)==0
                    waitbar(i/nFrames,hWB);
                    
                    % Track the points. Note that some points may be lost.
                    [points, isFound] = step(pointTracker, videoFrame);
                    visiblePoints = points(isFound, :);
                    oldInliers = oldPoints(isFound, :);
                    
                    if size(visiblePoints, 1) >= 3 % need at least 2 points to ensure we are still reliably tracking the object
                        
                        % Estimate the geometric transformation between the old points and the new points and eliminate outliers
                        [xform, oldInliers, visiblePoints] = estimateGeometricTransform(oldInliers, visiblePoints, 'similarity', 'MaxDistance', 4);
                        allATrans(:,:,i/skipBoundingBoxInSkip)=xform.T;
                        % Apply the transformation to the bounding box points
                        bboxPoints = transformPointsForward(xform, bboxPoints);
                        
                        % Reset the points
                        if size(oldInliers,1)<minTrackingPoints
                            contourBox=round([min(bboxPoints(:,1)) min(bboxPoints(:,2))  max(bboxPoints(:,1))-min(bboxPoints(:,1)) max(bboxPoints(:,2))-min(bboxPoints(:,2))]);
                            newPoints = detectMinEigenFeatures(videoFrame, 'ROI', contourBox ); %this function can not receive a polygon only a rectangle along the main axes
                            newPoints = newPoints.Location;
                            in = inpolygon(newPoints(:,1),newPoints(:,2),bboxPoints(:,1),bboxPoints(:,2));
                            points=newPoints(in,:);
                            setPoints(pointTracker,points);
                            %initialize(pointTracker, points, initFrame);
                            oldPoints = points; %all new added points are tracked
                            visiblePoints = points; %all new added points are tracked
                        else
                            oldPoints = visiblePoints;
                            setPoints(pointTracker, oldPoints);
                        end
                        %update Bounding box - check if box position was moved considerably and update accordingly
                        bboxCenter=[(bboxPoints(3,1)+bboxPoints(1,1))/2 (bboxPoints(3,2)+bboxPoints(1,2))/2]; %calculate center
                        if sqrt((bboxCenter(1)-bboxCenterOld(1)).^2+(bboxCenter(2)-bboxCenterOld(2)).^2) > bboxShiftDistanceThreshold %check if box moved too much such that its position should be updated
                            bboxPointsOld=bboxPoints; %update old (current) box to new box
                            %update the indices to be used for optic flow extraction
                            bboxCenterOld=bboxCenter; %update old box center
                            pbboxUpdate=[pbboxUpdate i];
                            [xInd,yInd,OFBox]=obj.recalculateSampledImageArea4OpticFlow(xInd,yInd,bboxCenter,frameWidth,frameHeight);
                            %opticFlow.reset;
                        end
                        
                        if plotTracking
                            % Insert a bounding box around the object being tracked
                            bboxPolygon = reshape(bboxPoints', 1, []);
                            bboxPolygonOld = reshape(bboxPointsOld', 1, []);
                            OFboxPolygon = reshape(OFBox', 1, []);
                            
                            videoFramePlot = insertShape(videoFrame, 'Polygon', bboxPolygon,'LineWidth', 2);
                            videoFramePlot = insertShape(videoFramePlot, 'Polygon', bboxPolygonOld,'LineWidth', 2,'color','r');
                            videoFramePlot = insertShape(videoFramePlot, 'Polygon', OFboxPolygon,'LineWidth', 2,'color','g');
                            
                            % Display tracked points
                            videoFramePlot = insertMarker(videoFramePlot, visiblePoints, '+','Color', 'white');
                            
                            % Display the annotated video frame using the video player object
                            step(videoPlayer, videoFramePlot);
                            
                            if saveTrackingVideo %save tracked video
                                step(videoWriter, videoFramePlot);
                            end
                        end
                    else
                        if manuallyUpdatePoints
                            f=figure('position',[100 100 1200 600]);
                            
                            confirm=0;
                            while ~confirm
                                subplot(1,3,1:2);imshow(videoFrame);
                                title('Points lost. Selected One point in the center of the region and press any key');
                                [xi, yi] = ginput(1);
                                %recalculate the area of the bounding box accroding to the center defined by the user.
                                bboxCenter=[xi,yi]; %bboxCenter=[bboxCenter(1)-xi,bboxCenter(2)-yi];
                                
                                bboxPointsOld=bboxPoints;
                                bboxCenterOld=bboxCenter;
                                pbboxUpdate=[pbboxUpdate i];
                                %recalculate position of rectangle
                                [xInd,yInd,OFBox]=obj.recalculateSampledImageArea4OpticFlow(xInd,yInd,bboxCenter,frameWidth,frameHeight);
                                
                                subplot(1,3,3);imshow(videoFrame(yInd,xInd,:));
                                title('If region selected well, press 1 (other wise press another number)');
                                x = input('If region selected well, press 1 (other wise press another number):')
                                if x==1
                                    confirm=1;
                                end
                            end
                            close(f);
                            

                            %opticFlow.reset;
                            
                            contourBox=round([min(bboxPoints(:,1)) min(bboxPoints(:,2))  max(bboxPoints(:,1))-min(bboxPoints(:,1)) max(bboxPoints(:,2))-min(bboxPoints(:,2))]);
                            newPoints = detectMinEigenFeatures(videoFrame, 'ROI', contourBox ); %this function can not receive a polygon only a rectangle along the main axes
                            newPoints = newPoints.Location;
                            in = inpolygon(newPoints(:,1),newPoints(:,2),bboxPoints(:,1),bboxPoints(:,2));
                            points=newPoints(in,:);
                            setPoints(pointTracker,points);
                            %initialize(pointTracker, points, initFrame);
                            oldPoints = points; %all new added points are tracked
                            visiblePoints = points; %all new added points are tracked
                        else
                            disp(['Tracking analysis stopped at ' num2str(i) '/' num2str(nFrames) ' since all tracking points were lost']);
                            parChestTracking.pStopDue2LostPoints=i;
                            mAngle(i:end)=[];
                            bboxCenterAll(i:end,:)=[];
                            pFrames(i:end)=[];
                            break; %stop for loop
                        end
                    end
                    
                end
                im = videoFrame(yInd,xInd);
                tmpOF=opticFlow.estimateFlow(im);
                tmpVx=tmpOF.Vx;
                tmpVy=tmpOF.Vy;
                if removeBorderOF
                    tmpVx(pBorder)=0;
                    tmpVy(pBorder)=0;
                end
                
                if saveFullOFMatrices
                    allVx(:,:,i) = tmpVx;
                    allVy(:,:,i) = tmpVy;
                    allIm(:,:,i) = im;
                end
                [mAngle(i)]=cart2pol(mean(tmpVx(:)),mean(tmpVy(:)));
                bboxCenterAll(i,:)=bboxCenter;
                
            end
            close(hWB);
            
            save(obj.files.chestTracking,'allATrans','mAngle','allVx','allVy','allIm','pbboxUpdate','parChestTracking','pFrames','bboxCenterAll','initialFrameSubregion','frameRate','nFramesVideo');
            
            % Clean uprelease(videoReader);
            release(pointTracker);
            if nonConsecutiveVideo
                delete(videoReader);
            else
                release(videoReader);
            end
            
            if saveTrackingVideo %save tracked video
                release(videoWriter);
            end
            if plotTracking
                release(videoPlayer);
            end
            
        end

        %% getDelta2BetaRatio
        function data=getDelta2BetaRatio(obj,varargin)
            obj.checkFileRecording;
            
            parseObj = inputParser;
            addParameter(parseObj,'ch',obj.recTable.defaulLFPCh(obj.currentPRec),@isnumeric);
            addParameter(parseObj,'movLongWin',1000*60*30,@isnumeric); %max freq. to examine
            addParameter(parseObj,'movWin',10000,@isnumeric);
            addParameter(parseObj,'movOLWin',9000,@isnumeric);
            addParameter(parseObj,'segmentWelch',1000,@isnumeric);
            addParameter(parseObj,'dftPointsWelch',2^10,@isnumeric);
            addParameter(parseObj,'OLWelch',0.5);
            addParameter(parseObj,'tStart',0,@isnumeric);
            addParameter(parseObj,'win',0,@isnumeric); %if 0 uses the whole recording duration
            addParameter(parseObj,'deltaBandCutoff',4,@isnumeric);
            addParameter(parseObj,'betaBandLowCutoff',10,@isnumeric);
            addParameter(parseObj,'betaBandHighCutoff',40,@isnumeric);
            addParameter(parseObj,'applyNotch',0,@isnumeric);
            addParameter(parseObj,'saveSpectralProfiles',0,@isnumeric);
            addParameter(parseObj,'maxVoltage',1500,@isnumeric);
            addParameter(parseObj,'overwrite',0,@isnumeric);
            addParameter(parseObj,'inputParams',false,@isnumeric);
            parseObj.parse(varargin{:});
            if parseObj.Results.inputParams
                disp(parseObj.Results);
                return;
            end
            
            %evaluate all input parameters in workspace
            for i=1:numel(parseObj.Parameters)
                eval([parseObj.Parameters{i} '=' 'parseObj.Results.(parseObj.Parameters{i});']);
            end
            
            %make parameter structure
            parDBRatio=parseObj.Results;
            
            if isnan(ch)
                disp('Error: no reference channel for Delta 2 Beta extraction');
                return;
            end
            %check if analysis was already done done
            obj.files.dbRatio=[obj.currentAnalysisFolder filesep 'dbRatio_ch' num2str(ch) '.mat'];
            if exist(obj.files.dbRatio,'file') & ~overwrite
                if nargout==1
                    data=load(obj.files.dbRatio);
                else
                    disp('DB analysis already exists for this recording');
                end
                return;
            end
            
            obj.getFilters;
            movWinSamples=movWin/1000*obj.filt.FFs;%obj.filt.FFs in Hz, movWin in samples
            movOLWinSamples=movOLWin/1000*obj.filt.FFs;
            timeBin=(movWin-movOLWin); %ms
            
            segmentWelchSamples = round(segmentWelch/1000*obj.filt.FFs);
            samplesOLWelch = round(segmentWelchSamples*OLWelch);
            
            %run welch once to get frequencies for every bin (f) determine frequency bands
            [~,f] = pwelch(randn(1,movWinSamples),segmentWelchSamples,samplesOLWelch,dftPointsWelch,obj.filt.FFs);
            pfLowBand=find(f<=deltaBandCutoff);
            pfHighBand=find(f>=betaBandLowCutoff & f<betaBandHighCutoff);
            
            %if obj.currentDataObj.recordingDuration_ms<movLongWin
            %    movLongWin=obj.currentDataObj.recordingDuration_ms;
            %end
            
            if win==0
                win=obj.currentDataObj.recordingDuration_ms-tStart;
                endTime=obj.currentDataObj.recordingDuration_ms;
            else
                endTime=min(win+tStart,obj.currentDataObj.recordingDuration_ms);
            end
            startTimes=tStart:(movLongWin-movOLWin):endTime;
            nChunks=numel(startTimes);
            deltaBetaRatioAll=cell(1,nChunks);
            t_ms=cell(1,nChunks);
            %deltaBetaRatioAllLow=cell(1,nChunks);;deltaBetaRatioAllHigh=cell(1,nChunks);
            
            if saveSpectralProfiles
                FMLongB = buffer(true(1,movLongWin/1000*obj.filt.FFs),movWinSamples,movOLWinSamples,'nodelay');
                fftInBuffer=size(FMLongB,2)
                allFreqProfiles=zeros(ceil(dftPointsWelch/2)+1,nChunks*fftInBuffer);
            else
                allFreqProfiles=[];
            end
            if applyNotch
                obj.filt.FN=filterData(obj.currentDataObj.samplingFrequency(1));
                obj.filt.FN.filterDesign='cheby1';
                obj.filt.FN.padding=true;
                obj.filt.FN=obj.filt.FN.designNotch;
            end
            
            fprintf('\nDelta2Beta extraction (%d chunks)-',nChunks);
            for i=1:nChunks
                fprintf('%d,',i);
                MLong=obj.currentDataObj.getData(ch,startTimes(i),movLongWin);
                if applyNotch
                    MLong=obj.filt.FN.getFilteredData(MLong); %for 50Hz noise
                end
                FMLong=obj.filt.F.getFilteredData(MLong);
                
                FMLong(FMLong<-maxVoltage | FMLong>maxVoltage)=nan; %remove high voltage movement artifacts
                
                FMLongB = buffer(FMLong,movWinSamples,movOLWinSamples,'nodelay');
                pValid=all(~isnan(FMLongB));
                
                deltaBetaRatioAll{i}=nan(1,numel(pValid)); %changes from zeros to nan in these 3 lines (Mark)
                deltaRatioAll{i}=nan(1,numel(pValid));
                betaRatioAll{i}=nan(1,numel(pValid));
                if any(pValid)
                    [pxx,f] = pwelch(FMLongB(:,pValid),segmentWelchSamples,samplesOLWelch,dftPointsWelch,obj.filt.FFs);
                    
                    deltaBetaRatioAll{i}(pValid)=(mean(pxx(pfLowBand,:))./mean(pxx(pfHighBand,:)))';
                    deltaRatioAll{i}(pValid)=mean(pxx(pfLowBand,:))';
                    betaRatioAll{i}(pValid)=mean(pxx(pfHighBand,:))';
                else
                    pxx=zeros(dftPointsWelch/2+1,numel(pValid));
                end
                
                if saveSpectralProfiles
                    allFreqProfiles(:,(fftInBuffer*(i-1)+find(pValid)))=pxx;
                end
                
                t_ms{i}=startTimes(i)+((movWin/2):timeBin:(movLongWin-movWin/2));
            end
            fprintf('\n');
            deltaBetaRatioAll{end}(t_ms{end}>(endTime-movWin/2))=NaN; 
            deltaRatioAll{end}(t_ms{end}>(endTime-movWin/2))=NaN; 
            betaRatioAll{end}(t_ms{end}>(endTime-movWin/2))=NaN; 
            
            bufferedDelta2BetaRatio=cell2mat(deltaBetaRatioAll);bufferedDelta2BetaRatio=bufferedDelta2BetaRatio(:);
            bufferedDeltaRatio=cell2mat(deltaRatioAll);bufferedDeltaRatio=bufferedDeltaRatio(:);
            bufferedBetaRatio=cell2mat(betaRatioAll);bufferedBetaRatio=bufferedBetaRatio(:);
            
            t_ms=cell2mat(t_ms);
            
            save(obj.files.dbRatio,'t_ms','bufferedDelta2BetaRatio','parDBRatio','bufferedBetaRatio','bufferedDeltaRatio','allFreqProfiles');
        end        
        
        %% getPhaseAnalysis
        function data=getPhaseAnalysis(obj,varargin)
            obj.checkFileRecording;
            
            parseObj = inputParser;
            addParameter(parseObj,'ch1',NaN,@isnumeric);
            addParameter(parseObj,'ch2',NaN,@isnumeric);


            addParameter(parseObj,'overwrite',0,@isnumeric);
            addParameter(parseObj,'inputParams',false,@isnumeric);
            parseObj.parse(varargin{:});
            if parseObj.Results.inputParams
                disp(parseObj.Results);
                return;
            end
            
            %evaluate all input parameters in workspace
            for i=1:numel(parseObj.Parameters)
                eval([parseObj.Parameters{i} '=' 'parseObj.Results.(parseObj.Parameters{i});']);
            end
            
            %make parameter structure
            parPhaseAnalysis=parseObj.Results;
            
            if isnan(ch1) || isnan(ch2)
                disp('Error: no reference channel for Delta 2 Beta extraction');
                return;
            end
            %check if analysis was already done done
            obj.files.phaseAnalysis=[obj.currentAnalysisFolder filesep 'phaseAnalysis_ch' num2str(ch1) '-' num2str(ch2) '.mat'];
            if exist(obj.files.phaseAnalysis,'file') & ~overwrite
                if nargout==1
                    data=load(obj.files.phaseAnalysis);
                else
                    disp('Phase analysis already exists for this recording');
                end
                return;
            end
            
            slowCyclesFile1=[obj.currentAnalysisFolder filesep 'slowCycles_ch' num2str(ch1) '.mat'];
            slowCyclesFile2=[obj.currentAnalysisFolder filesep 'slowCycles_ch' num2str(ch2) '.mat'];
            obj.checkFileRecording(slowCyclesFile1,'slow cycle analysis missing, please first run getSlowCycles');
            obj.checkFileRecording(slowCyclesFile2,'slow cycle analysis missing, please first run getSlowCycles');
            SC1=load(slowCyclesFile1); %load data
            SC2=load(slowCyclesFile2); %load data
            
            obj.getFilters;
            
            %Extract REM / SWS segments that are common to both channels
            
            %pREM=ones(1,SC1.
            
            fprintf('\nDelta2Beta extraction (%d chunks)-',nChunks);
            
            for i=1:nChunks
                fprintf('%d,',i);
                MLong=obj.currentDataObj.getData(ch,startTimes(i),movLongWin);
                if applyNotch
                    FLong=obj.filt.FN.getFilteredData(MLong); %for 50Hz noise
                end
                FMLong=obj.filt.F.getFilteredData(MLong);
                
                FMLong(FMLong<-maxVoltage | FMLong>maxVoltage)=nan; %remove high voltage movement artifacts
                
            end
            
            
            
            movWinSamples=movWin/1000*obj.filt.FFs;%obj.filt.FFs in Hz, movWin in samples
            movOLWinSamples=movOLWin/1000*obj.filt.FFs;
            timeBin=(movWin-movOLWin); %ms
            
            segmentWelchSamples = round(segmentWelch/1000*obj.filt.FFs);
            samplesOLWelch = round(segmentWelchSamples*OLWelch);
            
            %run welch once to get frequencies for every bin (f) determine frequency bands
            [~,f] = pwelch(randn(1,movWinSamples),segmentWelchSamples,samplesOLWelch,dftPointsWelch,obj.filt.FFs);
            pfLowBand=find(f<=deltaBandCutoff);
            pfHighBand=find(f>=betaBandLowCutoff & f<betaBandHighCutoff);
            
            %if obj.currentDataObj.recordingDuration_ms<movLongWin
            %    movLongWin=obj.currentDataObj.recordingDuration_ms;
            %end
            
            if win==0
                win=obj.currentDataObj.recordingDuration_ms-tStart;
                endTime=obj.currentDataObj.recordingDuration_ms;
            else
                endTime=min(win+tStart,obj.currentDataObj.recordingDuration_ms);
            end
            startTimes=tStart:(movLongWin-movOLWin):endTime;
            nChunks=numel(startTimes);
            deltaBetaRatioAll=cell(1,nChunks);
            t_ms=cell(1,nChunks);
            %deltaBetaRatioAllLow=cell(1,nChunks);;deltaBetaRatioAllHigh=cell(1,nChunks);
            
            if saveSpectralProfiles
                FMLongB = buffer(true(1,movLongWin/1000*obj.filt.FFs),movWinSamples,movOLWinSamples,'nodelay');
                fftInBuffer=size(FMLongB,2)
                allFreqProfiles=zeros(ceil(dftPointsWelch/2)+1,nChunks*fftInBuffer);
            else
                allFreqProfiles=[];
            end
            if parPhaseAnalysis.applyNotch
                obj.filt.FN=filterData(obj.currentDataObj.samplingFrequency(1));
                obj.filt.FN.filterDesign='cheby1';
                obj.filt.FN.padding=true;
                obj.filt.FN=obj.filt.FN.designNotch;
            end
            
            fprintf('\nDelta2Beta extraction (%d chunks)-',nChunks);
            for i=1:nChunks
                fprintf('%d,',i);
                MLong=obj.currentDataObj.getData(ch,startTimes(i),movLongWin);
                if applyNotch
                    FLong=obj.filt.FN.getFilteredData(MLong); %for 50Hz noise
                end
                FMLong=obj.filt.F.getFilteredData(MLong);
                
                FMLong(FMLong<-maxVoltage | FMLong>maxVoltage)=nan; %remove high voltage movement artifacts
                
                FMLongB = buffer(FMLong,movWinSamples,movOLWinSamples,'nodelay');
                pValid=all(~isnan(FMLongB));
                
                [pxx,f] = pwelch(FMLongB(:,pValid),segmentWelchSamples,samplesOLWelch,dftPointsWelch,obj.filt.FFs);
                
                if saveSpectralProfiles
                    allFreqProfiles(:,(fftInBuffer*(i-1)+find(pValid)))=pxx;
                end
                deltaBetaRatioAll{i}=zeros(1,numel(pValid));
                deltaBetaRatioAll{i}(pValid)=(mean(pxx(pfLowBand,:))./mean(pxx(pfHighBand,:)))';
                
                deltaRatioAll{i}=zeros(1,numel(pValid));
                deltaRatioAll{i}(pValid)=mean(pxx(pfLowBand,:))';
                
                betaRatioAll{i}=zeros(1,numel(pValid));
                betaRatioAll{i}(pValid)=mean(pxx(pfHighBand,:))';
                
                t_ms{i}=startTimes(i)+((movWin/2):timeBin:(movLongWin-movWin/2));
            end
            fprintf('\n');
            deltaBetaRatioAll{end}(t_ms{end}>(endTime-movWin/2))=NaN; 
            deltaRatioAll{end}(t_ms{end}>(endTime-movWin/2))=NaN; 
            betaRatioAll{end}(t_ms{end}>(endTime-movWin/2))=NaN; 
            
            bufferedDelta2BetaRatio=cell2mat(deltaBetaRatioAll);bufferedDelta2BetaRatio=bufferedDelta2BetaRatio(:);
            bufferedDeltaRatio=cell2mat(deltaRatioAll);bufferedDeltaRatio=bufferedDeltaRatio(:);
            bufferedBetaRatio=cell2mat(betaRatioAll);bufferedBetaRatio=bufferedBetaRatio(:);
            
            t_ms=cell2mat(t_ms);
            
            save(obj.files.dbRatio,'t_ms','bufferedDelta2BetaRatio','parDBRatio','bufferedBetaRatio','bufferedDeltaRatio','allFreqProfiles');
        end
        
        %% getSlowCycles
        function data=getSlowCycles(obj,varargin)
            obj.checkFileRecording;
            
            parseObj = inputParser;
            addParameter(parseObj,'ch',obj.recTable.defaulLFPCh(obj.currentPRec),@isnumeric);
            addParameter(parseObj,'medianFiltWin',1000*20,@isnumeric);
            addParameter(parseObj,'longOrdFiltWin',1000*1000,@isnumeric);
            addParameter(parseObj,'longOrdFiltOrd',0.6,@isnumeric);
            addParameter(parseObj,'estimateFilterValuesFromPeriod',1,@isnumeric);
            addParameter(parseObj,'removeNonSignificatACSegments',0,@isnumeric);
            addParameter(parseObj,'excludeIrregularCycles',1,@isnumeric); %for excluding cycles which do not have a regular duration
            addParameter(parseObj,'overwrite',0,@isnumeric);
            
            addParameter(parseObj,'inputParams',false,@isnumeric);
            parseObj.parse(varargin{:});
            if parseObj.Results.inputParams
                disp(parseObj.Results);
                return;
            end
            
            %evaluate all input parameters in workspace
            for i=1:numel(parseObj.Parameters)
                eval([parseObj.Parameters{i} '=' 'parseObj.Results.(parseObj.Parameters{i});']);
            end
            
            %make parameter structure
            parSlowCycles=parseObj.Results;
            
            %check if analysis was already done done
            obj.files.slowCycles=[obj.currentAnalysisFolder filesep 'slowCycles_ch' num2str(ch) '.mat'];
            if exist(obj.files.slowCycles,'file') & ~overwrite
                if nargout==1
                    data=load(obj.files.slowCycles);
                else
                    disp('Slow cycle analysis already exists for this recording');
                end
                return;
            end
            
            dbRatioFile=[obj.currentAnalysisFolder filesep 'dbRatio_ch' num2str(ch) '.mat'];
            obj.checkFileRecording(dbRatioFile,'Delta to beta analysis missing, please first run getDelta2BetaRatio');
            load(dbRatioFile,'t_ms','bufferedDelta2BetaRatio','parDBRatio'); %load data  
            
            dbAutocorrFile=[obj.currentAnalysisFolder filesep 'dbAutocorr_ch' num2str(ch) '.mat'];
            obj.checkFileRecording(dbAutocorrFile,'Delta to beta autocorr analysis missing, please first run getDelta2BetaAC');
            load(dbAutocorrFile,'pSleepDBRatio','period','pSleepSlidingAC','pSleepDBRatioAC'); %load data
                
            timeBin=(parDBRatio.movWin-parDBRatio.movOLWin);
            bufferedDelta2BetaRatio(isnan(bufferedDelta2BetaRatio))=0;
            
            %calculate filter values based on oscillation period
            band=1.5;
            if estimateFilterValuesFromPeriod
                medianFiltWin=round(period*0.25);
                maxCycleSamples=round((period*band)/timeBin);
                minCycleSamples=round(period/band/timeBin);
            else
                maxCycleSamples=round(140/timeBin);
                minCycleSamples=round(10/timeBin);
            end
            
            %smooth with median filter
            medianFiltSamples=medianFiltWin/timeBin;
            DBRatioMedFilt = fastmedfilt1d(bufferedDelta2BetaRatio, medianFiltSamples);

            %plot(t_ms/1000/60/60,DBRatioMedFilt);hold on;plot(t_ms/1000/60/60,DBLongOrdFilt);
            
            HAng=phase(hilbert(DBRatioMedFilt));
            %the peaks in this analysis are the end of the delta period and the troughs are the
            [cycleMidPeaks,pTcycleMid]=findpeaks(HAng,'MinPeakProminence',pi/8,'MinPeakDistance',minCycleSamples,'MinPeakHeight',0,'MinPeakWidth',minCycleSamples/4);
            cycleMid=t_ms(pTcycleMid);
            %{
                    h(1)=subplot(2,1,1);plot(t_ms/1000/60/60,DBRatioMedFilt);
                    h(2)=subplot(2,1,2);plot(t_ms/1000/60/60,HAng);hold on;plot(cycleMid/1000/60/60,cycleMidPeaks,'or');
                    linkaxes(h,'x');
            %}
            %tSlidingAC
            removeNonSleepSegments=1;
            if removeNonSleepSegments
                %pTcycleOnset is places in t_ms
                pTcycleMid=intersect(pTcycleMid,find(pSleepDBRatio));
            end
            
            if removeNonSignificatACSegments
                pTcycleMid=intersect(pTcycleMid,find(pSleepDBRatioAC));
            end

            if excludeIrregularCycles %check if cycles are within the range of band and if not remove them
                pTcycleMid(diff(pTcycleMid)<minCycleSamples)=[];
                pTcycleNextMid=pTcycleMid(2:end);
                pTcycleMid=pTcycleMid(1:end-1);
            else
                pTcycleNextMid=pTcycleNextMid(2:end);
                pTcycleMid=pTcycleMid(1:end-1);
            end
            
            %calculate the middle state transition
            
            pTcycleOnset=zeros(numel(pTcycleMid),1);
            %edgesSamples=10;
            for i=1:numel(pTcycleMid)
                [~,pTmp]=min(HAng(pTcycleMid(i):pTcycleNextMid(i)));
                pTcycleOnset(i)=pTmp+pTcycleMid(i)-1;
            end
            pTcycleOffset=pTcycleOnset(2:end);
            pTcycleOnset=pTcycleOnset(1:end-1);
            pTcycleMid=pTcycleMid(2:end);
            
            ppRemove=(pTcycleOffset-pTcycleOnset)>maxCycleSamples;
            pTcycleOnset(ppRemove)=[];
            pTcycleMid(ppRemove)=[];
            pTcycleOffset(ppRemove)=[];

            TcycleMid=t_ms(pTcycleMid);
            TcycleOnset=t_ms(pTcycleOnset);
            TcycleOffset=t_ms(pTcycleOffset);
            
            %plot(t_ms/1000/60/60,HAng);hold on;plot(TcycleMid/1000/60/60,HAng(pTcycleMid),'or');plot(TcycleOffset/1000/60/60,HAng(pTcycleOffset),'og');plot(TcycleOnset/1000/60/60,HAng(pTcycleOnset),'.m');
            save(obj.files.slowCycles,'parSlowCycles','TcycleOnset','TcycleOffset','TcycleMid','pSleepDBRatio','t_ms','DBRatioMedFilt');
        end
        %{
         function data=getSlowCycles(obj,varargin)
            obj.checkFileRecording;
            
            parseObj = inputParser;
            addParameter(parseObj,'ch',obj.recTable.defaulLFPCh(obj.currentPRec),@isnumeric);
            addParameter(parseObj,'medianFiltWin',1000*20,@isnumeric);
            addParameter(parseObj,'longOrdFiltWin',1000*1000,@isnumeric);
            addParameter(parseObj,'longOrdFiltOrd',0.6,@isnumeric);
            addParameter(parseObj,'estimateFilterValuesFromPeriod',1,@isnumeric);
            addParameter(parseObj,'removeNonSignificatACSegments',0,@isnumeric);
            addParameter(parseObj,'excludeIrregularCycles',1,@isnumeric); %for excluding cycles which do not have a regular duration
            addParameter(parseObj,'overwrite',0,@isnumeric);
            
            addParameter(parseObj,'inputParams',false,@isnumeric);
            parseObj.parse(varargin{:});
            if parseObj.Results.inputParams
                disp(parseObj.Results);
                return;
            end
            
            %evaluate all input parameters in workspace
            for i=1:numel(parseObj.Parameters)
                eval([parseObj.Parameters{i} '=' 'parseObj.Results.(parseObj.Parameters{i});']);
            end
            
            %make parameter structure
            parSlowCycles=parseObj.Results;
            
            %check if analysis was already done done
            obj.files.slowCycles=[obj.currentAnalysisFolder filesep 'slowCycles_ch' num2str(ch) '.mat'];
            if exist(obj.files.slowCycles,'file') & ~overwrite
                if nargout==1
                    data=load(obj.files.slowCycles);
                else
                    disp('Slow cycle analysis already exists for this recording');
                end
                return;
            end
            
            dbRatioFile=[obj.currentAnalysisFolder filesep 'dbRatio_ch' num2str(ch) '.mat'];
            obj.checkFileRecording(dbRatioFile,'Delta to beta analysis missing, please first run getDelta2BetaRatio');
            load(dbRatioFile,'t_ms','bufferedDelta2BetaRatio','parDBRatio'); %load data  
            
            dbAutocorrFile=[obj.currentAnalysisFolder filesep 'dbAutocorr_ch' num2str(ch) '.mat'];
            obj.checkFileRecording(dbAutocorrFile,'Delta to beta autocorr analysis missing, please first run getDelta2BetaAC');
            load(dbAutocorrFile,'pSleepDBRatio','period','pSleepSlidingAC','pSleepDBRatioAC'); %load data
                
            timeBin=(parDBRatio.movWin-parDBRatio.movOLWin);
            bufferedDelta2BetaRatio(isnan(bufferedDelta2BetaRatio))=0;
            
            %calculate filter values based on oscillation period
            band=1.5;
            if estimateFilterValuesFromPeriod
                medianFiltWin=round(period*0.25);
                maxCycleSamples=round((period*band)/timeBin);
                minCycleSamples=round(period/band/timeBin);
            else
                maxCycleSamples=round(140/timeBin);
                minCycleSamples=round(10/timeBin);
            end
            
            %smooth with median filter
            medianFiltSamples=medianFiltWin/timeBin;
            DBRatioMedFilt = fastmedfilt1d(bufferedDelta2BetaRatio, medianFiltSamples);

            %plot(t_ms/1000/60/60,DBRatioMedFilt);hold on;plot(t_ms/1000/60/60,DBLongOrdFilt);

            Th=[];
            hilbertPhaseCycleAnalysis=1;
            if hilbertPhaseCycleAnalysis
                HAng=phase(hilbert(DBRatioMedFilt));
                %the peaks in this analysis are the end of the delta period and the troughs are the
                [cycleOnsetPeaks,pTcycleOnset]=findpeaks(HAng,'MinPeakProminence',pi/8,'MinPeakDistance',minCycleSamples,'MinPeakHeight',0,'MinPeakWidth',minCycleSamples/4);
                cycleOnset=t_ms(pTcycleOnset);
                %
                %{
                    h(1)=subplot(2,1,1);plot(t_ms/1000/60/60,DBRatioMedFilt);
                    h(2)=subplot(2,1,2);plot(t_ms/1000/60/60,HAng);hold on;plot(cycleOnset/1000/60/60,cycleOnsetPeaks,'or');
                    linkaxes(h,'x');
                %}
            else
                edgeSamples=100;
                %long order filter to determine edges of DB fluctuation
                longOrdFiltSamples=round(longOrdFiltWin/timeBin);
                longOrdFiltOrdSamples=round(longOrdFiltOrd*longOrdFiltSamples);
                DBLongOrdFilt = ordfilt2(DBRatioMedFilt, longOrdFiltOrdSamples, ones(longOrdFiltSamples,1));
                sortDBLongOrdFilt=sort(DBLongOrdFilt);
                sortDBLongOrdFilt(isnan(sortDBLongOrdFilt))=[];
                Th=mean(sortDBLongOrdFilt(1:edgeSamples))+(mean(sortDBLongOrdFilt((end-edgeSamples):end))-mean(sortDBLongOrdFilt(1:edgeSamples)))/2;
                %Th=min(DBLongOrdFilt)+(max(DBLongOrdFilt)-min(DBLongOrdFilt))/2;
                pTcycleOnset=find((DBRatioMedFilt(2:end)>=Th & DBRatioMedFilt(1:end-1)<Th) & pSleepDBRatio(1:end-1));
            end
            %tSlidingAC
            removeNonSleepSegments=1;
            if removeNonSleepSegments
                %pTcycleOnset is places in t_ms
                pTcycleOnset=intersect(pTcycleOnset,find(pSleepDBRatio));
            end
            
            if removeNonSignificatACSegments
                pTcycleOnset=intersect(pTcycleOnset,find(pSleepDBRatioAC));
            end

            if excludeIrregularCycles %check if cycles are within the range of band and if not remove them
                pTcycleOnset(diff(pTcycleOnset)<minCycleSamples)=[];
                pTcycleOffset=pTcycleOnset(2:end);
                pTcycleOnset=pTcycleOnset(1:end-1);
                ppRemove=(pTcycleOffset-pTcycleOnset)>maxCycleSamples;
                pTcycleOffset(ppRemove)=[];
                pTcycleOnset(ppRemove)=[];
            else
                pTcycleOffset=pTcycleOnset(2:end);
                pTcycleOnset=pTcycleOnset(1:end-1);
            end
            
            %calculate the middle state transition
            
            pTcycleMid=zeros(numel(pTcycleOnset),1);
            %edgesSamples=10;
            for i=1:numel(pTcycleOnset)
                [~,pTmp]=min(HAng(pTcycleOnset(i):pTcycleOffset(i)));
                pTcycleMid(i)=pTmp+pTcycleOnset(i)-1;
            %    pTmp=find(DBRatioMedFilt((pTcycleOnset(i)+edgesSamples):(pTcycleOffset(i)-edgesSamples))<Th,1,'first');
            %    if ~isempty(pTmp)
            %        pTcycleMid(i)=pTmp;
            %    end
            end
            TcycleMid=t_ms(pTcycleMid);
            TcycleOnset=t_ms(pTcycleOnset);
            TcycleOffset=t_ms(pTcycleOffset);
            %switch between onset/offset and mid to adhere to previous function.
            %tmp=TcycleOffset;
            %TcycleOnset=TcycleMid(1:end-1);
            %TcycleOffset=TcycleMid(2:end);
            %TcycleMid=tmp(1:end-1);
            
            %plot(t_ms/1000/60/60,HAng);hold on;plot(TcycleMid/1000/60/60,HAng(pTcycleMid),'or');plot(TcycleOnset/1000/60/60,HAng(pTcycleOnset),'og');
            save(obj.files.slowCycles,'parSlowCycles','TcycleOnset','TcycleOffset','TcycleMid','pSleepDBRatio','t_ms','DBRatioMedFilt','Th');
         end
        %}
        %% plotDelta2BetaRatio
        function [h]=plotSlowCycles(obj,varargin)
            
            parseObj = inputParser;
            addParameter(parseObj,'ch',obj.recTable.defaulLFPCh(obj.currentPRec),@isnumeric);
            addParameter(parseObj,'saveFigures',1,@isnumeric);
            addParameter(parseObj,'h',0,@ishandle);
            addParameter(parseObj,'printLocalCopy',0,@isnumeric);
            addParameter(parseObj,'inputParams',false,@isnumeric);
            parseObj.parse(varargin{:});
            if parseObj.Results.inputParams
                disp(parseObj.Results);
                return;
            end
            
            %evaluate all input parameters in workspace
            for i=1:numel(parseObj.Parameters)
                eval([parseObj.Parameters{i} '=' 'parseObj.Results.(parseObj.Parameters{i});']);
            end
            
            slowCyclesFile=[obj.currentAnalysisFolder filesep 'slowCycles_ch' num2str(ch) '.mat'];
            dbRatioFile=[obj.currentAnalysisFolder filesep 'dbRatio_ch' num2str(ch) '.mat'];
            
            obj.checkFileRecording(slowCyclesFile,'Delta to beta analysis missing, please first run getSlowCycles');
            obj.checkFileRecording(dbRatioFile,'Delta to beta analysis missing, please first run getDBRatio');
            load(slowCyclesFile); %load data
            load(dbRatioFile); %load data

            
            if h==0
                f=figure('Position',[200 200 900 500]);
                h(1)=subaxis(7,1,1,'S',0.01);
                h(2)=subaxis(7,1,2,'S',0.01);
                h(3)=subaxis(7,1,1,3,1,5,'S',0.01);
            else
                saveFigures=0;
            end
            
            %'parSlowCycles','TcycleOnset','TcycleOffset','TcycleMid','pSleep'
            
            axes(h(1));
            plot(t_ms(pSleepDBRatio')/1000/60/60,ones(1,numel(find(pSleepDBRatio))),'.k','MarkerSize',10);hold on;
            ylim([0 1]);
            axis off;
            l=legend('sleep');
            l.Box='off';l.Location='northeastoutside';l.Position=[0.8881    0.8805    0.1015    0.0979];
            
            axes(h(2));
            plot(TcycleOnset/1000/60/60,ones(1,numel(TcycleOnset)),'.b','MarkerSize',10);ylim([-1 2]);hold on;
            plot(TcycleOffset/1000/60/60,ones(1,numel(TcycleOffset)),'or','MarkerSize',10);ylim([-1 2]);
            plot(TcycleMid/1000/60/60,ones(1,numel(TcycleOffset)),'.g','MarkerSize',10);ylim([-1 2]);
            l=legend('onset','offset','middle');
            ylim([0.5 1.5]);
            axis off;
            l.Box='off';l.Location='northeastoutside';l.Position=[0.8881    0.6787    0.1015    0.0979];
            
            axes(h(3));
            plot(t_ms/1000/60/60,bufferedDelta2BetaRatio);hold on;
            plot(t_ms/1000/60/60,DBRatioMedFilt);
            if ~isempty(Th)
                plot(t_ms([1 end])/1000/60/60,[Th Th]);
            end
            ylabel('\delta/\beta ratio');
            xlabel('Time [h]');
            
            linkaxes(h,'x');
            
            if saveFigures
                set(f,'PaperPositionMode','auto');
                fileName=[obj.currentPlotFolder filesep 'slowCycles_ch' num2str(ch)];
                print(fileName,'-djpeg',['-r' num2str(obj.figResJPG)]);
                if printLocalCopy
                    fileName=[cd filesep obj.recTable.Animal{obj.currentPRec} '_Rec' num2str(obj.currentPRec) '_slowCycles_ch' num2str(ch)];
                    print(fileName,'-djpeg',['-r' num2str(obj.figResJPG)]);
                end
            end
        end
        
        %% getSharpWaves
        function [data]=getSharpWavesAnalysis(obj,varargin)
            
            obj.checkFileRecording;
            
            parseObj = inputParser;
            addParameter(parseObj,'ch',obj.recTable.defaulLFPCh(obj.currentPRec),@isnumeric);
            addParameter(parseObj,'preSW',1000,@isnumeric);
            addParameter(parseObj,'winSW',2500,@isnumeric);
            addParameter(parseObj,'overwrite',0,@isnumeric);
                    
            addParameter(parseObj,'inputParams',false,@isnumeric);
            parseObj.parse(varargin{:});
            if parseObj.Results.inputParams
                disp(parseObj.Results);
                return;
            end
            
            %evaluate all input parameters in workspace
            for i=1:numel(parseObj.Parameters)
                eval([parseObj.Parameters{i} '=' 'parseObj.Results.(parseObj.Parameters{i});']);
            end
            
            %make parameter structure
            parSharpWavesAnalysis=parseObj.Results;

            %check if analysis was already done
            obj.files.sharpWaveAnalysis=[obj.currentAnalysisFolder filesep 'sharpWavesAnalysis_ch' num2str(ch) '.mat'];
            if exist(obj.files.sharpWaveAnalysis,'file') & ~overwrite
                if nargout==1
                    data=load(obj.files.sharpWaveAnalysis);
                else
                    disp('Sharp wave analysis already exists for this recording');
                end
                return;
            end
            
            sharpWavesFile=[obj.currentAnalysisFolder filesep 'sharpWaves_ch' num2str(ch) '.mat'];
            obj.checkFileRecording(sharpWavesFile,'Sharp wave file missing, please run getSharpWaves');
            load(sharpWavesFile);
            
            %determine new length based on downsampling factor
            winSW=ceil(winSW/obj.filt.DS4Hz.downSamplingFactor)*obj.filt.DS4Hz.downSamplingFactor;
            
            nSW=min(1000,numel(tSW));
            [allRaw,tRaw]=obj.currentDataObj.getData(ch,tSW(1:nSW)-preSW,winSW);
            [allDS4Hz,tDS4Hz]=obj.filt.DS4Hz.getFilteredData(allRaw);
            [allFHR,tFHR]=obj.filt.FHR.getFilteredData(allRaw);
            
            allSWAbsAI=squeeze(mean(abs(reshape(permute(allFHR,[3,1,2]),[obj.filt.DS4Hz.downSamplingFactor  size(allFHR,3)/obj.filt.DS4Hz.downSamplingFactor nSW])),1))';
            meanProfiles.mSWAbsAI=mean(allSWAbsAI);
            meanProfiles.mSWAbsHP=squeeze(mean(abs(allFHR),2));
            meanProfiles.mSWRaw=squeeze(mean(allRaw,2));
            meanProfiles.mSWLP=squeeze(mean(allDS4Hz,2));
            meanProfiles.tSWAbsAI=tDS4Hz;
            meanProfiles.tSWAbsHP=tFHR;
            meanProfiles.tSWRaw=tRaw;
            meanProfiles.tSWLP=tDS4Hz;
            
            %polar((1:numel(mSWLP))/numel(mSWLP)*2*pi,mSWLP'/max(abs(mSWLP)),'b');hold on;
            %polar((1:numel(mSWAbsAI))/numel(mSWAbsAI)*2*pi,mSWAbsAI/max(mSWAbsAI),'r');
            
            %{
            FAall=zeros(size(FAtmp));
            FAallLog=zeros(size(FAtmp));
            for i=1:500
                fprintf('%d ',i);
                [~,~,~,FAtmp]=spectrogram(squeeze(allSW(1,i,:))',2^13,round(0.9*(2^13)),2^13,obj.filt.FHR.samplingFrequency);
                FAall=FAtmp/500+FAall;
                FAallLog=10*log10(FAtmp)/500+FAallLog;
            end
            imagesc(10*log10(FAall));
            imagesc(flipud(FAallLog));
            %}
            save(obj.files.sharpWaveAnalysis,'allSWAbsAI','meanProfiles','parSharpWavesAnalysis');
        end
        
        
        %% plotDelta2BetaRatio
        function [h]=plotSharpWavesAnalysis(obj,varargin)
            
            parseObj = inputParser;
            addParameter(parseObj,'ch',obj.recTable.defaulLFPCh(obj.currentPRec),@isnumeric);
            addParameter(parseObj,'saveFigures',1,@isnumeric);
            addParameter(parseObj,'h',0,@ishandle);
            addParameter(parseObj,'printLocalCopy',0,@isnumeric);
            addParameter(parseObj,'inputParams',false,@isnumeric);
            parseObj.parse(varargin{:});
            if parseObj.Results.inputParams
                disp(parseObj.Results);
                return;
            end
            
            %evaluate all input parameters in workspace
            for i=1:numel(parseObj.Parameters)
                eval([parseObj.Parameters{i} '=' 'parseObj.Results.(parseObj.Parameters{i});']);
            end
            
            sharpWaveAnalysisFile=[obj.currentAnalysisFolder filesep 'sharpWavesAnalysis_ch' num2str(ch) '.mat'];
            obj.checkFileRecording(sharpWaveAnalysisFile,'Delta to beta analysis missing, please first run getSharpWaveAnalysis');
            load(sharpWaveAnalysisFile); %load data
            
            if h==0
                f=figure('Position',[100 100 500 900]);
                h(1)=subaxis(f,2,1,1,'S',0.01,'ML',0.15);
                h(2)=subaxis(f,2,1,2,'S',0.01,'ML',0.15);
            else
                saveFigures=0;
            end
            
            plot(meanProfiles.tSWAbsHP,meanProfiles.mSWAbsHP,'Parent',h(1));
            ylabel('High pass amp','Parent',h(1));
            set(h(1),'XTickLabel',[]);
            plot(meanProfiles.tSWLP,meanProfiles.mSWLP,'r','Parent',h(2));
            ylabel('LFP [\muV]','Parent',h(2));
            xlabel('Time [ms]','Parent',h(2));
            
            linkaxes(h,'x');
            axis tight;

            if saveFigures
                set(f,'PaperPositionMode','auto');
                fileName=[obj.currentPlotFolder filesep 'sharpWaveAnalysis_ch' num2str(ch)];
                print(fileName,'-djpeg',['-r' num2str(obj.figResJPG)]);
                if printLocalCopy
                    fileName=[cd filesep obj.recTable.Animal{obj.currentPRec} '_Rec' num2str(obj.currentPRec) '_sharpWaveAnalysis_ch' num2str(ch)];
                    print(fileName,'-djpeg',['-r' num2str(obj.figResJPG)]);
                end
            end
        end
        
        
        %% getSharpWaves
        function data=getSharpWaves(obj,varargin)
            
            obj.checkFileRecording;

            parseObj = inputParser;
            addParameter(parseObj,'ch',obj.recTable.defaulLFPCh(obj.currentPRec),@isnumeric);
            addParameter(parseObj,'nTestSegments',20,@isnumeric);
            addParameter(parseObj,'minPeakWidth',200,@isnumeric);
            addParameter(parseObj,'minPeakInterval',1000,@isnumeric);
            addParameter(parseObj,'crossCorrAmp',0.1,@isnumeric);
            addParameter(parseObj,'crossCorrProminence',0.2,@isnumeric);
            addParameter(parseObj,'detectOnlyDuringSWS',true);
            addParameter(parseObj,'preTemplate',500,@isnumeric);
            addParameter(parseObj,'winTemplate',1500,@isnumeric);
            addParameter(parseObj,'resultsFileName',[],@isstr);
            addParameter(parseObj,'percentile4ScaleEstimation',5,@isnumeric);
            addParameter(parseObj,'startEnds',[],@isnumeric);
            addParameter(parseObj,'overwrite',0,@isnumeric);
            addParameter(parseObj,'inputParams',false,@isnumeric);
            parseObj.parse(varargin{:});
            if parseObj.Results.inputParams
                disp(parseObj.Results);
                return;
            end
            
            %evaluate all input parameters in workspace
            for i=1:numel(parseObj.Parameters)
                eval([parseObj.Parameters{i} '=' 'parseObj.Results.(parseObj.Parameters{i});']);
            end
            
            %make parameter structure
            parSharpWaves=parseObj.Results;
            
            %check if analysis was already done
            if isempty(resultsFileName)
                obj.files.sharpWaves=[obj.currentAnalysisFolder filesep 'sharpWaves_ch' num2str(ch) '.mat'];
            else
                obj.files.sharpWaves=[resultsFileName '.mat'];
            end
            if exist(obj.files.sharpWaves,'file') & ~overwrite
                if nargout==1
                    data=load(obj.files.sharpWaves);
                else
                    disp('Sharp wave analysis already exists for this recording');
                end
                return;
            end

            slowCyclesFile=[obj.currentAnalysisFolder filesep 'slowCycles_ch' num2str(ch) '.mat'];

            obj.checkFileRecording(slowCyclesFile,'slow cycle analysis missing, please first run getSlowCycles');
            load(slowCyclesFile); %load data
            obj.getFilters;
            nCycles=numel(TcycleOnset);
            if ~isempty(startEnds)
                %Not written yet - for awake states, selection needs to be done.
            else
                if nCycles<nTestSegments
                    fprintf('The number of cycles is very low (%d)! changing the number of tested segments to be the same\n',nCycles);
                    nTestSegments=nCycles;
                end
                pCycle=sort(randperm(nCycles,nTestSegments));
            end
            
            Mtest=cell(nTestSegments,1);
            tTest=cell(nTestSegments,1);
            for i=1:numel(pCycle)
                MTmp=obj.currentDataObj.getData(ch,TcycleOnset(pCycle(i)),TcycleMid(pCycle(i))-TcycleOnset(pCycle(i)));
                [Mtest{i},tTest{i}]=obj.filt.DS4Hz.getFilteredData(MTmp);
                tTest{i}=tTest{i}'+TcycleOnset(pCycle(i));
                Mtest{i}=squeeze(Mtest{i});
            end
            Mtest=cell2mat(Mtest);
            tTest=cell2mat(tTest);

            sortedMtest=sort(Mtest);
            scaleEstimator=sortedMtest(round(percentile4ScaleEstimation/100*numel(sortedMtest)));
            tmpFs=obj.filt.DS4Hz.filteredSamplingFrequency;
            
            [peakVal,peakTime,peakWidth,peakProminance]=findpeaks(-Mtest,...
                'MinPeakHeight',-scaleEstimator,'MinPeakDistance',minPeakInterval/1000*tmpFs,'MinPeakProminence',-scaleEstimator/2,'MinPeakWidth',minPeakWidth/1000*tmpFs,'WidthReference','halfprom');
            
            [allSW,tSW]=obj.currentDataObj.getData(ch,tTest(peakTime)-preTemplate,winTemplate);
            [FLallSW,tFLallSW]=obj.filt.DS4Hz.getFilteredData(allSW);
            
            template=squeeze(median(FLallSW,2));
            nTemplate=numel(template);
            ccEdge=floor(nTemplate/2);
            [~,pTemplatePeak]=min(template);
            peakLagSamples=ccEdge-pTemplatePeak;
            
            if detectOnlyDuringSWS
                TOn=TcycleOnset;
                TWin=TcycleMid-TcycleOnset;
            else
                seg=60000;
                TOn=0:seg:(obj.currentDataObj.recordingDuration_ms-seg);
                TWin=seg*ones(1,numel(TOn));
                nCycles=numel(TOn);
            end
            fprintf('Detecting sharp waves on section (/%d): ',nCycles);
            if isempty(startEnds)
                absolutePeakTimes=cell(nCycles,1);
                for i=1:nCycles
                    fprintf([repmat('\b',[1 strlength(num2str(i-1))]),'%d'],i);
                    [tmpM,tmpT]=obj.currentDataObj.getData(ch,TOn(i),TWin(i));
                    [tmpFM,tmpFT]=obj.filt.DS4Hz.getFilteredData(tmpM);
                    
                    [C]=xcorrmat(squeeze(tmpFM),template);
                    C=C(numel(tmpFM)-ccEdge:end-ccEdge);
                    %C=xcorr(squeeze(tmpFM),template,'coeff');
                    
                    [~,peakTime]=findpeaks(C,'MinPeakHeight',crossCorrAmp,'MinPeakProminence',crossCorrProminence,'WidthReference','halfprom');
                    peakTime(peakTime<=pTemplatePeak)=[]; %remove peaks at the edges where templates is not complete
                    absolutePeakTimes{i}=tmpFT(peakTime-peakLagSamples)'+TOn(i);
                    
                    %{
                        h(1)=subplot(3,1,1);plot(tmpFT,squeeze(tmpFM));hold on;plot(absolutePeakTimes{i}-TOn(i),zeros(1,numel(absolutePeakTimes{i})),'or');
                        h(2)=subplot(3,1,2);plot(1:numel(tmpFM),squeeze(tmpFM));hold on;plot(peakTime-peakLagSamples,zeros(1,numel(peakTime)),'or');
                        h(3)=subplot(3,1,3);plot((1:numel(C)),C);hold on;plot(peakTime,zeros(numel(peakTime),1),'or');linkaxes(h(2:3),'x');
                    %}
                end
                tSW=cell2mat(absolutePeakTimes);
            else
                
                nCycles=size(startEnds,2);
                absolutePeakTimes=cell(nCycles);
                for i=1:nCycles
                    fprintf([repmat('\b',[1 strlength(num2str(i-1))]),'%d'],i);
                    [tmpM,tmpT]=obj.currentDataObj.getData(ch,startEnds(1,i),startEnds(2,i)-startEnds(1,i));
                    [tmpFM,tmpFT]=obj.filt.DS4Hz.getFilteredData(tmpM);
                    
                    [C]=xcorrmat(squeeze(tmpFM),template);
                    C=C(numel(tmpFM)-ccEdge:end-ccEdge);
                    %C=xcorr(squeeze(tmpFM),template,'coeff');
                    
                    [~,peakTime]=findpeaks(C,'MinPeakHeight',0.1,'MinPeakProminence',0.2,'WidthReference','halfprom');
                    peakTime(peakTime<=pTemplatePeak)=[]; %remove peaks at the edges where templates is not complete
                    absolutePeakTimes{i}=tmpFT(peakTime-pTemplatePeak)'+startEnds(1,i);
                end
            end
            tSW=cell2mat(absolutePeakTimes);
            fprintf('Done!\n');
            save(obj.files.sharpWaves,'tSW','parSharpWaves');
        end
        
        %% plotDelta2BetaRatio
        function [h]=plotDelta2BetaRatio(obj,varargin)
            
            parseObj = inputParser;
            addParameter(parseObj,'ch',obj.recTable.defaulLFPCh(obj.currentPRec),@isnumeric);
            addParameter(parseObj,'tStart',0,@isnumeric);
            addParameter(parseObj,'win',obj.currentDataObj.recordingDuration_ms,@isnumeric);
            addParameter(parseObj,'saveFigures',1,@isnumeric);
            addParameter(parseObj,'chunksLength',1000*60*30,@isnumeric);
            addParameter(parseObj,'h',0,@ishandle);
            addParameter(parseObj,'printLocalCopy',0,@isnumeric);
            addParameter(parseObj,'inputParams',false,@isnumeric);
            parseObj.parse(varargin{:});
            if parseObj.Results.inputParams
                disp(parseObj.Results);
                return;
            end
            
            %evaluate all input parameters in workspace
            for i=1:numel(parseObj.Parameters)
                eval([parseObj.Parameters{i} '=' 'parseObj.Results.(parseObj.Parameters{i});']);
            end
            
            dbRatioFile=[obj.currentAnalysisFolder filesep 'dbRatio_ch' num2str(ch) '.mat'];
            obj.checkFileRecording(dbRatioFile,'Delta to beta analysis missing, please first run getDelta2BetaRatio');
            load(dbRatioFile); %load data
            
            if win+tStart>obj.currentDataObj.recordingDuration_ms, win=obj.currentDataObj.recordingDuration_ms-tStart; end
               
            pt=find(t_ms>tStart & t_ms<=(tStart+win));
            timeBin=(parDBRatio.movWin-parDBRatio.movOLWin);
            nSamples=numel(bufferedDelta2BetaRatio(pt));
            
            movWinSamples=round(chunksLength/timeBin);
            chunks=buffer(bufferedDelta2BetaRatio(pt),movWinSamples);
            tLong=t_ms(round(movWinSamples/2):movWinSamples:nSamples)/1000/60/60;
            
            sortedBetaRatio=sort(bufferedDelta2BetaRatio(~isnan(bufferedDelta2BetaRatio)));
            estimateColorMapMax=round(sortedBetaRatio(round(numel(sortedBetaRatio)*0.95))/100)*100;
            
            if h==0
                fDB=figure('Position',[100 100 900 500]);
                h=axes;
            else
                saveFigures=0;
                axes(h);
            end
            
            imagesc((1:size(chunks,1))*timeBin/1000/60,tLong,chunks',[0 estimateColorMapMax]);
            xlabel('Time [min]');ylabel('Time [hour]');
            
            h(2)=colorbar;
            set(h(2),'position',[0.9115    0.7040    0.0129    0.2220]);
            ylabel(h(2),'\delta/\beta');
            
            if saveFigures
                set(fDB,'PaperPositionMode','auto');
                fileName=[obj.currentPlotFolder filesep 'dbRatio_ch' num2str(ch)];
                print(fileName,'-djpeg',['-r' num2str(obj.figResJPG)]);
                if printLocalCopy
                    fileName=[cd filesep obj.recTable.Animal{obj.currentPRec} '_Rec' num2str(obj.currentPRec) '_dbRatio_ch' num2str(ch)];
                    print(fileName,'-djpeg',['-r' num2str(obj.figResJPG)]);
                end
            end
        end
        
        %% plotDelta2BetaAC
        function h=plotDelta2BetaAC(obj,varargin)
            %sleepAnalysis.getDelta2BetaAC - input parameters: 
            parseObj = inputParser;
            parseObj.FunctionName='sleepAnalysis\plotDelta2BetaAC';
            addParameter(parseObj,'ch',obj.recTable.defaulLFPCh(obj.currentPRec),@isnumeric);
            addParameter(parseObj,'saveFigures',1,@isnumeric);
            addParameter(parseObj,'printLocalCopy',0,@isnumeric);
            addParameter(parseObj,'h',0,@ishandle);
            
            addParameter(parseObj,'inputParams',false,@isnumeric);
            parseObj.parse(varargin{:});
            if parseObj.Results.inputParams
                disp(parseObj.Results);
                return;
            end
            
            %evaluate all input parameters in workspace
            for i=1:numel(parseObj.Parameters)
                eval([parseObj.Parameters{i} '=' 'parseObj.Results.(parseObj.Parameters{i});']);
            end
            
            dbAutocorrFile=[obj.currentAnalysisFolder filesep 'dbAutocorr_ch' num2str(ch) '.mat'];
            obj.checkFileRecording(dbAutocorrFile,'Autocorr analysis missing, please first run getDelta2BetaAC');
            load(dbAutocorrFile);

            if h==0
                fAC=figure;
                h=axes;
            else
                saveFigures=0;
                axes(h);
            end
            
            lineHandles = stem(xcf_lags/1000,real(xcf),'filled','r-o');
            set(lineHandles(1),'MarkerSize',4);
            grid('on');
            xlabel('Period [s]');
            ylabel('Auto corr.');
            hold('on');
            
            plot(period/1000,real(xcf(pPeriod)),'o','MarkerSize',5,'color','k');
            
            a = axis;
            plot([a(1) a(1); a(2) a(2)],[xcf_bounds([1 1]) xcf_bounds([2 2])],'-b');
            plot([a(1) a(2)],[0 0],'-k');
            hold('off');
            
            if saveFigures
                set(fAC,'PaperPositionMode','auto');
                fileName=[obj.currentPlotFolder filesep 'dbAC_ch' num2str(parDbAutocorr.ch) '_t' num2str(parDbAutocorr.tStart) '_w' num2str(parDbAutocorr.win)];
                print(fileName,'-djpeg',['-r' num2str(obj.figResJPG)]);
                if printLocalCopy
                    fileName=[cd filesep obj.recTable.Animal{obj.currentPRec} '_Rec' num2str(obj.currentPRec) '_dbAC_ch' num2str(parDbAutocorr.ch) '_t' num2str(parDbAutocorr.tStart) '_w' num2str(parDbAutocorr.win)];
                    print(fileName,'-djpeg',['-r' num2str(obj.figResJPG)]);
                end
            end
            
        end
      
        %% plotDelta2BetaSlidingAC
        function h=plotDelta2BetaSlidingAC(obj,varargin)
            %sleepAnalysis.plotDelta2BetaSlidingAC - input parameters: 
            parseObj = inputParser;
            parseObj.FunctionName='sleepAnalysis\plotDelta2BetaSlidingAC';
            addParameter(parseObj,'ch',obj.recTable.defaulLFPCh(obj.currentPRec),@isnumeric);
            addParameter(parseObj,'tStart',0,@isnumeric);
            addParameter(parseObj,'win',obj.currentDataObj.recordingDuration_ms,@isnumeric);
            addParameter(parseObj,'saveFigures',1,@isnumeric);
            addParameter(parseObj,'printLocalCopy',0,@isnumeric);
            addParameter(parseObj,'h',0);
            
            addParameter(parseObj,'inputParams',false,@isnumeric);
            parseObj.parse(varargin{:});
            if parseObj.Results.inputParams
                disp(parseObj.Results);
                return;
            end
            
            %evaluate all input parameters in workspace
            for i=1:numel(parseObj.Parameters)
                eval([parseObj.Parameters{i} '=' 'parseObj.Results.(parseObj.Parameters{i});']);
            end
            
            dbAutocorrFile=[obj.currentAnalysisFolder filesep 'dbAutocorr_ch' num2str(ch) '.mat'];
            obj.checkFileRecording(dbAutocorrFile,'Autocorr analysis missing, please first run getDelta2BetaAC');
            load(dbAutocorrFile);
            
            if win+tStart>obj.currentDataObj.recordingDuration_ms, win=obj.currentDataObj.recordingDuration_ms-tStart; end
            pt=find(tSlidingAC>=tStart & tSlidingAC<=(tStart+win+parDbAutocorr.movingAutoCorrWin/2));
            tSlidingAC=tSlidingAC-tSlidingAC(pt(1));
            
            if h(1)==0
                fSAC=figure('position',[200 200 550 600]);
                h(1)=subaxis(fSAC,2,1,1,'S',0.05,'M',0.1);
                h(2)=subaxis(fSAC,2,1,2,'S',0.05,'M',0.1);
            else
                saveFigures=0;
            end
            
            axes(h(1));
            h(3)=imagesc(tSlidingAC(pt)/1000/60/60,autocorrTimes/1000,real(acf(:,pt)),[-0.5 0.5]);
            ylabel('Autocorr lag [s]');
            ylim(xcf_lags([1 end])/1000);%important for panel plots
            yl=ylim;
            xlim(tSlidingAC(pt([1 end]))/1000/60/60); %important for panel plots
            xl=xlim;
            set(h(1),'YDir','normal');
            set(h(1),'XTickLabel',[]);
            hold on;
            
            x=[(tStartSleep-tStart)/1000/60/60 (tEndSleep-tStart)/1000/60/60 (tEndSleep-tStart)/1000/60/60 (tStartSleep-tStart)/1000/60/60];
            W=0.03;
            y=yl(2)+W*[diff(yl) diff(yl) diff(yl)*3 diff(yl)*3];
            h(4)=patch(x,y,[0.2 0.2 0.2],'Clipping','off','lineStyle','none','FaceAlpha',0.5); 
            text((x(1)+x(2))/2,(y(1)+y(3))/2,'E-Sleep','HorizontalAlignment','center','VerticalAlignment','middle');
            h(7)=line(xlim,[period/1000 period/1000],'color',[1 0.8 0.8]);

            axes(h(2));
            
            h(5)=scatter(tSlidingAC(pSleepSlidingAC)/1000/60/60,acfPeriodAll(pSleepSlidingAC)/1000,5,[0.8 0.8 1],'filled');hold on;
            h(6)=plot((tFilteredSlidingPeriod-tStart)/1000/60/60,filteredSlidingPeriod/1000,'-','lineWidth',3);
            ylabel('Period [s]');
            xlabel('Time [h]');
            set(h(2),'Box','on');
            axis tight;
            xlim(xl);
            yl=ylim;
            marg=diff(yl)*0.02;
            ylim([yl(1)-marg,yl(2)+marg]);
            h(8:9)=line([parDbAutocorr.tStart parDbAutocorr.tStart;parDbAutocorr.tStart+parDbAutocorr.win parDbAutocorr.tStart+parDbAutocorr.win]'/1000/60/60,[yl;yl]','color',[0.8 1 0.8]);


            if saveFigures
                set(fSAC,'PaperPositionMode','auto');
                fileName=[obj.currentPlotFolder filesep 'dbSAC_ch' num2str(parDbAutocorr.ch) '_t' num2str(parDbAutocorr.tStart) '_w' num2str(parDbAutocorr.win)];
                print(fileName,'-djpeg',['-r' num2str(obj.figResJPG)]);
                if printLocalCopy
                    fileName=[cd filesep obj.recTable.Animal{obj.currentPRec} '_Rec' num2str(obj.currentPRec) '_dbSAC_ch' num2str(parDbAutocorr.ch) '_t' num2str(parDbAutocorr.tStart) '_w' num2str(parDbAutocorr.win)];
                    print(fileName,'-djpeg',['-r' num2str(obj.figResJPG)]);
                end
            end
        end
                
        %% getDelta2BetaAC
        function [data]=getDelta2BetaAC(obj,varargin)
            %sleepAnalysis.getDelta2BetaAC - input parameters: ch,tStart,win,movOLWin,XCFLag,movingAutoCorrWin,movingAutoCorrOL
            parseObj = inputParser;
            parseObj.FunctionName='sleepAnalysis\getDelta2BetaAC';
            addParameter(parseObj,'ch',obj.recTable.defaulLFPCh(obj.currentPRec),@isnumeric);
            addParameter(parseObj,'tStart',0,@isnumeric); 
            addParameter(parseObj,'win',obj.currentDataObj.recordingDuration_ms,@isnumeric);
            addParameter(parseObj,'maxPeriodBand',20,@isnumeric);
            addParameter(parseObj,'movOLWin',4000,@isnumeric);
            addParameter(parseObj,'XCFLag',500000,@isnumeric);
            addParameter(parseObj,'movingAutoCorrWin',1000*1000,@isnumeric);
            addParameter(parseObj,'movingAutoCorrOL',900*1000,@isnumeric);
            addParameter(parseObj,'oscilDurationMovingWin',60*60*1000,@isnumeric);
            addParameter(parseObj,'smoothingDuration',1000*60*60,@isnumeric);
            addParameter(parseObj,'oscilDurationThresh',0.25,@isnumeric);
            addParameter(parseObj,'overwrite',0,@isnumeric);
            
            addParameter(parseObj,'inputParams',false,@isnumeric);
            parseObj.parse(varargin{:});
            if parseObj.Results.inputParams
                disp(parseObj.Results);
                return;
            end
            
            %evaluate all input parameters in workspace
            for i=1:numel(parseObj.Parameters)
                eval([parseObj.Parameters{i} '=' 'parseObj.Results.(parseObj.Parameters{i});']);
            end
            
            %make parameter structure
            parDbAutocorr=parseObj.Results;
            
            %check if analysis was already done done
            obj.files.dbAutocorr=[obj.currentAnalysisFolder filesep 'dbAutocorr_ch' num2str(ch) '.mat'];
            if exist(obj.files.dbAutocorr,'file') & ~overwrite
                if nargout==1
                    data=load(obj.files.dbAutocorr);
                else
                    disp('Autocorr analysis already exists for this recording');
                end
                return;
            end
            
            dbRatioFile=[obj.currentAnalysisFolder filesep 'dbRatio_ch' num2str(ch) '.mat'];
            obj.checkFileRecording(dbRatioFile,'Delta to beta analysis missing, please first run getDelta2BetaRatio');
            load(dbRatioFile); %load data
            
            bufferedDelta2BetaRatio(isnan(bufferedDelta2BetaRatio))=0; %for cross-corr analysis nans result in imaginary values
            
            %cross correlation analysis
            pOscillation=find(t_ms>tStart & t_ms<(tStart+win));
            timeBin=(parDBRatio.movWin-parDBRatio.movOLWin);
            XCFLagSamples=XCFLag/timeBin;
            [xcf,xcf_lags,xcf_bounds]=crosscorr(bufferedDelta2BetaRatio(pOscillation),bufferedDelta2BetaRatio(pOscillation),XCFLagSamples);
            
            xcf_lags=xcf_lags*1000;
            %calculate periodicity
            
            %find first vally and peak in the autocorrelation function
            [~,pPeak] = findpeaks(xcf(XCFLagSamples+1:end),'MinPeakProminence',0.1);
            [~,pVally] = findpeaks(-xcf(XCFLagSamples+1:end),'MinPeakProminence',0.1);
            if isempty(pPeak) %if peak is weak, try a different value
                [~,pPeak] = findpeaks(xcf(XCFLagSamples+1:end),'MinPeakProminence',0.05);
                [~,pVally] = findpeaks(-xcf(XCFLagSamples+1:end),'MinPeakProminence',0.05);
                disp('Prominance for peak detection was reduced to 0.05 due to low periodicity values!!!');
            end
            
            
            
            if isempty(pPeak) | isempty(pVally)
                pPeriod=NaN;
                period=NaN;
                pVally=NaN;
                vallyPeriod=NaN;
                peak2VallyDiff=NaN;
                fprintf('\nCount not complete the run. No prominent oscillations detected in the data!!!\n');
                return;
            else
                pPeriod=pPeak(1)+XCFLagSamples;
                period=xcf_lags(pPeriod);
                pAntiPeriod=pVally(1)+XCFLagSamples;
                vallyPeriod=xcf_lags(pAntiPeriod);
                peak2VallyDiff=xcf(pPeriod)-xcf(pAntiPeriod);
            end
            
            %sliding autocorr analysis
            movingAutoCorrWinSamples=movingAutoCorrWin/timeBin;
            movingAutoCorrOLSamples=movingAutoCorrOL/timeBin;
            autoCorrTimeBin=(movingAutoCorrWin-movingAutoCorrOL);
            BetaRatioForSlidingAutocorr = buffer(bufferedDelta2BetaRatio,movingAutoCorrWinSamples,movingAutoCorrOLSamples,'nodelay');
            tSlidingAC=(movingAutoCorrWin/2):(movingAutoCorrWin-movingAutoCorrOL):(t_ms(end)-movingAutoCorrWin/2+movingAutoCorrWin-movingAutoCorrOL);
           
            %R=xcorrmat(BetaRatioForSlidingAutocorr,BetaRatioForSlidingAutocorr,autoCorrSamples);
            
            acfSamples=floor(movingAutoCorrWinSamples/2);
            acf=zeros(size(BetaRatioForSlidingAutocorr,1)+1,size(BetaRatioForSlidingAutocorr,2));
            peak2VallyDiffSliding=zeros(1,size(BetaRatioForSlidingAutocorr,2));
            for i=1:size(BetaRatioForSlidingAutocorr,2)
                [acf(:,i),autoCorrSamples] = crosscorr(BetaRatioForSlidingAutocorr(:,i),BetaRatioForSlidingAutocorr(:,i),acfSamples);
                %calculate peak2VallyDiff for different times
                acf(:,i)=smooth(acf(:,i),10,'moving');
                
                [acfPeakAll(i),acfPeriodAll(i)]=max(acf((acfSamples+pPeak(1)-maxPeriodBand):(acfSamples+pPeak(1)+maxPeriodBand),i));
                [acfVallyAll(i),acfAntiPeriodAll(i)]=min(acf((acfSamples+pVally(1)-maxPeriodBand):(acfSamples+pVally(1)+maxPeriodBand),i));
                peak2VallyDiffSliding(i)=acfPeakAll(i)-acfVallyAll(i);
                
                %{
                [~,pPeak] = findpeaks(acf(acfSamples+1:end,i),'MinPeakProminence',0.1);
                [~,pVally] = findpeaks(-acf(acfSamples+1:end,i),'MinPeakProminence',0.1);
                findpeaks(acf(acfSamples+1:end,i),'MinPeakProminence',0.1);
                disp([pPeak(1) pVally(1)])
                pause;
                
                if ~isempty(pPeak) & ~isempty(pVally)
                    pPeriodTmp=pPeak(1)+acfSamples;
                    pVally=pVally(1)+acfSamples;
                    peak2VallyDiff(i)=acf(pPeriodTmp,i)-acf(pVally,i);
                end
                %}
            end
            autocorrTimes=autoCorrSamples*timeBin;
            acfPeriodAll=autocorrTimes((acfPeriodAll+acfSamples+pPeak(1)-maxPeriodBand-1));
            
            oscilDurationMovingSamples=oscilDurationMovingWin/autoCorrTimeBin;
            tmpOscDuration=peak2VallyDiffSliding>oscilDurationThresh;
            filtOscilDuration = medfilt1(double(tmpOscDuration),oscilDurationMovingSamples);
            pSleepSlidingAC=filtOscilDuration>=0.5;
            
            tmpBin=movingAutoCorrWinSamples-movingAutoCorrOLSamples;
            pSleepDBRatio=false(numel(bufferedDelta2BetaRatio),1);
            for i=1:numel(pSleepSlidingAC)
                pSleepDBRatio(((i-1)*tmpBin+1):(i*tmpBin))=pSleepSlidingAC(i);
            end
            
            pStartSleep=find(pSleepDBRatio==1,1,'first');
            tStartSleep=t_ms(pStartSleep);
            tEndSleep=t_ms(find(pSleepDBRatio(pStartSleep:end)==1,1,'last')+pStartSleep);
            
            pSleepSlidingAC=find(tSlidingAC>=tStartSleep & tSlidingAC<=tEndSleep & peak2VallyDiffSliding>oscilDurationThresh);
            for i=1:numel(pSleepSlidingAC)
                pSleepDBRatioAC(((i-1)*tmpBin+1):(i*tmpBin))=pSleepSlidingAC(i);
            end
            
            smoothingSamples=round(smoothingDuration/autoCorrTimeBin);
            filteredSlidingPeriod=smooth(tSlidingAC(pSleepSlidingAC),acfPeriodAll(pSleepSlidingAC),smoothingSamples,'moving');
            edgeSamples=tSlidingAC(pSleepSlidingAC)<=(tSlidingAC(pSleepSlidingAC(1))+smoothingDuration/2) | tSlidingAC(pSleepSlidingAC)>=(tSlidingAC(pSleepSlidingAC(end))-smoothingDuration/2);
            filteredSlidingPeriod(edgeSamples)=[];
            tFilteredSlidingPeriod=tSlidingAC(pSleepSlidingAC(~edgeSamples))';
            
            %save data
            save(obj.files.dbAutocorr,'parDbAutocorr','xcf','xcf_lags','xcf_bounds','BetaRatioForSlidingAutocorr','autoCorrTimeBin','autocorrTimes','timeBin',...
                'pPeriod','period','acf','vallyPeriod','peak2VallyDiff','pSleepDBRatio','pSleepSlidingAC','acfPeakAll','acfVallyAll','peak2VallyDiffSliding','tSlidingAC','acfPeriodAll',...
                'tStartSleep','tEndSleep','filteredSlidingPeriod','tFilteredSlidingPeriod','pSleepSlidingAC','pSleepDBRatioAC');
        end

        
        %% plotRespirationSlidingAC
        function h=plotRespirationSlidingAC(obj,varargin)
            %sleepAnalysis.plotDelta2BetaSlidingAC - input parameters: 
            parseObj = inputParser;
            parseObj.FunctionName='sleepAnalysis\plotRespirationSlidingAC';
            addParameter(parseObj,'ch',obj.recTable.defaulLFPCh(obj.currentPRec),@isnumeric);
            addParameter(parseObj,'tStart',0,@isnumeric);
            addParameter(parseObj,'win',obj.currentDataObj.recordingDuration_ms,@isnumeric);
            addParameter(parseObj,'saveFigures',1,@isnumeric);
            addParameter(parseObj,'printLocalCopy',0,@isnumeric);
            addParameter(parseObj,'h',0);
            
            addParameter(parseObj,'inputParams',false,@isnumeric);
            parseObj.parse(varargin{:});
            if parseObj.Results.inputParams
                disp(parseObj.Results);
                return;
            end
            
            %evaluate all input parameters in workspace
            for i=1:numel(parseObj.Parameters)
                eval([parseObj.Parameters{i} '=' 'parseObj.Results.(parseObj.Parameters{i});']);
            end
            
            dbAutocorrFile=[obj.currentAnalysisFolder filesep 'dbAutocorr_ch' num2str(ch) '.mat'];
            obj.checkFileRecording(dbAutocorrFile,'Autocorr analysis missing, please first run getDelta2BetaAC');
            load(dbAutocorrFile);
            
            if win+tStart>obj.currentDataObj.recordingDuration_ms, win=obj.currentDataObj.recordingDuration_ms-tStart; end
            pt=find(tSlidingAC>=tStart & tSlidingAC<=(tStart+win+parDbAutocorr.movingAutoCorrWin/2));
            tSlidingAC=tSlidingAC-tSlidingAC(pt(1));
            
            respirationAutocorrFile=[obj.currentAnalysisFolder filesep 'getRespirationAC.mat'];
            obj.checkFileRecording(respirationAutocorrFile,'Autocorr analysis missing, please first run getRespirationAC');
            RAC=load(respirationAutocorrFile);
            
            if h(1)==0
                fSAC=figure('position',[200 200 550 600]);
                h(1)=subaxis(fSAC,2,1,1,'S',0.05,'M',0.1);
                h(2)=subaxis(fSAC,2,1,2,'S',0.05,'M',0.1);
            else
                saveFigures=0;
            end
            
            axes(h(1));
            h(3)=imagesc(tSlidingAC(pt)/1000/60/60,autocorrTimes/1000,real(acf(:,pt)),[-0.5 0.5]);
            ylabel('Autocorr lag [s]');
            ylim(xcf_lags([1 end])/1000);%important for panel plots
            yl=ylim;
            xlim(tSlidingAC(pt([1 end]))/1000/60/60); %important for panel plots
            xl=xlim;
            set(h(1),'YDir','normal');
            set(h(1),'XTickLabel',[]);
            hold on;
            
            x=[(tStartSleep-tStart)/1000/60/60 (tEndSleep-tStart)/1000/60/60 (tEndSleep-tStart)/1000/60/60 (tStartSleep-tStart)/1000/60/60];
            W=0.03;
            y=yl(2)+W*[diff(yl) diff(yl) diff(yl)*3 diff(yl)*3];
            h(4)=patch(x,y,[0.2 0.2 0.2],'Clipping','off','lineStyle','none','FaceAlpha',0.5); 
            text((x(1)+x(2))/2,(y(1)+y(3))/2,'E-Sleep','HorizontalAlignment','center','VerticalAlignment','middle');
            h(7)=line(xlim,[period/1000 period/1000],'color',[1 0.8 0.8]);

            axes(h(2));
            h(5)=scatter(RAC.tSlidingAC/1000/60/60,RAC.acfPeriodAll/1000,10,[0.8 0.8 1],'filled');hold on;
            h(6)=plot((RAC.tFilteredSlidingPeriod)/1000/60/60,RAC.filteredSlidingPeriod/1000,'-','lineWidth',3);
            ylabel('Period [s]');
            xlabel('Time [h]');
            set(h(2),'Box','on');
            axis tight;
            xlim(xl);
            yl=ylim;
            marg=diff(yl)*0.02;
            ylim([yl(1)-marg,yl(2)+marg]);
            %h(8:9)=line([parDbAutocorr.tStart parDbAutocorr.tStart;parDbAutocorr.tStart+parDbAutocorr.win parDbAutocorr.tStart+parDbAutocorr.win]'/1000/60/60,[yl;yl]','color',[0.8 1 0.8]);


            if saveFigures
                set(fSAC,'PaperPositionMode','auto');
                fileName=[obj.currentPlotFolder filesep 'respSAC_ch' num2str(parDbAutocorr.ch) '_t' num2str(parDbAutocorr.tStart) '_w' num2str(parDbAutocorr.win)];
                print(fileName,'-djpeg',['-r' num2str(obj.figResJPG)]);
                if printLocalCopy
                    fileName=[cd filesep obj.recTable.Animal{obj.currentPRec} '_Rec' num2str(obj.currentPRec) '_respSAC_ch' num2str(parDbAutocorr.ch) '_t' num2str(parDbAutocorr.tStart) '_w' num2str(parDbAutocorr.win)];
                    print(fileName,'-djpeg',['-r' num2str(obj.figResJPG)]);
                end
            end
        end
        
        %% getRespirationAC
        function [data]=getRespirationAC(obj,varargin)
            %sleepAnalysis.getRespirationAC - input parameters: ch,tStart,win,movOLWin,XCFLag,movingAutoCorrWin,movingAutoCorrOL
            parseObj = inputParser;
            parseObj.FunctionName='sleepAnalysis\getRespirationAC';
            addParameter(parseObj,'videoFile',[obj.recTable.VideoFiles{obj.currentPRec}],@(x) exist(x,'file'));
            addParameter(parseObj,'digitalVideoSyncCh',5,@isnumeric);
            addParameter(parseObj,'maxPeriodBand',1000,@isnumeric);%band width arround xcf peak to look for correlations [ms]
            addParameter(parseObj,'respResampleRate',5,@isnumeric); % the resampled respiration signal sampling freq for further analysis
            addParameter(parseObj,'movOLWin',400,@isnumeric);
            addParameter(parseObj,'XCFLag',20000,@isnumeric);
            addParameter(parseObj,'movingAutoCorrWin',40*1000,@isnumeric);
            addParameter(parseObj,'movingAutoCorrOL',36*1000,@isnumeric);
            addParameter(parseObj,'smoothingDuration',5*60*1000,@isnumeric);
            addParameter(parseObj,'respirationMedianFilterDuration',2*1000,@isnumeric);
            addParameter(parseObj,'pixelMoveThresh',10,@isnumeric);
            addParameter(parseObj,'nFramesRemoveAfterROIShift',5,@isnumeric);            
            addParameter(parseObj,'overwrite',0,@isnumeric);
            
            addParameter(parseObj,'inputParams',false,@isnumeric);
            parseObj.parse(varargin{:});
            if parseObj.Results.inputParams
                disp(parseObj.Results);
                return;
            end
            
            %evaluate all input parameters in workspace
            for i=1:numel(parseObj.Parameters)
                eval([parseObj.Parameters{i} '=' 'parseObj.Results.(parseObj.Parameters{i});']);
            end
            
            %make parameter structure
            parRespirationAutocorr=parseObj.Results;
            
            %check if analysis was already done done
            [~,videoFileName]=fileparts(videoFile);
            obj.files.respirationAutocorr=[obj.currentAnalysisFolder filesep 'respirationAC_' videoFileName '.mat'];
            if exist(obj.files.respirationAutocorr,'file') & ~overwrite
                if nargout==1
                    data=load(obj.files.respirationAutocorr);
                else
                    disp('Autocorr respiration analysis already exists for this recording');
                end
                return;
            end
                        
            chestTrackingFile=[obj.currentAnalysisFolder filesep 'chestTracking_' videoFileName '.mat'];
            obj.checkFileRecording(chestTrackingFile,'Chest tracking analysis missing, please first run getRespirationMovement');
            load(chestTrackingFile,'parChestTracking','nFramesVideo','pFrames','mAngle','pbboxUpdate','bboxCenterAll','allATrans'); %load data
            
            digiTrigFile=[obj.currentAnalysisFolder filesep 'getDigitalTriggers.mat'];
            obj.checkFileRecording(digiTrigFile,'digital trigger file missing, please first run getDigitalTriggers');
            load(digiTrigFile); %load data

            tFrames=tTrig{digitalVideoSyncCh};
            diffFrames=abs(numel(tFrames)-round(nFramesVideo));
            if diffFrames==0
                disp('Number of frames in video and in triggers is equal, proceeding with analysis');
            elseif diffFrames<50
                fprintf('\n\nNumber of frames in video and in triggers differs by %d, \nproceeding with analysis assuming uniform distribution of lost frames in video\n',diffFrames);
                tFrames(round((1:diffFrames)/diffFrames*numel(tFrames)))=[];
            else
                error(['Number of frames in video and in trigger (' num2str(digitalVideoSyncCh) ') differs by ' num2str(diffFrames) ', check recording!!!']);
            end
            
            %remove frames that are close to a ROI shift and frames with large shifts
            p2RemoveShifts=find(sqrt(diff(bboxCenterAll(:,1)).^2+diff(bboxCenterAll(:,2)).^2)>pixelMoveThresh/4)+1;
            p2RemoveShifts=union(p2RemoveShifts,pbboxUpdate);
            pFrames2Remove=zeros(1,numel(pFrames));
            pFrames2Remove(p2RemoveShifts)=1;
            pFrames2Remove=convn(pFrames2Remove,ones(1,nFramesRemoveAfterROIShift),'same');
            pFrames2Remove=find(pFrames2Remove);
            pFramesValid=pFrames;
            if ~isempty(pbboxUpdate) || ~isempty(pFrames2Remove)
                mAngle(pFrames2Remove)=[];
                pFramesValid(pFrames2Remove)=[];
                bboxCenterAll(pFrames2Remove,:)=[];
                allATrans(:,:,pFrames2Remove)=[];
            end
            
            useAffineTrasform=true;
            if useAffineTrasform
                tRespFrames=tFrames(pFramesValid);
            else %use optical flow
                tRespFrames=tFrames(pFramesValid(parChestTracking.skipBoundingBoxInSkip:parChestTracking.skipBoundingBoxInSkip:end));
            end
            
            %Choose best direction for movement
            [~,score] = pca(reshape(allATrans,[size(allATrans,1)*size(allATrans,2),size(allATrans,3)])','NumComponents',1);
            
            %cross correlation analysis
            %timeBin=mean(diff(tRespFrames));
            respResampleRate=5; %Hz
            timeBin=1/respResampleRate*1000;
            respirationMedianFilterBin=ceil(respirationMedianFilterDuration/timeBin);
            respirationSignal=medfilt1(score,respirationMedianFilterBin)';
            respirationSignal(1)=respirationSignal(2);
            

            [respirationSignal,tRespFrames]=resample(double(respirationSignal),tRespFrames,respResampleRate/1000);
            %respirationSignal=medfilt1(mAngle,respirationMedianFilterBin);            
            XCFLagSamples=ceil(XCFLag/timeBin);
            %[xcf,xcf_lags,xcf_bounds]=crosscorr(mAngle,mAngle,XCFLagSamples);
            [xcf,xcf_lags,xcf_bounds]=crosscorr(respirationSignal,respirationSignal,XCFLagSamples);
            xcf_lags=xcf_lags*1000;
            %calculate periodicity
            
            %find first vally and peak in the autocorrelation function
            [~,pPeak] = findpeaks(xcf(XCFLagSamples+1:end));pPeak=pPeak(1);
            [~,pVally] = findpeaks(-xcf(XCFLagSamples+1:end));pVally=pVally(1);
            
            if isempty(pPeak) | isempty(pVally)
                pPeriod=NaN;
                period=NaN;
                pVally=NaN;
                vallyPeriod=NaN;
                peak2VallyDiff=NaN;
                fprintf('\nCount not complete the run. No prominent respiration oscillations detected in the data!!!\n');
                return;
            else
                pPeriod=pPeak(1)+XCFLagSamples;
                period=xcf_lags(pPeriod);
                pAntiPeriod=pVally(1)+XCFLagSamples;
                vallyPeriod=xcf_lags(pAntiPeriod);
                peak2VallyDiff=xcf(pPeriod)-xcf(pAntiPeriod);
            end
            
            %sliding autocorr analysis
            movingAutoCorrWinSamples=ceil(movingAutoCorrWin/timeBin);
            movingAutoCorrOLSamples=ceil(movingAutoCorrOL/timeBin);
            step=(movingAutoCorrWin-movingAutoCorrOL);
            autoCorrTimeBin=(movingAutoCorrWin-movingAutoCorrOL);
            respirationForSlidingAutocorr = buffer(respirationSignal,movingAutoCorrWinSamples,movingAutoCorrOLSamples,'nodelay');
            tSlidingAC=tRespFrames(1)+movingAutoCorrWin/2+(1:size(respirationForSlidingAutocorr,2))*step;
           
            %R=xcorrmat(respirationForSlidingAutocorr,respirationForSlidingAutocorr,autoCorrSamples);
            maxPeriodBandSamples=ceil(maxPeriodBand/timeBin);
            acfSamples=floor(movingAutoCorrWinSamples/2);
            acf=zeros(size(respirationForSlidingAutocorr,1)+1,size(respirationForSlidingAutocorr,2));
            peak2VallyDiffAll=zeros(1,size(respirationForSlidingAutocorr,2));
            acfPeriodAll=zeros(1,size(respirationForSlidingAutocorr,2));
            for i=1:size(respirationForSlidingAutocorr,2)
                [acf(:,i),autoCorrSamples] = crosscorr(respirationForSlidingAutocorr(:,i),respirationForSlidingAutocorr(:,i),acfSamples);
                %calculate peak2VallyDiff for different times
                acf(:,i)=smooth(acf(:,i),10,'moving');
                
                [acfPeakAll(i),acfPeriodAll(i)]=max(acf((acfSamples+pPeak(1)-maxPeriodBandSamples):(acfSamples+pPeak(1)+maxPeriodBandSamples),i));
                [acfVallyAll(i),acfAntiPeriodAll(i)]=min(acf((acfSamples+pVally(1)-maxPeriodBandSamples):(acfSamples+pVally(1)+maxPeriodBandSamples),i));
                peak2VallyDiffAll(i)=acfPeakAll(i)-acfVallyAll(i);
            end
            autocorrTimes=xcf_lags;
            acfPeriodAll=autocorrTimes((acfPeriodAll+acfSamples+pPeak(1)-maxPeriodBandSamples-1));
            
            smoothingSamples=round(smoothingDuration/autoCorrTimeBin);
            filteredSlidingPeriod=smooth(tSlidingAC,acfPeriodAll,smoothingSamples,'moving');
            edgeSamples=tSlidingAC<=(tSlidingAC(1)+smoothingDuration/2) | tSlidingAC>=(tSlidingAC(end)-smoothingDuration/2);
            filteredSlidingPeriod(edgeSamples)=[];
            tFilteredSlidingPeriod=tSlidingAC(~edgeSamples)';
            %save data
            save(obj.files.respirationAutocorr,'parRespirationAutocorr','respirationSignal','pFramesValid','tRespFrames','xcf','xcf_lags','xcf_bounds','respirationForSlidingAutocorr','autoCorrTimeBin','autocorrTimes','timeBin',...
                'pPeriod','period','acf','vallyPeriod','peak2VallyDiff','peak2VallyDiffAll','acfPeakAll','acfVallyAll','tSlidingAC','acfPeriodAll','videoFile',...
                'filteredSlidingPeriod','tFilteredSlidingPeriod');
        end
        
        %% getRespirationDBCycle
        function [data]=getRespirationDBCycle(obj,varargin)
            %sleepAnalysis.getRespirationAC - input parameters: ch,tStart,win,movOLWin,XCFLag,movingAutoCorrWin,movingAutoCorrOL
            parseObj = inputParser;
            parseObj.FunctionName='sleepAnalysis\getRespirationDBCycle';
            addParameter(parseObj,'videoFile',[obj.recTable.VideoFiles{obj.currentPRec}],@(x) exist(x,'file'));
            addParameter(parseObj,'ch',obj.recTable.defaulLFPCh(obj.currentPRec),@isnumeric);
            addParameter(parseObj,'padding',1.5,@isnumeric); %padd the data to avoid extrapolation
            addParameter(parseObj,'nBins',25,@isnumeric);
            addParameter(parseObj,'interpolationMethod','linear');
            addParameter(parseObj,'overwrite',0,@isnumeric);
            addParameter(parseObj,'plotSingleCycles',0,@isnumeric);
            addParameter(parseObj,'inputParams',false,@isnumeric);
            parseObj.parse(varargin{:});
            if parseObj.Results.inputParams
                disp(parseObj.Results);
                return;
            end
            
            %evaluate all input parameters in workspace
            for i=1:numel(parseObj.Parameters)
                eval([parseObj.Parameters{i} '=' 'parseObj.Results.(parseObj.Parameters{i});']);
            end
            
            %make parameter structure
            parRespirationDBCycle=parseObj.Results;
            
            %check if analysis was already done done
            obj.files.respirationDBCycle=[obj.currentAnalysisFolder filesep 'getRespirationDBCycle.mat'];
            if isfile(obj.files.respirationDBCycle) & ~overwrite
                if nargout==1
                    data=load(obj.files.respirationDBCycle);
                else
                    disp('Respiration delta to beta cycle analysis already exists for this recording');
                end
                return;
            end
            
            [~,videoFileName]=fileparts(videoFile);
            
            respirationACFile=[obj.currentAnalysisFolder filesep 'respirationAC_' videoFileName '.mat'];
            obj.checkFileRecording(respirationACFile,'RespirationAC analysis missing, please first run getRespirationAC');
            load(respirationACFile,'parRespirationAutocorr','respirationSignal','tRespFrames','period','peak2VallyDiffAll','tSlidingAC'); %load data
            
            dbRatioFile=[obj.currentAnalysisFolder filesep 'dbRatio_ch' num2str(ch) '.mat'];
            obj.checkFileRecording(dbRatioFile,'delta to beta file missing, please first run getDBRatio');
            load(dbRatioFile,'bufferedDelta2BetaRatio','t_ms'); %load data
            
%            dbAutocorrFile=[obj.currentAnalysisFolder filesep 'dbAutocorr_ch' num2str(ch) '.mat'];
%            obj.checkFileRecording(dbAutocorrFile,'Delta to beta autocorr analysis missing, please first run getDelta2BetaAC');
%            load(dbAutocorrFile,'pSleepDBRatio','pSleepSlidingAC'); %load data
            
            slowCyclesFile=[obj.currentAnalysisFolder filesep 'slowCycles_ch' num2str(ch) '.mat'];
            obj.checkFileRecording(slowCyclesFile,'slow cycles file missing, please first run getSlowCycles');
            load(slowCyclesFile,'TcycleOnset','TcycleOffset','TcycleMid'); %load data
            
            [pks,locs] =findpeaks(respirationSignal,tRespFrames,'MinPeakProminence',0.3,'MinPeakDistance',2*1000);
            [pksLow,locsLow] =findpeaks(-respirationSignal,tRespFrames,'MinPeakProminence',0.3,'MinPeakDistance',2*1000);
            pksLow=-pksLow;
                        
            % smoothly connect the maxima via a spline.
            yupper = interp1(locs,pks,locs,'spline');
            ylower = interp1(locsLow,pksLow,locs,'spline');
            %figure;plot(tRespFrames/1000/60/60,respirationSignal);hold on;plot(locs/1000/60/60,yupper);plot(locs/1000/60/60,ylower);
                        
            breathingIntervals=diff(locs);
            tBreathingIntervals=(locs(2:end)+locs(1:end-1))/2;
            resampledTemplateBI=nan(numel(TcycleOnset),nBins);
            resampledTemplateDB=nan(numel(TcycleOnset),nBins);
            resampledTemplateAmp=nan(numel(TcycleOnset),nBins);
            cycleDuration=TcycleOffset-TcycleOnset;
            cycleStartPadded=TcycleMid-cycleDuration/2*padding;
            cycleEndPadded=TcycleMid+cycleDuration/2*padding;
            cycleStart=TcycleMid-cycleDuration/2;
            cycleEnd=TcycleMid+cycleDuration/2;
            %calculate phase in db
            minPoints=4;
            for i=1:numel(TcycleOnset)
                
                pTmpB=find(tBreathingIntervals>cycleStartPadded(i) & tBreathingIntervals<cycleEndPadded(i));
                if numel(pTmpB)>minPoints
                    if tBreathingIntervals(pTmpB(1))<=cycleStart(i) && tBreathingIntervals(pTmpB(end))>=cycleEnd(i)
                        resampledTemplateBI(i,:) = interp1((tBreathingIntervals(pTmpB)-cycleStart(i))/cycleDuration(i),breathingIntervals(pTmpB)',(0:(nBins-1))/(nBins-1),interpolationMethod);
                        
                        pTmp=find(t_ms>cycleStartPadded(i) & t_ms<cycleEndPadded(i));
                        resampledTemplateDB(i,:) = interp1((t_ms(pTmp)-cycleStart(i))/cycleDuration(i),bufferedDelta2BetaRatio(pTmp)',(0:(nBins-1))/(nBins-1),interpolationMethod);
                        
                        pTmpEnv=find(locs>cycleStartPadded(i) & locs<cycleEndPadded(i));
                        resampledTemplateAmp(i,:) = interp1((locs(pTmpEnv)-cycleStart(i))/cycleDuration(i),(yupper(pTmpEnv)-ylower(pTmpEnv)),(0:(nBins-1))/(nBins-1),interpolationMethod);
                        
                        %phaseAll{i}=(t_mov_ms(pTmp)-(TcycleMid(i)-cycleDuration/2))/cycleDuration;
                        
                        %shufTimes=rand(1,numel(pTmp))*cycleDuration;
                        %phaseAllRand{i}=shufTimes/cycleDuration;
                        if plotSingleCycles
                            pTmpR=find(tRespFrames>cycleStart(i) & tRespFrames<cycleEnd(i));
                            h(1)=subplot(3,1,1);plot((t_ms(pTmp)-cycleStart(i))/1000,bufferedDelta2BetaRatio(pTmp),'b');hold on;ylabel('DB');
                            plot((0:(nBins-1))/(nBins-1)*cycleDuration(i)/1000,resampledTemplateDB(i,:),'b');
                            h(2)=subplot(3,1,2);plot((tRespFrames(pTmpR)-cycleStart(i))/1000,respirationSignal(pTmpR),'k');hold on;plot((locs(pTmpB+1)-cycleStart(i))/1000,pks(pTmpB+1),'or');
                            plot((locs(pTmpEnv)-cycleStart(i))/1000,yupper(pTmpEnv),'g');plot((locs(pTmpEnv)-cycleStart(i))/1000,ylower(pTmpEnv),'g');
                            plot((0:(nBins-1))/(nBins-1)*cycleDuration(i)/1000,resampledTemplateAmp(i,:),'g');ylabel('amp');
                            
                            h(3)=subplot(3,1,3);plot((tBreathingIntervals(pTmpB)-cycleStart(i))/1000,1./breathingIntervals(pTmpB),'.m-');hold on;
                            plot((0:(nBins-1))/(nBins-1)*cycleDuration(i)/1000,1./resampledTemplateBI(i,:),'m');ylabel('breath. rate');
                            xlabel('Time [s]');
                            linkaxes(h,'x');
                            xlim([0 cycleDuration(i)/1000])
                            
                            pause;
                            delete(h);
                        end
                        %}
                    end
                end
            end
            mResampledTemplateBI=nanmean(resampledTemplateBI);
            mResampledTemplateBR=nanmean(1./resampledTemplateBI);
            mResampledTemplateDB=nanmean(resampledTemplateDB);
            mResampledTemplateAmp=nanmean(resampledTemplateAmp);
            
            sResampledTemplateBI=nanstd(resampledTemplateBI);
            sResampledTemplateBR=nanstd(1./resampledTemplateBI);
            sResampledTemplateDB=nanstd(resampledTemplateDB);
            sResampledTemplateAmp=nanstd(resampledTemplateAmp);
            
            nAvgCycles=numel(~isnan(resampledTemplateAmp));
            
            %figure;plot(normZeroOne(1./mResampledTemplateBI));hold on;plot(normZeroOne(mResampledTemplateDB));plot(normZeroOne(mResampledTemplateAmp));legend({'Breathing rate','\delta/\beta','Env'});

            %save data
            save(obj.files.respirationDBCycle,'yupper','ylower','breathingIntervals','tBreathingIntervals','resampledTemplateBI',...
            'resampledTemplateDB','resampledTemplateAmp','mResampledTemplateBI','mResampledTemplateBR','mResampledTemplateDB','mResampledTemplateAmp',...
            'sResampledTemplateBI','sResampledTemplateBR','sResampledTemplateDB','sResampledTemplateAmp','nAvgCycles');
        end
        %% plotFreqBandDetection
        function [h,Z]=plotFreqBandDetection(obj,varargin)
            
            parseObj = inputParser;
            addParameter(parseObj,'ch',obj.recTable.defaulLFPCh(obj.currentPRec),@isnumeric);
            addParameter(parseObj,'plotDendrogram',true);
            addParameter(parseObj,'plotSpectralBands',true);
            addParameter(parseObj,'savePlots',true);
            addParameter(parseObj,'freqBandFile',[]);
            addParameter(parseObj,'cLim',0);
            addParameter(parseObj,'printLocalCopy',0,@isnumeric);
            addParameter(parseObj,'hDendro',0);
            addParameter(parseObj,'hSpectra',0);
            addParameter(parseObj,'inputParams',false,@isnumeric);
            parseObj.parse(varargin{:});
            if parseObj.Results.inputParams
                disp(parseObj.Results);
                return;
            end
            
            %evaluate all input parameters in workspace
            for i=1:numel(parseObj.Parameters)
                eval([parseObj.Parameters{i} '=' 'parseObj.Results.(parseObj.Parameters{i});']);
            end
            
            if isempty(freqBandFile)
                spectralClusteringFile=[obj.currentAnalysisFolder filesep 'spectalClustering_ch' num2str(ch) '.mat'];
            else
                spectralClusteringFile=freqBandFile;
            end
            obj.checkFileRecording(spectralClusteringFile,'Spectral band analysis missing, please first run getFreqBandDetection');
            load(spectralClusteringFile);
            
            if plotDendrogram
                maxDendroClusters=parFreqBandDetection.maxDendroClusters;
                
                if cLim==0
                    cLim=[];
                end
                if hDendro==0
                    hDendro=[];
                else
                    savePlots=[];
                end
                [DC,order,clusters,h,Z]=DendrogramMatrix(corrMat,'linkMetric','euclidean','linkMethod','ward','maxClusters',maxDendroClusters,...
                    'toPlotBinaryTree',1,'cLim',cLim,'hDendro',hDendro,'plotOrderLabels',0);
                %h(3).Position=[0.9149    0.7595    0.0137    0.1667];
                ylabel(h(3),'Corr.');
                xlabel(h(2),'Segment');
                xlabel(h(1),'Distance');
                if savePlots
                    set(gcf,'PaperPositionMode','auto');
                    fileName=[obj.currentPlotFolder filesep 'dendrogram_ch' num2str(parFreqBandDetection.ch) '_t' num2str(parFreqBandDetection.tStart) '_w' num2str(parFreqBandDetection.win)];
                    print(fileName,'-djpeg',['-r' num2str(obj.figResJPG)]);
                    if printLocalCopy
                        fileName=[cd filesep obj.recTable.Animal{obj.currentPRec} '_Rec' num2str(obj.currentPRec) '_dendrogram_ch' num2str(parFreqBandDetection.ch) '_t' num2str(parFreqBandDetection.tStart) '_w' num2str(parFreqBandDetection.win)];
                        print(fileName,'-djpeg',['-r' num2str(obj.figResJPG)]);
                    end
                end
            end
            
            if plotSpectralBands
                if hSpectra==0
                    fTmp=figure('position',[680   100   658   420]);
                    hTmp=axes;
                    h=[h hTmp];
                else
                    axes(hSpectra);
                    h=[h hSpectra];
                    savePlots=0;
                end
                for i=1:maxDendroClusters
                    PS=mean(normsPxx(:,clusters==i),2);
                    plot(freqHz,PS,'lineWidth',2);hold on;
                end
                if ~isempty(crossFreq)
                    plot(crossFreq,PS(crossFreq==freqHz),'ok','MarkerSize',8,'LineWidth',2);
                    text(crossFreq+(diff(xlim))*0.15,PS(crossFreq==freqHz),'F_{trans.}');
                end
                xlabel('Frequency (Hz)');
                ylabel('nPSD');
                xlim([0 parFreqBandDetection.fMax]);
                
                if savePlots
                    set(fTmp,'PaperPositionMode','auto');
                    fileName=[obj.currentPlotFolder filesep 'spectralBands_ch' num2str(parFreqBandDetection.ch) '_t' num2str(parFreqBandDetection.tStart) '_w' num2str(parFreqBandDetection.win)];
                    print(fileName,'-djpeg',['-r' num2str(obj.figResJPG)]);
                    if printLocalCopy
                        fileName=[cd filesep obj.recTable.Animal{obj.currentPRec} '_Rec' num2str(obj.currentPRec) '_spectralBands_ch' num2str(parFreqBandDetection.ch) '_t' num2str(parFreqBandDetection.tStart) '_w' num2str(parFreqBandDetection.win)];
                        print(fileName,'-djpeg',['-r' num2str(obj.figResJPG)]);
                    end
                end
                
            end
            
        end
        
        
        %% getHPSegments 
        function data=getAwakeVsSleepFreq(obj,varargin)
            % parameter and settings
            obj.checkFileRecording;
            
            parseObj = inputParser;
            addParameter(parseObj,'ch',obj.recTable.defaulLFPCh(obj.currentPRec),@isnumeric);
            addParameter(parseObj,'sleepFreqBandFile',[]); %median filter window for extracting optic flow baseline
            addParameter(parseObj,'binDuration',10000);
            addParameter(parseObj,'fMax',30,@isnumeric); %max freq. to examine
            addParameter(parseObj,'maxWin',1000*60*60*2,@isnumeric);
            addParameter(parseObj,'overwrite',false,@isnumeric);
            addParameter(parseObj,'saveFileName',[]);
            addParameter(parseObj,'inputParams',false,@isnumeric);
            parseObj.parse(varargin{:});
            if parseObj.Results.inputParams
                disp(parseObj.Results);
                return;
            end
            %evaluate all input parameters in workspace
            for i=1:numel(parseObj.Parameters)
                eval([parseObj.Parameters{i} '=' 'parseObj.Results.(parseObj.Parameters{i});']);
            end
            
            %make parameter structure
            parAwakeVsSleepFreq=parseObj.Results;
            
            if isempty(sleepFreqBandFile)
                spectralClusteringFile=[obj.currentAnalysisFolder filesep 'spectalClustering_ch' num2str(ch) '.mat'];
            else
                spectralClusteringFile=[sleepFreqBandFile '.mat'];
            end
            %obj.checkFileRecording(spectralClusteringFile,'Spectral band analysis missing, please first run getFreqBandDetection');
            %dataSleep=load(spectralClusteringFile,'sPxx','freqHz','normsPxx','clusters');
            
            %check if analysis was already done done
            if isempty(saveFileName)
                obj.files.AwakeVsSleepFreq=[obj.currentAnalysisFolder filesep 'AwakeVsSleepFreq_ch' num2str(ch)];
            else
                obj.files.AwakeVsSleepFreq=saveFileName;
            end
            
            if exist(obj.files.AwakeVsSleepFreq,'file') & ~overwrite
                if nargout==1
                    data=load(obj.files.AwakeVsSleepFreq);
                else
                    disp(['AwakeVsSleepFreq analysis file already exists']);
                end
                return;
            end
            
            animalStates=strsplit(obj.recTable.AnimalState{obj.currentPRec},'/');
            awakeStartTimeSec=obj.recTable.tStartAwake{obj.currentPRec};
            
            for i=1:numel(animalStates)
                if strcmp(animalStates{i},'Awake') || strcmp(animalStates{i},'Running') || strcmp(animalStates{i},'Resting')
                    recDuration=obj.currentDataObj.recordingDuration_ms;
                    if ~isnan(awakeStartTimeSec)
                        tStart=awakeStartTimeSec*1000;
                    else
                        tStart=0;
                    end
                    win=min(maxWin,floor((recDuration-tStart)/binDuration)*binDuration);
                    obj.getFreqBandDetection('tStart',tStart,'win',win,'binDuration',binDuration,'saveFile',obj.files.AwakeVsSleepFreq,'maxDendroClusters',1,'overwrite',overwrite,'fMax',fMax);
                    dataAwake=obj.getFreqBandDetection('saveFile',obj.files.AwakeVsSleepFreq);
                    
                    %{
                    for j=unique(dataSleep.clusters)'
                        PS(j,:)=mean(10*log10(dataSleep.normsPxx(:,dataSleep.clusters==j)),2);
                    end
                    PA=mean(bsxfun(@rdivide,dataAwake.sPxx,mean(dataSleep.sPxx,2)),2);
                    plot(dataSleep.freqHz,PS,'lineWidth',2);hold on;
                    plot(dataAwake.freqHz,PA,'lineWidth',2);
                    %}
                end
            end
            
            %save(obj.files.AwakeVsSleepFreq,'parAwakeVsSleepFreq');
        end
        
        %% getActivity4OpenVsClosedEyes
        function getActivity4OpenVsClosedEyes(obj,varargin)
            obj.checkFileRecording;

            parseObj = inputParser;
            addParameter(parseObj,'ch',[],@isnumeric);
            addParameter(parseObj,'saveFile',[]);
            addParameter(parseObj,'nZoomPanels',1);
            addParameter(parseObj,'overwrite',0,@isnumeric);
            addParameter(parseObj,'inputParams',false,@isnumeric);
            parseObj.parse(varargin{:});
            if parseObj.Results.inputParams
                disp(parseObj.Results);
                return;
            end
            
            %evaluate all input parameters in workspace
            for i=1:numel(parseObj.Parameters)
                eval([parseObj.Parameters{i} '=' 'parseObj.Results.(parseObj.Parameters{i});']);
            end
            
            %make parameter structure
            parActivity4OpenVsClosedEyes=parseObj.Results;
            
            %check if analysis was already done done
            if isempty(saveFile)
                obj.files.Activity4OpenVsClosedEyes=[obj.currentAnalysisFolder filesep 'Activity4OpenVsClosedEyes_ch' num2str(ch) '.mat'];
            else
                obj.files.Activity4OpenVsClosedEyes=[saveFile '.mat'];
            end
            
            if exist(obj.files.Activity4OpenVsClosedEyes,'file') & ~overwrite
                if nargout==1
                    data=load(obj.files.Activity4OpenVsClosedEyes);
                else
                    disp('Activity4OpenVsClosedEyes analysis already performed, use ''overwrite'' to recalculate');
                end
                return;
            end
            
            obj=obj.getFileNames;
            if exist(obj.files.dbRatio,'file')
                db=load(obj.files.dbRatio);
            end
            if exist(obj.files.dbRatio,'file')
                dbAC=load(obj.files.dbAutocorr,'tStartSleep','tEndSleep');
            end
            
            eye=load([obj.currentAnalysisFolder filesep 'eye.mat']);
            tmpEvents=min(numel(eye.eyeOpenStart),numel(eye.eyeCloseStart));
            if (eye.eyeCloseStart(1)-eye.eyeOpenStart(1)) >= 0 %first anotation segment is eye open
                openEyeStart=eye.eyeOpenStart(1:tmpEvents);
                openEyeEnd=eye.eyeCloseStart(1:tmpEvents);
                closedEyeStart=eye.eyeCloseStart(1:tmpEvents-1);
                closedEyeEnd=eye.eyeOpenStart(2:tmpEvents);
            else %first anotation segment is eyes close
                openEyeStart=eye.eyeOpenStart(1:tmpEvents-1);
                openEyeEnd=eye.eyeCloseStart(2:tmpEvents);
                closedEyeStart=eye.eyeCloseStart(1:tmpEvents);
                closedEyeEnd=eye.eyeOpenStart(1:tmpEvents);
            end
            
            pNonSleepOpen=find((openEyeStart<dbAC.tStartSleep & openEyeEnd<dbAC.tStartSleep) | (openEyeStart>dbAC.tEndSleep & openEyeEnd>dbAC.tEndSleep));
            pNonSleepClosed=find((closedEyeStart<dbAC.tStartSleep & closedEyeEnd<dbAC.tStartSleep) | (closedEyeStart>dbAC.tEndSleep & closedEyeEnd>dbAC.tEndSleep));
            
            %remove open closed segments that occur during the main sleep epoch
            openEyeStart=openEyeStart(pNonSleepOpen);
            openEyeEnd=openEyeEnd(pNonSleepOpen);
            closedEyeStart=closedEyeStart(pNonSleepClosed);
            closedEyeEnd=closedEyeEnd(pNonSleepClosed);
            
            allOpenDb={};allClosedDb={};
            for i=1:numel(openEyeStart)
                pTmp=find(db.t_ms>openEyeStart(i) & db.t_ms<=openEyeEnd(i));
                allOpenDb{i}=db.bufferedDelta2BetaRatio(pTmp);
            end
            for i=1:numel(closedEyeStart)
                pTmp=find(db.t_ms>closedEyeStart(i) & db.t_ms<=closedEyeEnd(i));
                allClosedDb{i}=db.bufferedDelta2BetaRatio(pTmp);
            end
            allOpenDb=cell2mat(allOpenDb');
            allClosedDb=cell2mat(allClosedDb');
            
            
            
            f=figure('position',[520   -97   560   895]);
            for i=1:nZoomPanels

                h(i)=subaxis(f,nZoomPanels+1,1,i,'s',0.03,'mt',0.01);
                plot(db.t_ms/1000/60,db.bufferedDelta2BetaRatio);hold on;
                yl=ylim;
                patch([openEyeStart;openEyeEnd;openEyeEnd;openEyeStart]/1000/60,(ones(numel(openEyeStart),1)*[yl(1) yl(1) yl(2) yl(2)])',[0 0 1],'FaceAlpha',0.2,'edgeColor','none');
                patch([closedEyeStart;closedEyeEnd;closedEyeEnd;closedEyeStart]/1000/60,(ones(numel(closedEyeStart),1)*[yl(1) yl(1) yl(2) yl(2)])',[1 0 0],'FaceAlpha',0.2,'edgeColor','none');
                axis tight;
                
                if i==1
                    [hl,ho]=legend({'\delta/\beta','open','closed'},'box','off','location','northwest');
                    %horizontalLegend(ho);
                end
            end
            
            xlabel('Time [min]');
            ylabel('\delta/\beta');
            
            
            
            h(nZoomPanels+1)=subaxis(f,nZoomPanels+1,1,nZoomPanels+1,'s',0.01);
            
            maxEdge=min(2000,6*std([allOpenDb;allClosedDb]));
            
            edges=[0:(maxEdge/10):maxEdge];
            [IOpen]=histc(allOpenDb,edges);
            [IClosed]=histc(allClosedDb,edges);
            bar(edges,[IOpen./sum(IOpen) IClosed/sum(IClosed)],1.1);
            xlabel('\delta/\beta');
            ylabel('Prob.');
            l=legend({'Open','Close'},'box','off');
        end
        
        %% getFreqBandDetectionEMG - function under construction
        function [data]=getFreqBandDetectionEMG(obj,varargin)
            obj.checkFileRecording;

            parseObj = inputParser;
            addParameter(parseObj,'ch',[],@isnumeric);
            addParameter(parseObj,'fMax',500,@isnumeric); %max freq. to examine
            addParameter(parseObj,'dftPoints',2^12,@isnumeric);
            addParameter(parseObj,'tStart',0,@isnumeric);
            addParameter(parseObj,'win',1000*60*60,@isnumeric);
            addParameter(parseObj,'maxDendroClusters',2,@isnumeric);
            addParameter(parseObj,'saveFile',[]);
            addParameter(parseObj,'overwrite',0,@isnumeric);
            addParameter(parseObj,'segmentLength',1000);
            addParameter(parseObj,'WelchOL',0.5);
            addParameter(parseObj,'binDuration',10000);
            addParameter(parseObj,'inputParams',false,@isnumeric);
            parseObj.parse(varargin{:});
            if parseObj.Results.inputParams
                disp(parseObj.Results);
                return;
            end
            
            %evaluate all input parameters in workspace
            for i=1:numel(parseObj.Parameters)
                eval([parseObj.Parameters{i} '=' 'parseObj.Results.(parseObj.Parameters{i});']);
            end
            
            %make parameter structure
            parFreqBandDetectionEMG=parseObj.Results;
            
            %check if analysis was already done done
            if isempty(saveFile)
                obj.files.spectralClusteringEMG=[obj.currentAnalysisFolder filesep 'spectalClusteringEMG_ch' num2str(ch) '.mat'];
            else
                obj.files.spectralClusteringEMG=[saveFile '.mat'];
            end
            
            if exist(obj.files.spectralClusteringEMG,'file') & ~overwrite
                if nargout==1
                    data=load(obj.files.spectralClusteringEMG);
                else
                    disp('Spectral clustering EMG analysis already exists for this recording');
                end
                return;
            end
            
            obj.filt.EMG1=filterData(obj.currentDataObj.samplingFrequency(1));
            obj.filt.EMG1.downSamplingFactor=32;
            obj.filt.EMG1.padding=true;
            obj.filt.EMG1=obj.filt.EMG1.designDownSample;
            
            MLong=obj.currentDataObj.getData(ch,tStart,win);
            FMLong=obj.filt.EMG1.getFilteredData(MLong);
            
            %calculate initial parameters
            segmentSamples = round(segmentLength/1000*obj.filt.EMG1.filteredSamplingFrequency);
            samplesOL = round(segmentSamples*WelchOL);
            samplesBin = binDuration/1000*obj.filt.EMG1.filteredSamplingFrequency;
            
            nBins=numel(FMLong)/samplesBin;

            FMLongB=reshape(FMLong,[samplesBin,nBins]);
            
            if (numel(FMLong)/samplesBin)~=round(numel(FMLong)/samplesBin)
                nBins=nBins-1;
                FMLong=FMLong(1:(samplesBin*nBins));
                disp('Last bin in recording not included due to a missmatch between recording duration and binDuration');
            end
                
            [pxx,f] = pwelch(FMLongB,segmentSamples,samplesOL,dftPoints,obj.filt.EMG1.filteredSamplingFrequency);
            %plot(10*log10(pxx))
            p=find(f<fMax);
            pp=find(sum(pxx(p,:))<500);
            
            %{
            [data]=obj.getDelta2BetaRatio;
            
            
            pDB=find(data.t_ms>tStart & data.t_ms<tStart+win);
            tEMG=2*1000*60*60+((5*1000):(10*1000):(2*60*60*1000));
            
            h(1)=subplot(2,1,1);
            plot(data.t_ms(pDB),data.bufferedDelta2BetaRatio(pDB)); hold on;
            h(2)=subplot(2,1,2);
            plot(tEMG,sum(pxx(p,:)),'r');
            plot(tEMG,mean(abs(FMLongB),1),'r');
            linkaxes(h,'x');
            
            figure;
            plot(data.t_ms(pDB),data.bufferedDelta2BetaRatio(pDB)); hold on;
            plot(tEMG(order(285:387)),200*ones(1,numel(order(285:387))),'.')
            %}
            
            sPxx=pxx(p,pp);
            freqHz=f(p);
            normsPxx=bsxfun(@rdivide,sPxx,mean(sPxx,2));
            corrMat=corrcoef(normsPxx);
            
            if maxDendroClusters==2
                
                [DC,order,clusters]=DendrogramMatrix(corrMat,'linkMetric','euclidean','linkMethod','ward','maxClusters',maxDendroClusters);
                
                S1=mean(normsPxx(:,clusters==1),2);
                S2=mean(normsPxx(:,clusters==2),2);
                if mean(S1(1:3))>mean(S2(1:3))
                    crossFreq=freqHz(1+find(S2-S1>=0,1,'last'));
                else
                    crossFreq=freqHz(1+find(S1-S2>=0,1,'last'));
                end
            else
                crossFreq=[];order=[];clusters=[];
            end
            
            save(obj.files.spectralClustering,'corrMat','sPxx','normsPxx','freqHz','parFreqBandDetectionEMG','order','clusters','crossFreq');
        end
        

        %% getFreqBandDetection
        function [data]=getFreqBandDetection(obj,varargin)
            obj.checkFileRecording;

            parseObj = inputParser;
            addParameter(parseObj,'ch',obj.recTable.defaulLFPCh(obj.currentPRec),@isnumeric);
            addParameter(parseObj,'fMax',30,@isnumeric); %max freq. to examine
            addParameter(parseObj,'dftPoints',2^10,@isnumeric);
            addParameter(parseObj,'tStart',0,@isnumeric);
            addParameter(parseObj,'win',1000*60*60,@isnumeric);
            addParameter(parseObj,'maxDendroClusters',2,@isnumeric);
            addParameter(parseObj,'saveFile',[]);
            addParameter(parseObj,'remove50HzArtifcats',false);
            addParameter(parseObj,'overwrite',0,@isnumeric);
            addParameter(parseObj,'segmentLength',1000);
            addParameter(parseObj,'WelchOL',0.5);
            addParameter(parseObj,'binDuration',10000);
            addParameter(parseObj,'inputParams',false,@isnumeric);
            parseObj.parse(varargin{:});
            if parseObj.Results.inputParams
                disp(parseObj.Results);
                return;
            end
            
            %evaluate all input parameters in workspace
            for i=1:numel(parseObj.Parameters)
                eval([parseObj.Parameters{i} '=' 'parseObj.Results.(parseObj.Parameters{i});']);
            end
            
            if isnan(ch)
                error('LFP channel not define, either define in database as ''defaulLFPCh'' or as input to method ,eg ''ch'',''1''');
            end
            %make parameter structure
            parFreqBandDetection=parseObj.Results;
            
            %check if analysis was already done done
            if isempty(saveFile)
                obj.files.spectralClustering=[obj.currentAnalysisFolder filesep 'spectalClustering_ch' num2str(ch) '.mat'];
            else
                obj.files.spectralClustering=[saveFile '.mat'];
            end
            
            if exist(obj.files.spectralClustering,'file') & ~overwrite
                if nargout==1
                    data=load(obj.files.spectralClustering);
                else
                    disp('Spectral clustering analysis already exists for this recording');
                end
                return;
            end
            obj.getFilters;
            
            if win>obj.currentDataObj.recordingDuration_ms-tStart
                win=obj.currentDataObj.recordingDuration_ms-tStart;
                fprintf('Window larger than recordings length, cutting window to %f [ms]\n',win);
            end
            win=floor(win/binDuration)*binDuration; %making win an integer number of segment length
            MLong=obj.currentDataObj.getData(ch,tStart,win);
            
            %filter data
            FMLong=obj.filt.F.getFilteredData(MLong);
            if remove50HzArtifcats
                obj.filt.notch=filterData(obj.filt.F.filteredSamplingFrequency);
                obj.filt.notch.filterDesign='cheby1';
                obj.filt.notch=obj.filt.notch.designNotch;
                obj.filt.notch.padding=true;
                FMLong=obj.filt.notch.getFilteredData(FMLong);
            end
            times=(tStart+binDuration/2):binDuration:(tStart+win);
            
            %calculate initial parameters
            segmentSamples = round(segmentLength/1000*obj.filt.FFs);
            samplesOL = round(segmentSamples*WelchOL);
            samplesBin = binDuration/1000*obj.filt.FFs;
            
            nBins=numel(FMLong)/samplesBin;

            FMLongB=reshape(FMLong,[samplesBin,nBins]);
            
            if (numel(FMLong)/samplesBin)~=round(numel(FMLong)/samplesBin)
                nBins=nBins-1;
                FMLong=FMLong(1:(samplesBin*nBins));
                disp('Last bin in recording not included due to a missmatch between recording duration and binDuration');
            end
                
            [pxx,f] = pwelch(FMLongB,segmentSamples,samplesOL,dftPoints,obj.filt.FFs);
            %plot(10*log10(pxx))
            p=find(f<fMax);
            pp=find(sum(pxx(p,:))<0.4e6); %reject signals with very high amplitudes (probably noise)
            
            sPxx=pxx(p,pp);
            freqHz=f(p);
            normsPxx=bsxfun(@rdivide,sPxx,mean(sPxx,2));
            corrMat=corrcoef(normsPxx);
            times=times(pp);
            if maxDendroClusters==2
                
                [DC,order,clusters]=DendrogramMatrix(corrMat,'linkMetric','euclidean','linkMethod','ward','maxClusters',maxDendroClusters);
                
                S1=mean(normsPxx(:,clusters==1),2);
                S2=mean(normsPxx(:,clusters==2),2);
                if mean(S1(1:3))>mean(S2(1:3))
                    crossFreq=freqHz(find(S2-S1>=0,1,'first'));
                else
                    crossFreq=freqHz(find(S1-S2>=0,1,'first'));
                end
            else
                [DC,order,clusters]=DendrogramMatrix(corrMat,'linkMetric','euclidean','linkMethod','ward','maxClusters',maxDendroClusters);
                
                for i=1:maxDendroClusters
                    S(:,i)=mean(normsPxx(:,clusters==i),2);
                end
                crossFreq=[];
            end
            
            save(obj.files.spectralClustering,'times','corrMat','sPxx','normsPxx','freqHz','parFreqBandDetection','order','clusters','crossFreq');
        end

        %% getFilters
        function [obj]=getFilters(obj,Fs)
            if nargin==1
                if isempty(obj.currentDataObj)
                    error('Sampling frequency is required as an input');
                else
                    Fs=obj.currentDataObj.samplingFrequency(1);
                    disp(['sampling frequency set to that of current recording:' num2str(Fs) '[Hz]']);
                end
            end
            
            obj.filt.F=filterData(Fs);
            obj.filt.F.downSamplingFactor=Fs/250;
            obj.filt.F=obj.filt.F.designDownSample;
            obj.filt.F.padding=true;
            obj.filt.FFs=obj.filt.F.filteredSamplingFrequency;
            
            obj.filt.DS4Hz=filterData(Fs);
            obj.filt.DS4Hz.downSamplingFactor=Fs/250;
            obj.filt.DS4Hz.lowPassCutoff=4;
            obj.filt.DS4Hz.padding=true;
            obj.filt.DS4Hz=obj.filt.DS4Hz.designDownSample;
            
            obj.filt.FH=filterData(Fs);
            obj.filt.FH.highPassPassCutoff=100;
            obj.filt.FH.highPassStopCutoff=80;
            obj.filt.FH.lowPassPassCutoff=1800;
            obj.filt.FH.lowPassStopCutoff=2000;
            obj.filt.FH.attenuationInLowpass=20;
            obj.filt.FH.attenuationInHighpass=20;
            obj.filt.FH=obj.filt.FH.designBandPass;
            obj.filt.FH.padding=true;

            obj.filt.FHR=filterData(Fs);
            obj.filt.FHR.highPassPassCutoff=60;
            obj.filt.FHR.highPassStopCutoff=50;
            obj.filt.FHR.lowPassPassCutoff=900;
            obj.filt.FHR.lowPassStopCutoff=1000;
            obj.filt.FHR.attenuationInLowpass=20;
            obj.filt.FHR.attenuationInHighpass=40;
            obj.filt.FHR=obj.filt.FHR.designBandPass;
            obj.filt.FHR.padding=true;
            
            obj.filt.FL=filterData(Fs);
            obj.filt.FL.lowPassPassCutoff=4.5;
            obj.filt.FL.lowPassStopCutoff=6;
            obj.filt.FL.attenuationInLowpass=20;
            obj.filt.FL=obj.filt.FL.designLowPass;
            obj.filt.FL.padding=true;
            
            obj.filt.FH2=filterData(Fs);
            obj.filt.FH2.highPassCutoff=100;
            obj.filt.FH2.lowPassCutoff=2000;
            obj.filt.FH2.filterDesign='butter';
            obj.filt.FH2=obj.filt.FH2.designBandPass;
            obj.filt.FH2.padding=true;
        end
        
                
        function [loggerData]=getTemperatureLoggerData(obj,timeCorrectionMs)
            if nargin==1
                timeCorrectionMs=0;
            end
                
            filename=obj.recTable.TempLogger_file(obj.currentPRec);
            filename=[obj.currentExpFolder filesep filename{1}];
            if isfile(filename)
                loggerData0 = readtable(filename,'Range','A1:G2');
                loggerData = readtable(filename);
                loggerData.Properties.VariableNames=loggerData0.Properties.VariableNames(1:5);
                loggerData = [loggerData0(1,1:5);loggerData];
                
                if iscell(obj.currentDataObj.startDate)
                    loggerData.loggerTimeStampsMs=seconds(loggerData.Timestamp-datetime(obj.currentDataObj.startDate{1}))*1000+timeCorrectionMs;
                else
                    loggerData.loggerTimeStampsMs=seconds(loggerData.Timestamp-datetime(obj.currentDataObj.startDate))*1000+timeCorrectionMs;
                end
            else
                disp('Logger data file not found!!!!!');
                loggerData=[];
            end
        end

    end
    
    methods (Static)
        
        %Helper methods for video analysis functions
        function [xInd,yInd,OFBox]=recalculateSampledImageArea4OpticFlow(xInd,yInd,bboxCenter,frameWidth,frameHeight)
            %set coordinates on image to the new box
            xInd=round(xInd-xInd(round(numel(xInd)/2))+bboxCenter(1));
            yInd=round(yInd-yInd(round(numel(yInd)/2))+bboxCenter(2));
            
            if any(yInd<1)
                yInd=1:numel(yInd);
            end
            if any(xInd<1)
                xInd=1:numel(xInd);
            end
            if any(yInd>frameHeight)
                yInd=(frameHeight-numel(yInd)+1):frameHeight;
            end
            if any(xInd>frameWidth)
                xInd=(frameWidth-numel(xInd)+1):frameWidth;
            end
            OFBox=[min(xInd),min(yInd);min(xInd),max(yInd);max(xInd),max(yInd);max(xInd),min(yInd)];
        end
    end
    
end