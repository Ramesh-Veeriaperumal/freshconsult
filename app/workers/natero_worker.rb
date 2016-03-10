class NateroWorker < BaseWorker
  sidekiq_options :queue => :natero_worker, :retry => 0, :backtrace => true, :failures => :exhausted

  def perform(params)
    Rails.logger.info "Natero worker"
    Rails.logger.info "JID #{jid} - TID #{Thread.current.object_id.to_s(36)}"
    Rails.logger.info "Start time :: #{Time.now.strftime('%H:%M:%S.%L')}"
    Rails.logger.info "Params :: #{params.inspect}"

    params.symbolize_keys!

    return if ::Account.current.blank? ||
              AppConfig['natero'][Rails.env].blank? ||
              params.blank? || params[:custom_options].blank?

    current_account = ::Account.current

    account_response = api_request_get(current_account.id)

    if request_success?(account_response) && account_response['results'].present?
      post_response = api_request_post(
        custom_options(current_account.id, params[:custom_options]).to_json)
    else
      post_response = api_request_post(
        account_options(current_account, params[:custom_options]).to_json)
    end

    Rails.logger.info "Account Response :: #{account_response}\n
    Natero's Response :: #{post_response}"

    unless request_success?(post_response)
      Rails.logger.error "Natero Post Failed\n
        Account :: #{current_account.id}\n"
      fail StandardError, 'Nater Post Failed', post_response
    end
  rescue => e
    Rails.logger.error "Error on while notifying natero api
      For Account ::#{current_account.id}\n
      Exception Message :: #{e.message}\n
      Exception Stacktrace :: #{e.backtrace.join('\n\t')}"
  end

  private

    def custom_options(account_id, options)
      {
        records: [{
          account_id: account_id
        }.merge(options)]
      }
    end

    def account_options(account, options)
      {
        records: [{
          account_id: account.id,
          name: account.name,
          join_date: (account.created_at.to_f * 1000)
        }.merge(options)]
      }
    end

    def api_request_post(request_body)
      HTTParty.post(
        "#{AppConfig['natero'][Rails.env]['url']}?api_key=#{AppConfig['natero'][Rails.env]['api_key']}",
        body: request_body,
        headers: { 'Content-Type' => 'application/json' })
    end

    def api_request_get(account_id)
      HTTParty.get(
        "#{AppConfig['natero'][Rails.env]['url']}/#{account_id}?api_key=#{AppConfig['natero'][Rails.env]['api_key']}",
        headers: { 'Content-Type' => 'application/json' })
    end

    def request_success?(response)
      response.present? && response['status_is_ok'].present?
    end
end

