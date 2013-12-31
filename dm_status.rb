require 'yaml'

class DM_Status

    attr_accessor :status_name, :status_path,

        #Process modes. UI sets to true to trigger a process.
        # Process sets to false when done.
        :enabled,
        :download,
        :convert,
        :consolidate,

        :job_uuid,
        #Files downloaded stats --> Progress bar.
        :files_total,
        :files_local,
        :file_size_mb,
        :files_consolidated,

        #File conversion stats --> Progress bar.
        :activities_total,
        :activities_converted,

        :file_current,
        :status,
        :error

    def initialize
        @status_name = "status.yaml"
        @status_path = "./"
        @job_uuid = ""
        @status = ""
        @files_local = 0
        @error = ""
    end

    def status_file
        return @status_path + @status_name
    end

    #read file.
    def save_status

        status_hash = {}
        status_hash["job_uuid"] = @job_uuid
        #Download stats.
        status_hash["files_total"] = @files_total
        status_hash["files_local"] = @files_local
        status_hash["files_size_mb"] = @file_size_mb

        #Conversion stats.
        status_hash["activities_total"] = @activities_total
        status_hash["activities_converted"] = @activities_converted

        #Consolidation stats
        status_hash["files_consolidated"] = @files_consolidated

        #General details.
        status_hash["file_current"] = @file_current
        status_hash["status"] = @status
        status_hash["error"] = @error

        #Process modes.
        status_hash["enabled"] = @enabled
        status_hash["download"] = @download
        status_hash["convert"] = @convert
        status_hash["consolidate"] = @consolidate

        File.open(status_file, 'w') do |f|  #This should NEVER append.
            f.write status_hash.to_yaml
        end
    end

    #Open YAML file and load settings into config object.
    def get_status

        #Create status file if needed...
        begin
            status_hash = YAML::load_file(status_file)
        rescue
            save_status
            status_hash = YAML::load_file(status_file)
        end

        @job_uuid = status_hash["job_uuid"]

        @files_total = status_hash["files_total"]
        @files_local = status_hash["files_local"]
        @file_size_mb = status_hash["files_size_mb"]

        #Conversion stats.
        @activities_total = status_hash["activities_total"]
        @activities_converted = status_hash["activities_converted"]

        #Consolidation stats.
        @file_consolidated = status_hash["files_consolidated"]

        @file_current = status_hash["file_current"]
        @status = status_hash["status"]
        @error = status_hash["error"]

        #Process modes.
        @enabled = status_hash["enabled"]
        @download = status_hash["download"]
        @convert = status_hash["convert"]
        @consolidate = status_hash["consolidate"]
    end
end

#-------------------------------------------------
# Application UI code:
if __FILE__ == $0  #This script code is executed when running this file.

    oStatus = DM_Status.new
    oStatus.files_total=2000
    oStatus.files_local=0

    #Exercise some methods.
    oStatus.save_status
    oStatus.get_status

    oStatus.files_total=100000
    oStatus.files_local=-99999999999

    oStatus.save_status

    oStatus.status = "this status"

    p oStatus.status

    p "Have completed #{oStatus.files_local} out of #{oStatus.files_total} items..."

end