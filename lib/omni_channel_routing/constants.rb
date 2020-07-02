module OmniChannelRouting
  module Constants
    OCR_BASE_URL = OCR_CONFIG[:api_endpoint]

    OCR_CLIENT_CONFIGS = [
      [:freshdesk, 'freshdesk', :jwt_secret],
      [:admin, 'admin', :admin_jwt_secret]
    ].freeze
    OCR_CLIENT_SERVICES = Hash[*OCR_CLIENT_CONFIGS.map { |i| [i[0], i[1]] }.flatten]
    OCR_CLIENT_SECRET_KEYS = Hash[*OCR_CLIENT_CONFIGS.map { |i| [i[0], OCR_CONFIG[i[2]]] }.flatten]

    OCR_PATHS_ARRAY = [
      [:update_agent, 'ocr_agents/%{user_id}'],
      [:update_ticket, 'tasks/%{ticket_id}'],
      [:get_availability_count, 'ocr_agents/availability_count']
    ].freeze
    OCR_PATHS = Hash[*OCR_PATHS_ARRAY.map { |i| [i[0], i[1]] }.flatten]

    OCR_JWT_SIGNING_ALG = 'HS256'.freeze
    OCR_JWT_HEADER = { 'alg' => OCR_JWT_SIGNING_ALG, 'typ' => 'JWT' }.freeze

    OMNI_CHANNELS = %w[freshdesk freshchat freshcaller].freeze
  end
end
