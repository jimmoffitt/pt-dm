require_relative "./pt_restful"
require_relative "./dm_config"
require_relative "./dm_status"
require_relative "./dm_logger"
require_relative "./dm_common"
require_relative "./file_manager"

require 'open-uri'  #TODO:Port to HTTP class.
require 'json'
require 'csv'
require 'zlib'

#Windows @SSL #Ruby 1.9.2
def suppress_warnings
    original_verbosity = $VERBOSE
    $VERBOSE = nil
    result = yield
    $VERBOSE = original_verbosity
    return result
end

class DM_Downloader

    attr_accessor :config, :http, :os,
                  :url_list, :to_get_list,
                  :logger,
                  :status, :files_total, :files_local

    #This is really only for Windows.
    suppress_warnings {OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE}


    def initialize(config, status = nil, logger = nil)  #Must supply config object.
        @config = config
        if @config.job_uuid.nil?
            @config.job_uuid = @config.set_uuid
        end

        if status.nil? then
            @status = DM_Status.new #create status object if not supplied.
        else
            @status = status
        end

        if logger.nil? then
            @logger = DM_Logger.new  #create logger object if not supplied.
        else
            @logger = logger
        end

        #This worker depends on a HTTP object that it creates and applies config.
        @http = PtRestful.new
        @http.publisher = @config.publisher
        @http.user_name = @config.user_name unless @config.user_name.nil? #Set the info needed for authentication.

        if @config.password_encoded?(@config.password) then
            @http.password_encoded = @config.password
        else
            @http.password = @config.password unless @config.password.nil?  #HTTP class can decrypt password if you set password_encrypted.
        end

        @http.url=@http.getHistoricalDataURL(@config.account_name, @config.job_uuid) unless @config.account_name.nil?  #Pass the URL to the HTTP object.

        #Determine what #OS we are on.
        oCommon = DM_Common.new
        @os = oCommon.os

        #SSL
        #Check #OS and if #Windows, set the HTTPS certificate file (see method for the sad story).
        #This call also sets @http.set_cert_file = true
        if @os == :windows
            @http.set_cert_file_location( File.dirname(__FILE__) )
        end
    end

    '''
    The *.json payload has this form:
    {"urlCount":24,
    "urlList":["https://s3-us-west-1.amazonaws.com/archive.replay.snapshots/snapshots/twitter/track/activity_streams/jim/2013/07/24/20130722-20130722_tf4kfhrtb8/2013/07/22/15/00_activities.json.gz?AWSAccessKeyId=AKIAIWTH5AP7S5RCSOBQ&Expires=1377296627&Signature=zs6%2B1dk%2FaL1lM9Slq2yilBnmmCY%3D"],
    "expiresAt":"2013-08-08T22:10:22Z",
    "totalFileSizeBytes":63969459}

    Take that and load up a hash of [file_name][link] key-value pairs.
    20130722-20130722_tf4kfhrtb8_2013_07_22_15_00_activities.json.gz
    https://s3-us-west-1.amazonaws.com/archive.replay.snapshots/snapshots/twitter/track/activity_streams/jim/2013/07/24/20130722-20130722_tf4kfhrtb8/2013/07/22/15/00_activities.json.gz?AWSAccessKeyId=AKIAIWTH5AP7S5RCSOBQ&Expires=1377296627&Signature=zs6%2B1dk%2FaL1lM9Slq2yilBnmmCY%3D

    '''
    def parse_url_list(data_url_json)

        data_files = Hash.new

        data = JSON.parse(data_url_json)

        if data["status"] != "error" then

            urlList = data["urlList"]

            urlList.each { |item|

                #Parse the file name from the link.
                begin
                    file_name = ((item.split(@config.account_name)[1]).split("/")[4..-1].join).split("?")[0]
                rescue #in case the link format changes, try this...
                    file_name = item[item.index(@config.job_uuid)..(item.index(".gz?")+2)].gsub!("/","_")
                end

                data_files[file_name] = item
            }

            data_files
        end
    end


    def parse_job_url(job_url_json)

        job_status = Hash.new

        if !job_url_json.include?("error") then

            data = JSON.parse(job_url_json)


            @status.activities_total = data["results"]["activityCount"]
            @status.file_size_mb = data["results"]["fileSizeMB"]
            @status.save_status
        else
            p job_url_json
        end
    end


    #Goes out and gets Data URL.
    #TODO: make more explicit about what URL we are hitting.
    def get_filelist
        @status.status = "Getting data file list for job #{@config.job_uuid}..."

        response = @http.GET()
        data_url_json = response.body

        if response.body.include?('expired') then
            p 'JOB HAS EXPIRED'
        elsif response.body.include?('error') then
            p "ERROR: #{response.body}"
        else
            @url_list = parse_url_list(data_url_json)
            @to_get_list = @url_list.clone
            @files_total = @url_list.length

            @logger.message "This job consists of #{@files_total} data files..."
            @status.files_total = @files_total
            @status.save_status
        end
    end


    def count_local_files

        local_files = 0

        Dir.foreach(@config.data_dir) do |f|
            if @url_list.has_key?(f) or @url_list.has_key?("#{f}.gz")
                local_files = local_files + 1
            end
        end

        return local_files
    end

    '''
    Look in the output folder, and make sure not to download any files already there.
    '''
    #TODO: this depends on hash.has_key? method.
    # Need to work with file name roots (with no extension).
    # Needs to work with *json, *csv, *gz
    def look_before_leap

        files_downloaded = 0

        Dir.foreach(@config.data_dir) do |f|
            if @to_get_list.has_key?(f) or @to_get_list.has_key?("#{f}.gz") or @to_get_list.has_key?("#{f.split('.')[0]}.json.gz")
                @to_get_list.delete(f)
                files_downloaded = files_downloaded + 1
            end
        end

        @files_local = files_downloaded

        if @files_local > 0 then
            @logger.message "Already have #{@files_local} files..."
        else
            @logger.message "No local files."
        end
        @status.files_local = @files_local
        @status.save_status
    end


    '''
    A simple wrapper to the gunzip command.
    #TODO: this is not used currently...
    '''
    def uncompress_files

        #Just uncompress the files now directly...
        Dir.glob(@config.data_dir + "/*.gz") do |file_name|

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

    def uncompress_file(file)
        begin

            Zlib::GzipReader.open(file) { |gz|
                new_name = File.dirname(file) + "/" + File.basename(file, ".*")
                g = File.new(new_name, "w")
                g.write(gz.read)
                g.close
            }

            File.delete(file)

        rescue
            p "Error decompressing file: #{file}"
        end
    end

    #Note: getting the Job URL is not available to non-subscription customers.
    def get_job_stats

        @http.url=@http.getHistoricalJobURL(@config.account_name,@config.job_uuid)
        response = @http.GET()
        parse_job_url(response.body)

        #Revert back to Data URL.
        @http.url=@http.getHistoricalDataURL(@config.account_name,@config.job_uuid)

    end

    def confirm_uncompressed


    end

    def download_files

        if @to_get_list.nil? then
            get_filelist
        end

        look_before_leap

        files_to_get = @files_total - @files_local



        if files_to_get > 0 then
            @logger.message "Starting to download #{files_to_get} files..."
        else
            @logger.message "All files have been downloaded..."

            #If files are to be decompressed, then see if they need to be decompressed.
            if @config.uncompress_data then
                uncompress_files
            end
            return
        end

        #Since there could be thousands of files to fetch, let's throttle the downloading.
        #Let's process a slice at a time, then multiple-thread the downloading of that slice.
        slice_size = 10
        thread_limit = 10
        sleep_seconds = 1

        threads = []

        begin_time = Time.now

        @to_get_list.each_slice(slice_size) do |these_items|
            for item in these_items

                @status.get_status
                if @status.download == false then
                    @logger.message 'Disabled, stopping download and exiting.'
                    exit
                end

                #p "Downloading #{item[0]}..."

                threads << Thread.new(item[1]) do |url|

                    until threads.map { |t| t.status }.count("run") < thread_limit do
                        print "."
                        sleep sleep_seconds
                    end

                    begin

                        begin
                            File.open(@config.data_dir + "/" + item[0], "wb") do |new_file|
                                # the following "open" is provided by open-uri
                                open(url, 'rb') do |read_file|
                                    new_file.write(read_file.read)
                                end
                                @status.file_current = item[0]
                                @logger.message "Downloaded #{item[0]}"
                            end
                        rescue
                            p 'DOWNLOAD ERROR THROWN'
                        end

                        p item[0]

                        if @config.uncompress_data == true or @config.uncompress_data == "1" then
                            uncompress_file(@config.data_dir + "/" + item[0])
                        end

                        @status.error = ""
                    rescue   #TODO: flush out with specific error catching...
                        @status.error = "Download error."

                    end

                end
                threads.each { |thr| thr.join}
            end

            #Config the number of files we've downloaded.
            @status.files_local = count_local_files
            @status.save_status
        end

        @logger.message "Took #{Time.now - begin_time} seconds to download files.  "

        @status.status = "Finished downloading."
    end


end

#Following code is NOT invoked by any pt_dm component.
#Code sandbox -- to help with code usage examples and design...
#When deployed dm_process acts as a wrapper around dm_worker class.
#--------------------------------------------------------------------------
if __FILE__ == $0  #This script code is executed when running this file.

    #Set config.
    #Create a config object here, then pass into the Worker object.
    #Config would normally be created and set in the UI object, then passed to Worker.
    oConfig = DM_Config.new
    oConfig.get_config_yaml

    #Set Status.
    #Create a status object here, and pass to Worker.
    oStatus = DM_Status.new

    #Download files.
    oWorker = DM_Downloader.new(oConfig,oStatus,nil)

    oWorker.download_files

end