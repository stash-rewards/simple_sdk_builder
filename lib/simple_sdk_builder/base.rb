# frozen_string_literal: true

require 'active_model'
require 'simply_configurable'
require 'typhoeus'

module SimpleSDKBuilder
  module Base
    DEFAULT_TIMEOUT_MILLISECONDS = 15_000

    def self.included(klass)
      klass.class_eval do
        include SimplyConfigurable
      end

      klass.extend ClassMethods

      klass.config service_url: 'http://localhost:3000/v1'
      klass.config timeout: DEFAULT_TIMEOUT_MILLISECONDS
      klass.config error_handlers: {
        nil => ConnectionError,
        '404' => NotFoundError,
        '422' => RequestError,
        '*' => UnknownError
      }
      klass.config logger: default_logger
    end

    def ==(other)
      equal?(other) || (id && id == other.id && self.class == other.class)
    end

    def eql?(other)
      self == other
    end

    def json_request(options = {})
      self.class.json_request(options)
    end

    def logger
      self.class.logger
    end

    def self.default_logger
      if defined?(::Rails)
        ::Rails.logger
      else
        logger = ::Logger.new(STDERR)
        logger.level = ::Logger::INFO
        logger
      end
    end

    module ClassMethods
      def json_request(options = {})
        options = config.merge(
          path: '/',
          method: :get,
          body: nil,
          params: nil,
          build: false
        ).merge(options)

        options[:headers] = {
          'Content-Type' => 'application/json'
        }.merge(options[:headers] || {})

        hydra = config[:hydra] || Typhoeus::Hydra.new

        url = "#{options[:service_url]}#{options[:path]}"

        request_body = options[:body]
        request_body = request_body.to_json if request_body && !request_body.is_a?(String)

        request = Typhoeus::Request.new url,
                                        method: options[:method],
                                        timeout: options[:timeout],
                                        headers: options[:headers],
                                        params: options[:params],
                                        body: request_body

        logger.debug "running HTTP #{options[:method]}: #{url}; PARAMS: #{options[:params]}; " \
          "BODY: #{request_body};"

        hydra.queue(request)
        hydra.run

        response = request.response

        logger.debug "received response code #{response.code}; BODY: #{response.body};"

        check_response(response)
        Response.new(response)
      end

      def check_response(response)
        return if response.code.to_s.start_with?('2')

        error_handlers = config[:error_handlers] || {}

        if response.timed_out?
          raise_response_error(error_handlers[nil], response, 'timed out before receiving response')
        end

        # search for exact match
        error_handlers.each do |key, error|
          if key.is_a?(Integer) || key.is_a?(String) || key.is_a?(Symbol)
            raise error, response if response.code.to_s == key.to_s
          end
        end

        # search for regex match
        error_handlers.each do |key, error|
          if key.is_a?(Regexp)
            raise error, response if !!(key =~ response.code.to_s)
          end
        end

        raise_response_error(
          error_handlers['*'],
          response,
          "an error occurred with the response; code: #{response.code}; body: #{response.body};"
        )
      end

      def logger
        config[:logger]
      end

      private

      def raise_response_error(error_handler, response, default_message)
        if error_handler
          raise error_handler, response
        else
          raise StandardError, default_message
        end
      end
    end
  end
end
