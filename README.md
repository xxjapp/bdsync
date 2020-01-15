# Bdsync

Bidirectional Synchronization tool for sftp or local file system

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'bdsync'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install bdsync

## Usage

bdsync_sftp: Bidirectional synchronization from and to a sftp server directory:

```bash
bdsync_sftp --site ftp.example.com --user root --local_root_path /tmp/local_test --remote_root_path /tmp/remote_test
# OR
bdsync_sftp -s ftp.example.com -u root -l /tmp/local_test -r /tmp/remote_test
```

You can use [`direct_ssh`](https://rubygems.org/gems/direct_ssh/) to setup ssh authorization if necessary.

bdsync_lfs: Bidirectional synchronization from and to a local file directory:

```bash
bdsync_lfs --local_root_path /tmp/local_test --remote_root_path /tmp/remote_test
# OR
bdsync_lfs -l /tmp/local_test -r /tmp/remote_test
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/xxjapp/bdsync. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/xxjapp/bdsync/blob/master/CODE_OF_CONDUCT.md).


## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Bdsync project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/xxjapp/bdsync/blob/master/CODE_OF_CONDUCT.md).

## Links

1. ruby gem [bdsync](https://rubygems.org/gems/bdsync)
