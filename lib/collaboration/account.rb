class Collaboration::Account
  require 'net/http'
  require 'jwt'
  require 'json'

  def initialize
    @current_account = Account.current
  end

  def pre_collab_enable
    register_account_with_collab
  end

  def pre_collab_disable
    disable_account_with_collab
  end

  def disable_collab_bitmap_feature
    @current_account.revoke_feature(:collaboration)
  end

  private

    def disable_account_with_collab
      protocol = Rails.env.development? ? 'http://' : 'https://'
      res = RestClient::Request.execute(
        method: :post,
        url: "#{CollabConfig['collab_url']}/accounts.disable",
        payload: {
          account_id: @current_account.id.to_s,
        }.to_json,
        headers: {
          'Content-Type' => 'application/json',
          'Authorization' => collab_request_token,
          'ClientId' => Collaboration::Ticket::HK_CLIENT_ID
        }) || {}

      if res.code == 200 || res.code == 201
        Rails.logger.info "Response: #{res.body}"
      else
        Rails.logger.error "Error while disabling Account to ChatApi. Response: #{res.body}, #{res.code}"
      end
    end

    def register_account_with_collab
      protocol = Rails.env.development? ? 'http://' : 'https://'
      res = RestClient::Request.execute(
        method: :post,
        url: "#{CollabConfig['collab_url']}/accounts.enable",
        payload: {
          domain_url: "#{protocol}#{Account.current.full_domain}",
          access_token: account_admin.single_access_token.presence
        }.to_json,
        headers: {
          'Content-Type' => 'application/json',
          'Authorization' => collab_request_token,
          'ClientId' => Collaboration::Ticket::HK_CLIENT_ID
        }) || {}

      if res.code == 200 || res.code == 201
        Rails.logger.info "Response: #{res.body}"
        resp_json = JSON.parse(res.body)
        cset = collab_setting
        cset.key = resp_json['key']
        @current_account.collab_settings = cset
        @current_account.collab_settings.save

        if res.code == 200
          reset_collab_agents
        else
          sync_agents_to_collab
          enable_iris
        end
      else
        Rails.logger.error "Error while enabling to ChatApi. Will disabled collab bitmap feature. Response: #{res.body}, #{res.code}"
        disable_collab_bitmap_feature
      end
    end

    def enable_iris
      unless @current_account.has_feature?(:user_notifications)
        @current_account.add_feature(:user_notifications)
      end
    end

    def collab_setting
      cset = Collab::Setting.find_by_account_id(@current_account.id)
      if cset.blank?
        cset = Collab::Setting.new
        cset.account_id = @current_account.id
      end
      cset
    end

    def reset_collab_agents
      res = RestClient::Request.execute(
        method: :post,
        url: "#{CollabConfig['collab_url']}/users.deleteAll",
        headers: {
          'Authorization' => collab_request_token,
          'ClientId' => Collaboration::Ticket::HK_CLIENT_ID
        }) || {}

      if res.code == 200 || res.code == 201
        sync_agents_to_collab
        enable_iris
      else
        Rails.logger.error "users.deleteAll failed. Error while resetting users on collab. Will disabled collab bitmap feature. Response: #{res.body}, #{res.code}"
        disable_collab_bitmap_feature
      end
    end

    def sync_agents_to_collab
      @current_account.technicians.find_each do |user|
        message = {
          object: 'user',
          user_properties: {
            id: user.id,
            account_id: @current_account.id,
            name: user.name,
            job_title: user.job_title,
            email: user.email,
            mobile: user.mobile,
            phone: user.phone,
            created_at: user.created_at,
            deleted: user.deleted,
            helpdesk_agent: user.helpdesk_agent,
            is_admin: user.privilege?(:admin_tasks)
          }
        }
        AwsWrapper::SqsV2.send_message(SQS[:collab_agent_update_queue], message.to_json)
        Rails.logger.info "Collab: SQS: #{user.name} added to the queue: #{SQS[:collab_agent_update_queue]}"
      end
    end

    def collab_request_token
      @request_token ||= JWT.encode(
        {
          ClientAccountId: @current_account.id.to_s,
          ClientId: Collaboration::Ticket::HK_CLIENT_ID,
          IsServer: '1'
        }, CollabConfig['secret_key']
      )
    end

    def account_admin
      @current_account.account_managers.first
    end
end
