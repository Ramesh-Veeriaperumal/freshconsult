class Helpdesk::InlineAttachmentsController < ApplicationController
  
  skip_before_filter :freshdesk_form_builder 
  
  skip_before_filter :remove_pjax_param
  skip_before_filter :check_privilege
  skip_before_filter :redirect_to_mobile_url
  skip_before_filter :set_time_zone, :check_day_pass_usage 
  skip_before_filter :set_locale, :force_utf8_params
  skip_before_filter :ensure_proper_protocol
  around_filter { |&block| Sharding.run_on_slave(&block) }
  before_filter :redirect_to_referer_host, :if => :global_host?
  before_filter :check_anonymous_user
  
  def one_hop_url
    decoded_hash = Helpdesk::Attachment.decode_token(params[:token])
    attachment = current_account.attachments.where(:id => decoded_hash[:id]).first
    if attachment.present?
      redirect_to attachment.authenticated_s3_get_url(:expires => 5.minutes)
    else
      render_404
    end
  rescue => e
    Rails.logger.info e
    render :nothing => true, :status => 500
  end

  private

    def env_config
      @env_config ||= AppConfig[:attachment][Rails.env]
    end

    def global_host
      @global_host ||= env_config[:domain][PodConfig['CURRENT_POD']]
    end

    def global_host?
      request.host == global_host
    end

    def request_host
      @request_host ||= current_domain
    end

    def current_domain
      payload[:domain]
    end

    def payload
      @payload ||= JSON.parse(JWT.base64url_decode(params[:token].split('.')[1]),{:symbolize_names => true})
    end

    def redirect_host
      if request.referer
        referer_uri = URI(request.referer)
        "#{referer_uri.scheme}://#{referer_uri.host}"
      else
        "#{env_config[:protocol]}://#{request_host}"
      end
    end

    def invalid_referer? referer_host
      shard_mapping = ShardMapping.fetch_by_domain(referer_host)
      shard_mapping.nil? || shard_mapping.account_id != current_account.id
    end

    def redirect_to_referer_host
      referer = redirect_host
      host = URI(referer).host
      # Checking the host to ensure its not the same as global host to avoid looping
      # Also, checking to ensure the host is not a third party referer to avoid a redirect attack
      render_404 and return if host == global_host || invalid_referer?(host)
      redirect_to "#{referer}#{env_config[:port]}/inline/attachment?token=#{params[:token]}"
    end
end
