# encoding: UTF-8

#This class is tied to the Download Manager UI and process objects...
require 'base64'
require 'yaml'
require 'fileutils'

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
        :activity_template,  #Template for conversion process.
        :data_span,

        :arrays_to_collapse,
        :header_overrides,
        :header_mappings

    def initialize
        #Defaults.
        @config_path = './' #Default to app root directory.
        @config_name = 'config.yaml'

        @publisher = 'twitter'
        @product = 'historical'
        @stream_type = 'track'
        @data_dir = './output'

        @consolidate_dir = './consolidate'
        @uncompress_data = false
        @convert_csv = false
        @activity_template = './tweet_template.json'
        @data_span = 'hour'

        #These need to be unique, thus 'urls' require their parent object name.
        @arrays_to_collapse = 'hashtags,user_mentions,twitter_entities.urls,gnip.urls,matching_rules,topics'
        @header_overrides = 'actor.location.objectType,actor.location.displayName'
        @header_mappings = generate_special_header_mappings

    end

    #twitter_entities.hashtags.0.text               --> hashtags
    #twitter_entities.urls.0.url                    --> twitter_urls
    #twitter_entities.urls.0.expanded_url           --> twitter_expanded_urls
    #twitter_entities.urls.0.display_url            --> twitter_display_urls
    #twitter_entities.user_mentions.0.screen_name   --> user_mention_screen_names
    #twitter_entities.user_mentions.0.name          --> user_mention_names
    #twitter_entities.user_mentions.0.id            --> user_mention_ids
    #gnip.matching_rules.0.value                    --> rule_values
    #gnip.matching_rules.0.tag                      --> tag_values

    def generate_special_header_mappings

        mappings = Hash.new

        mappings['twitter_entities.hashtags.0.text'] = 'hashtags'
        mappings['twitter_entities.urls.0.url'] = 'twitter_urls'
        mappings['twitter_entities.urls.0.expanded_url'] = 'twitter_expanded_urls'
        mappings['twitter_entities.urls.0.display_url'] = 'twitter_display_urls'
        mappings['twitter_entities.user_mentions.0.screen_name'] = 'user_mention_screen_names'
        mappings['twitter_entities.user_mentions.0.name'] = 'user_mention_names'
        mappings['twitter_entities.user_mentions.0.id'] = 'user_mention_ids'
        mappings['gnip.matching_rules.0.value'] = 'rule_values'
        mappings['gnip.matching_rules.0.tag'] = 'rule_tags'
        mappings['gnip.language.value'] = 'gnip_lang'

        #Geographical metadata labels.
        mappings['location.geo.coordinates.0.0.0'] = 'box_sw_long'
        mappings['location.geo.coordinates.0.0.1'] = 'box_sw_lat'
        mappings['location.geo.coordinates.0.1.0'] = 'box_nw_long'
        mappings['location.geo.coordinates.0.1.1'] = 'box_nw_lat'
        mappings['location.geo.coordinates.0.2.0'] = 'box_ne_long'
        mappings['location.geo.coordinates.0.2.1'] = 'box_ne_lat'
        mappings['location.geo.coordinates.0.3.0'] = 'box_se_long'
        mappings['location.geo.coordinates.0.3.1'] = 'box_se_lat'
        mappings['geo.coordinates.0'] = 'point_long'
        mappings['geo.coordinates.1'] = 'point_lat'

        #These Klout topics need some help.
        mappings['gnip.klout_profile.topics.0.klout_topic_id'] = 'klout_topic_id'
        mappings['gnip.klout_profile.topics.0.display_name'] = 'klout_topic_name'
        mappings['gnip.klout_profile.topics.0.link'] = 'klout_topic_link'

        mappings
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
            if @job_info.include?('historical.gnip.com') #then Data URL was entered
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
        account['account_name'] = @account_name
        account['user_name'] = @user_name
        account['password'] = @password

        settings = {}
        #Downloading, compression.
        settings['data_dir'] = @data_dir
        settings['job_info'] = @job_info
        settings['uncompress_data'] = @uncompress_data
        #Conversion.
        settings['convert_csv'] = @convert_csv
        settings['activity_template'] = @activity_template
        settings['arrays_to_collapse'] = @arrays_to_collapse
        settings['header_overrides'] = @header_overrides
        #Consolidation.
        settings['consolidate_dir'] = @consolidate_dir
        settings['data_span'] = @data_span

        header_mappings = {}

        config = {}
        config['account'] = account
        config['settings'] = settings
        config['header_mappings'] = header_mappings

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

        @account_name = config['account']['account_name']
        @user_name = config['account']['user_name']
        @password = config['account']['password']

        if !password_encoded?(@password)
            begin
                @password = Base64.encode64(@password)
            rescue
                @password = ""
            end
            #Rewrite config file with encoded password
            save_config_yaml
        end

        @job_info = config['settings']['job_info']
        set_uuid
        @data_dir = check_directory(config['settings']['data_dir'])
        @uncompress_data = config['settings']['uncompress_data']

        #Conversion.
        @convert_csv = config['settings']['convert_csv']
        @activity_template = config['settings']['activity_template']
        temp = config['settings']['arrays_to_collapse']
        if !temp.nil? then
            @arrays_to_collapse = temp
        end
        temp = config['settings']['header_overrides']
        if !temp.nil? then
            @header_overrides = temp
        end

        #Consolidation.
        @consolidate_dir = config['settings']['consolidate_dir']
        @data_span = config['settings']['data_span']

        #Header mappings
        temp = config['header_mappings']
        if temp.length > 0 then
            @header_mappings = temp
        end
    end
end

#--------------------------------------------------------------------------
if __FILE__ == $0  #This script code is executed when running this file.

    oConfig = DM_Config.new

    #Account-specific.
    oConfig.account_name = "AccountName"
    oConfig.user_name = "me@there.com"
    oConfig.password = "GotMeSomeData"

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


#Similar code that uses binary (via Marshall) to save config.
=begin
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
=end


