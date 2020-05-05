class Aloha::SignupController < ApplicationController
  include Aloha::Constants
  include Aloha::Validations
  include Aloha::Util
  include Freshchat::AgentUtil
  include Freshcaller::AgentUtil
  include Freshchat::JwtAuthentication
  include Freshcaller::JwtAuthentication

  skip_before_filter :check_privilege, :verify_authenticity_token, only: [:callback]
  before_filter :validate_params, only: [:callback]
  around_filter :select_account, only: [:callback]
  before_filter :seeder_product_validations, only: [:callback]
  before_filter :verify_aloha_token, only: [:callback]

  def callback
    seeder_product = params['product_name'].downcase
    if safe_send("create_#{seeder_product}_record")
      render json: { status: 200, message: "#{seeder_product} record created successfully" }
    else
      render json: { status: 500, message: "#{seeder_product} record creation failed" }
    end
  end

  private

    def validate_params
      params.permit(*CALLBACK_PARAMS)
      params['account'].permit(*ACCOUNT_PARAMS)
      params['organisation'].permit(*ORGANISATION_PARAMS)
      params['user'].permit(*USER_PARAMS)
    end

    def create_freshchat_record
      freshchat_account_params = params['account']
      freshchat_misc_params = params['misc'].is_a?(Hash) ? params['misc'] : JSON.parse(params['misc'])
      @current_account.create_freshchat_account(app_id: freshchat_misc_params['userInfoList'][0]['appId'], portal_widget_enabled: false, token: freshchat_misc_params['userInfoList'][0]['webchatId'], enabled: true, domain: freshchat_account_params['domain'])
      enable_freshchat_agent
      send_access_token_to_chat
    end

    def create_freshcaller_record
      freshcaller_params = params['account']
      @current_account.add_feature(:freshcaller)
      @current_account.add_feature(:freshcaller_widget)
      Freshcaller::Account.create(account_id: @current_account.id, freshcaller_account_id: freshcaller_params['id'], domain: freshcaller_params['domain'])
      enable_freshcaller_agent
      send_access_token_to_caller
    end

    def select_account(&block)
      params[:freshdesk_account_id] = get_account_id(params['organisation']['id'])
      render json: { message: 'Account ID Not Found!' }, status: 500 and return if params[:freshdesk_account_id].nil?
      begin
        Sharding.select_shard_of(params[:freshdesk_account_id]) do
          @current_account = Account.find(params[:freshdesk_account_id])
          @current_account.make_current
          yield
          Account.reset_current_account
        end
      rescue ActiveRecord::RecordNotFound, ShardNotFound, DomainNotReady, AccountBlocked => e
        NewRelic::Agent.notice_error(e)
        render json: { message: "Something went wrong => #{e.inspect}" }, status: 500
      end
    end

    def get_account_id(org_id)
      return @account_id if @account_id.present?

      org = Organisation.where(organisation_id: org_id).first
      @account_id = OrganisationAccountMapping.where(organisation_id: org.id).first.try(:account_id) if org.present?
    end

    def send_access_token_to_chat
      fc_acc = Account.current.freshchat_account
      return if fc_acc.nil?
    
      response = HTTParty.put("https://#{fc_acc.api_domain}/v2/omnichannel-integration/#{fc_acc.app_id}",
                              body: { account: @current_account.domain, token: admin_access_token }.to_json,
                              headers: { 'Content-Type' => 'application/json',
                                         'Accept' => 'application/json',
                                         'x-fc-client-id' => Freshchat::Account::CONFIG[:freshchatClient],
                                         'Authorization' => "Bearer #{freshchat_jwt_token}" })
      Rails.logger.info "Omni freshchat Response :: #{response.code} :: #{response.headers.inspect}"
    end

    def send_access_token_to_caller
      response = freshcaller_request(linking_params ,"https://#{params['account']['domain']}/link_account", :put)
      Rails.logger.info "Omni freshcaller Response :: #{response.code} :: #{response.headers.inspect}"
    end

    def enable_freshchat_agent
      account_admin = @current_account.account_managers.first
      if account_admin.present? && @current_account.omni_chat_agent_enabled? && valid_freshchat_agent_action?(account_admin.agent)
        agent = account_admin.agent
        agent.freshchat_enabled = true
        handle_fchat_agent(agent)
      end
    end

    def enable_freshcaller_agent
      account_admin = @current_account.account_managers.first
      if account_admin.present? && Account.current.freshcaller_enabled? && valid_fcaller_agent_action?(account_admin.agent)
        agent = account_admin.agent
        agent.freshcaller_enabled = true
        freshcaller_misc_params = params['misc'].is_a?(Hash) ? params['misc'] : JSON.parse(params['misc'])
        agent.create_freshcaller_agent(agent: agent, fc_enabled: true, fc_user_id: freshcaller_misc_params['user']['freshcaller_account_admin_id'])
        handle_fcaller_agent(agent)
      end
    end

    def linking_params
      { account_name: @current_account.name,
        account_id: @current_account.id,
        email: @current_account.admin_email,
        url: params['account']['domain'],
        activation_required: false,
        app: 'Freshdesk',
        bundle_id: params['bundle_id'],
        freshdesk_calls_url: "https://#{@current_account.full_domain}/api/channel/freshcaller_calls",
        domain_url: "https://#{@current_account.full_domain}",
        access_token: admin_access_token,
        account_region: ShardMapping.fetch_by_account_id(@current_account.id).region,
        fresh_id_version: Freshid::V2::Constants::FRESHID_SIGNUP_VERSION_V2,
        organisation_domain: @current_account.organisation_domain }
    end

    def admin_access_token
      @current_account.users.find_by_email(@current_account.admin_email).single_access_token
    end
end
