require_relative '../unit_test_helper'

class TicketsDependencyTest < ActionView::TestCase
  def test_before_filters_web_tickets_controller
    expected_filters =  [:determine_pod, :activate_authlogic, :clean_temp_files, :select_shard, :unset_current_account, :unset_current_portal, :unset_shard_for_payload, :set_current_account, :set_shard_for_payload, :set_default_locale, :set_locale, :ensure_proper_protocol, :check_privilege, :freshdesk_form_builder, :remove_rails_2_flash_before, :check_account_state, :set_time_zone, :check_day_pass_usage, :force_utf8_params, :persist_user_agent, :set_cache_buster, :remove_pjax_param, :set_last_active_time, :remove_rails_2_flash_after, :set_affiliate_cookie, :verify_authenticity_token, :build_item, :load_multiple_items, :add_to_history, :redirect_to_mobile_url, :portal_check, :verify_format_and_tkt_id, :check_compose_feature, :find_topic, :redirect_merged_topics, :run_on_slave, :save_article_filter, :run_on_db, :set_mobile, :normalize_params, :cache_filter_params, :load_cached_ticket_filters, :load_ticket_filter, :check_autorefresh_feature, :load_sort_order, :get_tag_name, :clear_filter, :add_requester_filter, :load_filter_params, :load_article_filter, :disable_notification, :enable_notification, :set_selected_tab, :filter_params_ids, :scoper_ticket_actions, :load_items, :set_native_mobile, :verify_ticket_permission_by_id, :load_ticket, :load_ticket_with_notes, :verify_permission, :check_outbound_permission, :build_ticket_body_attributes, :build_ticket, :set_required_fields, :set_date_filter, :csv_date_range_in_days, :check_ticket_status, :handle_send_and_set, :validate_manual_dueby, :set_default_filter, :load_email_params, :load_conversation_params, :load_reply_to_all_emails, :load_note_reply_cc, :load_note_reply_from_email, :show_password_expiry_warning, :set_adjacent_list]
    actual_filters = Helpdesk::TicketsController._process_action_callbacks.map { |c| c.filter.to_s }.reject { |f| f.starts_with?('_') }.compact
    assert_equal expected_filters.map(&:to_s).sort, actual_filters.sort
  end

  # def test_validations_ticket
  #   actual = Helpdesk::Ticket.validators.map { |x| [x.class, x.attributes, x.options] }
  #   expected = [[ActiveModel::Validations::PresenceValidator, [:requester_id], {:message=>"should be a valid email address"}], [ActiveModel::Validations::NumericalityValidator, [:requester_id, :responder_id], {:only_integer=>true, :allow_nil=>true}], [ActiveModel::Validations::NumericalityValidator, [:source, :status], {:only_integer=>true}], [ActiveModel::Validations::InclusionValidator, [:source], {:in=>1..9}], [ActiveModel::Validations::InclusionValidator, [:priority], {:in=>[1, 2, 3, 4], :message=>"should be a valid priority"}], [ActiveRecord::Validations::UniquenessValidator, [:display_id], {:case_sensitive=>true, :scope=>:account_id}], [ActiveModel::Validations::PresenceValidator, [:group], {:if=>#<Proc:0x007fc63e295de0@/Users/user/Github/Rails3-helpkit/app/models/helpdesk/ticket/validations.rb:11 (lambda)>}], [ActiveModel::Validations::PresenceValidator, [:responder], {:if=>#<Proc:0x007fc63e29f778@/Users/user/Github/Rails3-helpkit/app/models/helpdesk/ticket/validations.rb:12 (lambda)>}], [ActiveModel::Validations::PresenceValidator, [:email_config], {:if=>#<Proc:0x007fc63e29cdc0@/Users/user/Github/Rails3-helpkit/app/models/helpdesk/ticket/validations.rb:13 (lambda)>}], [ActiveModel::Validations::PresenceValidator, [:product], {:if=>#<Proc:0x007fc63e2a62d0@/Users/user/Github/Rails3-helpkit/app/models/helpdesk/ticket/validations.rb:14 (lambda)>}]]
  #   assert_equal expected, actual
  # end
end
