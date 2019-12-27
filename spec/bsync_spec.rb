require "bsync"

RSpec.describe Bsync do
    it "has a version number" do
        expect(Bsync::VERSION).not_to be nil
    end
end
