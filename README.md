# Tochka

"Tochka" is softwares to build Wi-Fi frame capturing box with Raspberry Pi +  PiTFT.

Welcome to your new gem! In this directory, you'll find the files you need to be able to package up your Ruby library into a gem. Put your Ruby code in the file `lib/tochka`. To experiment with that code, run `bin/console` for an interactive prompt.

TODO: Delete this and the text above, and describe your gem

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'tochka'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install tochka

### install init.d scripts

1. copy ext/tochkad, ext/tochka-miniui into /etc/init.d
2. do chmod +x onto both
3. do 'update-rc.d <name> defaults' to both

## Usage

### PiTFT UI

Tochka provides with user interface to start/stop capture on top of PiTFT.

![tochka-miniui](http://enukane.github.io/images/2015-08-31/tochka-miniui.jpg)

TOUCHSCREEN is currently of NO USE. Just make yourself happy with moving cursor :).
Use buttons instead: 4 buttons are "START", "STOP", "MODE1", "MODE2".

### Starting capture

Press "START" button and "State" turns into "running"

### Stop capture

Press "STOP", "MODE1" and "MODE2" buttons in an order. Check that "stop count" is now 3.
Then press "STOP" button again will turn off capturing. The "State" will turn into "stop".

### collecting captured data

Captured data (pcapng files) are stored in /cap directory

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment. Run `bundle exec tochka` to use the gem in this directory, ignoring other installed copies of this gem.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/enukane/tochka.

