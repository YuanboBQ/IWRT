function RunProgram(setup, procedure, images, audio)
%Iterates through trials and collects data

%% TODO

%%
trialLength = size(procedure.known, 1);

% open experiment data file
dataWrite = fopen(setup.dataFileStr, 'w');
writeLine(dataWrite, {'date', 'id', 'name', 'age', ...
    'imgStart', 'audioStart', 'imgEnd', 'tobiiOnset', 'ptbOnset', 'trial', 'new', 'left', 'right', 'word', ...
    'imgLx0', 'imgLy0', 'imgLx1', 'imgLy1','imgRx0', 'imgRy0', 'imgRx1', 'imgRy1', ...
    'attentionGetterTime', 'expmntrEndPre', 'expmntrEndPost', 'subjectEndPost'});

% Perform basic initialization of the sound driver:
audioPtr = initPTBSound(44100);

% Open main window
windowPtr = tryScreenOpen(setup.screenNum, setup.bgColor);

% create blank masks
mask = blankMask(setup.screenRect, setup.maskColor);
maskTexture = Screen('MakeTexture', windowPtr, mask);
Screen('PreloadTextures', windowPtr, maskTexture);

% load attention getter images and audio
[aTextures, aBuffers] = LoadAttentionGetters(windowPtr, audioPtr, images, audio);

% initialize eye tracking variables
if setup.eyeTracker
    try
        tetio_stopTracking;
    catch
        disp('...');
    end
    tobiiLocalOnset = tetio_localTimeNow;
    sessionStart = GetSecs;
    tobiiStart = tetio_localToRemoteTime(tobiiLocalOnset);
else
    tobiiLocalOnset = -1;
    sessionStart = GetSecs;
end

% start experiment
HideCursor;

for trial = 1:trialLength
    clc;
    disp(['trials left: ', num2str(trialLength-trial+1)]);
    
    % reset tracking variables
    lookAwayFlagSet = false;
    breakTrialFlag = false;
    breakTrialDuration = 0;
    attentionImage = randi([1, 2], 1, 1);
    
    interruption_attention = 0;
    interruption_prerelease = false;
    interruption_postrelease = false;
    interruption_endbylook = false;
    
    if setup.eyeTracker
        leftEyeData = [];
        rightEyeData = [];
        gazeTimestamps = [];
        tetTimestamps = [];
        ptbTimestamps = [];
        lookAwayBuffer = [];
    end
    
    % get stimuli for current trial
    trialImg = GetImageStim(procedure, images, trial, ...
        setup.screenLeft-setup.sepAdj, setup.screenRight+setup.sepAdj, ...
        setup.screenCenterY, setup.screenWidth, setup.screenHeight);
    trialAud = GetAudioStim(procedure, audio, trial);
    
    % make textures
    leftTexture = Screen('MakeTexture', windowPtr, trialImg.imgL);
    rightTexture = Screen('MakeTexture', windowPtr, trialImg.imgR);
    Screen('PreloadTextures', windowPtr, [leftTexture, rightTexture]);
    
    % start fixation audio and fixation circle
    % wait until space bar is pressed
    if ~setup.debug
        disp('Press SPACE bar to continue');
        PsychPortAudio('FillBuffer', audioPtr, RandomFixationAudio(audio));
        PsychPortAudio('Start', audioPtr, 0, 0, 1);
        fixationCircle(windowPtr, false, setup.fixationDiameter);
        clc;
        PsychPortAudio('Stop', audioPtr);
    end
    
    % start tracker
    if setup.eyeTracker
        tetio_startTracking;
        TetDat(sessionStart, tobiiStart);
    end
    
    % draw blank mask for 350 milliseconds
    Screen('DrawTexture', windowPtr, maskTexture);
    Screen('Flip', windowPtr);
    WaitSecs(0.35);
    
    %% start pre audio screen
    onsetTimestamp = timeStamp(sessionStart);
    startTimestamp = GetSecs;
    disp('Press space to proceed manually.');
    
    while true
        
        % loop time for one iter
        loopDuration = GetSecs - startTimestamp;
        
        if loopDuration > setup.timeLimitPre
            break
        end

        if setup.eyeTracker
            
            % get tracking data
            [lefteye, righteye, gazeTS, tetTS, ptbTS, gzx, gzy] = TetDat(sessionStart, tobiiStart);
            
            % stack data
            leftEyeData = vertcat(leftEyeData, lefteye);
            rightEyeData = vertcat(rightEyeData, righteye);
            gazeTimestamps = vertcat(gazeTimestamps, gazeTS);
            tetTimestamps = vertcat(tetTimestamps, tetTS);
            ptbTimestamps = vertcat(ptbTimestamps, ptbTS);
            
            % check if looking away
            [lookAwayFlagSet, lookAwayBuffer] = LookAwayFlag(lookAwayFlagSet, lookAwayBuffer, gzx, gzy, setup.lookAwayBufferSize);
            
            % if not looking at screen show attention getter
            % also restart the preaudio clock
            if lookAwayFlagSet || checkTermination(KbName('UpArrow'))
                
                attentionShowTime = GetSecs;
                
                % check if sound is already playing. if not, play
                soundStatus = PsychPortAudio('GetStatus', audioPtr);
                if soundStatus.Active == 0
                    PsychPortAudio('FillBuffer', audioPtr, aBuffers(attentionImage));
                    PsychPortAudio('Start', audioPtr, 1, 0, 1);
                end
                
                % draw and show attention getter image
                Screen('DrawTexture', windowPtr, aTextures(attentionImage));
                Screen('Flip', windowPtr);
                
                interruption_attention = interruption_attention + ((GetSecs-attentionShowTime) .* 1000); 
                
                % reset clock
                startTimestamp = GetSecs;
                
            else % draw stim if lookAwayFlag is not set
                soundStatus = PsychPortAudio('GetStatus', audioPtr);
                if soundStatus.Active == 1
                    PsychPortAudio('Stop', audioPtr);
                    WaitSecs(0.02);
                end
                Screen('DrawTexture', windowPtr, leftTexture, [], trialImg.rectL);
                Screen('DrawTexture', windowPtr, rightTexture, [], trialImg.rectR);
                Screen('Flip', windowPtr);
            end
        else
            Screen('DrawTexture', windowPtr, leftTexture, [], trialImg.rectL);
            Screen('DrawTexture', windowPtr, rightTexture, [], trialImg.rectR);
            Screen('Flip', windowPtr);
        end
        
        % option to proceed manually
        if checkTermination(KbName('SPACE'))
            KbReleaseWait;
            interruption_prerelease = true;
            break
        end
        
    end
    
    clc;
    
    %% start audio and audio onset timestamp
    PsychPortAudio('Stop', audioPtr);
    PsychPortAudio('FillBuffer', audioPtr, trialAud.wav');
    audioTimestamp = timeStamp(sessionStart);
    PsychPortAudio('Start', audioPtr, 1, 0, 1);
    
    % start post audio screen
    startTimestamp = GetSecs;
    
    % reset look away components
    if setup.eyeTracker
        lookAwayBuffer = [];
        lookAwayFlagSet = false;
    end
    
    while true
        
        % loop time for one iter
        loopDuration = GetSecs - startTimestamp;
        
        if setup.eyeTracker
            % tracking data
            [lefteye, righteye, gazeTS, tetTS, ptbTS, gzx, gzy] = TetDat(sessionStart, tobiiStart);
            
            % stack data
            leftEyeData = vertcat(leftEyeData, lefteye);
            rightEyeData = vertcat(rightEyeData, righteye);
            gazeTimestamps = vertcat(gazeTimestamps, gazeTS);
            ptbTimestamps = vertcat(ptbTimestamps, ptbTS);
            tetTimestamps = vertcat(tetTimestamps, tetTS);
            
            % check if looking at screen
            [lookAwayFlagSet, lookAwayBuffer] = LookAwayFlag(lookAwayFlagSet, lookAwayBuffer, gzx, gzy, setup.lookAwayBufferSize);
            
            % check if need to end trial early for not looking
            if lookAwayFlagSet && (GetSecs - startTimestamp) > 0.1
                % start looking away clock
                lookAwayTimestamp = GetSecs;
                disp('Countdown started to end trial early');
                
                while true
                    breakTrialDuration = GetSecs-lookAwayTimestamp;
                    loopDuration = GetSecs - startTimestamp;
                    [~, ~, ~, ~, ~, gzx, gzy] = TetDat(sessionStart, tobiiStart);
                    [lookAwayFlagSet, lookAwayBuffer] = LookAwayFlag(lookAwayFlagSet, lookAwayBuffer, gzx, gzy, setup.lookAwayBufferSize);
                    
                    % trial time ran out before looking away assessment
                    if loopDuration > setup.timeLimitPost
                        breakTrialFlag = false;
                        breakTrialDuration = GetSecs-lookAwayTimestamp;
                        clc;
                        disp('Trial over already');
                        break
                    end
                    
                    % looked back on screen, add more time and continue
                    if ~lookAwayFlagSet
                        startTimestamp = startTimestamp + (lookAwayTimestamp-startTimestamp) + 0.1;
                        breakTrialFlag = false;
                        breakTrialDuration = 0;
                        clc;
                        disp('Looked back at screen');
                        break
                    end
                    
                    % didn't look back in time, set end trial flag
                    if breakTrialDuration > setup.lookAwayTime
                        breakTrialFlag = true;
                        breakTrialDuration = GetSecs-lookAwayTimestamp;
                        clc;
                        disp('Ending trial early due to looking away');
                        break
                    end
                end
            end
        end
        
        % end trial early if set
        if breakTrialFlag
            interruption_endbylook = true;
            break
        end
        
        % check if trial is over
        if loopDuration > setup.timeLimitPost
            break
        end
        
        % draw stim
        Screen('DrawTexture', windowPtr, leftTexture, [], trialImg.rectL);
        Screen('DrawTexture', windowPtr, rightTexture, [], trialImg.rectR);
        Screen('Flip', windowPtr);
        
        % wait some time
        WaitSecs(.008);
        
        % option to contiue early manually
        if checkTermination(KbName('SPACE'))
            KbReleaseWait;
            interruption_postrelease = true;
            break
        end
        
    end
    
    % update end trial time with subtraction if necessary
    offsetTimestamp = timeStamp(sessionStart) - breakTrialDuration .* 1000000;
    
    % stop eye tracker data collection
    if setup.eyeTracker
        tetio_stopTracking;
    end
    
    % stop audio
    PsychPortAudio('Stop', audioPtr);
    
    % write screenshot
    if setup.screenshot
        screenShot = Screen('GetImage', windowPtr);
        imwrite(screenShot, [setup.screenshotFileStr, 'scrCap_', sprintf('%03d', trial), '.jpg'], 'Quality', 100);
    end
    
    % remove textures
    Screen('Close', [leftTexture, rightTexture]);
    
    % write experiment data
    writeLine(dataWrite, {setup.date, setup.subID, setup.subName, setup.subAge, ...
        onsetTimestamp, audioTimestamp, offsetTimestamp, double(tobiiLocalOnset), sessionStart, ...
        trial, ~trialImg.known, trialImg.nameL, trialImg.nameR, trialAud.name, ...
        trialImg.normL(1), trialImg.normL(2), trialImg.normL(3), trialImg.normL(4),...
        trialImg.normR(1), trialImg.normR(2), trialImg.normR(3), trialImg.normR(4), ...
        interruption_attention, interruption_prerelease, interruption_postrelease, interruption_endbylook});
    
    % write tracking data
    if setup.eyeTracker
        tobiifile = [setup.tobiiFileStr, 'eyeData_', sprintf('%03d', trial), '.csv'];
        WriteTobiiData(tobiifile, leftEyeData, rightEyeData, gazeTimestamps, tetTimestamps, ptbTimestamps);
    end
    
    % check for escape key
    if checkTermination(setup.escKeys)
        clc;
        disp('Experiment ended early!');
        break
    end
    
end
clc;

% finish screen
tstring = 'Finished!';
disp(tstring);
Screen('FillRect', windowPtr, [0 0 0]);
DrawFormattedText(windowPtr, tstring, 'center', 'center', [255 255 255],[],[],[],3);
Screen('Flip', windowPtr);
WaitSecs(2);

% close up everything
ShowCursor;
fprintf(dataWrite, '\n');
fclose(dataWrite);
PsychPortAudio('Close', audioPtr);
Screen('CloseAll');

% try to disconnect eye tracker
if setup.eyeTracker
    try
        tetio_disconnectTracker;
        tetio_cleanUp;
    catch
        disp('Tobii already stopped');
    end
end


end