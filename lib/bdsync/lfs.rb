require "bdsync/core"
require "ostruct"

module Bdsync
    class Lfs < Core
        def initialize params
            super params, "lfs"
        end

        def self.options
            Core.options
        end

        # yield object like this
        # {
        #   name:
        #   attributes: {
        #       directory?:
        #       mtime:
        #   }
        # }
        def remote_dir_foreach remote_path
            Dir.foreach(remote_path) { |filename|
                file_path = "#{remote_path}/#{filename}"

                yield OpenStruct.new name: filename, attributes: OpenStruct.new(
                    directory?: File.directory?(file_path),
                    mtime: File.mtime(file_path).to_i
                )
            }
        end

        def remote_get_object remote_path
            stat = File.lstat remote_path

            OpenStruct.new(
                directory?: stat.directory?,
                mtime: stat.mtime.to_i
            )
        rescue Errno::ENOENT
            nil
        end

        def download_file local_path, remote_path
            local_ensure_parent local_path

            puts "#{Utils.caller_info 1} cp #{remote_path}, #{local_path}".white
            FileUtils.cp remote_path, local_path
        end

        def upload_file local_path, remote_path
            remote_ensure_parent remote_path

            puts "#{Utils.caller_info 1} cp #{local_path}, #{remote_path}".white
            FileUtils.cp local_path, remote_path

            remote_get_object remote_path
        end

        def remote_mkdir remote_path
            puts "#{Utils.caller_info 1} mkdir #{remote_path}".white
            FileUtils.mkdir remote_path
            remote_get_object remote_path
        end

        def remote_remove_file remote_path
            puts "#{Utils.caller_info 1} rm #{remote_path}".white
            FileUtils.rm remote_path
        end

        def remote_remove_dir remote_path
            puts "#{Utils.caller_info 1} rm_rf #{remote_path}".white
            FileUtils.rm_rf remote_path
        end

        def remote_rename remote_path, new_remote_path
            puts "#{Utils.caller_info 1} mv #{remote_path} #{new_remote_path}".yellow
            FileUtils.mv remote_path, new_remote_path
        end

        def remote_ensure_dir path
            local_ensure_dir path
        end

        def remote_ensure_parent path
            local_ensure_parent path
        end

        def get_remote_file_md5 path
            Utils.file_md5 path
        end

        # for test
        def create_remote_file remote_path, content
            File.write remote_path, content
        end
    end
end
