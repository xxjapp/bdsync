require "bdsync"

RSpec.describe Bdsync do
    before :all do
        @test_root_path     = "/tmp/bdsync-test"
        @remote_root_path   = "#{@test_root_path}/remote"
        @local_root_path    = "#{@test_root_path}/local"

        @remote_dir         = "#{@remote_root_path}/abc"
        @remote_file        = "#{@remote_root_path}/1.txt"
        @local_dir          = "#{@local_root_path}/abc"
        @local_file         = "#{@local_root_path}/1.txt"
        @site               = "localhost"
        @user               = "root"
    end

    before :each do
        @bdsync = Bdsync::Sftp.new({
            "remote_root_path"  => @remote_root_path,
            "local_root_path"   => @local_root_path,
            "site"              => @site,
            "user"              => @user
        })

        FileUtils.rm_rf @test_root_path
        FileUtils.rm_f @bdsync.data_path
    end

    it "sftp: first-time sync file from remote to local" do
        # setup
        FileUtils.mkdir_p   @remote_root_path
        FileUtils.touch     @remote_file

        # test
        @bdsync.synchronize

        # check
        expect(File.file? @local_file).to eq(true)
    end

    it "sftp: first-time sync file from local to remote" do
        # setup
        FileUtils.mkdir_p   @local_root_path
        FileUtils.touch     @local_file

        # test
        @bdsync.synchronize

        # check
        expect(File.file? @remote_file).to eq(true)
    end

    it "sftp: synchronized directory removed from remote should also removed from local" do
        # setup
        FileUtils.mkdir_p @remote_dir

        # test
        @bdsync.synchronize

        # check
        expect(File.directory? @local_dir).to eq(true)

        # test
        FileUtils.rm_rf @remote_dir
        @bdsync.synchronize

        # check
        expect(File.exist? @local_dir).to eq(false)
    end

    it "sftp: synchronized directory removed from local should also removed from remote" do
        # setup
        FileUtils.mkdir_p @remote_dir

        # test
        @bdsync.synchronize

        # check
        expect(File.directory? @local_dir).to eq(true)

        # test
        FileUtils.rm_rf @local_dir
        @bdsync.synchronize

        # check
        expect(File.exist? @remote_dir).to eq(false)
    end
end
