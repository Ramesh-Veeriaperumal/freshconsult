module IntegrationServices::Services
  class SlackService < IntegrationServices::Service

    def self.title
      "Slack_V2"
    end

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

    def receive_history token
      begin
        handle_success({ :history => im_resource.history(token) })
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

    def receive_test token
      begin
        handle_success({ :test => auth_resource.test(token) })
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

    def receive_post_message body_hash
      begin
        handle_success({:post_notice => chat_resource.post_message(body_hash)})
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
      if user_slack_token.present?
        response = receive_test(user_slack_token)
        if response[:error].blank?
          user_details = get_user
          user = user_details[:user]
          user_cred = user_details[:user_cred]
        end
      else
        user_cred = @installed_app.user_credentials.find_by_remote_user_id(slack_user_id)
        user = user_cred.user if user_cred.present?
      end
      create_ticket(user, user_cred) if user.present? && user_cred.present?
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

      def ticket_processor conversation, users_list, user
        IntegrationServices::Services::Slack::Processor::TicketProcessor.new(@payload, @installed_app, conversation, users_list, user)
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
            post_to_channel(channel_id) if channel_id.present?
          end
        end
      end

      def post_to_channel channel_id
        body_hash = {}
        body_hash["channel"] = channel_id
        body_hash["text"] = message_formatter.text
        body_hash["attachments"] = attachment_formatter.attachment
        receive_post_message(body_hash)
      end

      def valid_push_to_channel?
        push_to = @payload[:act_hash][:push_to]
        case push_to
        when "dm_agent"
          @configs["allow_dm"].present?
        else
          @configs["public_channels"].include?(push_to) || @configs["private_channels"].include?(push_to)
        end
      end

      def get_conversation user, user_cred
        token = user_cred.auth_info["oauth_token"]
        return nil if token.blank?
        history_response = receive_history(token)
        history_response[:error].blank? ? history_response[:history] : nil
      end

      def create_or_update_user_cred user, remote_user_id, params
        user_credential = @installed_app.user_credentials.find_by_user_id(user.id)
        unless user_credential
          user_credential = @installed_app.user_credentials.build
          user_credential.user_id = user.id
          user_credential.account_id = @installed_app.account_id
          user_credential.remote_user_id = remote_user_id
        end
        user_credential.auth_info = params
        user_credential.save!
        user_credential
      end

      def create_ticket user, user_cred
        conversation = get_conversation(user, user_cred)
        users_hash = get_users_list_hash
        if conversation.present? && users_hash.present?
          obj = ticket_processor(conversation, users_hash, user)
          ticket_url = obj.create_ticket
          notify_slash_command_user(user_cred, ticket_url)
        end
      end

      def create_fd_user
        user = @installed_app.account.contacts.new
        user.active = true
        result = user.signup!(
          :user => {
            :name => slack_user_name,
            :email => slack_email
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
        NewRelic::Agent.notice_error(e)
        {:error => true, :error_message => e.message}
      end

  end
end
