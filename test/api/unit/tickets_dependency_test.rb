require_relative '../unit_test_helper'

class TicketsDependencyTest < ActionView::TestCase
  def test_before_filters_web_tickets_controller
    expected_filters = [
      :determine_pod, :supress_logs, :activate_authlogic, :clean_temp_files, :select_shard, :unset_thread_variables,
      :unset_current_account, :unset_current_portal, :unset_shard_for_payload,
      :set_current_account, :set_current_ip, :reset_language, :set_shard_for_payload, :set_default_locale,
      :set_locale, :set_msg_id, :set_ui_preference, :ensure_proper_protocol, :check_privilege, :freshdesk_form_builder,
      :check_account_state, :set_time_zone, :check_day_pass_usage,
      :force_utf8_params, :persist_user_agent, :set_cache_buster, :remove_pjax_param,
      :set_pjax_url, :set_last_active_time, :reset_language,
      :set_affiliate_cookie, :verify_authenticity_token, :build_item, :load_multiple_items,
      :load_ticket_item, :build_note_body_attributes, :build_conversation_for_ticket,
      :check_for_from_email, :kbase_email_included, :set_default_source, :prepare_mobile_note_for_send_set,
      :fetch_note_attachments, :traffic_cop_warning, :check_for_public_notes,
      :check_reply_trial_customers_limit, :redirect_to_mobile_url, :portal_check, :verify_format_and_tkt_id,
      :check_compose_feature, :check_trial_outbound_limit, :find_topic, :redirect_merged_topics, :run_on_slave,
      :save_article_filter, :run_on_db, :set_mobile, :normalize_params, :cache_filter_params,
      :load_cached_ticket_filters, :load_ticket_filter, :check_autorefresh_feature, :load_sort_order,
      :get_tag_name, :clear_filter, :add_requester_filter, :load_filter_params, :load_article_filter,
      :disable_notification, :enable_notification, :set_selected_tab, :filter_params_ids, :validate_bulk_scenario,
      :validate_ticket_close, :scoper_ticket_actions, :set_native_mobile, :load_items, :verify_ticket_permission_by_id,
      :load_ticket, :load_ticket_with_notes, :load_ticket_contact_data, :check_outbound_permission,
      :build_ticket_body_attributes, :build_ticket, :set_required_fields, :check_trial_customers_limit,
      :set_date_filter, :csv_date_range_in_days, :check_ticket_status, :handle_send_and_set, :validate_manual_dueby,
      :set_default_filter, :verify_permission, :validate_scenario, :validate_quick_assign_close, :load_email_params,
      :load_conversation_params, :load_reply_to_all_emails, :load_note_reply_cc, :load_note_reply_from_email,
      :show_password_expiry_warning, :load_assoc_parent, :load_tracker_ticket, :set_adjacent_list, :fetch_item_attachments,
      :load_tkt_and_templates, :check_ml_feature, :load_parent_template, :load_associated_tickets, :outbound_email_allowed?,
      :requester_widget_filter_params, :check_custom_view_feature, :ensure_proper_sts_header, :remove_skill_param,
      :export_limit_reached?, :record_query_comment, :log_csrf, :remove_session_data, :check_session_timeout, :set_all_agent_groups_permission
    ]

    actual_filters = Helpdesk::TicketsController._process_action_callbacks.map { |c| c.filter.to_s }.reject { |f| f.starts_with?('_') }.compact
    assert_equal expected_filters.map(&:to_s).sort, actual_filters.sort
  end

  # def test_validations_ticket
  #   actual = Helpdesk::Ticket.validators.map { |x| [x.class, x.attributes, x.options] }
  #   expected = [[ActiveModel::Validations::PresenceValidator, [:requester_id], {:message=>"should be a valid email address"}], [ActiveModel::Validations::NumericalityValidator, [:requester_id, :responder_id], {:only_integer=>true, :allow_nil=>true}], [ActiveModel::Validations::NumericalityValidator, [:source, :status], {:only_integer=>true}], [ActiveModel::Validations::InclusionValidator, [:source], {:in=>1..9}], [ActiveModel::Validations::InclusionValidator, [:priority], {:in=>[1, 2, 3, 4], :message=>"should be a valid priority"}], [ActiveRecord::Validations::UniquenessValidator, [:display_id], {:case_sensitive=>true, :scope=>:account_id}], [ActiveModel::Validations::PresenceValidator, [:group], {:if=>#<Proc:0x007fc63e295de0@/Users/user/Github/Rails3-helpkit/app/models/helpdesk/ticket/validations.rb:11 (lambda)>}], [ActiveModel::Validations::PresenceValidator, [:responder], {:if=>#<Proc:0x007fc63e29f778@/Users/user/Github/Rails3-helpkit/app/models/helpdesk/ticket/validations.rb:12 (lambda)>}], [ActiveModel::Validations::PresenceValidator, [:email_config], {:if=>#<Proc:0x007fc63e29cdc0@/Users/user/Github/Rails3-helpkit/app/models/helpdesk/ticket/validations.rb:13 (lambda)>}], [ActiveModel::Validations::PresenceValidator, [:product], {:if=>#<Proc:0x007fc63e2a62d0@/Users/user/Github/Rails3-helpkit/app/models/helpdesk/ticket/validations.rb:14 (lambda)>}]]
  #   assert_equal expected, actual
  # end
end
