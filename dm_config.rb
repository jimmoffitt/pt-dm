
#This class is tied to the Download Manager UI and process objects...
require 'base64'
require 'yaml'
require "fileutils"

class DM_Config

    attr_accessor :config_name, :config_path,
        #Account-specific.
        :account_name, :user_name, :password,
        #Historical PT Job details:
        :job_info,
        :job_uuid,  #User can enter Data URL or UUID as job_info.  We use either to set job_uuid.
        :publisher, :product, :stream_type,
        #app/script configuration.
        :data_dir,
        :consolidate_dir,
        :uncompress_data,
        :convert_csv,
        :data_span

    def initialize
        #Defaults.
        @config_path = "./" #Default to app root directory.

        @publisher = "twitter"
        @product = "historical"
        @stream_type = "track"
        @data_dir = "./output"
        #TODO: these are not implemented yet.
        @consolidate_dir = "./consolidate"
        @uncompress_data = false
        @convert_csv = false
        @data_span = "day"
    end

    #Confirm a directory exists, creating it if necessary.
    def check_directory(directory)
        #Make sure directory exists, making it if needed.
        if not File.directory?(directory) then
            FileUtils.mkpath(directory) #logging and user notification.
        end
        directory
    end

    #Determine @job_uuid from @job_info.
    def set_uuid
        begin
            if @job_info.include?("historical.gnip.com") #then Data URL was entered
                @job_uuid = @job_info.split("/")[-2]
            else
                @job_uuid = @job_info
            end
        rescue
            @job_uuid = ""   #Creating a config file.
        end
    end

    def config_file
        return @config_path + @config_name
    end

    #Attempts to determine if password is base64 encoded or not.
    #Uses this recipe: http://stackoverflow.com/questions/8571501/how-to-check-whether-the-string-is-base64-encoded-or-not
    def password_encoded?(password)
        reg_ex_test = "^([A-Za-z0-9+/]{4})*([A-Za-z0-9+/]{4}|[A-Za-z0-9+/]{3}=|[A-Za-z0-9+/]{2}==)$"

        if password =~ /#{reg_ex_test}/ then
            return true
        else
            return false
        end
    end

    #Write current config settings as YAML.
    def save_config_yaml

        account = {}
        account["account_name"] = @account_name
        account["user_name"] = @user_name
        account["password"] = @password

        settings = {}
        settings["data_dir"] = @data_dir
        settings["job_info"] = @job_info

        not_implemented = {}
        not_implemented["uncompressed_data"] = @uncompress_data
        not_implemented["consolidate_dir"] = @consolidate_dir
        not_implemented["data_span"] = @data_span
        not_implemented["convert_csv"] = @convert_csv

        config = {}
        config["account"] = account
        config["settings"] = settings
        config["not_implemented"] = not_implemented

        File.open(config_file, 'w') do |f|
            f.write config.to_yaml
        end

    end

    #Open YAML file and load settings into config object.
    def get_config_yaml


        begin
            config = YAML::load_file(config_file)
        rescue
            save_config_yaml
            config = YAML::load_file(config_file)
        end

        @account_name = config["account"]["account_name"]
        @user_name = config["account"]["user_name"]
        @password = config["account"]["password"]

        if !password_encoded?(@password)
            begin
                @password = Base64.encode64(@password)
            rescue
                @password = ""
            end
            #Rewrite config file with encoded password
            save_config_yaml
        end

        @job_info = config["settings"]["job_info"]
        set_uuid
        @data_dir = check_directory(config["settings"]["data_dir"])

        #These are not implemented yet!
        @uncompress_data = config["not_implemented"]["uncompressed_data"]
        @consolidate_dir = config["not_implemented"]["consolidate_dir"]
        @convert_csv = config["not_implemented"]["convert_csv"]
        @data_span = config["not_implemented"]["data_span"]

    end


    #Uses Ruby Marshall to pack config file.
    def save_config_byte

        config = Config.new

        config.account_name=@account_name
        config.user_name=@user_name
        config.password=Base64.encode64(@password)
        config.data_dir=@data_dir
        config.consolidate_dir=@consolidate_dir
        config.job_info=@job_info
        config.data_span=@data_span
        set_uuid

        config.uncompress_data=1

        #write to file
        File.open(config_file, "w") do |f|
            Marshal.dump(config,f)
        end
    end

    #Uses Ruby Marshall to unpack config file.
    def get_config_byte
        config = Config.new

        if File.exist?(config_file) then

            begin
                #Load from Config file.
                File.open(config_file, "r") do |f|
                    config = Marshal.load(f)
                end

                #p config
                @account_name = config.account_name
                @user_name = config.user_name
                @password = Base64.decode64(config.password) unless config.password.nil?
                @data_dir = config.data_dir
                @consolidate_dir = config.consolidate_dir
                @job_info  = config.job_info
                @data_span = config.data_span
                set_uuid

            rescue
                p "Failed to load configuration."
            end
        else
            p "No configuration file to load..."
        end
    end
end

#--------------------------------------------------------------------------
if __FILE__ == $0  #This script code is executed when running this file.

    oConfig = DM_Config.new

    #Account-specific.
    oConfig.account_name = "jim"
    oConfig.user_name = "jmoffitt@gnipcentral.com"
    oConfig.password = "test_password"

    p oConfig.password_encoded?(oConfig.password)


    temp = Base64.encode64(oConfig.password)

    p temp

    p oConfig.password_encoded?(temp)

    temp2 = Base64.encode64(temp)

    p temp2

    temp3 = Base64.decode64(temp2)

    p temp3

    temp4  = Base64.decode64(temp3)

    p temp4






    #Historical PT Job details:
    job_info = ""

end


