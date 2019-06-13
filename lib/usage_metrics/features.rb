module UsageMetrics::Features
  module_function

  extend UsageMetrics::ForestFeatures

  MAX_FEATURES_COUNT_PER_REQUEST = 10
  FEATURES_LIST = [:skill_based_round_robin, :sla_management,
                   :custom_ticket_fields, :custom_company_fields, :custom_contact_fields,
                   :custom_ticket_views, :occasional_agent, :create_observer, :multiple_emails,
                   :surveys, :whitelisted_ips, :parent_child_tickets_toggle, :link_tickets_toggle,
                   :css_customization, :multi_language, :forums, :round_robin, :knowledge_base,
                   :shared_ownership_toggle, :customer_slas, :multi_product, :dynamic_sections,
                   :layout_customization, :custom_roles, :auto_ticket_export, :custom_dashboard,
                   :multiple_user_companies, :multiple_business_hours, :mailbox, :supervisor,
                   :canned_response, :email_notification, :tags, :scenario_automations,
                   :omni_channel_support, :installed_apps, :ticket_templates, :timesheets,
                   :data_center_location, :advanced_social, :todos_reminder_scheduler,
                   :custom_status, :session_replay, :custom_domain, :requester_widget,
                   :contact_company_notes, :segments, :sandbox, :support_bot,
                   :ticket_summary, :canned_forms, :allow_auto_suggest_solutions].freeze
  FEATURES_TRUE_BY_DEFAULT = [:default_ticket_view, :private_note,
                              :agent_performance, :ticket_export, :default_dashboard, :default_dispatcher,
                              :forward, :default_business_hours, :group_performance, :default_sla,
                              :helpdesk_in_depth, :timesheet_reports, :scheduling_reports, :customer_analysis, :gamification,
                              :drill_down_to_tickets, :ticket_volume_trends, :performance_distribution,
                              :image_annotation, :dynamic_content].freeze

  FEATURES_TRUE_BY_DEFAULT.each do |feature_name|
    define_method(feature_name) do |args|
      true
    end
  end

  def metrics(account, shard, features_list)
    Hash.new.tap do |feature_usage|
      args = { account: account, shard: shard }
      features_list.each do |feature|
        begin
          feature_usage[feature] = safe_send(feature, args)
        rescue => e
          Rails.logger.error "EXCEPTION occured while getting feature usage \
          metrics for feature: #{feature}, account: #{args[:account].id}, \
          trace: #{e.backtrace.join("\n")}"
          NewRelic::Agent.notice_error(e, {
            :description => "Error occured while getting feature usage metrics \
            for account: #{args[:account].id}, feature: #{feature}"})
          feature_usage[feature] = false
        end
      end
    end
  end
end