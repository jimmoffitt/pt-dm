#Application gems.
require_relative './dm_config'
require_relative './dm_status'
require_relative './dm_common'

#TODO: loading 'select dir' control with 'pre-set' value.

#App UI code.  Based on Tk.  Requires a download manager object (oConfig)
#=======================================================================================================================

#User Interface gems
#TODO: may not be needed anymore after refactor. Need to retest on Windows.  Not needed on Linux/MacOS.
#module TkCore
#    RUN_EVENTLOOP_ON_MAIN_THREAD = true
#end

require 'tk'
require 'tkextlib/tile'
require 'zlib'

APP_TITLE = 'Gnip Historical PowerTrack File Manager'

#UI defaults
BUTTON_WIDTH = 15

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

def test_convert
    p 'Conversion experiment!'
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
    root = TkRoot.new {title APP_TITLE}
    content = Tk::Tile::Frame.new(root) {padding '3 3 12 12'}

    #------------------------------------------------------------
    #Account details.
    #------------------------------------------------------------

    lbl_account = Tk::Tile::Label.new(content) {text 'Account'}
    txt_account = Tk::Tile::Entry.new(content) {width 25; textvariable $UI_account_name}
    #Username
    lbl_username = Tk::Tile::Label.new(content) {text 'Username'}
    txt_username = Tk::Tile::Entry.new(content) {width 45; textvariable $UI_user_name}
    #Password
    lbl_password = Tk::Tile::Label.new(content) {text 'Password'}
    txt_password = Tk::Tile::Entry.new(content) {width 35; textvariable $UI_password; show "*"}


    #------------------------------------------------------------
    #Download details.
    #------------------------------------------------------------
    #Long textbox for Data URL.  Also supports entry of job UUID.
    lbl_download = Tk::Tile::Label.new(content) {text 'Download Data Files'}
    lbl_uuid = Tk::Tile::Label.new(content) {text 'Job UUID or Data URL'}
    txt_uuid = Tk::Tile::Entry.new(content) {width 90; textvariable $UI_job_info}

    #Data folder widgets. Label, TextBox, and Button that activates the ChooseDir standard dialog.
    lbl_data_dir = Tk::Tile::Label.new(content) {text 'Data Directory'}
    txt_data_dir = Tk::Tile::Entry.new(content) {width 15; textvariable $UI_data_dir}
    btn_data_dir = Tk::Tile::Button.new(content) {text '... '; width 5; command {$UI_data_dir.value=select_data_dir(oConfig)}}

    #Uncompress data?
    chk_uncompress = Tk::Tile::CheckButton.new(content) {text 'Uncompress data files'; variable $UI_uncompress_data; set_value $UI_uncompress_data.to_s; }
    #Do it now?
    btn_uncompress = Tk::Tile::Button.new(content) {text 'Now'; width 5; command {uncompress_files(oConfig)}}
    $btn_download = Tk::Tile::Button.new(content) {text 'Download'; width BUTTON_WIDTH; command {toggle_download(oStatus)}}

    #Download Progress Bar details.
    progress_bar_download = Tk::Tile::Progressbar.new(content) {orient 'horizontal'; }
    progress_bar_download.maximum = 100
    progress_bar_download.variable = UI_progress_bar_download

    $status_label_download = Tk::Tile::Label.new(content) {text 'Status:'}


    #------------------------------------------------------------
    #Conversion details.
    #------------------------------------------------------------

    #Data conversion widgets.
    #Convert to CSV?
    chk_convert = Tk::Tile::CheckButton.new(content) {text 'Convert from JSON to CSV   '; variable $UI_convert_csv; set_value $UI_convert_csv.to_s; }
    $btn_convert = Tk::Tile::Button.new(content) {text 'Convert'; width BUTTON_WIDTH; command {toggle_convert(oStatus)}}

    #Test controls.
    $btn_test = Tk::Tile::Button.new(content) {text 'Test'; width BUTTON_WIDTH; command {test_convert}}

    #Conversion Template file.
    #Data folder widgets. Label, TextBox, and Button that activates the ChooseDir standard dialog.
    lbl_template = Tk::Tile::Label.new(content) {text 'JSON Template File'}
    txt_template = Tk::Tile::Entry.new(content) {width 15; textvariable $UI_activity_template}
    btn_template = Tk::Tile::Button.new(content) {text '...'; width 5; command {$UI_activity_template.value=select_activity_template(oConfig)}}

    #Conversion Progress Bar details.
    progress_bar_convert = Tk::Tile::Progressbar.new(content) {orient 'horizontal'; }
    progress_bar_convert.maximum = 100
    progress_bar_convert.variable = UI_progress_bar_convert

    $status_label_convert = Tk::Tile::Label.new(content) {text 'Status:'}


    #------------------------------------------------------------
    #Consolidation frame.
    #------------------------------------------------------------

    #Consoliation output folder... TODO: Needed?  Just use temp folder?
    #Data Aggregation Output Folder.
    #Tk::Tile::Label.new(consolidation) {text 'Data Consolidation Directory'}
    #Tk::Tile::Entry.new(consolidation) {width 84; textvariable $UI_consolidate_dir}
    #Tk::Tile::Label.new(consolidation) {text '        '}
    #Tk::Tile::Button.new(consolidation) {text 'Select Dir'; width 15; command {$UI_consolidate_dir.value = select_consolidate_dir(oConfig)};state "disabled"}

    lbl_consolidate = Tk::Tile::Label.new(content) {text 'Data Consolidation'}
    rd_data_span_0 = Tk::Tile::RadioButton.new(content) {text 'None'; variable $UI_data_span; value 0; }
    rd_data_span_1 = Tk::Tile::RadioButton.new(content) {text '1-hour'; variable $UI_data_span; value 1; }
    rd_data_span_2 = Tk::Tile::RadioButton.new(content) {text '1-day'; variable $UI_data_span; value 2; }
    rd_data_span_3 = Tk::Tile::RadioButton.new(content) {text 'Single File'; variable $UI_data_span; value 3; }
    rd_data_span_4 = Tk::Tile::RadioButton.new(content) {text '10 MB Files'; variable $UI_data_span; value 4; }
    $btn_consolidate = Tk::Tile::Button.new(content) {text 'Consolidate '; width BUTTON_WIDTH; command {toggle_consolidate(oStatus,oConfig)}}

    #Consolidation Progress Bar details.
    progress_bar_consolidate = Tk::Tile::Progressbar.new(content) {orient 'horizontal'; }
    progress_bar_consolidate.maximum = 100
    progress_bar_consolidate.variable = UI_progress_bar_consolidate


    #-----------------------------------------
    btn_save = Tk::Tile::Button.new(content) {text 'Save Settings'; width 15; command {save_config(oConfig,oStatus)}}
    btn_exit = Tk::Tile::Button.new(content) {text 'Exit'; width 15; command {exit_app(oStatus)}}
    $btn_process = Tk::Tile::Button.new(content) {text 'Do All'; width BUTTON_WIDTH; command {toggle_process(oStatus)}}


    #-----------------------------------------

    #Tweak Progress Bar size depending on OS.
    if $os == :windows then
        #TODO: these need to be tweaked during next round of Windows testing.
        progress_bar_download.length = 770
        progress_bar_convert.length = 770
        progress_bar_consolidate.length = 770
        btn_uncompress.width = 200
    else
        progress_bar_download.length = 900
        progress_bar_convert.length = 900
        progress_bar_consolidate.length = 900
    end

    content.grid :column => 0, :row => 0, :sticky => 'nsew'

    current_row = -1
    current_row = current_row + 1

    #Account details ---------------------------------------------------------------------------------------------------

    #Set up grid positions
    lbl_account.grid :row => current_row, :column => 0, :columnspan => 1, :sticky => 'e'
    txt_account.grid :row => current_row, :column => 2, :columnspan => 2, :sticky => 'w'
    lbl_username.grid :row => current_row, :column => 4, :columnspan => 1, :sticky => 'w'
    txt_username.grid :row => current_row, :column => 5, :columnspan => 1,  :sticky => 'w'
    lbl_password.grid :row => current_row, :column => 6, :columnspan => 1, :sticky => 'w'
    txt_password.grid :row => current_row, :column => 7, :columnspan => 2, :sticky => 'w'

    #---------------------------------------------
    current_row = current_row + 1
    lbl_space_1 = Tk::Tile::Label.new(content) {text ' '}.grid( :row => current_row, :column => 0)
    current_row = current_row + 1
    lbl_space_1b = Tk::Tile::Label.new(content) {text ' '}.grid( :row => current_row, :column => 0)
    current_row = current_row + 1
    sep_1 = Tk::Tile::Separator.new(content) { orient 'horizontal'}.grid( :row => current_row, :columnspan => 10, :sticky => 'we')


    #Download details---------------------------------------------------------------------------------------------------
    current_row = current_row + 1
    lbl_download.grid :row => current_row, :column => 0, :columnspan => 2
    current_row = current_row + 1
    lbl_uuid.grid :row => current_row, :column => 0, :columnspan => 3, :sticky => 'e'
    txt_uuid.grid :row => current_row, :column => 3, :columnspan => 6, :sticky => 'we'

    current_row = current_row + 1
    lbl_data_dir.grid :row => current_row, :column => 0, :columnspan => 3, :sticky => 'e'
    txt_data_dir.grid :row => current_row, :column => 3, :columnspan => 6, :sticky => 'we'
    btn_data_dir.grid :row => current_row, :column => 8, :columnspan => 1, :sticky => 'e'

    current_row = current_row + 1
    chk_uncompress.grid :row => current_row, :column => 3, :columnspan => 1
    btn_uncompress.grid :row => current_row, :column => 4, :columnspan => 1

    current_row = current_row + 1
    progress_bar_download.grid :row => current_row, :column => 3, :columnspan => 6,:sticky => 'we'

    current_row = current_row + 1
    $status_label_download.grid :row => current_row, :column => 3, :columnspan => 8,:sticky => 'w'
    $btn_download.grid :row => current_row, :column => 8, :columnspan => 1, :sticky => 'e'
    #---------------------------------------------
    current_row = current_row + 1
    lbl_space_2 = Tk::Tile::Label.new(content) {text ' '}.grid( :row => current_row, :column => 0)
    current_row = current_row + 1
    lbl_space_2b = Tk::Tile::Label.new(content) {text ' '}.grid( :row => current_row, :column => 0)
    current_row = current_row + 1
    sep_2 = Tk::Tile::Separator.new(content) { orient 'horizontal'}.grid( :row => current_row, :columnspan => 10, :sticky => 'we')

    #Conversion details-------------------------------------------------------------------------------------------------
    current_row = current_row + 1
    chk_convert.grid :row => current_row, :column => 0, :columnspan => 4,:sticky => 'w'

    $btn_test.grid :row => current_row, :column => 8, :columnspan => 1, :sticky => 'e'
    current_row = current_row + 1
    lbl_template.grid :row => current_row, :column => 0, :columnspan => 3, :sticky => 'e'
    txt_template.grid :row => current_row, :column => 3, :columnspan => 6, :sticky => 'we'
    btn_template.grid :row => current_row, :column => 8, :columnspan => 1, :sticky => 'e'
    #$btn_experiment

    current_row = current_row + 1
    progress_bar_convert.grid :row => current_row, :column => 3, :columnspan => 6,:sticky => 'we'

    current_row = current_row + 1
    $status_label_convert.grid :row => current_row, :column => 3, :columnspan => 8,:sticky => 'w'
    $btn_convert.grid :row => current_row, :column => 8, :columnspan => 1, :sticky => 'e'

    #---------------------------------------------
    current_row = current_row + 1
    lbl_space_3 = Tk::Tile::Label.new(content) {text ' '}.grid( :row => current_row, :column => 0)
    current_row = current_row + 1
    lbl_space_3b = Tk::Tile::Label.new(content) {text ' '}.grid( :row => current_row, :column => 0)
    current_row = current_row + 1
    sep_3 = Tk::Tile::Separator.new(content) { orient 'horizontal'}.grid( :row => current_row, :columnspan => 10, :sticky => 'we')

    #Consolodation details----------------------------------------------------------------------------------------------
    current_row = current_row + 1
    lbl_consolidate.grid :row => current_row, :column => 0, :columnspan => 2
    rd_data_span_0.grid :row => current_row, :column => 2, :columnspan => 1#, :sticky => 'ew'
    rd_data_span_1.grid :row => current_row, :column => 3, :columnspan => 1#, :sticky => 'ew'
    rd_data_span_2.grid :row => current_row, :column => 4, :columnspan => 1#, :sticky => 'ew'
    rd_data_span_3.grid :row => current_row, :column => 5, :columnspan => 1#, :sticky => 'ew'
    rd_data_span_4.grid :row => current_row, :column => 6, :columnspan => 1#, :sticky => 'ew'

    current_row = current_row + 1
    progress_bar_consolidate.grid :row => current_row, :column => 3, :columnspan => 6,:sticky => 'we'
    current_row = current_row + 1
    $btn_consolidate.grid :row => current_row, :column => 8, :columnspan => 1, :sticky => 'e'

    current_row = current_row + 1

    #---------------------------------------------
    current_row = current_row + 1
    lbl_space_4 = Tk::Tile::Label.new(content) {text ' '}.grid( :row => current_row, :column => 0)
    current_row = current_row + 1
    lbl_space_4b = Tk::Tile::Label.new(content) {text ' '}.grid( :row => current_row, :column => 0)
    current_row = current_row + 1
    sep_4 = Tk::Tile::Separator.new(content) { orient 'horizontal'}.grid( :row => current_row, :columnspan => 10, :sticky => 'we')

    #Application details------------------------------------------------------------------------------------------------
    current_row = current_row + 1
    btn_save.grid :row => current_row, :column => 0, :columnspan => 2, :sticky => 'e'
    btn_exit.grid :row => current_row, :column => 2, :columnspan => 2
    $btn_process.grid :row => current_row, :column => 8, :columnspan => 1, :sticky => 'e'


    TkGrid.columnconfigure root, 0, :weight => 1
    TkGrid.rowconfigure root, 0, :weight => 1

    #This initializes the progress bar, called only at startup.
    oStatus.get_status
    oStatus.files_local = oCommon.count_local_files(oConfig.data_dir,oStatus.job_uuid)
    oStatus.save_status

    i = 1
    tick = proc{|o|

        begin #UI event loop.

            #p 'UI timer...'

            oStatus.get_status

            #Are we downloading?
            if oStatus.download then

                #p 'UI Timer: download!'

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

                $status_label_download.text = "Have downloaded #{oStatus.files_local} of #{oStatus.files_total} files."

                if (oStatus.files_local.to_f == oStatus.files_total.to_f) and oStatus.files_total.to_f > 0 then
                    $status_label_download.text = $status_label_download.text + '  Finished.'
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

                $status_label_convert.text = "Have converted #{oStatus.activities_converted} of #{oStatus.activities_total} activities."

                if (oStatus.activities_converted.to_f == oStatus.activities_total.to_f) and oStatus.activities_total.to_f > 0 then
                    $status_label_convert.text = $status_label_convert.text + '  Finished.'
                    oStatus.enabled = false
                    oStatus.convert = false
                    $enabled = false
                    oStatus.save_status
                    $btn_convert.text = 'Convert Data'
                end
            else
                $btn_convert.text = 'Convert'
            end

            #Are we consolidating?
            if oStatus.consolidate and oConfig.data_span.to_i > 0 then
                #p 'UI Timer: consolidate!'

                #Update consolidation progress bar.
                if oStatus.files_total == 0 or oStatus.files_total.nil? then
                    UI_progress_bar_consolidate.value = (oStatus.files_consolidated.to_f / oStatus.files_local.to_f) * 100
                else
                    UI_progress_bar_consolidate.value = (oStatus.files_consolidated.to_f / oStatus.files_total.to_f) * 100
                end

            else
                $btn_consolidate.text = 'Consolidate'
            end

        rescue
           p 'ERROR in main timer (*but keep going*)!'
        end
    }

    #-------------------------------------------------------------------------------------------------------------------
    #Timer hits tick loop every interval--------------------------------------------------------------------------------
    timer = TkTimer.new(500, -1, tick )
    timer.start(0)

    #This script code is executed when running this file.
    #p "Starting Download Manager application..."
    Tk.mainloop

end

