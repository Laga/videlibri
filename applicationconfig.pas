unit applicationconfig;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils,Graphics,forms,libraryparser,registry,inifiles,rcmdline,errordialog,tnaaccess,autoupdate,progressDialog;

const MENU_ID_START_LCL=1;
      MENU_ID_UPDATE=2;
      MENU_ID_AUTO_UPDATE=3;
      MENU_ID_EXTEND=4;
      MENU_ID_LIMIT_INFO=5;
      MENU_ID_CLOSE=6;

type TErrorArray=array of record
                     error: string;
                     details: array of record
                       account: TCustomAccountAccess;
                       details: string;
                     end;
                   end;
  
const VIDELIBRI_MUTEX_NAME='VideLibriStarted';
  
var programPath,userPath,dataPath:string;
    machineConfig,userConfig: TIniFile;

    accountIDs: TStringList;
    libraryManager: TLibraryManager=nil;

    cancelStarting,startToTNA:boolean;
    accountsRefreshed: boolean=false; //at least one function is to notify the checkthread to stop
    lclStarted: boolean=false;
    lclStartedTime: longword=$FFFFFFFF;

    currentDate:longint;
    lastCheck: integer;
    nextLimit:longint=MaxInt-1;
    nextNotExtendableLimit:longint=MaxInt;
    nextLimitStr: string;

    appFullTitle:string='VideLibri';
    versionNumber:integer=989;//=>versionNumber/1000
    newVersionInstalled: boolean=false;

    startedMutex:THandle=0;


    needApplicationRestart: boolean; //Soll das Programm nach Beenden neugestartet werden

    //cached
    colorLimited:tcolor;
    colorTimeNear:tcolor;
    colorOK:tcolor;
    colorOld:tcolor;
    colorSearchMark: tcolor=clAqua;
    colorSearchMarkField: tcolor=(clBlue + clAqua) div 2;
    colorSearchTextNotFound: tcolor=$6060FF;
    colorSearchTextFound: tcolor=clWindow;
    redTime: integer;
    RefreshInterval: integer;
    HistoryBackupInterval: longint;
    refreshAllAndIgnoreDate:boolean; //gibt an, dass alle Medien aktualisiert werden
                                     //sollen unabh�ngig vom letzten Aktualisierungdatum

    sharewareUser, sharewareCode: string;

  errorMessageList:TErrorArray = nil;
  //oldErrorMessageList:TErrorArray = nil;
  oldErrorMessageString:string;
var tna:TTNAIcon;


  procedure applicationUpdate(auto:boolean);

  procedure initApplicationConfig;
  procedure finalizeApplicationConfig;
  procedure saveLibIDs;

  procedure showErrorMessages();
  procedure addErrorMessage(errorStr,errordetails:string;lib:TCustomAccountAccess=nil);
  procedure createErrorMessageStr(exception:exception; var errorStr,errordetails:string;account:TCustomAccountAccess=nil);
  procedure createAndAddException(exception:exception; account:TCustomAccountAccess=nil);


  //get the values the tna should have not the one it actually has
  //function getTNAHint():string;
  function getTNAIconFileName():string;

  procedure updateGlobalAccountDates;
  procedure updateActiveInternetConfig;

  function DateToPrettyStr(const date: tdatetime):string;
  function DateToPrettyGrammarStr(preDate,preName:string;const date: tdatetime):string;

implementation
uses bookwatchmain,windows,internetaccess,w32internetaccess,controls,libraryaccess,FileUtil,bbdebugtools;
  procedure errorCallback(sender:TObject; var Done: Boolean);
  begin
    messagebeep(0);
    Application.OnIdle:=nil;
    showErrorMessages();
    done:=true;
  end;
  procedure showErrorMessages();
  var i,j:integer;
      mes,mesDetails: string;
      //met: TMethod;
  begin
    if not lclStarted then begin
      {lclStarted:=true;
      Application.Initialize;
      Application.ShowMainForm:=false;
      Application.CreateForm(TmainForm, mainForm);
      met.Code:=@errorCallback;
      met.Data:=nil;
      Application.OnIdle:=TIdleEvent(met);
      Application.Run;
      tna.stopStandalone;}
      exit;
    end;
    for i:=0 to high(errorMessageList) do begin
      if oldErrorMessageString='' then
        oldErrorMessageString:=#13#10#13#10#13#10'====Fehlerinformationen �ber alle vorhin aufgetretenden Fehler===='#13#10;
      with errorMessageList[i] do begin
        mes:=' ist leider folgender Fehler aufgetreten: '#13#10+error;
        case length(details) of
          0: mes:=' kein Konto (dieser Fehler macht keinen Sinn) '+mes;
          1: mes:=' das Konto '+details[0].account.prettyName+mes;
          else begin
            mes:=details[high(details)-1].account.prettyName+' und '+details[high(details)].account.prettyName+mes;
            for j:=0 to high(details)-2 do
              mes:=details[j].account.prettyName+', '+mes;
            mes:=' die Konten '+mes;
          end;
        end;
        mes:='Beim Zugriff auf'+mes;
        mesDetails:='';
        for j:=0 to high(details) do
          mesDetails:=mesDetails+'Details f�r den Zugriff auf Konto '+details[j].account.prettyname+':'#13#10+
                      details[j].details+#13#10#13#10;
        oldErrorMessageString:=oldErrorMessageString+'---Fehler---'#13#10+mes+#13#10'Details:'#13#10+mesdetails;
        if lclStarted and mainForm.Visible then
          TshowErrorForm.showError('Fehler beim Aktualisieren der B�cherdaten',mes,mesdetails,@mainForm.MenuItem16Click)
         else
          TshowErrorForm.showError('Fehler beim Aktualisieren der B�cherdaten',mes,mesdetails);
        //Application.MessageBox(pchar(error),pchar('Fehler bei Zugriff auf '+lib.prettyName),MB_APPLMODAL or MB_ICONERROR or MB_OK);
      end;
    end;
    setlength(errorMessageList,0);
    
  end;

  procedure addErrorMessage(errorStr,errordetails:string;lib:TCustomAccountAccess=nil);
  var i:integer;
  begin
    for i:=0 to high(errorMessageList) do
      if errorMessageList[i].error=errorstr then begin
        SetLength(errorMessageList[i].details,length(errorMessageList[i].details)+1);
        errorMessageList[i].details[high(errorMessageList[i].details)].account:=lib;
        errorMessageList[i].details[high(errorMessageList[i].details)].details:=errordetails;
        exit;
      end;
    SetLength(errorMessageList,length(errorMessageList)+1);
    errorMessageList[high(errorMessageList)].error:=errorstr;
    setlength(errorMessageList[high(errorMessageList)].details,1);
    errorMessageList[high(errorMessageList)].details[0].account:=lib;
    errorMessageList[high(errorMessageList)].details[0].details:=errordetails;
  end;

  procedure createErrorMessageStr(exception: exception; var errorStr,
    errordetails: string; account: TCustomAccountAccess);
  var i:integer;
  begin
    if exception is EInternetException then begin
      errorstr:=exception.message+#13#10#13#10+'Bitte �berpr�fen Sie Ihre Internetverbindung.';
      errordetails:=EInternetException(exception).details;
     end else if exception is ELoginException then begin
      errorstr:=#13#10+exception.message;
      errordetails:='';
     end else if exception is ELibraryException then begin
      errorstr:=#13#10+exception.message;
      errordetails:=ELibraryException(exception).details;
     end else begin
      errorstr:=//'Es ist folgender Fehler aufgetreten:      '#13#10+
           exception.className()+': '+ exception.message+'     ';
      errordetails:='';
     end;
    errordetails:=errordetails+#13#10'Detaillierte Informationen �ber die entsprechende Quellcodestelle: (zur Angabe bei Supportanfragen) '#13#10+ BackTraceStrFunc(ExceptAddr);
    for i:=0 to ExceptFrameCount-1 do
      errordetails:=errordetails+#13#10+BackTraceStrFunc(ExceptFrames[i]);
    if logging then log('Exception: '+errorstr+#13#10'      Details: '+errordetails);
  end;

  procedure createAndAddException(exception: exception;
    account: TCustomAccountAccess);
  var errorStr,errordetails:string;
  begin
    createErrorMessageStr(exception,errorStr,errordetails,account);
    addErrorMessage(errorStr,errorDetails,account);
  end;

(*  function getTNAHint(): string;
  begin
    {if nextLimit>=MaxInt then
      result:='VideLibri'#13#10'Keine bekannte Abgabefrist'
     else if nextNotExtendableLimit=nextLimit then
      result:='VideLibri'#13#10'N�chste bekannte Abgabefrist:'#13#10+DateToPrettyStr(nextNotExtendableLimit)
     else
      result:='VideLibri'#13#10'N�chste bekannte Abgabefrist:'#13#10+DateToPrettyStr(nextLimit)+'  (verl�ngerbar)';}
     result:='
  end;        *)


  function getTNAIconFileName(): string;
  begin
    if nextLimit<=redTime then
      result:=dataPath+'smallRed.ico'
     else if nextNotExtendableLimit=nextLimit then
      result:=dataPath+'smallYellow.ico'
     else
      result:=dataPath+'smallGreen.ico';
  end;

  procedure updateGlobalAccountDates;
  var i,j:integer;
  begin
    //set global nextLmiit and nextNotExtandable
    //(search next one)
    nextLimit:=MaxInt-1;
    nextNotExtendableLimit:=MaxInt;

    lastcheck:=currentDate;
    for i:=0 to accountIDs.count-1 do begin
      for j:=0 to TCustomAccountAccess(accountIDs.objects[i]).getBooks().getBookCount(botCurrent)-1 do
        with TCustomAccountAccess(accountIDs.objects[i]).getBooks().getBook(botCurrent,j)^ do
          lastcheck:=min(lastcheck,lastExistsDate);
      if (TCustomAccountAccess(accountIDs.objects[i]).getBooks().nextLimit>0) then
         nextLimit:=min(nextLimit,TCustomAccountAccess(accountIDs.objects[i]).getBooks().nextLimit);
      if (TCustomAccountAccess(accountIDs.objects[i]).getBooks().nextNotExtendableLimit>0) then
        nextNotExtendableLimit:=min(nextNotExtendableLimit,TCustomAccountAccess(accountIDs.objects[i]).getBooks().nextNotExtendableLimit);
    end;
    nextLimitStr:=DateToPrettyStr(nextLimit);
    if nextLimit<>nextNotExtendableLimit then
      nextLimitStr:=nextLimitStr+' (verl�ngerbar)';
    if startToTNA then begin
  //    tna.changeHint(getTNAHint());
      tna.changeIcon(getTNAIconFileName());
    end;
  end;
  procedure updateActiveInternetConfig;
  begin
    defaultInternetConfiguration.userAgent:='Mozilla 3.0 (compatible; VideLibri '+IntToStr(versionNumber)+' '+machineConfig.ReadString('debug','userAgentAdd','')+')';
//    defaultInternetConfiguration.userAgent:='Mozilla 3.0 (compatible; VideLibri ';//2:13/20
//    defaultInternetConfiguration.userAgent:='Mozilla 3.0 (compatible; VideLibri '+IntToStr(versionNumber);//+' '+machineConfig.ReadString('debug','userAgentAdd','')+')';
    defaultInternetConfiguration.connectionCheckPage:='www.duesseldorf.de';
    case userConfig.readInteger('access','internet-type',0) of
      0: defaultInternetConfiguration.tryDefaultConfig:=true;
      1: begin
           defaultInternetConfiguration.tryDefaultConfig:=false;
           defaultInternetConfiguration.useProxy:=false;
         end;
      2: begin
           defaultInternetConfiguration.tryDefaultConfig:=false;
           defaultInternetConfiguration.useProxy:=true;
         end;
    end;
    defaultInternetConfiguration.proxyHTTPName:=userConfig.ReadString('access','httpProxyName','');
    defaultInternetConfiguration.proxyHTTPPort:=userConfig.ReadString('access','httpProxyPort','');
    defaultInternetConfiguration.proxyHTTPSName:=userConfig.ReadString('access','httpsProxyName','');
    defaultInternetConfiguration.proxyHTTPSPort:=userConfig.ReadString('access','httpsProxyPort','');
  end;

  procedure applicationUpdate(auto:boolean);
  var  updater: TAutoUpdater;
       temp:string;
       wnd: THANDLE;
  begin
    if auto and ((userConfig.ReadInteger('updates','auto-check',1) = 0)
                 or (currentDate-userConfig.ReadInteger('updates','lastcheck',0)<userConfig.ReadInteger('updates','interval',3))) then
      exit;
    if logging then log('applicationUpdate really started');
    if mainForm<>nil then wnd:=mainForm.Handle
    else wnd:=0;
    updater:=TAutoUpdater.create(versionNumber,programpath,'http://www.benibela.de/updates/videlibri/version.xml'
                                                          ,'http://www.benibela.de/updates/videlibri/changelog.xml');
    if updater.existsUpdate then begin
      if not updater.hasDirectoryWriteAccess then begin
        MessageBox(wnd,pchar('Es gibt ein Update auf die Version '+floattostr(updater.newVersion/1000)+':'#13#10#13#10+
                            updater.listChanges+#13#10+
                            'Um das Update herunterzuladen und zu installieren, m�ssen Sie Videlbri unter einem Benutzerkonto mit Administratorrechten starten.'),'Videlibri Update',mb_ok or MB_APPLMODAL);
        updater.free;
        if logging then log('applicationUpdate exited');
        exit;
      end else if { (not auto) or} (MessageBox(wnd,pchar('Es gibt ein Update auf die Version '+floattostr(updater.newVersion/1000)+':'#13#10#13#10+
                                              updater.listChanges+#13#10+
                                              'Soll es jetzt heruntergeladen und installiert werden?'),'Videlibri Update',mb_yesno or MB_APPLMODAL)=idyes) then begin
        if lclStarted then begin
          Screen.cursor:=crHourglass;
          temp:=mainForm.StatusBar1.Panels[0].Text;
          mainForm.StatusBar1.Panels[0].Text:='Bitte warten, Update wird heruntergeladen...';
        end;
        updater.downloadUpdate();
        if lclStarted then
          mainForm.StatusBar1.Panels[0].Text:='Bitte warten, Update wird installiert...';
        updater.installUpdate();
        if lclStarted then begin
          Screen.cursor:=crDefault;
          mainForm.StatusBar1.Panels[0].Text:=temp;
        end;
        if updater.needRestart then begin
          if lclStarted then mainForm.close
          else PostMessage(tna.messageWindow,WM_CLOSE,0,0);
        end else if not auto then
          MessageBox(wnd,pchar('Update wurde installiert'),'Videlibri Update',mb_ok or MB_APPLMODAL);
      end;
    end else if not auto then
      MessageBox(wnd,pchar('Kein Update gefunden'),'Videlibri Update',mb_ok or MB_APPLMODAL);
    updater.free;
    userConfig.WriteInteger('updates','lastcheck',currentDate);
    if logging then log('applicationUpdate ended');
  end;

  //normal exception handling doesn't seem to work properly when lcl is not loaded
  procedure raiseInitializationError(s: string);
  begin
    MessageBox(0,pchar(s),'VideLibri',MB_APPLMODAL or MB_ICONERROR);
    cancelStarting:=true;
    if logging then log('raiseInitializationError: '+s);
    raise exception.Create(s);
  end;

  function bringToFrontEnumeration(window:HWND; _para2:LPARAM):WINBOOL;stdcall;
  var proc: THANDLE;
  begin
    GetWindowThreadProcessId(window,@proc);
    if proc=_para2 then
      if IsWindowEnabled(window) and IsWindowVisible(window) then begin
        SetForegroundWindow(window);
        BringWindowToTop(window);
        exit(false);
      end;
    exit(true);
  end;

  procedure initApplicationConfig;
  var reg:TRegistry;
      i:integer;
      window,proc:THANDLE;
      commandLine:TCommandLineReader;
      //checkOne: boolean;
  begin
    currentDate:=trunc(now);

//    if currentDate>39264 then
  //     raiseInitializationError('Dises Betaversion ist abgelaufen (seit 1. Juli 2007).  Die neueste Version sollte unter www.benibela.de zu bekommen sein.');

    appFullTitle:='VideLibri '+FloatToStr(versionNumber / 1000);

    //Kommandozeile lesen
    commandLine:=TCommandLineReader.create;
    commandLine.declareFlag('autostart','Gibt an, ob das Programm automatisch gestartet wurde.');
    commandLine.declareFlag('start-always','Startet das Program auch, wenn es schon l�uft.');
    commandLine.declareFlag('minimize','Gibt an, ob das Programm minimiert gestartet werden soll.');
    commandLine.declareInt('updated-to','Das Programm wurde auf Version ($1) aktualisiert (ACHTUNG: veraltet)',0);
    commandLine.declareInt('debug-addr-info','Wandelt in der Debugversion eine Adresse in eine Funktionszeile um',0);
    commandLine.declareFlag('log','Zeichnet alle Aktionen auf',false);
    commandLine.declareFlag('refreshAll','Aktualisiert alle Medien',false);

    //�berpr�ft, ob das Programm schon gestart ist, und wenn ja, �ffnet dieses
    SetLastError(0);
    startedMutex:=CreateMutex(nil,true,VIDELIBRI_MUTEX_NAME);
    if (not commandLine.readFlag('start-always')) and (GetLastError=ERROR_ALREADY_EXISTS) then begin
      window:=FindWindow(pchar(TTNAIcon.getClassName()),nil);
      if window=0 then begin
        window:=FindWindow(nil,pchar(appFullTitle));//FindWindow(nil,'VideLibri');
        if IsWindowEnabled(window) then begin
          //SendMessage(window,SW_SHOW,0,0);
          SetForegroundWindow(window);
          BringWindowToTop(window);
        end else begin
          GetWindowThreadProcessId(window,@proc);
          EnumWindows(@bringToFrontEnumeration,proc);
        end;
      end else begin
        SendMessage(window,WM_COMMAND,MENU_ID_START_LCL,0);
      end;
      cancelStarting:=true;
      commandLine.free;
      exit;
    end;
  
    //Aktiviert das Logging
    logging:=commandLine.readFlag('log');
    if logging then log('Started with logging enabled, command line:'+GetCommandLine);


    //�berpr�ft die Farbeinstellung des Monitors
    if ScreenInfo.ColorDepth=8 then
      MessageBox(0,'VideLibri funktioniert im 256-Farbenmodus nur unvollst�ndig.'#13#10+
                   'Am besten �ndern Sie Ihre Monitoreinstellungen.','VideLibri',MB_APPLMODAL or MB_ICONWARNING);

    //Pfade auslesen und �berpr�fen
    programPath:=ExtractFilePath(ParamStr(0));
    if not (programPath[length(programPath)] in ['/','\']) then programPath:=programPath+'\';
    dataPath:=programPath+'data\';

    if logging then log('programPath is '+programPath);
    if logging then log('dataPath is '+dataPath);

    if not DirectoryExists(programPath) then
      raiseInitializationError('Datenpfad "'+dataPath+'" wurde nicht gefunden');
    if not DirectoryExists(dataPath) then
      raiseInitializationError('Datenpfad "'+dataPath+'" wurde nicht gefunden');

    if logging and (not FileExists(datapath+'machine.config')) then
      log('machine.config will be created');

    //Globale Einstellungen lesen
    machineConfig:=TIniFile.Create(datapath+'machine.config');
    if machineConfig.ReadInteger('version','number',versionNumber)<versionNumber then begin
      machineConfig.writeInteger('version','number',versionNumber);
      newVersionInstalled:=true;
    end;
    versionNumber:=machineConfig.ReadInteger('version','number',versionNumber);
    
    if logging then log('DATA-Version ist nun bekannt: '+inttostr(versionNumber));

    //Userpfad auslesen und �berpr�fen
    userPath:=machineConfig.ReadString('paths','user',programPath+'config\');
    if logging then log('plain user path: '+userPath);
    userPath:=StringReplace(userPath,'{$appdata}',GetAppConfigDir(false),[rfReplaceAll,rfIgnoreCase]);
    if logging then log('replaced user path: '+userPath);
    if (copy(userpath,2,2)<>':\') and (copy(userpath,1,2)<>'\\') then
      userPath:=programPath+userpath;
    userPath:=IncludeTrailingPathDelimiter(userPath);
    if logging then log('finally user path: '+userPath);
    
    if not DirectoryExists(userPath) then begin
      try
        if logging then log('user path: '+userPath+' doesn''t exists');
        ForceDirectory(userPath);
        if logging then log('user path: '+userPath+' should be created');
        if not DirectoryExists(userPath) then
          raiseInitializationError('Benutzerpfad "'+userPath+'" wurde nicht gefunden und konnte nicht erzeugt werden');
       except
         raiseInitializationError('Benutzerpfad "'+userPath+'" wurde nicht gefunden und konnte nicht erzeugt werden');
       end;
    end;

    if logging and (not FileExists(userPath+'user.config')) then
      log('user.config will be created');

    //Userdaten lesen
    userConfig:=TIniFile.Create(userPath+'user.config');
    RefreshInterval:=userConfig.ReadInteger('access','refresh-interval',2);
    HistoryBackupInterval:=userConfig.ReadInteger('base','history-backup-interval',30);

    libraryManager:=TLibraryManager.create();
    libraryManager.init(userPath);
    if libraryManager.enumeratePrettyLongNames()='' then
      raise EXCEPTION.Create('Keine B�chereitemplates im Verzeichnis '+dataPath+' vorhanden');

    accountIDs:=TStringList.create;
    if FileExists(userPath+'account.list') then
      accountIDs.LoadFromFile(userPath+'account.list');
    for i:=0 to accountIDs.count-1 do
      accountIDs.Objects[i]:=libraryManager.getAccount(accountIDs[i]);

    nextLimitStr:=DateToPrettyStr(nextLimit);
    if nextLimit<>nextNotExtendableLimit then
      nextLimitStr:=nextLimitStr+' (verl�ngerbar)';


    if commandLine.readInt('debug-addr-info')<>0 then begin
      cancelStarting:=true;
      MessageBox(0,@BackTraceStrFunc(pointer(commandLine.readInt('debug-addr-info')))[1],'Point',0);
      raise exception.create(BackTraceStrFunc(pointer(commandLine.readInt('debug-addr-info'))));
    end;

    if commandLine.readInt('updated-to')<>0 then begin
      if commandLine.readInt('updated-to')=905 then
        MessageBox(0,'Die wichtigsten �nderungen sind, dass die �nderungen von zuk�nftigen Updates vor dem Runterladen dieser angezeigt werden und einige Fehler korrigiert wurden.','',0);

      userConfig.WriteInteger('version','number',commandLine.readInt('updated-to'));

    end;

    sharewareUser:=userConfig.ReadString('registration','user','');
    sharewareCode:=userConfig.ReadString('registration','code','');



    redTime:=trunc(now)+userConfig.ReadInteger('base','near-time',2);

    if commandLine.readFlag('autostart') then begin
      startToTNA:=userConfig.ReadBool('autostart','minimized',true);
      if (userConfig.ReadInteger('autostart','type',1)=1) then begin
        cancelStarting:=true;
        for i:=0 to accountIDs.count-1 do
          if (TCustomAccountAccess(accountIDs.Objects[i]).lastCheckDate<=currentDate-refreshInterval) or
             (TCustomAccountAccess(accountIDs.Objects[i]).checkMaximalBookTimeLimit) or 
             ((TCustomAccountAccess(accountIDs.Objects[i]).getBooks().nextLimit<>0)and(TCustomAccountAccess(accountIDs.Objects[i]).getBooks().nextLimit<=redTime))then begin
            cancelStarting:=false;
            break;
          end;
      end else cancelStarting:=false;
    end else begin
      cancelStarting:=false;
      //Check autostart registry value (for later starts)
      if (not userConfig.SectionExists('autostart')) or
         (userConfig.ReadInteger('autostart','type',1)<>2) then begin
        reg:=TRegistry.create;
        reg.RootKey:=HKEY_CURRENT_USER;
        reg.OpenKey('\Software\Microsoft\Windows\CurrentVersion\Run',true);
        //MessageBox(0,pchar(ParamStr(0)),'',0);
        if lowercase(reg.ReadString('VideLibriAutostart')) <> lowercase('"'+ParamStr(0)+'" /autostart') then
          if MessageBox(0,'Der Autostarteintrag ist ung�ltig'#13#10+
                          'Wenn er nicht ge�ndert wird, k�nnen die Medien wahrscheinlich nicht automatisch verl�ngert werden.'#13#10+
                          'Soll er nun ge�ndert werden?','VideLibri',MB_YESNO) = IDYES then
            reg.WriteString('VideLibriAutostart','"'+ParamStr(0)+'" /autostart');
        reg.free;
      end;
    end;
    if not cancelStarting then begin
      refreshAllAndIgnoreDate:=commandline.readFlag('refreshAll');
    
      colorLimited:=userConfig.ReadInteger('appearance','limited',integer(clYellow));
      colorTimeNear:=userConfig.ReadInteger('appearance','timeNear',integer(clRed));
      colorOK:=userConfig.ReadInteger('appearance','default',integer((clGreen+clLime) div 2));
      colorOld:=userConfig.ReadInteger('appearance','history',integer(clSilver));


      updateActiveInternetConfig;
      defaultInternet:=TW32InternetAccess.create;
      
      updateThreadsRunning:=0;
      fillchar(updateThreadConfig,sizeof(updateThreadConfig),0);
      InitializeCriticalSection(updateThreadConfig.libraryAccessSection);
    end;
    commandLine.free;
  end;
  
  procedure finalizeApplicationConfig;
  var i:integer;
  begin
    if logging then log('finalizeApplicationConfig started');
    if accountIDs<>nil then begin
      for i:=0 to accountIDs.count-1 do
        try
          accountIDs.Objects[i].free;
        except
          ;
        end;
      accountIDs.free;
      libraryManager.free;
      userConfig.free;
      machineConfig.free;
    end;
    FreeAndNil(defaultInternet);
    if not cancelStarting then
      DeleteCriticalSection(updateThreadConfig.libraryAccessSection);
    if startedMutex<>0 then
      ReleaseMutex(startedMutex);
    if needApplicationRestart then begin
      WinExec(pchar(ParamStr(0)+' --start-always') ,SW_SHOWNORMAL);
    end;
    if logging then begin
      log('finalizeApplicationConfig ended'#13#10' => program will exit normally, after closing log');
      if logFileCreated then begin
        close(logFile);
        DeleteCriticalSection(logFileSection);
      end;
    end;
  end;
  
  procedure saveLibIDs;
  begin
    accountIDs.SaveToFile(userPath+'account.list');
  end;

  function DateToPrettyStr(const date: tdatetime):string;
  begin
    if date=0 then result:='unbekannt'
    else case trunc(date-currentDate) of
      -2: result:='vorgestern';
      -1: result:='gestern';
      0: result:='heute';
      1: result:='morgen';
      2: result:='�bermorgen';
      else result:=DateToStr(date);
    end;
  end;

  function DateToPrettyGrammarStr(preDate,preName: string; const date: tdatetime
    ): string;
  begin
    if date=0 then result:='unbekannt'
    else case trunc(date-currentDate) of
      -2: result:=preName+'vorgestern';
      -1: result:=preName+'gestern';
      0: result:=preName+'heute';
      1: result:=preName+'morgen';
      2: result:=preName+'�bermorgen';
      else result:=preDate+DateToStr(date);
    end;
  end;

end.

