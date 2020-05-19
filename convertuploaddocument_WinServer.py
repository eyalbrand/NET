import _pickle as pickle
import logging

import numpy as np
import pandas as pd

import concurrent.futures as cf

import os
import subprocess

import re
import hashlib

# import boto3
# from boto3.s3.transfer import TransferConfig
"from google.cloud import storage"

class WindowsInhibitor:
    '''Prevent OS sleep/hibernate in windows; code from:
    https://github.com/h3llrais3r/Deluge-PreventSuspendPlus/blob/master/preventsuspendplus/core.py
    API documentation:
    https://msdn.microsoft.com/en-us/library/windows/desktop/aa373208(v=vs.85).aspx'''
    ES_CONTINUOUS = 0x80000000
    ES_SYSTEM_REQUIRED = 0x00000001

    def __init__(self):
        pass

    def inhibit(self):
        import ctypes
        print("Preventing Windows from going to sleep")
        ctypes.windll.kernel32.SetThreadExecutionState(
            WindowsInhibitor.ES_CONTINUOUS | \
            WindowsInhibitor.ES_SYSTEM_REQUIRED)

    def uninhibit(self):
        import ctypes
        print("Allowing Windows to go to sleep")
        ctypes.windll.kernel32.SetThreadExecutionState(
            WindowsInhibitor.ES_CONTINUOUS)

class convertuploaddocument:
    """Class which allows for upload and batch conversion
    of mcds files generated by MultiChannel Systems Experimenter
    The class is meant to work on the MCS recording computer in Windows 10.
    Version 1: 10-06-19 Noah Dolev
    Version 1.1: 11-06-19 Noah Dolev [added spreadsheet export]
    """

    def walk(self):
        """Get all files in path
        """
        for p, d, f in os.walk(self.searchpath):
            for ff in f:
                if ff.endswith(self.suffix):
                    self.files.append(os.path.join(p, ff))

    def scanforexperiments(self):
        """Takes a search path and looks recursively for all MSRD files
        """

        self.logger.info('Start: Scan for new files')
        self.walk()
        self.logger.info('Process: %d total files found' % len(self.files))
        self.logger.info('End: Scan for files complete')

    def parsefields(self, getvalchar='<', nextfieldchar='_'):
        
        if os.path.exists(os.path.join(self.WexacH5Path, 'experiments.xlsx')): #WexacH5Path is a misleading name now that we have our own server
            self.field_completed = pd.read_excel(os.path.join(self.WexacH5Path, 'experiments.xlsx'))
            if not self.startfresh:
                self.files = [f for f in self.files if f not in np.unique(self.field_completed.fullpathmsrd)]
                self.logger.info('Process: start_fresh disabled, only %d new files will be processed' % len(self.files))
        
        if len(self.files)>0:
            self.field['fullpathmsrd'] = self.files 
            self.field.sort_values(by=['fullpathmsrd'], inplace=True)
            self.field.reset_index(drop=True, inplace=True)
            self.field['MEAfiles'] = self.field['fullpathmsrd'].apply(lambda x: x.split('\\')[-1].replace(self.suffix, 'h5'))
            self.field['recNames'] = self.field['MEAfiles'].apply(lambda x: hashlib.md5(x.replace('.h5', '').encode()).hexdigest())                                      
            self.field['OrigFileFolder'] = ['\\' + os.path.join(*word[:-1]) for word in
                                    [f.split('\\') for f in self.field['fullpathmsrd']]]
            self.field['folder'] = [os.path.join(self.WexacH5Path,recname) for recname in self.field['recNames']]
            self.field['OrigFileName'] = self.field['MEAfiles']
            self.field['MEAfiles'] = self.field['recNames']+'.h5'            
            self.field['recNames'] = self.field['MEAfiles']
    
            def setrecformat(x):
                if 'h5' in x:
                    return ('MCH5Recording')
                else:
                    return ('binaryRecording')

            self.field['recFormat'] = [setrecformat(x) for x in self.field['MEAfiles']]

            flatten = lambda l: [item for sublist in l for item in sublist]
            nvc = '|'.join(flatten([nextfieldchar]))
            gvc = '|'.join(flatten([getvalchar]))
            
            for ind in self.field.index:
                word = self.field['fullpathmsrd'].loc[ind].split('\\')
                keyvalpair = [re.split(nvc, w) for w in word]
                for kv in keyvalpair:
                    for k in kv:
                        if '=' in k:
                            temp = re.split(gvc, k)[0]
                            temp = temp[-np.min([6, len(temp)]):]  # maximum field length is 6 characters
                            key = ''.join(j for j in temp if not j.isdigit())  #
                            temp = re.split(gvc, k)[1:]
                            val = ''.join(temp)
                            if key not in self.field.columns:
                                self.field[key] = 'unspecified'
                            self.field[key].loc[ind] = val.split('.' + self.suffix)[0]
            self.field.fillna('unspecified', inplace=True)
        else:
            self.logger.info('End: No new files to process')

    def makeGSdir(self, directory='database/'):
        """Creates a google storage bucket for data
        """
        blob = self.bucket.blob(directory.replace('\\', '/'))
        blob.upload_from_string('', content_type='application/x-www-form-urlencoded;charset=UTF-8')

    def createDirStructure(self):
        """Parses pandas dataframe into a directory structure for easy reading by a database engine
        whereby each field and value are changed into "x=y" directories.
        _Should add code to automatically form the directory hierarchy so that the smallest number of files is in the lowest folder_
        """
        table = self.field
        table = table[table['MEAfiles'].str.contains('h5')].drop(
            ['fullpathmsrd', 'exclude', 'recFormat', 'recNames', 'folder', 'comments'], axis=1)
        table = table.reindex(columns=(['user'] + list([col for col in table.columns if col != 'user'])))
        dirs = [t for t in table.columns.values if t != 'MEAfiles']
        for i in range(0, table.shape[0]):
            dtemp = 'database'
            for d in dirs:
                if 'unspecified' not in table[d].iloc[i]:
                    dtemp = os.path.join(dtemp, d + '=%s' % table[d].iloc[i])
            self.directory.append(dtemp.replace('\\', '/'))

    def uploadFile(self, file, path, bucket):
        """Uploads files to Google Cloud Storage
        :param file: the file to be uploaded
        :param path: the generated path using the file's inferred experiment attributes
        :param bucket: the bucket to place the file
        """
        path = path + '\\'
        path = path.replace('\\', '/')
        testexists = bucket.blob(path + file.replace('.msrd', '.h5').split('\\')[-1])
        if not testexists.exists():
            self.makeGSdir(directory=path)
            bashCommand = 'gsutil -o GSUtil:parallel_composite_upload_threshold=150M -m cp "%s" "gs://%s"' % (
                file.replace('.msrd', '.h5'), path)
            # Multi-threaded composite upload. Still quite slow.
            subprocess.Popen(bashCommand, stdout=subprocess.PIPE, shell=True)

    def multi_part_upload_with_s3(self, file_path, key_path, bucket="meadata"):
        """Uploads files in parallel to Amazon s3 buckets
        :param file_path: path of file to upload
        :param key_path: generated path using the file's inferred experiment attributes
        :param bucket: bucket to place the file
        """
        # Multipart upload
        with open(self.awsaccesskey, 'rb') as csvfile:
            keys = pd.read_csv(csvfile)
        s3 = boto3.resource('s3', aws_access_key_id=keys["Access key ID"][0],
                            aws_secret_access_key=keys["Secret access key"][0])
        config = TransferConfig(multipart_threshold=1024 * 25, max_concurrency=8,
                                multipart_chunksize=1024 * 25, use_threads=True)
        b = s3.Bucket(bucket)
        objs = list(b.objects.filter(Prefix=key_path))
        if len(objs) > 0 and objs[0].key == key_path:
            print("%s already Exists - skipping upload!" % file_path.split('\\')[-1])
        else:
            s3.meta.client.upload_file(Filename=file_path, Bucket=bucket, Key=key_path,
                                       Config=config)

    def localnetworkcopy(self, f, d, archive=True):
        """
        :param f: file to copy
        :param d: directory to place file
        :param archive: Flag for whether to also copy file to local network archive
        """
        self.logger.info('Process: Copy h5 to local network location')
        subprocess.call(
            ["xcopy", f.replace("msrd", "h5"), os.path.join(self.localsharepath, d.replace('/', '\\')) + '\\',
             '/k/c/i/y/z'])
        self.logger.info('Process: %s copied succesfully' % f.replace("msrd", "h5"))
        if archive:
            self.logger.info('Process: Copy MSRD and MSRS to local network archive')
#             set_trace()
            subprocess.call(
                ["xcopy", f, os.path.join(self.localarchivepath, d.replace('/', '\\')) + '\\', '/k/c/i/y/z'])
            subprocess.call(
                ["xcopy", f.replace("msrd", "msrs"), os.path.join(self.localarchivepath, 
                                                                  d.replace('/', '\\')) + '\\','/k/c/i/y/z'])
            self.logger.info('Process: %s msrd and msrs copied succesfully to archive' % f.split('.')[0])

    def createspreadsheet(self):
        """Takes parsed file dataframe and creates a spreadsheet based on the fields
            :return pandas dataframe with list of uploaded files and their metadata
        """
        self.field = self.field.replace("unspecified", "")
        spreadsheetpath = os.path.join(self.searchpath, 'experiments.xlsx')
        self.field.to_excel(spreadsheetpath, index=False)
        if self.cloudflag == "gcs":
            self.logger.info('Process: Starting upload of spreadsheet to GS')
            self.uploadFile(file=spreadsheetpath, path='/database',
                            bucket=self.bucket)
            self.logger.info('Process: Successfully uploaded spreadsheet to GS')
        elif self.cloudflag == "aws":
            with open(self.awsaccesskey, 'rb') as csvfile:
                keys = pd.read_csv(csvfile)
            self.multi_part_upload_with_s3(file_path=spreadsheetpath, key_path="database/experiments.xlsx")
            self.logger.info("Process: Spreadsheet uploaded to AWS s3")
        else:
            self.logger.info('Process: Not uploading spreadsheet to cloud storage')
        if self.localcopyflag == True:
            self.localnetworkcopy(spreadsheetpath, self.localsharepath)
            subprocess.call(["xcopy", spreadsheetpath, self.WexacH5Path,'/c/i/y/z'])
        return (self.field)

    def converttoh5(self):
        """Takes files that were discovered and converts them to h5 then uploads them to google cloud / amazon S3 and/or makes a local network copy
        """

        def processfiles(f, d, bucket=self.bucket, mcspath=self.mcspath, cloudflag=self.cloudflag,
                         localcopyflag=self.localcopyflag):
            """Internal function for multiprocessing conversion and upload
            :param f: file to process
            :param d: generated path by createDirStructure
            :param bucket: bucket to place file
            :param mcspath: path to MCS commandline conversion tool
            :param cloudflag: flag whether to use google ("gcs", "aws" or "local")
            :param localcopyflag: if True, also copies file to a local network direction
            """

            if ((not os.path.isfile(f.replace('.msrd', '.h5'))) | self.overwriteh5):
                if os.path.isfile(f.replace('.msrd', '.h5')):
                    try:
                        os.remove(f.replace('.msrd', '.h5'))
                    except:
                        self.logger.error(' %s is locked, no overwrite possible' % f.split('.')[0])
                        
                print('Conversion to H5 running')
                bashCommand = '%s -t hdf5 "%s"' % (mcspath, f.replace('.msrd', '.msrs'))
                process = subprocess.Popen(bashCommand, stdout=subprocess.PIPE)
                output, error = process.communicate()
                if error is not None:
                    self.logger.error('File failed to convert with error: \n %s' % error)
                else:
                    self.logger.info('Process: Successfully converted file to H5')
                    # Workaround since there is no way to specify output file name with MCS commandline tool
                    try: 
                        hashstring = hashlib.md5(f.split('\\')[-1].split('.')[0]).encode().hexdigest()
                        os.rename(f.replace('.msrd', '.h5'), os.path.join('\\'.join(f.split('\\')[:-1]), hashstring + '.h5'))
                    except exception as e:
                        self.logger.error('File rename to hash failed: /n %s' % e)
                        os.remove(f.replace('.msrd', '.h5'))
                        pass
                    
                    f = os.path.join('\\'.join(f.split('\\')[:-1]),
                                     hashlib.md5(f.split('\\')[-1].split('.')[0].encode()).hexdigest() + '.h5')
                    self.logger.info('Process: File renamed to md5 hash successfully')
                    
                    print("1-"+f)

            if (cloudflag == "gcs"):
                self.logger.info('Process: Starting upload of HDF5 to target directory of GS')
                self.uploadFile(file=f, path=d,
                                bucket=bucket)
                # can be improved by composing a composite object containing all the files to upload
                self.logger.info('Process: Successfully uploaded H5 to GS')
            elif (cloudflag == "aws"):
                with open("D:\\code\\user=ND\\ND_AccessKey.csv", 'rb') as csvfile:
                    keys = pd.read_csv(csvfile)
                file_path = f.replace('.msrd', '.h5')
                key_path = d + '/' + f.replace('.msrd', '.h5').split('\\')[-1]
                self.logger.info('Process: %s Uploading' % file_path)
                self.logger.info('Process: File uploading to: %s' % key_path)
                try:
                    self.multi_part_upload_with_s3(file_path=file_path, key_path=key_path, bucket="meadata")
                except exception as e:
                    self.logger.error('File failed to upload with error: \n %s' % e)
                    pass
            else:
                self.logger.info('Process: Not uploading to cloud storage')
            if (localcopyflag == True):
                print("2-"+f)
                self.localnetworkcopy(f, d)

        self.logger.info('Start: Conversion from MSDS to H5')
        self.parsefields(getvalchar=['=', '>'], nextfieldchar=[',', '_'])
        try:
            self.createDirStructure()
        except:
            print('Error creating directory structure. Are you sure you scanned for new experiments?')
        self.logger.info('Process: Created target directory structure')
        with cf.ProcessPoolExecutor() as executor:
            _ = [executor.submit(processfiles(f=self.files[i], d=self.directory[i])) for i in range(0, len(self.files))]
        self.logger.info('End: Conversion from MSDS to H5')
        
    def wexac_copy(self,rawflag = False, h5flag = True):
        
        if rawflag:
            sretinush3qs
            elf.logger.info('Process: Copy raw data to Wexac archive')
            subprocess.call(
                ["xcopy", self.searchpath, self.localarchivepath,'/S /Y /D'])
            self.logger.info('Process: Raw data copied succesfully to archive')
        if h5flag:
            for p, d, fi in os.walk(self.localarchivepath):
                for ff in fi:
                    if ff.endswith(self.suffix):
                        hashstring = hashlib.md5(ff.split('.msrd')[0].encode()).hexdigest()
                        if not os.path.exists(os.path.join(os.path.join(self.WexacH5Path,hashstring+'\\'), hashstring+'.h5')):   
                            f = os.path.join(p, ff)
                            try:
                                bashCommand = '%s -t hdf5 "%s"' % (self.mcspath, f.replace(self.suffix, 'msrs'))
                                process = subprocess.Popen(bashCommand, stdout=subprocess.PIPE)
                                output, error = process.communicate()
                                if error is not None:
                                    self.logger.error('File failed to convert with error: \n %s' % error)
                                else:
                                    try:
                                        os.rename(f.replace('.msrd', '.h5'),os.path.join('\\'.join(f.split('\\')[:-1]), hashstring+'.h5'))
                                    except:
                                        pass
                                    
                                    os.makedirs(os.path.join(self.WexacH5Path,hashstring+'\\'),exist_ok=True)
                                    subprocess.call(["xcopy", os.path.join('\\'.join(f.split('\\')[:-1]), hashstring+'.h5'), os.path.join(self.WexacH5Path,hashstring+'\\'),'/c/i/y/z'])
                                    os.remove(os.path.join('\\'.join(f.split('\\')[:-1]), hashstring+'.h5'))
                                    self.logger.info('Process: Successfully converted file to H5 and copied')          
                            except:
                                 self.logger.error(' %s is locked, no overwrite possible' % f.split('.')[0])
            if self.field_completed.shape[0] > 0:
                self.field = self.field.append(self.field_completed, sort=False)
            self.field = self.field.replace("unspecified", "")
#             self.field['folder'] = self.WexacH5Path
            self.logger.info('Process: Saving Excel Experiment Record')
            if self.field.shape[0] > 0:
                try:
                    self.field.to_excel(os.path.join(self.WexacH5Path, 'experiments.xlsx'), index=False)
                    self.logger.info('End: Excel written succesfully')
                except:
                    self.field.to_excel(os.path.join(self.WexacH5Path, 'experiments_new.xlsx'), index=False)
                    print('Old experiment excel file is open somewhere and therefore could not be overwritten')
                    self.logger.info('End: Save completed succesfully but excel saved to experiments_new because old file was locked')
            else:
                self.logger.info('End: No experiments found')                

    def __init__(self, searchpath="D:\\Multi Channel DataManager\\", startfresh=False,
                 suffix='msrd', gcs_credentials_path="D:\\code\\user=ND\\divine-builder-142611-9884de65797a.json",
                 gcs_project_id='divine-builder-142611', bucketname='meadata',
                 logpath=os.path.join('c:\\', 'code', 'logs'),
                 mcspath=os.path.join('c:\\', 'Code',  'RetinaExperimentor', 'McsDataCommandLineConverter',
                                      "McsDataCommandLineConverter.exe"),
                 cloudflag="aws", localcopyflag=True, localsharepath="\\\\132.77.73.171\\MEA_DATA\\",
                 localarchivepath="\\\\data.wexac.weizmann.ac.il\\rivlinlab-arc\\raw\\",
                 WexacH5Path = "\\\\data.wexac.weizmann.ac.il\\rivlinlab-arc\\h5s\\",
                 awsaccesskey="D:\\code\\user=ND\\ND_AccessKey.csv", clearlogflag = False, overwriteh5=False):
        """Initialize class
        :param searchpath: path to directory with data files
        :param startfresh: flag, if 1 then attempt to upload all files
        :param suffix: suffix of data files
        :param gcs_credentials_path: path to google cloud credential file
        :param gcs_project_id: name of google cloud project
        :param bucketname: name of bucket to upload files
        :param logpath: path to save log file
        :param mcspath: path to mcs data command line converter
        :param cloudflag: flag, if 1 then attempt to upload files to google
        :param localsharepath: path to local network shared directory
        """
        if cloudflag != 'None':
            os.environ['GOOGLE_APPLICATION_CREDENTIALS'] = gcs_credentials_path
            self.gcs_client = storage.Client(project=gcs_project_id)
            self.bucket = self.gcs_client.get_bucket(bucketname)

        self.logpath = logpath
        self.logger = logging.getLogger(__name__)
        self.logger.setLevel(logging.INFO)

        # create a file handler
        if os.path.exists(os.path.join(self.logpath, 'SpreadSheet_RunLog.log')):
            if clearlogflag:
                try:
                    os.remove(os.path.join(self.logpath, 'SpreadSheet_RunLog.log'))
                except:
                    pass
            else:
                self.handler = logging.FileHandler(os.path.join(self.logpath, 'SpreadSheet_RunLog.log'), mode='a')
        else:       
            self.handler = logging.FileHandler(os.path.join(self.logpath, 'SpreadSheet_RunLog.log'), mode='w') 
        self.handler.setLevel(logging.INFO)

        # create a logging format
        self.formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
        self.handler.setFormatter(self.formatter)

        # add the handlers to the logger
        self.logger.addHandler(self.handler)
        self.files = []
        colnames = ['fullpathmsrd', 'exclude', 'folder', 'coating', 'cleaning', 'MEAfiles', 'recFormat', 'recNames',
                    'comments']
        self.field = pd.DataFrame(columns=colnames)
        self.field_completed = pd.DataFrame(columns=colnames)
        self.searchpath = searchpath
        self.startfresh = startfresh
        self.suffix = suffix
        self.numfiles = 0
        self.directory = []
        self.mcspath = mcspath
        self.cloudflag = cloudflag
        self.localcopyflag = localcopyflag
        self.localsharepath = localsharepath
        self.localarchivepath = localarchivepath
        self.awsaccesskey = awsaccesskey
        self.overwriteh5 = overwriteh5
        self.WexacH5Path = WexacH5Path