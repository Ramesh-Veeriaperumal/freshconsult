class ProductFeedbackWorker < BaseWorker
  sidekiq_options queue: :product_feedback, retry: 0, backtrace: true, failures: :exhausted

  def perform(payload)
    payload.symbolize_keys!
    api_key = PRODUCT_FEEDBACK_TOKENS['api_key']
    headers = {
      'Authorization' => "Basic #{Base64.encode64(api_key).strip}",
      'Content-Type' => 'application/json'
    }
    http_resp = HTTParty.post("#{AppConfig[:feedback_account][Rails.env]}/api/v2/tickets", body: payload.to_json, headers: headers)
    raise 'Feedback creation failed' unless http_resp.code == 201
  end
end
