require "bdsync"

RSpec.describe Bdsync do
    before :all do
        @test_root_path     = "/tmp/bdsync-test"
        @remote_root_path   = "#{@test_root_path}/remote"
        @local_root_path    = "#{@test_root_path}/local"

        @remote_file        = "#{@remote_root_path}/1.txt"
        @local_file         = "#{@local_root_path}/1.txt"
        @site               = "localhost"
        @user               = "root"
    end

    before :each do
        FileUtils.rm_rf @test_root_path
    end

    it "sftp: sync file from remote to local" do
        # setup
        FileUtils.mkdir_p   @remote_root_path
        FileUtils.touch     @remote_file

        bdsync = Bdsync::Sftp.new({
            "remote_root_path"  => @remote_root_path,
            "local_root_path"   => @local_root_path,
            "site"              => @site,
            "user"              => @user
        })

        FileUtils.rm_f bdsync.data_path

        # test
        bdsync.synchronize

        # check
        expect(File.file? @local_file).to eq(true)
    end
end
