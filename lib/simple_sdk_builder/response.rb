# frozen_string_literal: true

module SimpleSDKBuilder
  class Response
    def initialize(faraday_response)
      @faraday_response = faraday_response
    end

    def status
      @faraday_response.status
    end
    alias code status

    def time
      @faraday_response.time
    end

    def headers
      @faraday_response.headers
    end

    def body
      @faraday_response.body
    end

    def parsed_body
      @parsed_body ||= JSON.parse(body)
    end

    def build(type)
      if parsed_body.is_a?(Array)
        parsed_body.map { |value| type.new.from_json(value.to_json) }
      else
        type.new.from_json(body)
      end
    end

    def build_search_results(type)
      SearchResults.new(self, type)
    end
  end
end
