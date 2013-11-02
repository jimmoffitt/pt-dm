#This is a wrapper to the DM_Worker class.  This is the headless version of the "download manager."  (the other version has a UI)
#Script uses a config.yaml file to download Historical PowerTrack data files (see the DM_Config class for details).
#Scripts looks in the local directory for the configuration file (anticipated normal use-case).
#Creates an empty config file if one is not found in the local directory.
#Using this method to determine whether a password has been base64.encoded:
#       http://stackoverflow.com/questions/8571501/how-to-check-whether-the-string-is-base64-encoded-or-not
#

require_relative "./dm_config"
require_relative "./dm_status"
require_relative "./dm_worker"

#So far this is used only with this DM script code... so stuck here for now...
#Could/should evolve into a sample PT logger.
class DM_Logger

    attr_accessor :mode #UI or (headless) script | script --> console, UI --> textbox?

    def initialize
        mode = "script"
    end

    def message(message)
        if mode == "script" then
            p message
        else
            #TODO: where to display on UI? How to 'callback'?
        end
    end
end


#--------------------------------------------------------------------------
if __FILE__ == $0  #This script code is executed when running this file.

    #Create a logger object.
    oLog = DM_Logger.new
    oLog.mode = 'script'

    #Create a configuration object.
    oConfig = DM_Config.new

    oConfig.config_path = "./"  #This is the default, by the way, so not mandatory in this case.
    oConfig.config_name = "config.yaml"
    config_file = oConfig.config_path + oConfig.config_name

    #See if a configuration file exists.  If not, create one and exit.
    if !File.exists?(config_file) then

        #Trigger the creation of the config file and exit.
        oConfig.save_config_yaml

        #Tell user.
        oLog.message "Created empty configuration file at '#{oConfig.config_path}#{oConfig.config_file}'"
        oLog.message "Please open and complete configuration and restart this application."
        oLog.message "Press ENTER to continue..."
        gets

        exit
    end

    oConfig.get_config_yaml

    #Create a Status file.
    oStatus = DM_Status.new
    oStatus.status = "Starting"
    oStatus.enabled = true

    oStatus.save_status

    oWorker = DM_Worker.new(oConfig, oStatus, oLog)
    oWorker.download_files

    oLog.message "Finished."
    oLog.message "Press ENTER to continue..."
    gets
end

