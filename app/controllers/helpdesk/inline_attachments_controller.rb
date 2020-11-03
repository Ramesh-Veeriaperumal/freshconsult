class Helpdesk::InlineAttachmentsController < ApplicationController
  
  skip_before_filter :freshdesk_form_builder 
  
  skip_before_filter :remove_pjax_param
  skip_before_filter :check_privilege
  skip_before_filter :set_time_zone, :check_day_pass_usage 
  skip_before_filter :set_locale, :force_utf8_params
  skip_before_filter :ensure_proper_protocol, :ensure_proper_sts_header
  skip_before_filter :determine_pod
  around_filter :run_on_slave
  before_filter :redirect_to_host, :if => :global_host?
  before_filter :check_anonymous_user, :if => :private_inline?
  
  def one_hop_url
    decoded_hash = Helpdesk::Attachment.decode_token(params[:token])
    unless decoded_hash
      render nothing: true, status: 400
      return
    end
    attachment = current_account.attachments.where(:id => decoded_hash[:id]).first
    if attachment.present?
      redirect_to attachment.authenticated_s3_get_url(expires_in: attachment.expiry.try(:to_i))
    else
      render_404
    end
  end

  private

    def env_config
      @env_config ||= AppConfig[:attachment][Rails.env]
    end

    def global_host
      @global_host ||= env_config[:domain][PodConfig['CURRENT_POD']]
    end

    #Hack done to avoid inline attachment regression during EU -> EUC migration
    def global_host?
      request.host == global_host || (request.host == "euattachment.freshdesk.com" && PodConfig['CURRENT_POD'].include?("podeucentral"))
    end

    def request_host
      @request_host ||= global_host? ? image_domain : request.host
    end

    def payload
      @payload ||= JSON.parse(JWT.base64url_decode(params[:token].split('.')[1]),{:symbolize_names => true})
    rescue StandardError => e
      Rails.logger.info("Error in parsing token :: #{e.message}")
      nil
    end

    def image_account_id
      payload[:account_id]
    end

    def image_domain
      return unless payload
      return payload[:domain] if ShardMapping.fetch_by_domain(payload[:domain]).present?
      return unless image_account_id

      Sharding.select_shard_of(image_account_id) do
        Sharding.run_on_slave do
          return Account.find(image_account_id).try(:full_domain)
        end
      end
    rescue StandardError => e
      Rails.logger.info("Inline Image Account not found :: #{e.message}")
    end

    def image_host
      "#{current_account.url_protocol}://#{current_account.full_domain}"
    end

    def referer_host
      referer = request.referer
      return unless referer
      referer_uri = URI(referer)
      host = referer_uri.host
      "#{referer_uri.scheme}://#{host}" if host && image_account?(host)
    end

    def image_account? host
      shard_mapping = ShardMapping.fetch_by_domain(host)
      shard_mapping.present? && shard_mapping.account_id == current_account.id
    end

    def redirect_to_host
      redirect_host = referer_host || image_host
      redirect_to "#{redirect_host}#{env_config[:port]}/inline/attachment?token=#{params[:token]}"
    end

    def private_inline?
      current_account.private_inline_enabled?
    end
end
