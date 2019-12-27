require "bdsync/utils"
require "colorize"
require "yaml"

module Bdsync
    class Core
        attr_reader :data_path

        def initialize params, sync_type
            raise "local path not specified"    if !params["local_root_path"]
            raise "remote path not specified"   if !params["remote_root_path"]

            @local_root_path    = params["local_root_path"]
            @remote_root_path   = params["remote_root_path"]
            @infinite_loop      = params["infinite_loop"]
            @data_path          = "#{Dir.home}/.bdsync/#{sync_type}_#{Utils.md5 params.to_s}.yaml"
        end

        def self.options
            ["local_root_path:", "remote_root_path:", "infinite_loop"]
        end

        def synchronize
            # Run only one instance of a Ruby program at the same time - self locking
            # SEE: https://code-maven.com/run-only-one-instance-of-a-script
            Utils.try_lock {
                loop {
                    @old_data = load_data
                    @data = {}

                    start_session {
                        remote_ensure_dir @remote_root_path
                        local_ensure_dir @local_root_path

                        puts "\n==== traverse_remote_path ===="
                        traverse_remote_path @remote_root_path

                        # merge @data to @old_data, and clear @data
                        @old_data.merge! @data
                        @data     = {}

                        puts "\n==== traverse_local_path ===="
                        traverse_local_path @local_root_path
                    }

                    save_data @data

                    break if !@infinite_loop

                    sleep 1
                }
            }
        end

        def start_session &block
            fail NotImplementedError, "A subclass class must be able to #{__method__}!"
        end

        def load_data
            puts "\nload #{@data_path}"
            YAML.load_file @data_path
        rescue Errno::ENOENT
            {}
        end

        def save_data data
            local_ensure_parent @data_path
            File.write @data_path, data.to_yaml
            puts "\nsaved to #{@data_path}"
        end

        def traverse_remote_path remote_path
            next_level_dirs = []

            remote_dir_foreach(remote_path) { |entry|
                next if [".", "..", ".conflict"].include? entry.name

                path = "#{remote_path}/#{entry.name}"
                remote = entry.attributes

                if remote.directory?
                    next_level_dirs << [path, remote]
                else
                    handle_remote_entry remote, path, :file
                end
            }

            next_level_dirs.sort.each { |path, remote|
                handle_remote_entry remote, path, :directory
                traverse_remote_path path
            }
        end

        def traverse_local_path local_path
            next_level_dirs = []

            Dir.foreach(local_path) { |entry_name|
                next if [".", "..", ".conflict"].include? entry_name

                path = "#{local_path}/#{entry_name}"

                if File.directory? path
                    next_level_dirs << path
                else
                    handle_local_entry path, :file
                end
            }

            next_level_dirs.sort.each { |path|
                handle_local_entry path, :directory

                begin
                    traverse_local_path path
                rescue Errno::ENOENT
                    # OK: the local directory may be deleted with synchronization!
                end
            }
        end

        def handle_remote_entry remote, path, type
            puts "#{'%9s' % type}: #{path}".green

            # NOTE: force_encoding to output readable japanese text
            relative_path = path.sub(@remote_root_path + "/", "").force_encoding("UTF-8")

            local_path = "#{@local_root_path}/#{relative_path}"
            remote_path = "#{@remote_root_path}/#{relative_path}"

            old = @old_data[relative_path]

            if !old             # no old sync record
                do_first_time_sync_from_remote relative_path, local_path, remote_path, remote, type
            else                # old sync record found
                do_sync_from_remote relative_path, local_path, remote_path, remote, type, old
            end
        end

        def handle_local_entry path, type
            puts "#{'%9s' % type}: #{path}".green

            # NOTE: force_encoding to output readable japanese text
            relative_path = path.sub(@local_root_path + "/", "").force_encoding("UTF-8")

            local_path = "#{@local_root_path}/#{relative_path}"
            remote_path = "#{@remote_root_path}/#{relative_path}"

            remote = remote_get_object remote_path

            old = @old_data[relative_path]

            if !old             # no old sync record
                do_first_time_sync_from_local relative_path, local_path, remote_path, remote, type
            else                # old sync record found
                do_sync_from_local relative_path, local_path, remote_path, remote, type, old
            end
        end

        def do_first_time_sync_from_remote relative_path, local_path, remote_path, remote, type
            case type
            when :file
                if !File.exist? local_path
                    download_file local_path, remote_path
                    update_file_data relative_path, local_path, remote.mtime
                elsif File.directory? local_path
                    handle_local_conflict local_path
                    download_file local_path, remote_path
                    update_file_data relative_path, local_path, remote.mtime
                else
                    handle_local_conflict local_path
                    download_file local_path, remote_path
                    update_file_data relative_path, local_path, remote.mtime
                end
            when :directory
                if !File.exist? local_path
                    local_mkdir local_path
                    update_directory_data relative_path, local_path, remote.mtime
                elsif File.directory? local_path
                    update_directory_data relative_path, local_path, remote.mtime
                else
                    handle_local_conflict local_path
                    local_mkdir local_path
                    update_directory_data relative_path, local_path, remote.mtime
                end
            end
        end

        def do_first_time_sync_from_local relative_path, local_path, remote_path, remote, type
            case type
            when :file
                if !remote
                    remote = upload_file local_path, remote_path
                    update_file_data relative_path, local_path, remote.mtime
                elsif remote.directory?
                    handle_remote_conflict remote_path
                    remote = upload_file local_path, remote_path
                    update_file_data relative_path, local_path, remote.mtime
                else
                    handle_remote_conflict remote_path
                    remote = upload_file local_path, remote_path
                    update_file_data relative_path, local_path, remote.mtime
                end
            when :directory
                if !remote
                    remote = remote_mkdir remote_path
                    update_directory_data relative_path, local_path, remote.mtime
                elsif remote.directory?
                    update_directory_data relative_path, local_path, remote.mtime
                else
                    handle_remote_conflict remote_path
                    remote = remote_mkdir remote_path
                    update_directory_data relative_path, local_path, remote.mtime
                end
            end
        end

        def do_sync_from_remote relative_path, local_path, remote_path, remote, type, old
            remote_changed = (remote.mtime - old[:remote_mtime]) != 0

            case type
            when :file
                if !File.exist? local_path
                    if !remote_changed
                        remote_remove_file remote_path
                    else
                        handle_remote_conflict remote_path
                    end
                elsif File.directory? local_path
                    if !remote_changed
                        remote_remove_file remote_path
                        remote = remote_mkdir remote_path
                        update_directory_data relative_path, local_path, remote.mtime
                    else
                        if File.mtime(local_path).to_i > remote.mtime
                            handle_remote_conflict remote_path
                            remote = remote_mkdir remote_path
                            update_directory_data relative_path, local_path, remote.mtime
                        else
                            handle_local_conflict local_path
                            download_file local_path, remote_path
                            update_file_data relative_path, local_path, remote.mtime
                        end
                    end
                else
                    local_changed = (File.mtime(local_path).to_i - old[:local_mtime]) != 0

                    if !local_changed && !remote_changed
                        @data[relative_path] = old
                    elsif local_changed && !remote_changed
                        remote = upload_file local_path, remote_path
                        update_file_data relative_path, local_path, remote.mtime
                    elsif !local_changed && remote_changed
                        download_file local_path, remote_path
                        update_file_data relative_path, local_path, remote.mtime
                    else
                        if File.mtime(local_path).to_i > remote.mtime
                            handle_remote_conflict remote_path
                            remote = upload_file local_path, remote_path
                            update_file_data relative_path, local_path, remote.mtime
                        else
                            handle_local_conflict local_path
                            download_file local_path, remote_path
                            update_file_data relative_path, local_path, remote.mtime
                        end
                    end
                end
            when :directory
                if !File.exist? local_path
                    if !remote_changed
                        remote_remove_dir remote_path
                    else
                        handle_remote_conflict remote_path
                    end
                elsif File.directory? local_path
                    update_directory_data relative_path, local_path, remote.mtime
                else
                    if !remote_changed
                        remote_remove_dir remote_path
                        remote = upload_file local_path, remote_path
                        update_file_data relative_path, local_path, remote.mtime
                    else
                        if File.mtime(local_path).to_i > remote.mtime
                            handle_remote_conflict remote_path
                            remote = upload_file local_path, remote_path
                            update_file_data relative_path, local_path, remote.mtime
                        else
                            handle_local_conflict local_path
                            local_mkdir local_path
                            update_directory_data relative_path, local_path, remote.mtime
                        end
                    end
                end
            end
        end

        def do_sync_from_local relative_path, local_path, remote_path, remote, type, old
            local_changed = (File.mtime(local_path).to_i - old[:local_mtime]) != 0

            case type
            when :file
                if !remote
                    if !local_changed
                        local_remove_file local_path
                    else
                        handle_local_conflict local_path
                    end
                elsif remote.directory?
                    if !local_changed
                        local_remove_file local_path
                        local_mkdir local_path
                        update_directory_data relative_path, local_path, remote.mtime
                    else
                        if File.mtime(local_path).to_i > remote.mtime
                            handle_remote_conflict remote_path
                            remote = upload_file local_path, remote_path
                            update_file_data relative_path, local_path, remote.mtime
                        else
                            handle_local_conflict local_path
                            local_mkdir local_path
                            update_directory_data relative_path, local_path, remote.mtime
                        end
                    end
                else
                    remote_changed = (remote.mtime - old[:remote_mtime]) != 0

                    if !local_changed && !remote_changed
                        @data[relative_path] = old
                    elsif local_changed && !remote_changed
                        remote = upload_file local_path, remote_path
                        update_file_data relative_path, local_path, remote.mtime
                    elsif !local_changed && remote_changed
                        download_file local_path, remote_path
                        update_file_data relative_path, local_path, remote.mtime
                    else
                        if File.mtime(local_path).to_i > remote.mtime
                            handle_remote_conflict remote_path
                            remote = upload_file local_path, remote_path
                            update_file_data relative_path, local_path, remote.mtime
                        else
                            handle_local_conflict local_path
                            download_file local_path, remote_path
                            update_file_data relative_path, local_path, remote.mtime
                        end
                    end
                end
            when :directory
                if !remote
                    if !local_changed
                        local_remove_directory local_path
                    else
                        handle_local_conflict local_path
                    end
                elsif remote.directory?
                    update_directory_data relative_path, local_path, remote.mtime
                else
                    if !local_changed
                        local_remove_directory local_path
                        download_file local_path, remote_path
                        update_file_data relative_path, local_path, remote.mtime
                    else
                        if File.mtime(local_path).to_i > remote.mtime
                            handle_remote_conflict remote_path
                            remote = remote_mkdir remote_path
                            update_directory_data relative_path, local_path, remote.mtime
                        else
                            handle_local_conflict local_path
                            download_file local_path, remote_path
                            update_file_data relative_path, local_path, remote.mtime
                        end
                    end
                end
            end
        end

        def update_file_data relative_path, local_path, remote_mtime
            @data[relative_path] = {
                type: :file,
                remote_mtime: remote_mtime,
                local_mtime: File.mtime(local_path).to_i
            }
        end

        def update_directory_data relative_path, local_path, remote_mtime
            @data[relative_path] = {
                type: :directory,
                remote_mtime: remote_mtime,
                local_mtime: File.mtime(local_path).to_i
            }
        end

        def handle_local_conflict local_path
            ts = Utils.timestamp
            local_conflict_path = local_path.sub(@local_root_path, "#{@local_root_path}/.conflict") + "." + ts

            local_ensure_parent local_conflict_path
            local_rename local_path, local_conflict_path
        end

        def handle_remote_conflict remote_path
            ts = Utils.timestamp
            remote_conflict_path = remote_path.sub(@remote_root_path, "#{@remote_root_path}/.conflict") + "." + ts

            remote_ensure_parent remote_conflict_path
            remote_rename remote_path, remote_conflict_path
        end

        def local_mkdir local_path
            puts "#{Utils.caller_info 1} mkdir_p #{local_path}".white
            FileUtils.mkdir_p local_path
        end

        def local_remove_file local_path
            puts "#{Utils.caller_info 1} rm #{local_path}".white
            FileUtils.rm local_path
        end

        def local_remove_directory local_path
            puts "#{Utils.caller_info 1} rm_rf #{local_path}".white
            FileUtils.rm_rf local_path
        end

        def local_rename local_path, new_local_path
            puts "#{Utils.caller_info 1} mv #{local_path} #{new_local_path}".yellow
            FileUtils.mv local_path, new_local_path
        end

        def local_ensure_dir path
            FileUtils.mkdir_p path if !File.directory? path
        end

        def local_ensure_parent path
            local_ensure_dir File.dirname path
        end
    end
end
