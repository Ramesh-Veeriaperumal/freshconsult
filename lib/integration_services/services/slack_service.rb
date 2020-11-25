module IntegrationServices::Services
  class SlackService < IntegrationServices::Service

    DEFAULT_LINES = 200
    OLD_SLACK_COMMAND = "create_ticket"
    NEW_SLACK_COMMAND = "create_ticket_v3"

    def receive_channels
      begin
        handle_success({ :channels => channel_resource.list })
      rescue => e
        handle_error(e)
      end
    end

    def receive_groups
      begin
        handle_success({ :groups => group_resource.list })
      rescue => e
        handle_error(e)
      end
    end

    def receive_history token, count=200
      begin
        handle_success({ :history => im_resource.history(token, count) })
      rescue => e
        handle_error(e)
      end
    end

    def receive_open user_id
      begin
        handle_success({ :open => im_resource.open(user_id)})
      rescue => e
        handle_error(e)
      end

    end

    def receive_auth_info
      begin
        handle_success({:auth_info => auth_resource.test(user_slack_token)})
      rescue => e
        handle_error(e)  
      end
    end

    def receive_users_list
      begin
        @users_list ||= handle_success({ :users_list => user_resource.list})
      rescue => e
        handle_error(e)
      end
    end

    def receive_post_message body_hash, dm=false
      begin
        handle_success({:post_notice => chat_resource.post_message(body_hash,dm)})
      rescue => e
        handle_error(e)
      end
    end

    def receive_push_to_slack
      if valid_push_to_channel?
        selected_value = @payload[:act_hash][:push_to]
        if selected_value == "dm_agent"
          send_dm
        else
          channel_id = @payload[:act_hash][:push_to]
          post_to_channel(channel_id) if channel_id.present?
        end
      end
    end

    def receive_slash_command
      user, user_cred = nil, nil
      if user_slack_token.present? && @payload[:act_hash][:event_type] == OLD_SLACK_COMMAND
        response = receive_auth_info
        if response[:error].blank?
          user_details = get_user
          user = user_details[:user]
          user_cred = user_details[:user_cred]
        end
      else
        user, user_cred = check_user_exists
      end
      create_ticket(user, user_cred) if user.present? && user_cred.present?
    end

    def receive_slash_command_v3
      user, user_cred = check_user_exists
      requester =  requester_from_dm(user_cred) if user_cred.present?
      create_ticket(user, user_cred, requester) if user.present? && user_cred.present?
    end

    def check_user_exists
      user_cred = @installed_app.user_credentials.find_by_remote_user_id(slack_user_id)
      user = user_cred.user if user_cred.present?
      return user, user_cred
    end

    def requester_from_dm(user_cred)
      dm_user = receive_im_user(user_cred.auth_info["oauth_token"], @payload[:act_hash][:channel_id])
      return nil if dm_user[:error].present?
      slack_user_email = get_users_list_hash[dm_user[:dm_user]][:user_email]
      requester = Account.current.user_emails.user_for_email(slack_user_email) || create_fd_user(get_users_list_hash[dm_user[:dm_user]]) if slack_user_email.present?
    end

    def receive_im_user(token, channel_id)
      begin 
        handle_success({:dm_user => im_resource.list(token, channel_id)})
      rescue => e
        handle_error(e)
      end  
    end 

    def receive_add_slack
      remote_integ_map = get_remote_mapping
      raise "The Slack team has been linked to another FreshDesk account"  if remote_integ_map.present?
      remote_integ_map = Integrations::SlackRemoteUser.create!(:account_id => @installed_app.account_id, :remote_id => @installed_app.configs_team_id)
    end    

    def receive_remove_slack
      remote_integ_map = get_remote_mapping
      remote_integ_map.destroy unless remote_integ_map.nil?
    end

    def get_remote_mapping 
      Integrations::SlackRemoteUser.where(:account_id => @installed_app.account_id , :remote_id => @installed_app.configs_team_id).first
    end

    private

      def channel_resource
        @channel_resource ||= IntegrationServices::Services::Slack::ChannelResource.new(self)
      end

      def group_resource
        @group_resource ||= IntegrationServices::Services::Slack::GroupResource.new(self)
      end

      def im_resource
        @im_resource ||= IntegrationServices::Services::Slack::ImResource.new(self)
      end

      def user_resource
        @user_resource ||= IntegrationServices::Services::Slack::UserResource.new(self)
      end

      def chat_resource
        @chat_resource ||= IntegrationServices::Services::Slack::ChatResource.new(self)
      end

      def auth_resource
        @auth_resource ||= IntegrationServices::Services::Slack::AuthResource.new(self)
      end

      def attachment_formatter
        IntegrationServices::Services::Slack::Formatter::AttachmentFormatter.new(@payload, agent_slack_id, requester_slack_id)
      end

      def message_formatter
        IntegrationServices::Services::Slack::Formatter::MessageFormatter.new(@payload)
      end

      def ticket_processor conversation, users_list, user, requester=nil
        IntegrationServices::Services::Slack::Processor::TicketProcessor.new(@payload, @installed_app, conversation, users_list, user, requester)
      end

      def user_slack_token
        @user_slack_token ||= @payload[:act_hash][:user_slack_token]
      end

      def slack_user_id
        @slack_user_id ||= @payload[:act_hash][:user_id]
      end

      def slack_user_name
        @slack_user_name ||= @payload[:act_hash][:user_name]
      end

      def agent_slack_id
        @agent_slack_id ||= begin
          ticket = @payload[:act_on_object]
          agent_email = ticket.responder.try(:email)
          agent_email.present? ? get_slack_id(agent_email) : nil
        end
      end

      def requester_slack_id
        ticket = @payload[:act_on_object]
        requester_email = ticket.requester.try(:email)
        requester_email.present? ? get_slack_id(requester_email) : nil
      end

      def get_slack_id email
        users_list_response = receive_users_list
        if users_list_response[:error].blank?
          users_list_response[:users_list]["members"].each do |member|
            return member["id"] if member["profile"]["email"] == email
          end
        end
        nil
      end

      def get_user
        user, user_cred = nil, nil
        user = Account.current.user_emails.user_for_email(slack_email) || create_fd_user if slack_email.present?
        user_cred = create_or_update_user_cred(user, slack_user_id, {"oauth_token" => user_slack_token}) if user.present?
        { :user => user, :user_cred => user_cred }
      end

      def get_users_list_hash
        @get_users_list_hash ||= begin
          users_list_response = receive_users_list
          return nil if users_list_response[:error].present?
          users_list_response[:users_list]["members"].inject({}) do |hash, member|
              hash[member["id"]] = { :user_name => member["name"], :user_email => member["profile"]["email"] }
              hash
          end
        end
      end

      def slack_email
        @slack_email ||= begin
          result = nil
          users_hash = get_users_list_hash
          return nil if users_hash.blank?
          user_detail = users_hash[slack_user_id].present? ? users_hash[slack_user_id] : nil
          user_detail.present? ? user_detail[:user_email] : nil
        end
      end

      def send_dm
        dm_user_id = agent_slack_id
        if dm_user_id.present?
          channel = receive_open(dm_user_id)
          if channel[:error].blank?
            channel_id = channel[:open]
            post_to_channel(channel_id,true) if channel_id.present?
          end
        end
      end

      def post_to_channel channel_id, dm=false
        body_hash = {}
        body_hash["channel"] = channel_id
        body_hash["text"] = message_formatter.text
        body_hash["attachments"] = attachment_formatter.attachment
        receive_post_message(body_hash,dm)
      end

      def valid_push_to_channel?
        push_to = @payload[:act_hash][:push_to]
        case push_to
        when "dm_agent"
          @configs["allow_dm"].present?
        else
          Array.wrap(@configs["public_channels"]).include?(push_to) || Array.wrap(@configs["private_channels"]).include?(push_to)
        end
      end

      def get_conversation user, user_cred
        token = user_cred.auth_info["oauth_token"]
        return nil if token.blank?
        count = valid_params? ? no_of_lines : DEFAULT_LINES
        history_response = receive_history(token, count) 
        history_response[:error].blank? ? history_response[:history] : nil
      end

      def valid_params?
        @payload[:act_hash][:event_type] == NEW_SLACK_COMMAND && @payload[:act_hash][:user_slack_token].present?
      end

      def no_of_lines
        @payload[:act_hash][:user_slack_token].to_i
      end

      def create_or_update_user_cred user, remote_user_id, params
        user_credential = @installed_app.user_credentials.find_by_remote_user_id(remote_user_id)
        unless user_credential
          user_credential = @installed_app.user_credentials.build
          user_credential.account_id = @installed_app.account_id
        end
        user_credential.user_id = user.id
        user_credential.remote_user_id = remote_user_id
        user_credential.auth_info = params
        user_credential.save!
        user_credential
      end


      def create_ticket user, user_cred, requester=nil
        conversation = get_conversation(user, user_cred)
        users_hash = get_users_list_hash
        if conversation.present? && users_hash.present?
          obj = ticket_processor(conversation, users_hash, user, requester)
          ticket_url = obj.create_ticket
          notify_slash_command_user(user_cred, ticket_url)
        end
      end

      def create_fd_user(userhash = {})
        user = @installed_app.account.contacts.new
        user.active = true
        result = user.signup!(
          :user => {
            :name => userhash[:user_name] || slack_user_name,
            :email => userhash[:user_email] || slack_email
          }
        )
        result.present? ? user : nil
      end

      def notify_slash_command_user user_cred, ticket_url
        msg = nil
        if ticket_url.present?
          msg = I18n.t("integrations.slack_v2.message.ticket_success") + " #{ticket_url}"
        else
          msg = I18n.t("integrations.slack_v2.message.ticket_failure")
        end
        body_hash = {}
        body_hash["token"] = user_cred.auth_info["oauth_token"]
        body_hash["channel"] =  @payload[:act_hash][:channel_id]
        body_hash["text"] = msg
        receive_post_message(body_hash)
      end

      def handle_success hash_data
        hash_data[:error] = false
        hash_data
      end

      def handle_error e
        @logger.debug("slack_service error #{e.message}")
        NewRelic::Agent.notice_error(e, custom_params: { account_id: Account.current.id, payload: @payload.to_json }) unless skip_newrelic_notification?(e)
        {:error => true, :error_message => e.message}
      end

      def skip_newrelic_notification?(error)
        error.instance_of?(RatelimitError) || error.instance_of?(TokenRevokedError)
      end
  end
end
