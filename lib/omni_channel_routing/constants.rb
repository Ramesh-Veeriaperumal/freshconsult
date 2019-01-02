module OmniChannelRouting
  module Constants
    FRESHDESK_SERVICE = 'freshdesk'.freeze

    BASE_URL = OCR_CONFIG[:api_endpoint]

    AGENT_UPDATE_PATH = "#{BASE_URL}ocr_agents/%{user_id}"

    TICKET_UPDATE_PATH = "#{BASE_URL}tasks/%{ticket_id}"
  end
end
