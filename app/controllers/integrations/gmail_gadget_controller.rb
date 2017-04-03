require 'oauth/request_proxy/rack_request'

class Integrations::GmailGadgetController < ApplicationController
  include Redis::RedisKeys

  skip_before_filter :check_privilege, :verify_authenticity_token, :only => [:spec, :open_social_auth]

  skip_filter :select_shard, :only => [:open_social_auth]

  skip_before_filter :check_account_state, :check_day_pass_usage, :determine_pod, :set_current_account, :set_locale,
                     :ensure_proper_protocol, :only => [:open_social_auth]

  skip_after_filter :set_last_active_time, :only => [:open_social_auth]

  OPEN_SOCIAL_CERTIFICATE = OpenSSL::X509::Certificate.new(
                                File.read("#{Rails.root}/config/cert/pub.1210278512.2713152949996518384.cer"))


  def spec
  end

  def open_social_auth
    response = nil
    begin
      Account.reset_current_account
      response = verify_request_signature
    rescue => e
      Rails.logger.error "Problem in processing google opensocial request. \n#{e.message}\n#{e.backtrace.join("\n\t")}"
      response = { :verified => :false, :reason=>t("flash.gmail_gadgets.unknown_error") }
    end
    Rails.logger.debug "result json #{response.inspect}"
    render :json => response
  end

  private

    def verify_request_signature
      response = nil
      sign = certificate_signature
      if sign.present? && sign.verify
        account_id = find_account_by_google_domain(params[:domain])
        if account_id.blank?
          response = { :verified => :false, :reason => t("flash.gmail_gadgets.account_not_associated") }
        else
          Sharding.select_shard_of(account_id) do
            account = Account.find(account_id)
            account.make_current
            response = lookup_with_viewer_id(viewer_id, account)
          end
        end
      else
        response = { :verified => :false, :reason => t("flash.gmail_gadgets.gmail_request_unverified") }
      end
      response
    end

    def certificate_signature
      public_key = OpenSSL::PKey::RSA.new(OPEN_SOCIAL_CERTIFICATE.public_key)
      container = params['opensocial_container']
      consumer = OAuth::Consumer.new(container, public_key)
      req = OAuth::RequestProxy::RackRequest.new(request)
      OAuth::Signature::RSA::SHA1.new(req, {:consumer => consumer})
    end

    def find_account_by_google_domain google_domain_name
      google_domain = Integrations::GoogleRemoteAccount.where(:remote_id => "#{google_domain_name}").first
      if google_domain.present?
        google_domain.account_id
      else
        full_domain  = "#{google_domain_name.split('.').first}.#{AppConfig['base_domain'][Rails.env]}"
        sm = ShardMapping.fetch_by_domain(full_domain)
        sm.present? ? sm.account_id : nil
      end
    end

    def lookup_with_viewer_id google_viewer_id, account
      if google_viewer_id.blank?
        { :verified => :false, :reason => t("flash.gmail_gadgets.viewer_id_not_sent_by_gmail") }
      else
        agent = account.agents.find_by_google_viewer_id(google_viewer_id)
        agent_verification_response(agent, google_viewer_id, account)
      end
    end

    def agent_verification_response agent, google_viewer_id, account
      if agent.blank?
        { :user_exists => :false,
          :t => generate_random_hash(google_viewer_id, account)
        }
      elsif agent.user.deleted? or !agent.user.active?
        { :verified => :false,
          :reason => t("flash.gmail_gadgets.agent_not_active")
        }
      else
        { :user_exists => :true,
          :t => agent.user.single_access_token,
          :url_root => account.full_domain,
          :ssl_enabled => account.ssl_enabled
        }
      end
    end

    def viewer_id
      params['opensocial_viewer_id'] || params['opensocial_owner_id']
    end

    def generate_random_hash google_viewer_id, account
      generated_hash = Digest::MD5.hexdigest(DateTime.now.to_s + google_viewer_id)
      key_options = { :account_id => account.id, :token => generated_hash}
      key_spec = Redis::KeySpec.new(GADGET_VIEWERID_AUTH, key_options)
      Redis::KeyValueStore.new(key_spec, google_viewer_id, {:group => :integration, :expire => 300}).set_key
      generated_hash
    end

end
