class Aloha::SignupController < ApplicationController
  include Aloha::Constants
  include Aloha::Validations
  include Aloha::Util
  include Freshchat::AgentUtil
  include Freshcaller::AgentUtil
  include Freshcaller::Util
  include Freshchat::Util
  include Freshchat::JwtAuthentication

  skip_before_filter :check_privilege, :verify_authenticity_token, only: [:callback]
  before_filter :validate_params, only: [:callback]
  around_filter :select_account, only: [:callback]
  before_filter :seeder_product_validations, only: [:callback]
  before_filter :verify_aloha_token, only: [:callback]

  def callback
    seeder_product = params['product_name'].downcase
    Rails.logger.info "Aloha - Bundle Linking API - account #{@current_account.id} :: #{seeder_product} :: #{@current_account.omni_bundle_id}"
    if safe_send("create_#{seeder_product}_record")
      Rails.logger.info "Aloha - Bundle Linking API success #{@current_account.id} :: #{seeder_product}"
      render json: { status: 200, message: "#{seeder_product} record created successfully" }
    else
      Rails.logger.info "Aloha - Bundle Linking API failed #{@current_account.id} :: #{seeder_product}"
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
      Account.current.launched?(:launch_kbase_omni_bundle) && enable_kbase_omni_bundle_in_freshchat && Account.current.launch(:kbase_omni_bundle)
      send_access_token_to_chat
    end

    def create_freshcaller_record
      freshcaller_params = params['account']
      freshcaller_misc_params = params['misc'].is_a?(Hash) ? params['misc'] : JSON.parse(params['misc'])
      Freshcaller::Account.create(account_id: @current_account.id, freshcaller_account_id: freshcaller_params['id'], domain: freshcaller_params['domain'])
      @current_account.add_feature(:freshcaller)
      @current_account.add_feature(:freshcaller_widget)
      enable_freshcaller_agent(@current_account.account_managers.first, freshcaller_misc_params['user']['freshcaller_account_admin_id'])
      link_params = freshcaller_bundle_linking_params(@current_account, @current_account.admin_email, admin_access_token, params)
      send_access_token_to_caller(params['account']['domain'], link_params)
    end

    def select_account(&block)
      params[:freshdesk_account_id] = get_account_id(params['organisation']['id'])
      if params[:freshdesk_account_id].nil?
        aloha_linking_error_logs ORG_ACC_MAP_MISSING_CODE
        render json: { message: 'Account ID Not Found!' }, status: 500 and return
      end
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
      response = update_access_token(@current_account.domain, admin_access_token, fc_acc, freshchat_jwt_token)
      aloha_linking_error_logs UPDATE_FRESHCHAT_ACCESS_TOKEN_CODE if response.code != 200
      response
    end

    def enable_kbase_omni_bundle_in_freshchat
      fc_acc = Account.current.freshchat_account
      return false if fc_acc.nil?

      begin
        feature_name = :kbase_omni_bundle
        response = update_features([feature_name], [], fc_acc, freshchat_jwt_token)
        return true if response.code == 200 && JSON.parse(response.body)['enabled_features'].include?(feature_name.to_s)
      rescue StandardError => e
        Rails.logger.info "Exception while enabling kbase_omni_bundle feature in freshchat message: #{e.message}, exception: #{e.backtrace}"
      end

      aloha_linking_error_logs ENABLE_KBASE_OMNI_BUNDLE_FRESHCHAT
      false
    end

    def enable_freshchat_agent
      account_admin = @current_account.account_managers.first
      if account_admin.present? && @current_account.omni_chat_agent_enabled? && account_admin.agent.additional_settings.try(:[], :freshchat).nil?
        agent = account_admin.agent
        additional_settings = agent.additional_settings
        additional_settings.merge!(freshchat: { enabled: true })
        agent.update_attribute(:additional_settings, additional_settings)
        Rails.logger.info "Enabled Freshchat from signup for Account #{@current_account.id} and for Agent #{agent.id}"
      else
        aloha_linking_error_logs ENABLE_FRESHCHAT_AGENT_CODE
      end
    end

    def admin_access_token
      @current_account.users.find_by_email(@current_account.admin_email).single_access_token
    end

    def aloha_linking_error_logs(errorcode)
      Rails.logger.info "Aloha - Bundle Linking API error - #{errorcode} :: #{@current_account.id} :: #{@current_account.omni_bundle_id}"
    end
end
