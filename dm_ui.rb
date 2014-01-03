#Application gems.
require_relative './dm_config'
require_relative './dm_status'
require_relative './dm_common'

#TODO: loading 'select dir' control with 'pre-set' value.
#TODO: implement uncompressing.
#TODO: implement CSV conversion.
#TODO: implement data consolidation (with either JSON or CSV).

#App UI code.  Based on Tk.  Requires a download manager object (oConfig)
#=======================================================================================================================

#User Interface gems
#TODO: may not be needed anymore after refactor.
#module TkCore
#    RUN_EVENTLOOP_ON_MAIN_THREAD = true
#end

require 'tk'
require 'tkextlib/tile'
require 'zlib'

$enabled = false
oCommon = DM_Common.new
$os = oCommon.os

#UI actions that update app settings.
def select_data_dir(oConfig)
    #try to get rid of these globals, tweak call-backs on 'other' side
    oConfig.data_dir = Tk::chooseDirectory
    #p "Data folder set to #{oConfig.data_dir}"
    oConfig.data_dir
end

def select_consolidate_dir(oConfig)
    oConfig.consolidate_dir = Tk::chooseDirectory
    #p "Consolidate Data folder set to #{oConfig.consolidate_dir}"
    oConfig.consolidate_dir
end

def select_activity_template(oConfig)
    ftypes = [["JSON files", '*json']]
    oConfig.activity_template = Tk::getOpenFile('filetypes'=>ftypes)
    oConfig.activity_template
end

def initialize_status(oStatus)
    #Turn off everything.
    oStatus.enabled = false
    oStatus.download = false
    oStatus.convert = false
    oStatus.consolidate = false
    oStatus.save_status
end

def exit_app(oStatus)
    initialize_status(oStatus)
    Kernel.exit
end

def save_config(oConfig, oStatus)
    oConfig.user_name = $UI_user_name.value
    oConfig.password = $UI_password.value
    oConfig.account_name = $UI_account_name.value
    oConfig.job_info = $UI_job_info.value
    oConfig.set_uuid

    if oStatus.job_uuid != oConfig.job_uuid then
        #We have a new job_uuid, so clear the status
        oStatus.files_local = 0
        oStatus.files_total = 0
        oStatus.job_uuid = oConfig.job_uuid
        oStatus.activities_total = 0
        oStatus.activities_converted = 0
        oStatus.files_consolidated = 0
        oStatus.save_status
    end

    oConfig.data_dir = $UI_data_dir.value
    oConfig.uncompress_data = $UI_uncompress_data.value
    oConfig.convert_csv = $UI_convert_csv.value
    oConfig.activity_template = $UI_activity_template.value
    oConfig.consolidate_dir = $UI_consolidate_dir.value
    oConfig.data_span = $UI_data_span.value
    oConfig.save_config_yaml
end

def convert_experiment
    p 'Conversion experiment!'
end

def consolidate_data
    p 'Consolidate data...'
end

#TODO: port to somewhere else...
def uncompress_files(oConfig)

    #Just uncompress the files now directly...
    Dir.glob(oConfig.data_dir + "/*.gz") do |file_name|

        #This code throws no errors, but does nothing.
        Zlib::GzipReader.open(file_name) { |gz|
            new_name = File.dirname(file_name) + "/" + File.basename(file_name, ".*")
            g = File.new(new_name, "w")
            g.write(gz.read)
            g.close
        }
        File.delete(file_name)
    end
end

def toggle_download(oStatus)
    #p "toggle download"

    #If enabling we launch dm_worker
    # On Windows, we "shell" to the dm_worker.exe.
    # On Linux/MacOS, we also shell?  call "".\ruby dm_worker.rb""?)
    if oStatus.download == false  or oStatus.download.nil? then
        oStatus.download = true
        oStatus.save_status
        sleep 0.5
        #Update button to "Disable/stop"
        $btn_download.text = 'Stop Download'
        trigger_process
    else
        #update oStatus.enabled = false
        oStatus.download = false
        oStatus.save_status
        $btn_download.text = 'Download Data'
    end
end

def toggle_convert(oStatus)
    p "toggle convert"
    if !oStatus.convert or oStatus.convert.nil? then
        oStatus.convert = true
        oStatus.save_status
        sleep 0.5
        #Update controls.
        $btn_convert.text = 'Stop Conversion'
        trigger_process
    else
        oStatus.convert = false
        oStatus.save_status
        #Update controls.
        $btn_convert.text = 'Convert'
    end
end

def toggle_consolidate(oStatus, oConfig)
    p "toggle consolidate"
    if (!oStatus.consolidate or oStatus.consolidate.nil?) and oConfig.data_span.to_i > 0 then
        oStatus.consolidate = true
        oStatus.save_status
        sleep 0.5
        #Update controls.
        $btn_consolidate.text = 'Stop Consolidation'
        trigger_process
    else
        oStatus.consolidate = false
        oStatus.save_status
        #Update controls.
        $btn_consolidate.text = 'Consolidate'
    end
end

#When enabled, a timer process is running, which checks list of things to do.
#When enabled (running) the individual process buttons should be disabled.
#If enabling we launch dm_process.
def toggle_process(oStatus)
    p "toggle process."
    #return

    if $enabled == false then #We are getting enabled, go do work!
        $enabled = true

        #Do all.
        oStatus.enabled = true
        oStatus.download = true
        oStatus.convert = true
        oStatus.consolidate = true
        oStatus.save_status

        #While we are running, do we need to update any controls?
        $btn_process.text = "Stop Processing"
        #Disable individual process buttons.
        $btn_download.state = "disabled"
        #btn_convert.state = "disabled"
        #btn_consolidate = "disabled"

        trigger_process

    else
        #update oStatus.enabled = false
        $enabled = false

        #Turn everything off.
        oStatus.enabled = false
        oStatus.download = false
        oStatus.convert = false
        oStatus.consolidate = false
        oStatus.save_status

        #While we are running, do we need to update any controls?
        $btn_download.text = "Download Files"
        #Disable individual process buttons.
        $btn_download.state = "enabled"
        #btn_convert.state = "enabled"
        #btn_consolidate = "enabled"

    end

    #If disabling, we update the oStatus.enabled boolean to false, then dm_process gracefully (hopefully)
    # finishes current download, then exits.

    oStatus.enabled = $enabled
    oStatus.save_status
end

def trigger_process
    if $os == :windows then #OS #Windows
        process_name = 'dm_process.exe' #On Windows, we "shell" to the dm_process.exe.
    else
        process_name = 'ruby ./dm_process.rb' # On Linux/MacOS, we also shell?  call "".\ruby dm_worker.rb""?)
    end

    #Launching an external process.
    pid = spawn process_name
    Process.detach(pid) #tell the OS we're not interested in the exit status

end



#-------------------------------------------------
# Application UI code:
if __FILE__ == $0  #This script code is executed when running this file.
    #p "Creating Application object..."

    oConfig = DM_Config.new
    oConfig.config_path = './'  #This is the default, by the way, so not mandatory in this case.
    oConfig.config_name = 'config.yaml'
    #Load settings.
    oConfig.get_config_yaml
    oConfig.save_config_yaml #Creates one if needed.

    # Status.
    oStatus = DM_Status.new
    #Status object does not initialize these "process gatekeepers.
    #We may want to enable the app to automatically start-up in the future.
    #If so, we would want to remove the following initialization.
    initialize_status(oStatus)


    #============================================================================
    # Bye-bye Clean Code... entering the Tk Zone.
    #Create Tk variables. Each one maps a UI control to a config setting.
    #These are encapsulated in the DM_Config object.
    $UI_user_name = TkVariable.new
    $UI_password = TkVariable.new
    $UI_account_name = TkVariable.new
    $UI_job_info = TkVariable.new
    $UI_job_uuid = TkVariable.new
    $UI_data_dir = TkVariable.new
    $UI_uncompress_data = TkVariable.new
    $UI_consolidate_dir = TkVariable.new
    $UI_convert_csv = TkVariable.new
    $UI_activity_template = TkVariable.new
    $UI_data_span = TkVariable.new

    #Progress bar features.  Not persisted.  Generated from Status object.
    UI_progress_bar_download = TkVariable.new
    UI_progress_bar_convert = TkVariable.new
    UI_progress_bar_consolidate = TkVariable.new

    UI_status = TkVariable.new
    UI_status.value = 'Starting.'

    #Transfer oConfig values to TkVariables.
    $UI_user_name.value = oConfig.user_name
    $UI_password.value = oConfig.password
    $UI_account_name.value = oConfig.account_name
    $UI_job_info.value = oConfig.job_info
    $UI_data_dir.value = oConfig.data_dir
    $UI_uncompress_data.value = oConfig.uncompress_data
    $UI_consolidate_dir.value = oConfig.consolidate_dir
    $UI_convert_csv.value = oConfig.convert_csv
    $UI_activity_template.value = oConfig.activity_template
    $UI_data_span.value = oConfig.data_span

    #============================================================================
    #Associates above TkVariables with UI controls.

    #Start building user interface.
    root = TkRoot.new {title 'Gnip Historical PowerTrack Data Manager'}
    content = Tk::Tile::Frame.new(root) {padding '3 3 12 12'}

    #------------------------------------------------------------
    #Account Download frame.
    #------------------------------------------------------------
    account = Tk::Tile::Frame.new(content) {padding '3 3 12 12'; borderwidth 4; relief 'sunken'}.grid( :sticky => 'nsew')
    account.grid :column=>0, :row=>0#, :columnspan => 9, :rowspan => 1

    current_row = -1
    current_row = current_row + 1
    #Account
    Tk::Tile::Label.new(account) {text 'Account'}.grid( :column => 0, :row => current_row, :sticky => 'e')
    Tk::Tile::Entry.new(account) {width 30; textvariable $UI_account_name}.grid( :column => 1, :columnspan => 2, :row => current_row, :sticky => 'we' )
    #Username
    Tk::Tile::Label.new(account) {text 'Username'}.grid( :column => 3, :row => current_row, :sticky => 'e')
    Tk::Tile::Entry.new(account) {width 40; textvariable $UI_user_name}.grid( :column => 4,  :columnspan => 2, :row => current_row, :sticky => 'we' )
    #Password
    Tk::Tile::Label.new(account) {text 'Password'}.grid( :column => 6, :row => current_row, :sticky => 'e')
    Tk::Tile::Entry.new(account) {width 30; textvariable $UI_password; show "*"}.grid( :column => 7,  :columnspan => 2, :row => current_row, :sticky => 'we' )

    #------------------------------------------------------------
    #Format Download frame.
    #------------------------------------------------------------

    download = Tk::Tile::Frame.new(content) {padding '3 3 12 12'; borderwidth 4; relief 'sunken'}.grid( :sticky => 'nsew')
    download.grid :column=>0, :row=>2#, :columnspan => 9, :rowspan => 4

    current_row = current_row + 1
    #Long textbox for Data URL.  Also supports entry of job UUID.
    Tk::Tile::Label.new(download) {text 'Job UUID or Data URL'}.grid( :column => 0, :row => current_row, :sticky => 'e')
    Tk::Tile::Entry.new(download) {width 90; textvariable $UI_job_info}.grid( :column => 1, :columnspan => 8, :row => current_row, :sticky => 'we' )

    current_row = current_row + 1
    #Data folder widgets. Label, TextBox, and Button that activates the ChooseDir standard dialog.
    Tk::Tile::Label.new(download) {text 'Data Directory'}.grid( :column => 0, :row => current_row, :sticky => 'e')
    Tk::Tile::Entry.new(download) {width 15; textvariable $UI_data_dir}.grid( :column => 1, :columnspan => 8, :row => current_row, :sticky => 'we' )
    Tk::Tile::Button.new(download) {text 'Select Dir'; width 15; command {$UI_data_dir.value=select_data_dir(oConfig)}}.grid( :column => 8, :row => current_row, :sticky => 'e')

    current_row = current_row + 1
    #Uncompress data?
    Tk::Tile::CheckButton.new(download) {text 'Uncompress data files'; variable $UI_uncompress_data; set_value $UI_uncompress_data.to_s; }.grid( :column => 1, :row => current_row, :sticky => 'w')
    #Do it now?
    Tk::Tile::Button.new(download) {text ' '; width 3; command {uncompress_files(oConfig)}}.grid( :column => 2, :row => current_row, :sticky => 'w')
    $btn_download = Tk::Tile::Button.new(download) {text 'Download Files'; width 15; command {toggle_download(oStatus)}}.grid( :column => 8, :row => current_row, :sticky => 'e')

    #Download Progress Bar details.
    current_row = current_row + 1
    Tk::Tile::Label.new(download) {text '   '}.grid( :column => 0, :row => current_row, :sticky => 'w')
    progress_bar_download = Tk::Tile::Progressbar.new(download) {orient 'horizontal'; }.grid( :column => 1, :columnspan =>8, :row => current_row, :sticky => 'we')
    progress_bar_download.maximum = 100
    progress_bar_download.variable = UI_progress_bar_download

    current_row = current_row + 1
    $status_label = Tk::Tile::Label.new(download) {text 'Status:'}.grid( :column => 1, :row => current_row, :columnspan => 3, :sticky => 'w')


    #------------------------------------------------------------
    #Format Conversion frame.
    #------------------------------------------------------------

    conversion = Tk::Tile::Frame.new(content) {padding '3 3 12 12'; borderwidth 4; relief 'sunken'}.grid( :sticky => 'nsew')
    conversion.grid :column=>0, :row=>9#, :columnspan => 9, :rowspan => 4
    #Data conversion widgets.
    current_row = current_row + 1
    #Convert to CSV?
    Tk::Tile::CheckButton.new(conversion) {text 'Convert from JSON to CSV   '; variable $UI_convert_csv; set_value $UI_convert_csv.to_s; }.grid( :column => 0, :row => current_row, :sticky => 'w')


    #Conversion Progress Bar details.
    #current_row = current_row + 1
    progress_bar_convert = Tk::Tile::Progressbar.new(conversion) {orient 'horizontal'; }.grid( :column => 3, :columnspan =>6, :row => current_row, :sticky => 'e')
    progress_bar_convert.maximum = 100
    progress_bar_convert.variable = UI_progress_bar_convert
    $btn_convert = Tk::Tile::Button.new(conversion) {text 'Convert'; width 15; command {toggle_convert(oStatus)}}.grid( :column => 9, :row => current_row, :sticky => 'e')

    #Conversion Template file.
    current_row = current_row + 1
    #Data folder widgets. Label, TextBox, and Button that activates the ChooseDir standard dialog.
    Tk::Tile::Label.new(conversion) {text 'JSON Template File'}.grid( :column => 0, :row => current_row, :sticky => 'e')
    Tk::Tile::Entry.new(conversion) {width 15; textvariable $UI_activity_template}.grid( :column => 1, :columnspan => 7, :row => current_row, :sticky => 'we' )
    Tk::Tile::Button.new(conversion) {text 'Select File'; width 15; command {$UI_activity_template.value=select_activity_template(oConfig)}}.grid( :column => 9, :row => current_row, :sticky => 'e')
    current_row = current_row + 1
    $btn_experiment = Tk::Tile::Button.new(conversion) {text 'Test Conversion'; width 15; command {convert_experiment}}.grid( :column => 9, :row => current_row, :sticky => 'e')


    #------------------------------------------------------------
    #Consolidation frame.
    #------------------------------------------------------------

    consolidation = Tk::Tile::Frame.new(content) {padding '3 3 12 12'; borderwidth 4; relief 'sunken'}.grid( :sticky => 'nsew')
    consolidation.grid :column=>0, :row=>13#, :columnspan => 9, :rowspan => 3

    #Consoliation output folder... TODO: Needed?  Just use temp folder?
    #current_row = current_row + 1
    #Data Aggregation Output Folder.
    #Tk::Tile::Label.new(consolidation) {text 'Data Consolidation Directory'}.grid( :column => 0, :row => current_row, :sticky => 'e')
    #Tk::Tile::Entry.new(consolidation) {width 84; textvariable $UI_consolidate_dir}.grid( :column => 1, :row => current_row, :columnspan => 9, :sticky => 'we' )
    #Tk::Tile::Label.new(consolidation) {text '        '}.grid( :column => 4, :row => current_row, :sticky => 'e')    #Empty label as a spacer...
    #Tk::Tile::Button.new(consolidation) {text 'Select Dir'; width 15; command {$UI_consolidate_dir.value = select_consolidate_dir(oConfig)};state "disabled"}.grid( :column => 10, :row => current_row, :sticky => 'e')

    current_row = current_row + 1
    Tk::Tile::Label.new(consolidation) {text 'Data Consolidation'}.grid( :column => 0, :row => current_row, :sticky => 'e')
    Tk::Tile::RadioButton.new(consolidation) {text 'None'; variable $UI_data_span; value 0}.grid( :column => 3, :row => current_row, :sticky => 'w')
    Tk::Tile::RadioButton.new(consolidation) {text '1-hour'; variable $UI_data_span; value 1}.grid( :column => 4, :row => current_row, :sticky => 'w')
    Tk::Tile::RadioButton.new(consolidation) {text '1-day'; variable $UI_data_span; value 2}.grid( :column => 5, :row => current_row, :sticky => 'w')
    Tk::Tile::RadioButton.new(consolidation) {text 'Single File'; variable $UI_data_span; value 3; }.grid( :column => 6, :row => current_row, :sticky => 'w')

    #Consolidation Progress Bar details.
    #current_row = current_row + 1
    progress_bar_consolidate = Tk::Tile::Progressbar.new(consolidation) {orient 'horizontal'; }.grid( :column => 7, :columnspan =>3, :row => current_row, :sticky => 'e')
    progress_bar_consolidate.maximum = 100
    progress_bar_consolidate.variable = UI_progress_bar_consolidate

    $btn_consolidate = Tk::Tile::Button.new(consolidation) {text 'Consolidate '; width 15; command {toggle_consolidate(oStatus,oConfig)}}.grid( :column => 11, :row => current_row, :sticky => 'e')

    #-----------------------------------------
    app_buttons = Tk::Tile::Frame.new(content) {padding '3 3 12 12'; borderwidth 4; relief 'sunken'}.grid( :sticky => 'nsew')
    app_buttons.grid :column=>0, :row=>16#, :columnspan => 9, :rowspan => 1
    current_row = current_row + 1
    Tk::Tile::Button.new(app_buttons) {text 'Save Settings'; width 15; command {save_config(oConfig,oStatus)}}.grid( :column => 1, :row => current_row, :sticky => 'w')
    Tk::Tile::Button.new(app_buttons) {text 'Exit'; width 15; command {exit_app(oStatus)}}.grid( :column => 4, :row => current_row, :sticky => 'w')
    $btn_process = Tk::Tile::Button.new(app_buttons) {text 'Process Data'; width 15; command {toggle_process(oStatus)}}.grid( :column => 10, :row => current_row, :sticky => 'e')



    #-----------------------------------------

    #Tweak Progress Bar size depending on OS.
    if $os == :windows then
        #TODO: these need to be tweaked during next round of Windows testing.
        progress_bar_download.length = 770
        progress_bar_convert.length = 530
        progress_bar_consolidate.length = 370
    else
        progress_bar_download.length = 900
        progress_bar_convert.length = 600
        progress_bar_consolidate.length = 500
    end

    content.grid :column => 0, :row => 0, :sticky => 'nsew'

    TkGrid.columnconfigure root, 0, :weight => 1
    TkGrid.rowconfigure root, 0, :weight => 1

    #This initializes the progress bar, called only at startup.
    oStatus.get_status
    oStatus.files_local = oCommon.count_local_files(oConfig.data_dir,oStatus.job_uuid)
    oStatus.save_status

    i = 1
    tick = proc{|o|

        begin

            #p 'UI timer...'

            oStatus.get_status

            #Are we downloading?
            if oStatus.download then

                p 'UI Timer: download!'

                if oStatus.job_uuid != oConfig.job_uuid then
                    #We have a new job_uuid, so clear the status
                    oStatus.files_local = 0
                    oStatus.files_total = 0
                    oStatus.job_uuid = oConfig.job_uuid
                    oStatus.activities_total = 0
                    oStatus.activities_converted = 0
                    oStatus.files_consolidated = 0
                    oStatus.save_status
                end

                #Pull oStatus attributes for UI display --> status note, progress bar.
                UI_progress_bar_download.value = (oStatus.files_local.to_f/oStatus.files_total.to_f) * 100
                i = i + 1

                $status_label.text = "Have downloaded #{oStatus.files_local} of #{oStatus.files_total} files."

                if (oStatus.files_local.to_f == oStatus.files_total.to_f) and oStatus.files_total.to_f > 0 then
                    $status_label.text = $status_label.text + '  Finished.'
                    oStatus.enabled = false
                    oStatus.download = false
                    $enabled = false
                    oStatus.save_status
                    $btn_download.text = 'Download Data'
                end
            end

            #Are we converting?
            if oStatus.convert then
                #p 'UI Timer: convert!'

                #Update conversion progress bar.
                UI_progress_bar_convert.value = (oStatus.activities_converted.to_f / oStatus.activities_total.to_f) * 100

            else
                $btn_convert.text = 'Convert'
            end

            #Are we consolidating?
            if oStatus.consolidate and oConfig.data_span.to_i > 0 then
                p 'UI Timer: consolidate!'

                #Update consolidation progress bar.
                UI_progress_bar_consolidate.value = (oStatus.files_consolidated.to_f / oStatus.files_total.to_f) * 100

            else
                $btn_consolidate.text = 'Consolidate'
            end

        rescue
           p 'ERROR in main timer, keep going!'
        end
    }

    timer = TkTimer.new(500, -1, tick )
    timer.start(0)

    #This script code is executed when running this file.
    #p "Starting Download Manager application..."
    Tk.mainloop

end

