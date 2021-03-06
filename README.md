# Msgr: *Rails-like Messaging Framework*


[![Gem Version](https://badge.fury.io/rb/msgr.svg)](http://badge.fury.io/rb/msgr)
[![Build Status](http://img.shields.io/travis/jgraichen/msgr/master.svg)](https://travis-ci.org/jgraichen/msgr)
[![Coverage Status](http://img.shields.io/coveralls/jgraichen/msgr/master.svg)](https://coveralls.io/r/jgraichen/msgr)
[![Code Climate](http://img.shields.io/codeclimate/github/jgraichen/msgr.svg)](https://codeclimate.com/github/jgraichen/msgr)
[![Dependency Status](http://img.shields.io/gemnasium/jgraichen/msgr.svg)](https://gemnasium.com/jgraichen/msgr)
[![RubyDoc Documentation](http://img.shields.io/badge/rubydoc-here-blue.svg)](http://rubydoc.info/github/jgraichen/msgr/master/frames)

You know it and you like it. Using Rails you can just declare your routes and
create a controller. That's all you need to process requests.

With *Msgr* you can do the same for asynchronous AMQP messaging. Just define
your routes, create your consumer and watch your app processing messages.

## Installation

Add this line to your application's Gemfile:

    gem 'msgr'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install msgr

## Usage

After adding 'msgr' to your gemfile create a `config/rabbitmq.yml` like this:

```yaml
common: &common
  uri: amqp://localhost/

test:
  <<: *common

development:
  <<: *common

production:
  <<: *common
```

Specify your messaging routes in `config/msgr.rb`:

```ruby
route 'local.test.index', to: 'test#index'
route 'local.test.another_action', to: 'test#another_action'
```

Create your consumer in `app/consumers`:

```ruby
class TestConsumer < Msgr::Consumer
  def index
    data = { fuubar: 'abc' }

    publish data, to: 'local.test.another_action'
  end

  def another_action
    puts "#{payload.inspect}"
  end
end
```

Use `Msgr.publish` in to publish a message:

```ruby
class TestController < ApplicationController
  def index
    @data = { abc: 'abc' }

    Msgr.publish @data, to: 'local.test.index'

    render nothing: true
  end
end
```

## Msgr and fork web server like unicorn

Per default msgr opens the rabbitmq connect when rails is loaded. If you use a multi-process web server that preloads the application (like unicorn) will lead to unexpected behavior. In this case adjust `config/rabbitmq.yml` and adjust `autostart = false`:


```yaml
common: &common
  uri: amqp://localhost/
  autostart: false
```

And call inside each worker `Msgr.start` - e.g. in an after-fork block


## Testing

### Recommended configuration

```yaml
test:
  <<: *common
  pool_class: Msgr::TestPool
  raise_exceptions: true
```

The `Msgr::TestPool` pool implementation executes all consumers synchronously.
By enabling the `raise_exceptions` configuration flag, we can ensure that exceptions raised in a consumer will not be swallowed by dispatcher (which it usually does in order to retry consuming the message).

### RSpec example

In your `spec_helper.rb`:

```ruby
config.after(:each) do
  # Flush the consumer queue
  Msgr.client.stop delete: true
  Msgr::TestPool.reset
end
```

In a test:

```ruby
before { Msgr.client.start }

it 'executes the consumer' do
  # Publish an event on our queue
  Msgr.publish 'payload', to: 'msgr.queue.my_queue'

  # Let the TestPool handle exactly one event
  Msgr::TestPool.run count: 1

  # And finally, assert that something happened
  expect(actual).to eq expected
end
```


## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
