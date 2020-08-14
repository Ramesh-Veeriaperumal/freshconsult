module Migration
  class UpdateNotifcationPreferences < Base
    include Helpdesk::IrisNotifications

    REDIS_KEY = 'FAILED_NOTIFICATION_PREFRENCES_MIGRATION'.freeze
    NOTIFICATION_TYPES = ['sla_first_response_reminder', 'sla_resolution_due_reminder', 'sla_next_response_reminder', 'sla_first_response_escalation', 'sla_resolution_escalation', 'sla_next_response_escalation'].freeze
    USER_PREFERENCE_URL = '/config/users/preferences'.freeze

    def initialize(options = {})
      options[:redis_key] = REDIS_KEY
      super(options)
    end

    def perform
      perform_migration do
        toggle_user_preferences
      end
    end

    private

      def toggle_user_preferences
        @success_count = 0
        failed_ids = Hash.new { |h, k| h[k] = { backtrace: [], id: [] } }
        account.agents_details_pluck_from_cache.each do |agent|
          begin
            NOTIFICATION_TYPES.each do |notification_type|
              payload = {
                account_id: account.id.to_s,
                user_id: agent.first.to_s,
                notification_type: notification_type,
                pipe: 'rts',
                enabled: false
              }
              post_to_iris(USER_PREFERENCE_URL, payload)
            end
            @success_count += 1
          rescue Exception => e
            failed_ids[e.message][:backtrace] = e.backtrace[0..10]
            failed_ids[e.message][:id] << agent.first
          end
        end
        log("Account: #{account.id}, Success count: #{@success_count}, Failed IDs: #{failed_ids.inspect}")
      end

      def verify_migration
        @success_count >= account.agents_details_pluck_from_cache.size
      end
  end
end
