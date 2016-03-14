module Freshfone
  module Jobs
    # Will be Removed when Sidekiq Scheduler gets Stabilised
    class CallQueueWorker
      include Freshfone::FreshfoneUtil
      include Freshfone::Queue

      attr_accessor :params, :agent, :current_account

      def perform(params)
        Rails.logger.info 'Freshfone call queue worker (Resque)'
        Rails.logger.info "#{params.inspect}, agent :: #{params[:agent]}"

        begin
          return if params[:agent].blank?

          self.current_account =  ::Account.current
          self.params          =  params
          current_user         =  current_account.users.technicians.visible.find(params[:agent])
          freshfone_user       =  current_user.freshfone_user if current_user.present?

          return if current_user.blank? || freshfone_user.blank? || !freshfone_user.online?

          bridge_queued_call(params[:agent])

        rescue => e
          Rails.logger.error(
            "Error on call queue worker for account #{params[:account_id]}\n
            for User #{params[:agent]}.\n
            #{e.message}\n#{e.backtrace.join("\n\t")}")
          notify_error(e, params, params[:agent])
        end
      end

      def notify_error(exception, params, agent)
        return if current_account.blank?
        Rails.logger.info "Call queue worker account additional settings :
          #{params[:account_id]} : #{current_account.id} :
          #{current_account.account_additional_settings.present?}"
        return unless current_account.account_additional_settings.present?
        FreshfoneNotifier.freshfone_ops_notifier(current_account,
          subject: "Call Queue Worker failure (Resque)",
          message:"Account :: #{params[:account_id]} <br>
          User Id :: #{agent}<br>
          Params :: #{params.inspect}<br><br>
          Exception Message : #{exception.message}<br><br>
          Stacktrace :: #{exception.backtrace.join("\n\t")}<br>")
      end
    end
  end
end
