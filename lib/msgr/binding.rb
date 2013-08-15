module Msgr
  # A single binding
  class Binding
    attr_reader :connection, :route, :subscription, :dispatcher

    def initialize(connection, route, dispatcher)
      @connection = connection
      @route      = route
      @dispatcher = dispatcher

      queue    = connection.queue route.name

      queue.bind connection.exchange, routing_key: route.key

      @subscription = queue.subscribe ack: true, &method(:call)
    end

    # Called from Bunny Thread Pool. Will create message object from
    # provided bunny data and dispatch message to connection.
    #
    def call(info, metadata, payload)
      message = Message.new(connection, info, metadata, payload, route)
      dispatcher.dispatch :call, message
    rescue => error
      Msgr.logger.warn(self) { "Error received within bunny subscribe handler: #{error.inspect}." }
    end

    # Cancel subscription to not receive any more messages.
    #
    def release
      subscription.cancel if subscription
    end
  end
end
