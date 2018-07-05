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
    Rails.logger.debug "HT Fail. #{response.code} #{response.body}" if response.code != 200
    JSON.parse response.body
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

    def next_link_valid?(link)
      link.start_with?("#{base_url}?")
    end

    def basic_auth
      {
        username: HyperTrail::CONFIG[hyper_trail_type]['username'],
        password: HyperTrail::CONFIG[hyper_trail_type]['password']
      }
    end
end
