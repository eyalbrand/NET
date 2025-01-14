function processArgs(obj)
    %PROCESSARGS Handle command-line arguments, load param file
    nargs = numel(obj.args);

    if nargs == 0
        return;
    end

    obj.cmd = lower(obj.args{1});
    obj.args = obj.args(2:end);
    nargs = nargs - 1;

    % paired manual commands
    if contains(obj.cmd, '-manual')
        obj.cmd = strrep(obj.cmd, '-manual', '');
        obj.isCurate = 1;
    end

    if nargs > 0
        % load parameter file
        configFile = obj.args{1};

        % arg 1 need not be a config file
        [~, ~, ext] = fileparts(configFile);
        if strcmpi(ext, '.prm')
            try
                obj.hCfg = jrclust.Config(configFile);
                % save imported config file
                if obj.hCfg.isV3Import
                    obj.hCfg.save();
                end
            catch ME
                warning('Failed to load %s: %s', configFile, ME.message);
            end
        end
    end

    switch obj.cmd
        % deprecated commands; will be removed in a future release
        case {'compile-ksort', 'dir', 'edit', 'git-pull', 'issue', 'import-kilosort-sort', ...
              'import-ksort-sort', 'kilosort', 'kilosort-verify', 'ksort', 'ksort-verify' ...
              'which', 'wiki', 'wiki-download'}
            obj.deprecateCmd(obj.cmd);
            obj.isCompleted = 1;

        case {'doc', 'doc-edit'}
            iMsg = 'Please visit the wiki at https://github.com/JaneliaSciComp/JRCLUST/wiki';
            obj.deprecateCmd(obj.cmd, iMsg);
            obj.isCompleted = 1;

        case 'download'
            iMsg = 'You can find sample.bin and sample.meta at https://drive.google.com/drive/folders/1-UTasZWB0TwFFFV49jSrpRPHmtve34O0?usp=sharing';
            obj.deprecateCmd(obj.cmd, iMsg);
            obj.isCompleted = 1;

        case 'gui'
            iMsg = 'GUI is not implemented yet';
            obj.deprecateCmd(obj.cmd, iMsg);
            obj.isCompleted = 1;

        case 'install'
            iMsg = 'You might be looking for `compile` instead';
            obj.deprecateCmd(obj.cmd, iMsg);
            obj.isCompleted = 1;

        case {'set', 'setprm', 'set-prm'}
            iMsg = 'Create a new JRC handle instead';
            obj.deprecateCmd(obj.cmd, iMsg);
            obj.isCompleted = 1;

        case 'update'
            iMsg = 'Please check the repository at https://github.com/JaneliaSciComp/JRCLUST for updates';
            obj.deprecateCmd(obj.cmd, iMsg);
            obj.isCompleted = 1;

        case {'load-bin', 'export-wav', 'wav'}
            iMsg = 'Please use jrclust.models.recordings.Recording instead';
            obj.deprecateCmd(obj.cmd, iMsg);
            obj.isCompleted = 1;

        % deprecated synonyms, warn but proceed
        case 'spikedetect'
            obj.deprecateCmd(obj.cmd, '', 'detect');

        case {'cluster', 'clust', 'sort-verify', 'sort-validate'}
            obj.deprecateCmd(obj.cmd, '', 'sort');

        case {'detectsort', 'spikesort', 'spikesort-verify', 'spikesort-validate'}
            obj.deprecateCmd(obj.cmd, '', 'detect-sort');

        case 'all'
            obj.deprecateCmd(obj.cmd, '', 'full');

        case 'auto'
            obj.deprecateCmd(obj.cmd, '', 'recluster');
            obj.recluster();
            obj.isCompleted = ~obj.isError;

        case 'plot-activity'
            obj.deprecateCmd(obj.cmd, '', 'activity');
            obj.activity();
            obj.isCompleted = 1;

        case {'makeprm', 'createprm'}
            obj.deprecateCmd(obj.cmd, '', 'bootstrap');
            obj.bootstrap(obj.args{:});
            obj.isCompleted = 1;

        % info commands
        case 'about'
            md = jrclust.utils.info();
            verstr = sprintf('%s v%s', md.program, jrclust.utils.version());
            abstr = jrclust.utils.about();
            msgbox(abstr, verstr);
            obj.isCompleted = 1;

        case 'help'
            jrclust.utils.help();
            obj.isCompleted = 1;

        case 'version'
            md = jrclust.utils.info();
            fprintf('%s v%s\n', md.program, jrclust.utils.version());
            obj.isCompleted = 1;

        % workflow commands
        case 'bootstrap'
            obj.bootstrap(obj.args{:});
            obj.isCompleted = 1;

        case 'compile'
            jrclust.CUDA.compileCUDA();
            obj.isCompleted = 1;

        case 'importv3'
            [hCfg_, res_] = jrclust.import.v3(obj.args{1});
            if isempty(hCfg_)
                obj.error('Import failed');
            else
                obj.hCfg = hCfg_;
                obj.res = res_;
                obj.saveRes();
                obj.hCfg.save('', 1);

                obj.isCompleted = 1;
            end

        case 'import-ksort'
            [hCfg_, res_] = jrclust.import.kilosort_new(obj.args{1});
            if isempty(hCfg_)
                obj.error('Import failed');
            else
                obj.hCfg = hCfg_;
                obj.res = res_;

                obj.saveRes();
                obj.hCfg.save('', 1);

                obj.isCompleted = 1;
            end

        case 'export-phy'
            if isempty(obj.hCfg)
                obj.error(sprintf('%s not found or not a config file', obj.args{1}));
                return;
            end

            try
                jrclust.export.phy(obj.hCfg);
                obj.isCompleted = 1;
            catch ME
                obj.error(ME.message);
            end

        % misc commands
        case 'activity'
            obj.activity();
            obj.isCompleted = 1;

        case 'probe'
            if isempty(obj.hCfg) && nargs == 0
                obj.isError = 1;
                obj.errMsg = 'Specify a probe or a config file';
            elseif isempty(obj.hCfg) % arg 1 not a config file
                obj.probe(obj.args{1});
                obj.isCompleted = 1;
            else
                obj.probe();
                obj.isCompleted = 1;
            end

        case 'preview'
            obj.preview();
            obj.isCompleted = 1;

        case 'recluster'
            obj.recluster();
            obj.isCompleted = ~obj.isError;

        case 'traces'
            obj.traces();
            obj.isCompleted = 1;
    end

    if ~obj.inProgress
        if ~isempty(obj.hCfg)
            obj.hCfg.closeLog();
        end
        return;
    end

    % command sentinel
    detectCmds = {'detect', 'detect-sort', 'full'};
    sortCmds   = {'sort', 'detect-sort', 'full'};
    curateCmds = {'manual', 'full'};

    legalCmds = unique([detectCmds, sortCmds curateCmds]);

    if ~any(strcmpi(obj.cmd, legalCmds))
        obj.errMsg = sprintf('Command `%s` not recognized', obj.cmd);
        errordlg(obj.errMsg, 'Unrecognized command');
        obj.isError = 1;
        return;
    end

    obj.hCfg.openLog(sprintf('%s-%s.log', obj.cmd, datestr(now(), 30)));

    % determine which commands in the pipeline to run
    if any(strcmp(obj.cmd, curateCmds))
        obj.isCurate = 1;
    end

    if any(strcmp(obj.cmd, sortCmds))
        obj.isSort = 1;
    end

    if any(strcmp(obj.cmd, detectCmds))
        obj.isDetect = 1;
    end
end
