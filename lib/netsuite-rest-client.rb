require 'rest-client'
require 'json'
require 'uri'

module Netsuite
  class Client
    BASE_URL = "https://rest.netsuite.com/app/site/hosting/restlet.nl"
    DEFAULT_REST_SCRIPT_ID    = 11
    DEFAULT_REST_DEPLOY_ID    = 1
    DEFAULT_SEARCH_SCRIPT_ID  = 10
    DEFAULT_SEARCH_DEPLOY_ID  = 1
    DEFAULT_SEARCH_BATCH_SIZE = 1000
    DEFAULT_REQUEST_TIMEOUT   = -1

    attr_accessor :headers, :request_timeout, :rest_script_id,
                  :search_script_id, :rest_deploy_id, :search_deploy_id

    def initialize(account_id, login, password, role_id, options={})
      super()

      auth_string       = "NLAuth nlauth_account=#{account_id}," +
                          "nlauth_email=#{URI.escape(login, Regexp.new("[^#{URI::PATTERN::UNRESERVED}]"))}," +
                          "nlauth_signature=#{password}," +
                          "nlauth_role=#{role_id}"

      @headers          = { :authorization  => auth_string,
                            :content_type   => "application/json" }

      @cookies          = { "NS_VER" => "2011.2.0" }

      @timeout          = options[:timeout] || DEFAULT_REQUEST_TIMEOUT

      @rest_script_id   = options[:rest_script_id] || DEFAULT_REST_SCRIPT_ID
      @rest_deploy_id   = options[:rest_deploy_id] || DEFAULT_REST_DEPLOY_ID
      @search_script_id = options[:search_script_id] || DEFAULT_SEARCH_SCRIPT_ID
      @search_deploy_id = options[:search_deploy_id] || DEFAULT_SEARCH_DEPLOY_ID
    end

    def get_record(record_type, internal_id)
      params = { 'script'      => @rest_script_id,
                 'deploy'      => @rest_deploy_id,
                 'record_type' => record_type,
                 'internal_id' => internal_id }

      parse_json_result_from_rest(:get, params)
    end

    def initialize_record(record_type)
      params = { 'script'      => @rest_script_id,
                 'deploy'      => @rest_deploy_id,
                 'record_type' => record_type }

      parse_json_result_from_rest(:get, params)
    end

    def update(record_type, internal_id, record_data)
      upsert(record_type, internal_id, record_data, :update_only=>true)
    end

    def upsert(record_type, internal_id, record_data, options={})
      params = { 'script'      => @rest_script_id,
                 'deploy'      => @rest_deploy_id,
                 'record_type' => record_type,
                 'internal_id' => internal_id,
                 'update_only' => options[:update_only] }

      parse_json_result_from_rest(:put, params)
    end

    def delete(record_type, internal_id)
      params = { 'script'      => @rest_script_id,
                 'deploy'      => @rest_deploy_id,
                 'record_type' => record_type,
                 'internal_id' => internal_id }

      parse_json_result_from_rest(:delete, params)
    end

    def get_saved_search(record_type, search_id, options={})
      results = Array.new
      params = { 'script'      => @search_script_id,
                 'deploy'      => @search_deploy_id,
                 'record_type' => record_type,
                 'search_id'   => search_id,
                 'start_id'    => options[:start_id] || 0,
                 'batch_size'  => @search_batch_size }

      while true
        results_segment = parse_json_result_from_rest(:get, params)
        results += results_segment.first
        break if results_segment.first.empty? || results_segment.first.length < params['batch_size'].to_i
        params['start_id'] = results_segment.last.to_i
      end

      results
    end

    def parse_json_result_from_rest(method, params)
      JSON.parse(RestClient::Request.execute :method  => method,
                                             :url     => create_url(params),
                                             :headers => @headers,
                                             :cookies => @cookies,
                                             :timeout => @timeout)
    end

    def create_url(params)
      BASE_URL + '?' + params.map { |key, value| "#{key}=#{value}" }.join('&')
    end
  end
end