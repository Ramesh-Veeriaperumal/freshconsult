class HyperTrail::Timeline < HyperTrail::Base
  TIMELINE_BASIC_AUTH = {
    username: HyperTrail::CONFIG['timeline']['username'].freeze,
    password: HyperTrail::CONFIG['timeline']['password'].freeze
  }.freeze

  TICKET_TYPE = 'ticket'.freeze
  POST_TYPE = 'post'.freeze
  SURVEY_TYPE = 'survey'.freeze
  CUSTOM_ACTIVITY = 'contact_custom_activity'.freeze
  FRESHDESK_SOURCE = 'freshdesk'.freeze

  def hyper_trail_type
    'timeline'
  end

  def fetch
    response = perform_hypertrail_request(constructed_url)
    modify_response(response)
  end

  def fetch_next_page
    params.symbolize_keys!
    next_page_url = "#{constructed_url}?#{params[:after]}"
    response = perform_hypertrail_request(next_page_url)
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

  def modify_response(response)
    ht_response = HyperTrail::Response.new
    response.symbolize_keys!
    activity_data = response[:data]
    link_data = response[:links]
    activity_data.each do |activity|
      activity.symbolize_keys!
      ht_response.push(activity)
    end
    ht_response.meta_info(link_data)
    ht_response.transform_activities
    ht_response
  end

  private

    def perform_hypertrail_request(url)
      Rails.logger.info "HyperTrail Request => url #{url}, params #{params.inspect}"
      response = HTTParty.get(url, params.merge(basic_auth: basic_auth))
      if response.code != 200
        Rails.logger.debug "HyperTrail Fail. #{response.code} #{response.body}"
        error_msg = "HyperTrail Failure :: Account id : #{Account.current.id} \
                    :: Resource :: #{timeline_type} :: Resource id: #{params[:id]} :: Response :: #{response.code} :: \
                    #{response.body}"
        Rails.logger.error error_msg.to_s
        NewRelic::Agent.notice_error(error_msg.squish)
        raise
      end
      JSON.parse response.body
    end
end
