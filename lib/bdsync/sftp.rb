require "bdsync/core"
require "net/sftp"
require "tempfile"

module Bdsync
    class Sftp < Core
        def initialize params
            @site   = params["site"]
            @user   = params["user"]
            @sftp   = Net::SFTP.start(@site, @user)

            super params, "sftp"
        end

        def self.options
            Core.options + ["site:", "user:"]
        end

        def remote_dir_foreach remote_path
            @sftp.dir.foreach(remote_path) { |entry|
                yield entry
            }
        end

        # Return
        # OpenStruct.new(
        #     directory?:
        #     mtime:
        # )
        def remote_get_object remote_path
            @sftp.lstat! remote_path
        rescue Net::SFTP::StatusException
            nil
        end

        def download_file local_path, remote_path
            local_ensure_parent local_path

            puts "#{Utils.caller_info 1} sftp.download! #{remote_path}, #{local_path}".white
            @sftp.download! remote_path, local_path
        end

        def upload_file local_path, remote_path
            remote_ensure_parent remote_path

            puts "#{Utils.caller_info 1} sftp.upload! #{local_path}, #{remote_path}".white
            @sftp.upload! local_path, remote_path

            remote_get_object remote_path
        end

        def remote_mkdir remote_path
            puts "#{Utils.caller_info 1} sftp.mkdir! #{remote_path}".white
            @sftp.mkdir! remote_path
            remote_get_object remote_path
        end

        def remote_remove_file remote_path
            puts "#{Utils.caller_info 1} sftp.remove! #{remote_path}".white
            @sftp.remove! remote_path
        end

        def remote_remove_dir remote_path
            puts "#{Utils.caller_info 1} remote_remove_dir #{remote_path}".white

            remote = remote_get_object remote_path
            return if !remote || !remote.directory?

            remote_dir_foreach(remote_path) { |entry|
                next if [".", ".."].include? entry.name

                path = "#{remote_path}/#{entry.name}"
                remote = entry.attributes

                if remote.directory?
                    remote_remove_dir path
                else
                    remote_remove_file path
                end
            }

            @sftp.rmdir! remote_path
        end

        def remote_rename remote_path, new_remote_path
            puts "#{Utils.caller_info 1} sftp.rename! #{remote_path} #{new_remote_path}".yellow
            @sftp.rename! remote_path, new_remote_path
        end

        def remote_ensure_dir path
            begin
                @sftp.lstat! path
            rescue Net::SFTP::StatusException
                remote_ensure_parent path
                @sftp.mkdir! path
            end
        end

        def remote_ensure_parent path
            remote_ensure_dir File.dirname path
        end

        def get_remote_file_md5 remote_path
            puts "#{Utils.caller_info 1} sftp.session.exec! md5sum #{remote_path}".white
            res = @sftp.session.exec! "md5sum #{remote_path}"
            res.split[0]
        end

        # for test
        def create_remote_file remote_path, content
            tmpfile = Tempfile.new 'sftp.rb-create_remote_file-'

            begin
                tmpfile.write content
                tmpfile.flush
                
                @sftp.upload! tmpfile.path, remote_path
            ensure
                tmpfile.close
                tmpfile.unlink  # deletes the temp file
            end
        end
    end
end
