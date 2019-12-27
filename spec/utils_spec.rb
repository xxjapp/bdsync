require "bdsync/utils"

RSpec.describe Bdsync::Utils do
    it "second try lock failed" do
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
end
