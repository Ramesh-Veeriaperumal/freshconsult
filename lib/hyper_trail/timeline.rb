class HyperTrail::Timeline < HyperTrail::Base

  TIMELINE_BASIC_AUTH = {
    username: HyperTrail::CONFIG['timeline']['username'].freeze,
    password: HyperTrail::CONFIG['timeline']['password'].freeze
  }

  TICKET_TYPE = 'ticket'.freeze
  POST_TYPE = 'post'.freeze
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
    response.symbolize_keys!
    activity_data = response[:data]
    all_activities = []
    link_data = response[:links]
    activity_data.each do |each_activity|
      each_activity.symbolize_keys!
      content = each_activity[:content]
      type = content.keys.first
      ret_hash = {
        activity: {
          name: each_activity[:action],
          actor: each_activity[:actor].symbolize_keys,
          object: {
            type: type
          }
        }
      }
      case type
      when TICKET_TYPE
        ret_hash[:activity][:source] = freshdesk_source
        ret_hash[:activity][:object][:id] = content['ticket']['display_id']
      when POST_TYPE
        ret_hash[:activity][:source] = freshdesk_source
        ret_hash[:activity][:object][:id] = content['post']['id']
      end
      all_activities << ret_hash
    end
    modified_response = { activities: all_activities, link: link_data }
    HyperTrail::Response.new(modified_response)
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

    def freshdesk_source
      {
        name: FRESHDESK_SOURCE,
        id: Account.current.id
      }
    end
end
