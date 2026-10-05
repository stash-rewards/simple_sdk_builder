# frozen_string_literal: true

RSpec.describe SimpleSDKBuilder::Base do
  class MockResponse
    attr_accessor :timed_out, :status, :body

    def initialize(options = {}) # rubocop:disable Style/OptionHash
      self.status = 200
      self.body = %({"value":"it worked!"})

      options.each do |key, value|
        public_send("#{key}=", value)
      end
    end
  end

  let(:base_class) do
    Class.new do
      include SimpleSDKBuilder::Base
    end
  end

  subject { base_class }

  describe '#==' do
    let(:resource_class) do
      Class.new do
        include SimpleSDKBuilder::Base
        include SimpleSDKBuilder::Resource

        simple_sdk_attribute :id, :name
      end
    end

    let(:other_resource_class) do
      Class.new do
        include SimpleSDKBuilder::Base
        include SimpleSDKBuilder::Resource

        simple_sdk_attribute :id
      end
    end

    let(:resource_without_id_class) do
      Class.new do
        include SimpleSDKBuilder::Base
        include SimpleSDKBuilder::Resource

        simple_sdk_attribute :date, :rate
      end
    end

    it 'treats the same class with the same id as equal' do
      a = resource_class.new(id: 1, name: 'a')
      b = resource_class.new(id: 1, name: 'b')

      expect(a).to eq(b)
      expect(a).to eql(b)
      expect(a.hash).to eq(b.hash)
      expect([a, b].uniq.size).to eq(1)
    end

    it 'treats different ids as not equal' do
      expect(resource_class.new(id: 1)).not_to eq(resource_class.new(id: 2))
    end

    it 'treats objects without an id as equal only to themselves' do
      a = resource_class.new(name: 'a')

      expect(a).to eq(a)
      expect(a).not_to eq(resource_class.new(name: 'a'))
    end

    it 'treats different classes with the same id as not equal' do
      expect(resource_class.new(id: 1)).not_to eq(other_resource_class.new(id: 1))
    end

    it 'returns false rather than raising for objects that have no id' do
      a = resource_class.new(id: 1)

      [nil, {}, { 'id' => 1 }, 'string', 1, :symbol, Object.new].each do |other|
        expect(a == other).to be(false)
        expect(a.eql?(other)).to be(false)
      end
    end

    it 'falls back to identity for a resource class without an id attribute' do
      a = resource_without_id_class.new(date: '2026-10-05', rate: 100)

      expect(a == a).to be(true)
      expect(a == resource_without_id_class.new(date: '2026-10-05', rate: 100)).to be(false)
      expect(a == nil).to be(false)
      expect(a.hash).to eq(a.hash)
    end

    it 'can be compared with true, as ActiveSupport::Cache::Entry#dup_value! does' do
      expect(resource_class.new(id: 1) == true).to be(false)
    end
  end

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
      it 'should return successfully with a 200 status' do
        expect { subject.check_response(MockResponse.new) }.not_to raise_error
      end

      it 'should raise a not_found_error with a 404 status' do
        expect { subject.check_response(MockResponse.new(status: 404)) }
          .to raise_error(not_found_error)
      end

      it 'should raise a server_error with a 503 status' do
        expect { subject.check_response(MockResponse.new(status: 503)) }
          .to raise_error(server_error)
      end

      it 'should raise an unknown_error with a 301 status' do
        expect { subject.check_response(MockResponse.new(status: 301)) }
          .to raise_error(unknown_error)
      end
    end

    context 'when the request times out' do
      before { base_class.config timeout: 0.00001, service_url: 'https://www.stashrewards.com' }

      it 'raises the right error' do
        # Ruby >= 3 keeps net/http's wrapping ("Failed to open TCP connection to ...
        # (execution expired)"); Ruby 2's timeout.rb reset the message to the bare string.
        expect { subject.json_request }.to raise_error(timeout_error, /execution expired/)
      end
    end

    context 'a subclass' do
      subject { Class.new(base_class) }

      it "should use parent's not_found_error" do
        expect { subject.check_response(MockResponse.new(status: 404)) }
          .to raise_error(not_found_error)
      end
    end
  end

  context 'with a service url and stubbed typhoeus instance configured' do
    before do
      stubs = Faraday::Adapter::Test::Stubs.new do |stub|
        stub.get('/') { |_env| [200, {}, '{"foo":"bar"}'] }
      end

      base_class.config service_url: 'https://api.davidmdawson.com', adapter: :test, stubs: stubs
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
