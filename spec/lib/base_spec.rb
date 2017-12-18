RSpec.describe SimpleSDKBuilder::Base do
  class MockResponse
    attr_accessor :timed_out, :code, :body

    def initialize(options = {})
      self.timed_out = false
      self.code = 200
      self.body = %{{"value":"it worked!"}}

      options.each do |key, value|
        self.send("#{key}=", value)
      end
    end

    def timed_out?
      @timed_out
    end
  end

  let(:base_class) do
    Class.new do
      include SimpleSDKBuilder::Base
    end
  end

  before { Typhoeus::Expectation.clear }

  subject { base_class }

  it 'can be configured with a :service_url' do
    url = 'https://api.davidmdawson.com'
    base_class.config service_url: url
    expect(base_class.config[:service_url]).to eq(url)
  end

  context 'with error handlers defined' do
    let(:timeout_error) { Class.new(StandardError) }
    let(:not_found_error) { Class.new(StandardError) }
    let(:server_error) { Class.new(StandardError) }
    let(:unknown_error) { Class.new(StandardError) }

    before do
      base_class.config error_handlers: {
        nil => timeout_error,
        '404' => not_found_error,
        /^5/ => server_error,
        '*' => unknown_error
      }
    end

    subject { base_class }

    context 'the check_response method' do
      it 'should return successfully with a 200 status code' do
        expect { subject.check_response(MockResponse.new) }.not_to raise_error
      end

      it 'should raise a not_found_error with a 404 status code' do
        expect { subject.check_response(MockResponse.new(code: 404)) }.to raise_error(not_found_error)
      end

      it 'should raise a server_error with a 503 status code' do
        expect { subject.check_response(MockResponse.new(code: 503)) }.to raise_error(server_error)
      end

      it 'should raise an unknown_error with a 301 status code' do
        expect { subject.check_response(MockResponse.new(code: 301)) }.to raise_error(unknown_error)
      end

      it 'should raise a timeout_error upon a timeout' do
        expect { subject.check_response(MockResponse.new(timed_out: true, code: nil)) }.to raise_error(timeout_error)
      end

    end

    context 'a subclass' do
      subject { Class.new(base_class) }

      it "should use parent's not_found_error" do
        expect { subject.check_response(MockResponse.new(code: 404)) }.to raise_error(not_found_error)
      end
    end
  end

  context 'with a service url and stubbed hydra instance configured' do
    before do
      response = Typhoeus::Response.new(code: 200, body: '{"foo":"bar"}')
      Typhoeus.stub(/davidmdawson/).and_return(response)

      base_class.config service_url: 'https://api.davidmdawson.com'
    end

    it 'should default to a GET /' do
      expect(subject.json_request.parsed_body).to eq('foo' => 'bar')
    end

    context 'with a serializable foo class' do
      let(:foo_class) do
        Class.new do
          include ActiveModel::Serializers::JSON
          attr_accessor :attributes
        end
      end

      it 'should build a foo class when requested' do
        response = subject.json_request
        result = response.build(foo_class)
        expect(result).to be_a(foo_class)
        expect(result.attributes).to eq('foo' => 'bar')
      end
    end
  end
end
