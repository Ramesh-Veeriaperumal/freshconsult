module Channel
  module Bot
    class ServicesController < ApiApplicationController
      include Helpdesk::IrisNotifications
      include ChannelAuthentication
      include BotHelper

      skip_before_filter :check_privilege, :verify_authenticity_token, only: [:training_completed]
      before_filter :channel_client_authentication, :load_bot_by_external_id, only: [:training_completed]
      around_filter :handle_exception, only: [:training_completed]

      def training_completed
        return unless validate_state(BotConstants::BOT_STATUS[:training_inprogress])
        @bot.training_completed!
        @bot_user = current_account.users.find_by_id(@bot.last_updated_by)
        send_notifications
        head 204
      end

      private

        def load_bot_by_external_id
          @bot = scoper.where(external_id: params[:id]).first
          log_and_render_404 unless @bot
        end

        def send_notifications
          categories = @bot.solution_category_meta.includes(:primary_category).map(&:name)
          ::Admin::BotMailer.send_later(:bot_training_completion_email, @bot, @bot_user.email, @bot_user.name, categories)
          notify_to_iris
        end

        def notify_to_iris
          push_data_to_service(IrisNotificationsConfig['api']['collector_path'], iris_payload)
        end

        def payload
          {
            bot_id: @bot.id,
            user_id: @bot_user.id,
            bot_name: @bot.name
          }
        end

        def iris_payload
          {
            payload: payload,
            payload_type: BotConstants::IRIS_NOTIFICATION_TYPE,
            account_id: @bot.account_id.to_s
          }
        end
        
        def scoper
          current_account.bots
        end

    end
  end
end
