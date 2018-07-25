class HyperTrail::Timeline < HyperTrail::Base

  TIMELINE_BASIC_AUTH = {
    username: HyperTrail::CONFIG['timeline']['username'].freeze,
    password: HyperTrail::CONFIG['timeline']['password'].freeze
  }

  def hyper_trail_type
    'timeline'
  end

  def fetch
    response = hypertrail_response
    modify_response(response)
  end

  def timeline_type
    "#{params[:type]}timeline"
  end

  def basic_auth
    TIMELINE_BASIC_AUTH
  end

  def constructed_url
    params.symbolize_keys!
    url = base_url
    "#{url}/#{timeline_type}/#{params[:id]}"
  end

  def hypertrail_response(url = constructed_url)
    Rails.logger.info "HyperTrail Request => url #{url}, params #{params.inspect}"
    response = HTTParty.get(url, params.merge(basic_auth: basic_auth))
    if response.code != 200
      Rails.logger.debug "HyperTrail Fail. #{response.code} #{response.body}"
      error_msg = "HyperTrail Failure :: Account id : #{Account.current.id} \
                  :: Resource :: #{timeline_type} :: Resource id: #{params[:id]} :: Response :: #{response.code} :: \
                  #{response.body}"
      Rails.logger.error "#{error_msg} Message: #{e.message}"
      NewRelic::Agent.notice_error(e, error_msg.squish)
      raise
    end
    JSON.parse response.body
  end

  def modify_response(response)
    response.symbolize_keys!
    data = response[:data]
    result = {}
    activity_data = data.first(CompanyConstants::MAX_ACTIVITIES_COUNT)
    result[:ticket_ids] = []
    result[:post_ids] = []
    activity_data.each do |each_activity|
      each_response = each_activity.deep_symbolize_keys
      content = each_response[:content]
      type = content.keys.first
      case type
      when :ticket
        result[:ticket_ids].push(content[:ticket][:display_id])
      when :post
        result[:post_ids].push(content[:post][:id])
      end
    end
    result.delete(:ticket_ids) if result[:ticket_ids].empty?
    result.delete(:post_ids) if result[:post_ids].empty?
    { data: result }
  end
end
