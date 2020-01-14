require "bdsync/utils"

RSpec.describe Bdsync::Utils do
    it "second try lock should failed" do
        n               = 0
        worker_count    = 2
        threads         = []

        worker_count.times {
            threads << Thread.new {
                Bdsync::Utils.try_lock {
                    n += 1
                    sleep 0.1
                }
            }
        }

        threads.each { |thr| thr.join }

        expect(n).to be 1
    end

    it "test file_md5" do
        path = "/tmp/empty_file"

        FileUtils.rm_rf path
        File.write path, "1"

        expect(Bdsync::Utils.file_md5 path).to eq "c4ca4238a0b923820dcc509a6f75849b"
    end
end
