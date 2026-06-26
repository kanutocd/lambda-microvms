# frozen_string_literal: true

require 'json'
require 'net/http'
require 'uri'

module Lambda
  module MicroVMs
    # HTTP client for a single Lambda MicroVM endpoint.
    class Endpoint
      attr_reader :url

      def initialize(url:, token:, http: Net::HTTP)
        @url = url
        @token = token
        @http = http
      end

      def get(path, headers: {})
        request(Net::HTTP::Get, path, headers:)
      end

      def post(path, json: nil, body: nil, headers: {})
        request(Net::HTTP::Post, path, json:, body:, headers:)
      end

      def request(klass, path, json: nil, body: nil, headers: {})
        req = build_request(klass, path, headers:, body:, json:)
        response = @http.start(req.uri.host, req.uri.port, use_ssl: req.uri.scheme == 'https') do |http|
          http.request(req)
        end

        success = response.code.to_i.between?(200, 299)
        unless success
          raise EndpointError.new("MicroVM endpoint returned HTTP #{response.code}", status: response.code.to_i,
                                                                                     body: response.body)
        end

        parse_response(response)
      end

      private

      def build_uri(path)
        base = URI(@url)
        return base if path.nil? || path.empty? || path == '/'

        joined = [base.path.sub(%r{/\z}, ''), path.sub(%r{\A/}, '')].reject(&:empty?).join('/')
        base.path = "/#{joined}"
        base
      end

      def parse_response(response)
        content_type = response['Content-Type'].to_s
        return JSON.parse(response.body) if content_type.include?('application/json') && !response.body.to_s.empty?

        response.body
      end

      def build_request(klass, path, headers: {}, json: nil, body: nil)
        uri = build_uri(path)
        request = klass.new(uri)
        headers = headers.merge('Authorization' => @token ? "Bearer #{@token}" : nil)
        if json
          headers['Content-Type'] ||= 'application/json'
          request.body = JSON.generate(json)
        elsif body
          request.body = body
        end
        headers.each_pair.with_object(request) { |(key, value), req| req[key] = value }
      end
    end
  end
end
