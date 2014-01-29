#Fundamental state objects.
require_relative './dm_config'
require_relative './dm_status'

#Separate objects for separate data tasks:

#Process Objects:
require_relative './dm_downloader'          #Downloads data. TODO: refactor to 'downloader'.
require_relative './dm_converter'       #Converts data from JSON to CSV.
require_relative './dm_consolidator'    #Consolidates data into larger but fewer files.

#A simple wrapper to the pt_dm Process object.
#
#On Windows, this is made into an executable that the UI triggers, then monitors the 'shared' status file.

#--------------------------------------------------------------------------
if __FILE__ == $0  #This script code is executed when running this file.

    #Create a logger object?  TODO: currently UI does not display.
    #oLog = DM_Logger.new
    #oLog.mode = 'ui'

    p 'Triggered by UI app...'

    #Create a configuration object.
    oConfig = DM_Config.new

    oConfig.config_path = './'  #This is the default, by the way, so not mandatory in this case.
    oConfig.config_name = 'config.yaml'
    oConfig.get_config_yaml

    #Create a Status file.
    oStatus = DM_Status.new
    #And load its contents.
    oStatus.get_status
    oStatus.status = 'Starting. Checking for things to do.'

    oStatus.job_uuid = oConfig.job_uuid
    oStatus.save_status

    oWorker = DM_Downloader.new(oConfig, oStatus, nil)
    #oWorker.get_job_stats  #Nope, not gonna happen.  One-off customers do not have API access.

    if oStatus.download then  #Download files? (Always looks before it leaps)
        start = Time.now
        p 'Starting download...'
        #oWorker.get_job_stats
        oWorker.manage_downloads
        oStatus.files_local = oStatus.files_total #set progress bar to 100%
        oStatus.save_status
        sleep 2
        oStatus.download = false
        p "Spent #{Time.now - start} seconds downloading files."
    end

    #Convert files? (Always looks before it leaps)
    if (oConfig.convert_csv or oConfig.convert_csv == '1') and oStatus.convert then
        start = Time.now
        p 'Starting conversion...'
        oConverter = DM_Converter.new(oConfig, oStatus, nil)
        oConverter.convert_files
        oStatus.activities_converted = oStatus.activities_total #set progress bar to 100%
        oStatus.save_status
        sleep 2
        oStatus.convert = false
        p "Spent #{Time.now - start} seconds converting files."
    end

    #Consolidate files? (Always looks before it leaps)
    if oConfig.data_span.to_i > 0 and oStatus.consolidate
        start = Time.now
        oConsolidator = DM_Consolidator.new(oConfig, oStatus, nil)
        oConsolidator.consolidate_files
        if oStatus.files_total == 0 or oStatus.files_total.nil? then
            oStatus.files_consolidated = oStatus.files_local  #set progress bar to 100%
        else
            oStatus.files_consolidated = oStatus.files_total  #set progress bar to 100%
        end

        oStatus.save_status
        sleep 2
        oStatus.consolidate = false
        p "Spent #{Time.now - start} seconds consolidating files."
    end

    oStatus.status = 'Completed.'
    oStatus.save_status
    p 'Completed.'
    #Kernel.exit
end