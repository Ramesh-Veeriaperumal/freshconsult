module Middleware::RequestVerifier

  CONFIG = YAML::load_file(File.join(Rails.root, 'config', 'apigee.yml'))[Rails.env].freeze
  API_PATH = '/api/'.freeze
  PIPE_PATH = '/api/pipe/'.freeze
  FRESHID_PATH = '/api/freshid/'.freeze
  CHANNEL_PATH = '/api/channel/v2'.freeze
  PRIVATE_API_PATH = '/api/_/'.freeze
  API_V2_PATH = '/api/v2/'.freeze
  WIDGET_PATH = '/api/widget/'.freeze

  def api_request?(env = nil)
    verify_path?(env['PATH_INFO'], API_PATH)
  end

  def private_api_request?(env = nil)
    verify_path?(env['PATH_INFO'], PRIVATE_API_PATH)
  end

  def apigee_api_request?(env = nil)
    is_apigee?(env)
  end

  def pipe_api_request?(env = nil)
    verify_path?(env['PATH_INFO'], PIPE_PATH)
  end

  def freshid_api_request?(env = nil)
    verify_path?(env['PATH_INFO'], FRESHID_PATH)
  end

  def channel_api_request?(env = nil)
    verify_path?(env['PATH_INFO'], CHANNEL_PATH)
  end

  def api_v2_request?(env = nil)
    verify_path?(env['PATH_INFO'], API_V2_PATH)
  end

  def widget_api_request?(env = nil)
    verify_path?(env['PATH_INFO'], WIDGET_PATH)
  end

  private

    def verify_path?(resource, path)
      resource.starts_with?(path)
    end

    def is_apigee?(env)
      unless Rails.env.development?
        source_ip = env['HTTP_X_FORWARDED_FOR']
        return CONFIG['ips'].include?(source_ip)
      end
      false
    end
end
