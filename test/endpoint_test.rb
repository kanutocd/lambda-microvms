# frozen_string_literal: true

require 'test_helper'

Response = Struct.new(:code, :body, :headers, keyword_init: true) do
  def [](key)
    headers[key]
  end
end

class FakeHttp
  attr_reader :last_request

  def initialize(response)
    @response = response
  end

  def start(_host, _port, use_ssl:)
    @use_ssl = use_ssl
    yield self
  end

  def request(request)
    @last_request = request
    @response
  end
end

class EndpointTest < Minitest::Test
  def test_post_json
    http = FakeHttp.new(Response.new(code: '200', body: '{"ok":true}',
                                     headers: { 'Content-Type' => 'application/json' }))
    endpoint = Lambda::MicroVMs::Endpoint.new(url: 'https://example.test', token: 'token', http: http)

    result = endpoint.post('/process', json: { hello: 'world' })

    assert_equal({ 'ok' => true }, result)
    assert_equal 'Bearer token', http.last_request['Authorization']
    assert_equal 'application/json', http.last_request['Content-Type']
  end

  def test_raises_on_non_success
    http = FakeHttp.new(Response.new(code: '500', body: 'boom', headers: {}))
    endpoint = Lambda::MicroVMs::Endpoint.new(url: 'https://example.test', token: 'token', http: http)

    error = assert_raises(Lambda::MicroVMs::EndpointError) do
      endpoint.get('/health')
    end

    assert_equal 500, error.status
    assert_equal 'boom', error.body
  end
end
