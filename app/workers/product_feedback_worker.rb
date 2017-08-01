class ProductFeedbackWorker < BaseWorker
  sidekiq_options queue: :product_feedback, retry: 0, backtrace: true, failures: :exhausted

  def perform(payload)
    payload.symbolize_keys!
    api_key = PRODUCT_FEEDBACK_CONFIG['api_key']
    headers = {
      'Authorization' => "Basic #{Base64.encode64(api_key).strip}",
      'Content-Type' => 'application/json'
    }
    http_resp = HTTParty.post("#{PRODUCT_FEEDBACK_CONFIG['feedback_account']}/#{PRODUCT_FEEDBACK_CONFIG['feedback_path']}", body: payload.to_json, headers: headers)
    raise 'Feedback creation failed' unless http_resp.code == 201
  end
end
