require "bsync/utils"

RSpec.describe Bsync::Utils do
    it "second try lock failed" do
        n               = 0
        worker_count    = 2
        threads         = []

        worker_count.times {
            threads << Thread.new {
                Bsync::Utils.try_lock {
                    n += 1
                    sleep 0.1
                }
            }
        }

        threads.each { |thr| thr.join }

        expect(n).to be 1
    end
end
