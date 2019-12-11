module Freshcaller::Util
  include Freshcaller::Endpoints
  include Freshcaller::JwtAuthentication

  def enable_freshcaller_feature
    freshcaller_response = freshcaller_request(signup_params, "#{FreshcallerConfig['signup_domain']}/accounts", :post)
    activate_freshcaller(freshcaller_response) if freshcaller_response.present? && freshcaller_response['freshcaller_account_id'].present?
    freshcaller_response
  end

  def disconnect_account
    freshcaller_response = freshcaller_request({}, freshcaller_disconnect_url, :put, email: current_user.email)
    Freshcaller::AccountDeleteWorker.perform_async(account_id: Account.current.id) if freshcaller_response.code == 200
    freshcaller_response
  end

  def enable_integration
    freshcaller_response = freshcaller_request({}, freshcaller_enable_url, :put, email: current_user.email)
    Account.current.freshcaller_account.enable if freshcaller_response.code == 200
    freshcaller_response
  end

  def disable_integration
    freshcaller_response = freshcaller_request({}, freshcaller_disable_url, :put, email: current_user.email)
    Account.current.freshcaller_account.disable if freshcaller_response.code == 200
    freshcaller_response
  end

  private

    def activate_freshcaller(freshcaller_response)
      freshcaller_activation_actions(freshcaller_response)
      add_freshcaller_agent(freshcaller_response)
      current_account.toggle_phone_channel
    end

    def freshcaller_activation_actions(freshcaller_response)
      add_freshcaller_account(freshcaller_response)
      enable_freshcaller
      disable_freshfone if current_account.freshfone_enabled?
    end

    def add_freshcaller_account(freshcaller_response)
      @item = current_account.create_freshcaller_account(freshcaller_account_id: freshcaller_response['freshcaller_account_id'], domain: freshcaller_response['freshcaller_account_domain'])
    end

    def enable_freshcaller
      current_account.add_feature(:freshcaller)
      current_account.add_feature(:freshcaller_widget)
    end

    def disable_freshfone
      current_account.freshfone_account.suspend
      current_account.features.freshfone.destroy
    end

    def add_freshcaller_agent(freshcaller_response)
      current_user.agent.create_freshcaller_agent(agent: current_user.agent, fc_enabled: true, fc_user_id: freshcaller_response['user']['id'])
    end

    def signup_params
      suffix = defined?(@retry) ? rand.to_s[2..4] : '' # For retrying with random suffix for signup
      create_new_account_params = {
        signup: {
          user_name: current_user.name,
          user_email: current_user.email,
          user_phone: current_user.phone.presence || current_user.mobile,
          account_name: current_account.name,
          time_zone: current_account.conversion_metric.try(:offset).to_s,
          account_domain: "#{FreshcallerConfig['domain_prefix']}#{current_account.domain}#{suffix}",
          account_region: ShardMapping.fetch_by_account_id(current_account.id).region,
          currency: current_account.subscription.try(:currency).try(:name),
          api: {
            account_name: current_account.name,
            account_id: current_account.id,
            freshdesk_calls_url: "#{protocol}#{current_account.full_domain}/api/channel/freshcaller_calls",
            app: 'Freshdesk',
            client_ip: current_user.current_login_ip,
            domain_url: "#{protocol}#{current_account.full_domain}",
            access_token: current_user.single_access_token
          }
        }.merge(plan_name: Subscription::FRESHCALLER_PLAN_MAPPING[current_account.plan_name]).reject { |key, val| val.nil? },
        session_json: current_account.conversion_metric.try(:session_json),
        source: 'Freshdesk',
        medium: 'in-product',
        country: current_account.conversion_metric.try(:country),
        first_referrer: "#{protocol}#{current_account.full_domain}"
      }
      create_new_account_params.merge!(freshid_v2_params(true)) if current_account.freshid_org_v2_enabled?
      create_new_account_params
    end

    def freshid_v2_params(create_new_account = false)
      freshid_params = {
        fresh_id_version: Freshid::V2::Constants::FRESHID_SIGNUP_VERSION_V2,
        organisation_domain: current_account.organisation_domain
      }
      freshid_params[:join_token] = Freshid::V2::Models::Organisation.join_token if create_new_account
      freshid_params
    end

    def link_freshcaller(freshcaller_response)
      freshcaller_activation_actions(freshcaller_response)
      link_freshcaller_agents(freshcaller_response)
    end

    def link_freshcaller_agents(freshcaller_response)
      email_user_id_hash = freshcaller_response['user_details'].map { |user_hash| [user_hash['email'], user_hash['user_id']] }.to_h
      users = current_account.technicians.active(true).preload(:agent).where(email: email_user_id_hash.keys)
      users.each do |user|
        user.agent.create_freshcaller_agent(agent_id: user.agent.id,
                                            fc_enabled: true,
                                            fc_user_id: email_user_id_hash[user.email])
      end
    end

    def privileged_user?(user)
      (user.privilege?(:manage_account) || user.privilege?(:admin_tasks)) && user.active? if user
    end

    def linking_params
      link_params = params.merge(account_name: current_account.name,
                                 account_id: current_account.id,
                                 activation_required: false,
                                 app: 'Freshdesk',
                                 freshdesk_calls_url: "#{protocol}#{current_account.full_domain}/api/channel/freshcaller_calls",
                                 domain_url: "#{protocol}#{current_account.full_domain}",
                                 access_token: current_user.single_access_token,
                                 account_region: ShardMapping.fetch_by_account_id(current_account.id).region)
      link_params.merge!(freshid_v2_params) if current_account.freshid_org_v2_enabled?
      link_params
    end
end
