class DM_Common

    def os
        @os ||= (
        host_os = RbConfig::CONFIG['host_os']
        case host_os
            when /mswin|msys|mingw|cygwin|bccwin|wince|emc/
                :windows
            when /darwin|mac os/
                :macosx
            when /linux/
                :linux
            when /solaris|bsd/
                :unix
            else
                raise Error::WebDriverError, "unknown os: #{host_os.inspect}"
        end
        )
    end


    def count_local_files(data_dir, job_uuid)

        local_files = 0

        Dir.foreach(data_dir) do |f|

            #if job_uuid in filename, increment
            if f.include?(job_uuid)
                local_files = local_files + 1
            end
        end

        return local_files
    end

end



