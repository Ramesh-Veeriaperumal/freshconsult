class HyperTrail::Base
  attr_accessor :params

  def initialize(params)
    @params = params
  end

  def fetch
    if params[:next].present?
      valid_next_link = next_link_valid? params[:next]
      Rails.logger.info 'Invalid next link' unless valid_next_link
      return { data: [] } unless valid_next_link
      url = params[:next]
      @params = {}
    else
      url = full_url
    end
    Rails.logger.info "HT Request => url #{url}, params #{params.inspect}"
    response = HTTParty.get(url, basic_auth: basic_auth, query: params)
    if response.code != 200
      Rails.logger.debug "HT Fail. #{response.code} #{response.body}"
      return { data: [] }
    end
    JSON.parse response.body
  end

  def trigger_export
    url = export_base_url
    Rails.logger.info "Export Request => url #{url}, params #{params.inspect}"
    response = HTTParty.post(url, basic_auth: basic_auth_export, headers: { 'Content-Type' => 'application/json' }, body: params.to_json)

    if response.code != 202
      Rails.logger.debug "HT Fail. #{response.code} #{response.body}"
      return { data: response }
    end
    JSON.parse response.body
  end

  def retrive_export_data
    user_id = User.current.id
    AuditLogExport.perform_at(2.seconds.from_now, export_job_id: params['job_id'], time: 0, user_id: user_id,
                                                  archived: params[:archived], receive_via: params[:receive_via], format: params[:export_format])
  end

  private

    def full_url
      url = base_url
      if (AuditLogConstants::AUDIT_LOG_PARAMS & params.keys).any?
        AuditLogConstants::AUDIT_LOG_PARAMS.each do |param|
          url = "#{url}/#{param}/#{params[param]}"
          params.delete(param)
        end
      end
      url
    end

    def base_url
      format((HyperTrail::CONFIG[hyper_trail_type]['api_endpoint']).to_s,
             account_id: Account.current.id)
    end

    def export_base_url
      if params[:archived] == AuditLogConstants::ARCHIVED[0]
        format((HyperTrail::CONFIG[hyper_trail_archived_export]['api_endpoint']).to_s,
               account_id: Account.current.id)
      else
        format((HyperTrail::CONFIG[hyper_trail_filtered_export]['api_endpoint']).to_s,
               account_id: Account.current.id)
      end
    end

    def next_link_valid?(link)
      link.start_with?("#{base_url}?")
    end

    def basic_auth
      {
        username: HyperTrail::CONFIG[hyper_trail_type]['username'],
        password: HyperTrail::CONFIG[hyper_trail_type]['password']
      }
    end

    def basic_auth_export
      {
        username: HyperTrail::CONFIG[hyper_trail_filtered_export]['username'],
        password: HyperTrail::CONFIG[hyper_trail_filtered_export]['password']
      }
    end
end
