# frozen_string_literal: true

module SimpleSDKBuilder
  class SearchResults
    attr_reader :result_count, :links, :results

    def initialize(response, type)
      @result_count = response.headers['X-Count'].to_s.to_i

      @links = {}
      response.headers['Link'].to_s.split(',').each do |link|
        @links[Regexp.last_match(2)] = Regexp.last_match(1) if link.match?(/<(.*)>; rel="(.*)"/)
      end

      @results = response.build(type)
    end
  end
end
