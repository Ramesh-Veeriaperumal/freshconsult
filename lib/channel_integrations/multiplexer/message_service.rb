# frozen_string_literal: true

module ChannelIntegrations::Multiplexer
  module MessageService
    include Iam::AuthToken
    MULTIPLEXER_MESSAGE_API_PATH = '/api/v2/channels/%{channel_id}/messages'
    TIMEOUT_IN_SEC = 120

    def post_message(user, params)
      response = multiplexer.post do |req|
        req.url format(MULTIPLEXER_MESSAGE_API_PATH, channel_id: params[:channel_id])
        req.headers['Content-Type'] = 'application/json'
        req.headers['Authorization'] = construct_jwt_with_bearer(user)
        req.body = payload(params)
        req.options.timeout = TIMEOUT_IN_SEC
      end
      Rails.logger.info "Multiplexer response status:#{response.status}, body:#{response.body.try(:inspect)}"
    end

    def multiplexer
      Faraday.new(AppConfig['microservices']['internal_endpoint']) do |faraday|
        faraday.response :json, content_type: /\bjson$/
        faraday.adapter Faraday.default_adapter
      end
    end

    def payload(params)
      note = Account.current.notes.find_by_id(params[:note_id])
      {
        profile_unique_id: params[:profile_unique_id],
        body: params[:body],
        ticket_id: params[:ticket_id],
        attachments: (note.present? ? attachments_array(note) : [])
      }.to_json
    end

    def attachments_array(note)
      note.attachments.each_with_object([]) do |attachment, result|
        result << { file_name: attachment.content_file_name, url: attachment.attachment_url_for_api }
      end
    end
  end
end
