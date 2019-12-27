require "bdsync/core"
require "net/sftp"

module Bdsync
    class Sftp < Core
        def initialize params
            @site   = params["site"]
            @user   = params["user"]

            super params, "sftp"
        end

        def self.options
            Core.options + ["site:", "user:"]
        end

        def start_session &block
            Net::SFTP.start(@site, @user) { |sftp|
                @sftp = sftp
                yield
            }
        end

        def remote_dir_foreach remote_path
            @sftp.dir.foreach(remote_path) { |entry|
                yield entry
            }
        end

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
            puts "#{Utils.caller_info 1} sftp.session.exec! rm -rf #{remote_path}".white
            @sftp.session.exec! "rm -rf #{remote_path}"
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
    end
end
