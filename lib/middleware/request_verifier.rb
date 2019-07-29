module Middleware::RequestVerifier

  API_PATH = '/api/'.freeze
  PIPE_PATH = '/api/pipe/'.freeze
  FRESHID_PATH = '/api/freshid/'.freeze
  CHANNEL_PATH = '/api/channel/v2'.freeze
  CHANNEL_v1_PATH = '/api/channel/'.freeze
  PRIVATE_API_PATH = '/api/_/'.freeze
  API_V2_PATH = '/api/v2/'.freeze
  WIDGET_PATH = '/api/widget/'.freeze

  def api_request?(resource = nil)
    verify_path?(resource, API_PATH)
  end

  def private_api_request?(resource = nil)
    verify_path?(resource, PRIVATE_API_PATH)
  end

  def pipe_api_request?(resource = nil)
    verify_path?(resource, PIPE_PATH)
  end

  def freshid_api_request?(resource = nil)
    verify_path?(resource, FRESHID_PATH)
  end

  def channel_api_request?(resource = nil)
    verify_path?(resource, CHANNEL_PATH)
  end

  def channel_v1_api_request?(resource = nil)
    verify_path?(resource, CHANNEL_v1_PATH) && !channel_api_request?(resource)
  end

  def api_v2_request?(resource = nil)
    verify_path?(resource, API_V2_PATH)
  end

  def widget_api_request?(resource = nil)
    verify_path?(resource, WIDGET_PATH)
  end

  private

    def verify_path?(resource, path)
      resource.starts_with?(path)
    end

end
