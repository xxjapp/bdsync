require_relative 'lib/bdsync/version'

Gem::Specification.new do |spec|
    spec.name          = "bdsync"
    spec.version       = Bdsync::VERSION
    spec.authors       = ["Xia Xiongjun"]
    spec.email         = ["xxjapp@gmail.com"]

    spec.summary       = %q{Bidirectional Synchronization tool for sftp or local file system}
    spec.description   = %q{Bidirectional Synchronization tool for sftp or local file system}
    spec.homepage      = "https://github.com/xxjapp/bdsync"
    spec.license       = "MIT"
    spec.required_ruby_version = Gem::Requirement.new(">= 2.3.0")

    spec.metadata["homepage_uri"] = spec.homepage
    spec.metadata["source_code_uri"] = "https://github.com/xxjapp/bdsync"
    spec.metadata["changelog_uri"] = "https://github.com/xxjapp/bdsync/releases"

    # Specify which files should be added to the gem when it is released.
    # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
    spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
        `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
    end
    spec.bindir        = "exe"
    spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
    spec.require_paths = ["lib"]

    spec.add_runtime_dependency "colorize", "~> 0.8"
    spec.add_runtime_dependency "net-sftp", "~> 2.1"
end
