# encoding: UTF-8

#This class knows what it takes to consolidate Historical PowerTrack data files.

#With either JSON or CSV, we just open sub-files and write to super file in same format.
#Currently works with a single folder, and files are consumed as they transition from start to finish.

#data spans == "none", "hour", "day", "all"

#First use-cases
# ==> 10-minute JSON files --> hour JSON files
# ==> 10-minute CSV files --> hour CSV files

#Next use-cases
# ==> 10-minute JSON files --> day JSON files
# ==> 10-minute JSON files --> single JSON file

#"Source" files refer to the (shorter time duration) files we are consolidating.
#"Target" files refer to the (longer time duration) files we are generating.


#NOTES:

#IMPORTANT: this code does not parse data contents, and timestamp timezone are not yet managed.
#I.E., timestamps from filenames are loaded in Time.new objects and left in LOCAL timezone.
#All Historical PowerTrack file names embed timestamps which are in UTC.  We don't really care
#and we are not performing any TZ conversions...

#The method consolidate_files pushes back id uuid.gz files are found.

#Loop math and logic are based on Time objects.
#timestamps are converted to YYYYMMDDHHMM for file handling.

#Everything stays in UTC.  No TZ conversions!
#Consolidated datestamps are cropped to even day/hour timestamps.
#File START times are INCLUSIVE.
#File END times are EXCLUSIVE. (and are not usually used in file names)

#What are the file name conventions?
#@config.data_dir/20130914-20130915_51x5jqgsrk201309140000_activities.csv
#@config.data_dir/20130914-20130915_51x5jqgsrk201309140010_activities.csv

#Filenames?
#@filename_preface = 20130914-20130915_
#@filename_uuid = 51x5jqgsrk
#@filename_datestamp = 201309140000 #Start time!  YYYYMMDDHHMM
#@filename_prelude = _activities
#@filename_ext = csv, json, gz

#Source
#@filename = #@filename_preface + @filename_uuid + @filename_datestamp + @filename_prelude + . + @filename_ext
#Target
#if span_str != all
#@filename = @filename_uuid + @filename_datestamp + _ + @span_str + . + @filename_ext
#if span_str == all
#@filename = @filename_uuid + _ + @span_str + . + @filename_ext

=begin
201309140000 ==> 201309140000_hr
201309140100
201309140010
201309140020
201309140030
201309140040
201309140050 ==> 201309140000_hr
201309140100 ==> 201309140100_hr
201309140110

             ==> 201309140000_day
             ==> 201309150000_day

             ==> _all
=end


#TODO: push data_span = 1/2/3 details up to UI?  Have 10/60/1440/9999 enums?  "10-minute,hour,day,all" string enums?

require_relative './dm_config'
require_relative './dm_status'
require_relative './dm_logger'  #Not implemented yet.

class DM_Consolidator

    require 'time'
    require 'rake'

    ALL_MINUTES = 999999


    attr_accessor :config, #--> oConfig.data_span is set by user and = ending data span.
                  :status, #Fundamental state objects.

                  #There are about where we are starting.
                  :span_source,   #==>  #0-None, 1-hour, 2-day, or 3-all - inferred from filename metadata.
                  :span_source_minutes,
                  :span_source_marker,
                  #Date span of all, boundary conditions.
                  :set_source_start,
                  :set_source_end,
                  #File we are pulling from.
                  :file_source_start,
                  :file_source_end,

                  #These are about where we are going with consolidation.
                  :span_target,   #config.data_span ==>  #0-None, 1-hour, 2-day, or 3-all
                  :span_target_minutes,
                  :span_target_marker,
                  #Date span of all, boundary conditions.
                  :set_target_start,
                  :set_target_end,
                  #File we are generating from.
                  :file_target_start,
                  :file_target_end,

                  :filename_target_template,

                  :file_name_tokens,
                  :filename_preface,
                  :filename_ext


    def initialize(config, status = nil, logger = nil)
        @config = config

        if status.nil? then
            @status = DM_Status.new
        else
            @status = status
        end

        if logger.nil? then
            @logger = DM_Logger.new
        else
            @logger = logger
        end

        @span_target_marker = "none"
        @span_target_minutes = 0
    end

    #TODO: Not sure this is needed, but may come in handy for notifications/logging.
    def get_span_name(span)

        span = span.to_s

        case span
            when '0'
                nil
            when '1'
                'hour'
            when '2'
                'day'
            when '3'
                'all'
            else
                'error'
        end
    end


    #Set the span timestamps for the files we are creating (target files).
    def set_span_target_details(span_target)

        span_target = span_target.to_s

        case span_target
            #when '0' indicates an error, and implies there is no consolidation to perform.
            when '1'
                @span_target_minutes = 60
                @span_target_marker = 'hr'
            when '2'
                @span_target_minutes = 24 * 60
                @span_target_marker = 'day'
            when '3'
                @span_target_minutes = ALL_MINUTES
                @span_target_marker = 'all'
            else
                p 'Error getting minutes in data_span'
                @span_target_minutes = -1
                @span_target_marker = '_error_' #make visually obvious.
                @span_target = '0'
        end
    end

    def get_span_minutes(token)
        case token
            when 'activities'
                return 10
            when 'hr'
                return 60
            when 'day'
                return 24 * 60
            when 'all'
                return ALL_MINUTES
            else
                return -1
        end
    end

    #---------------------------
    #Sets the 'boundary conditions' for the file set we are producing.
    #This boundaries drive the fundamental file building loop.
    #Essentially 'snaps' start time back to integral span, and end time forward to integral time.
    #Start times:
    #Snaps 201311260340 --> 201311260300_hr
    #Snaps 201311260340 --> 201311260000_day
    #End times:
    #Snaps 201312040340 --> 201312040400_hr
    #Snaps 201312040340 --> 201312050000_day

    def set_target_times

        #Set defaults
        @set_target_start = @set_source_start
        @set_target_end = @set_source_end


        if @span_target_minutes == 0 then
            set_span_target_details(@span_target)
        end

        #Now snap appropriately!
        case @span_target_minutes
            when 60
                #snapping back to even hour.
                if @set_source_start.min > 0 then
                    @set_target_start = Time.utc(@set_source_start.year, @set_source_start.month, @set_source_start.day,@set_source_start.hour,0)
                end

                #snapping forward to even hour.
                if @set_source_end.min > 0 then
                    @set_target_end = Time.utc(@set_source_end.year, @set_source_end.month, @set_source_end.day, @set_source_end.hour + 1,0)
                end
            when 24 * 60
                #snapping back to even day.
                if @set_source_start.hour > 0 or @set_source_start.min then
                    @set_target_start = Time.utc(@set_source_start.year, @set_source_start.month, @set_source_start.day, 0 ,0)
                end

                #snapping forward to even day.
                if @set_source_end.hour > 0 then
                    @set_target_end = Time.utc(@set_source_end.year, @set_source_end.month, @set_source_start.day + 1, 0 ,0)
                end

            when ALL_MINUTES
                #All done.
        end
    end


    def get_file_time(filename)
        begin
            file_name_tokens = []
            file_name_tokens = filename.split(/[._]/)
            date_str = file_name_tokens[-3].gsub!(@config.job_uuid,'')
            date_str = "#{date_str[0..3]}-#{date_str[4..5]}-#{date_str[6..7]} #{date_str[8..9]}:#{date_str[10..11]} UTC"
            time = Time.parse(date_str)
        rescue
            p "Error parsing timestamp from filename."
        end
    end

    #---------------------------
    def set_source_times(filename)
        time = get_file_time(filename)

        #Compare with start and update it needed.
        if @set_source_start.nil? or time < @set_source_start then
            @set_source_start = time
        end

        file_name_tokens = []
        file_name_tokens = filename.split(/[._]/)

        #Examine the filename token indicating the span and use that to set end date.
        span_minutes = get_span_minutes(file_name_tokens[-2])
        time = time + (span_minutes * 60)

        if @set_source_end.nil? or time > @set_source_end then
            @set_source_end = time
        end
    end

    #---------------------------
    #Method follows 'standard' PowerTrack convention that file date stamps mark start of contents' times.
    #HPT Filename pattern: 20130914-20130915_51x5jqgsrk201309140000_activities
    #                      ########-#######_#{config.job_uuid}#{@file_start}_activities
    #           WHERE file_start is YYYYMMDDHHMM
    #                 file_end = file_start + data_span

    def set_file_times(filename)


        #if filename ends in _activities, then this is a 10-min HPT file.
        #Otherwise it ends in _hr _day or _all
        file_name_tokens = []
        file_name_tokens = filename.split(/[._]/)

        date_str = file_name_tokens[-3].gsub!(@config.job_uuid,'')
        time = Time.utc
        @file_start = Time.parse(date_str)
        @file_end = @file_start + (60 * @span_minutes)


        if @file_start < @set_start then
            @set_start = @file_start
        end

        if @file_end > @set_end then
            @set_end = @file_end
        end
    end


    #What are the file name conventions?
    #@config.data_dir/20130914-20130915_51x5jqgsrk201309140000_activities.csv
    #@config.data_dir/20130914-20130915_51x5jqgsrk201309140010_activities.csv

    #@filename_preface = 20130914-20130915_
    #@filename_uuid = 51x5jqgsrk
    #@filename_datestamp = 201309140000 #Start time!  YYYYMMDDHHMM
    #@filename_prelude = _activities
    #@filename_ext = csv, json, gz

    def set_target_filename(source_filename)

        file_name_tokens = source_filename.split(/[._\/]/)
        @filename_preface = file_name_tokens[-4]
        @filename_ext = file_name_tokens[-1]

        @filename_target_template = "#{@filename_preface}_#{config.job_uuid}<TARGET_FILE_DATE>_#{@span_target_marker}.#{filename_ext}"
    end

    def get_date_string(time)
        begin
            return time.year.to_s + sprintf('%02i', time.month) + sprintf('%02i', time.day) + sprintf('%02i', time.hour) + sprintf('%02i', time.min)
        rescue
            p 'Error parsing date object.'
        end
    end

    def get_date_object(time_string)
        time = Time.utc
        time = Time.parse(time_string)
        return time
    end

    def get_target_time(file_time)

        #Now snap appropriately!
        case @span_target_minutes
            when 60
                Time.utc(file_time.year, file_time.month, file_time.day, file_time.hour,0)

            when 24 * 60
                Time.utc(file_time.year, file_time.month, file_time.day, 0 ,0)

            when ALL_MINUTES
                file_time #just pass back, don't need to snap here.

        end
    end

    #Method that sweeps through the consolidation
    def consolidate_files

        p "Consolidating files: #{get_span_name(@config.data_span)}"

        #Looking before leaping.
        #What data span are the files currently in?
        #What data span are we generating?
        #What if there are two types? --> Supported, commonly use case where consolidation is not complete.
        #What if there are three?  --> Notify user and quit.

        #Tour data_dir and look at file names to determine what to do.
        #Do any files end in gz? Ignore gz files?

        set_span_target_details(@config.data_span)

        file_count = 0
        extensions = []
        have_target_filename = false
        target_span_name = get_span_name(@config.data_span)

        files = Array.new
        files = FileList.new("#{@config.data_dir}/*#{@config.job_uuid}*.*").exclude("*#{target_span_name}*")

        files.each do |file|
            if file.include? target_span_name then
                file.delete(file)
            end
        end


        files.each do |file|

            #p file.to_s

            file_count = file_count + 1

            ext = file.split('.')[-1]
            #p "Has extension: #{ext}"
            if !extensions.include?(ext) then
                extensions << ext
            end

            set_source_times(file)

            if !have_target_filename then
                set_target_filename(file)
                have_target_filename = true
            end
        end

        set_target_times #Based on source times, set target times

        p "Source files contain activities starting at #{@set_source_start} and ending at #{@set_source_end}"
        p "Will build Target files starting at #{@set_target_start} and ending at #{@set_target_end}"

        case extensions.length
            when 0
                p 'No files'
                return
            when 1
                p "Files: #{file_count} -- Single extension found: #{extensions[0]}"
                #If CSV or JSON we are set to consolidate.

            when 2
                # (*.json and *.csv and config.convert_data)?
                #   Probably stopped in middle of conversion process.
            else
                p "Have no idea what to do, bye, bye."
        end

        current_target_time = Time.new
        current_target_time = @set_target_start
        current_target_filename = @filename_target_template.gsub('<TARGET_FILE_DATE>', get_date_string(current_target_time))

        p "First target filename: #{current_target_filename}"

        #Now tour files to examine their names and read contents...
        #Compare Source filenames and extract date, then decide whether to write to current Target file,
        #OR create next Target file.

        #Going in, we know: set_source_start, set_source_end, set_target_start, set_target_end
        #Also, current boundaries: file_source_start/end, file_target_start/end
        #Also, source and target spans: span_source_minutes, span_target_minutes

        files_consolidated = 0
        #Create Target file.
        file_target = File.new("#{@config.data_dir}/#{current_target_filename}", 'w')
        need_header = true

        files.each do |filename|

            p "Processing #{filename}"
            #Look at file name

            files_consolidated = files_consolidated + 1

            if files_consolidated % 10 == 0 then
                @status.files_consolidated = files_consolidated
                @status.save_status

                @status.get_status
                if @status.consolidate == false then
                    @logger.message 'Disabled, stopping consolidation and exiting.'
                    exit
                end
            end

            if filename.include?("2340") or filename.include?("2350") or filename.include?("0000")  then
                p 'stop'
            end

            file_source = File.open(filename)

            file_time = get_file_time(filename)

            if (file_time < (current_target_time + (@span_target_minutes * 60)) or @span_target_minutes == ALL_MINUTES) then #Still in current target file's domain.
                #Write Source contents to Target file.
               p 'Write Source contents to Target file'

            else #Then we have a new Target file

                file_target.close

                #OK, we may have skipped one or more Target spans, so check and generate new Target filename.

                #Increment new Target time and generate new Target filename.
                current_target_time = get_target_time(file_time)
                current_target_filename = String.new(@filename_target_template.gsub('<TARGET_FILE_DATE>', get_date_string(current_target_time)))

                #p "Creating new Target file: #{current_target_filename}"

                file_target = File.new("#{@config.data_dir}/#{current_target_filename}", 'w')
                need_header = true
            end

            #TODO: we need to manage the source file headers here.
            if need_header then
                file_target.puts file_source.read
                need_header = false
            else
                file_target.puts File.readlines(file_source)[1..-2]
            end

            file_source.close
            File.delete(file_source)
        end

        if @span_target_minutes == ALL_MINUTES then
            file_target.close
        end
    end
end

#--------------------------------------------------------------------------
#Exercising this object directly.
if __FILE__ == $0  #This script code is executed when running this file.

    #Config and Status objects are helpful.
    oConfig = DM_Config.new  #Create a configuration object.
    oConfig.config_path = './'  #This is the default, by the way, so not mandatory in this case.
    oConfig.config_name = 'config.yaml'
    oConfig.get_config_yaml

    oStatus = DM_Status.new #Create a Status file.
                             #And load its contents.
    oStatus.get_status
    oStatus.status = 'Starting. Checking for things to do.'

    oConsolidator = DM_Consolidator.new(oConfig,oStatus,nil)
    oConsolidator.consolidate_files #Looks in oConfig data_dir and produces CSV files based on oConfig.activity_template

end