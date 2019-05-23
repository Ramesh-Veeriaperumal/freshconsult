module Middleware::RequestVerifier

  API_PATH = '/api/'.freeze
  PIPE_PATH = '/api/pipe/'.freeze
  FRESHID_PATH = '/api/freshid/'.freeze
  CHANNEL_PATH = '/api/channel/v2'.freeze
  CHANNEL_v1_PATH = '/api/channel/'.freeze
  PRIVATE_API_PATH = '/api/_/'.freeze
  API_V2_PATH = '/api/v2/'.freeze
  WIDGET_PATH = '/api/widget/'.freeze

  def api_request?(env = nil)
    verify_path?(env['PATH_INFO'], API_PATH)
  end

  def private_api_request?(env = nil)
    verify_path?(env['PATH_INFO'], PRIVATE_API_PATH)
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

  def channel_v1_api_request?(env = nil)
    verify_path?(env['PATH_INFO'], CHANNEL_v1_PATH) && !channel_api_request?(env)
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

end
