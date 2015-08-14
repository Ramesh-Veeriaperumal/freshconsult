require_relative '../test_helper'

class TicketsDependencyTest < ActionDispatch::IntegrationTest
  def test_before_filters_web_tickets_controller
    expected_filters =  [:activate_authlogic, :add_requester_filter, :add_to_history, :build_item, :build_ticket,
                         :build_ticket_body_attributes, :cache_filter_params, :check_account_state, :check_autorefresh_feature,
                         :check_day_pass_usage, :check_privilege, :check_ticket_status, :clean_temp_files, :clear_filter,
                         :csv_date_range_in_days, :determine_pod, :disable_notification, :enable_notification, :ensure_proper_protocol,
                         :filter_params_ids, :find_topic, :force_utf8_params, :freshdesk_form_builder, :get_tag_name, :handle_send_and_set,
                         :load_cached_ticket_filters, :load_conversation_params, :load_email_params, :load_items, :load_multiple_items,
                         :load_note_reply_cc, :load_reply_to_all_emails, :load_sort_order, :load_ticket, :load_ticket_filter,
                         :logging_details, :normalize_params, :persist_user_agent, :portal_check, :redirect_merged_topics,
                         :redirect_to_mobile_url, :remove_pjax_param, :remove_rails_2_flash_after, :remove_rails_2_flash_before,
                         :run_on_slave, :select_shard, :set_adjacent_list, :set_affiliate_cookie, :set_cache_buster, :set_current_account,
                         :set_date_filter, :set_default_filter, :set_default_locale, :set_locale, :set_mobile, :set_native_mobile,
                         :set_selected_tab, :set_time_zone, :unset_current_account, :unset_current_portal, :validate_manual_dueby,
                         :verify_authenticity_token, :verify_permission]
    actual_filters = Helpdesk::TicketsController._process_action_callbacks.map { |c| c.filter.to_s }.reject { |f| f.starts_with?('_') }.compact
    assert_equal expected_filters.map(&:to_s).sort, actual_filters.sort
  end

  # def test_validations_ticket
  #   actual = Helpdesk::Ticket.validators.collect { |x| [x.class, x.attributes, x.options] }
  #   expected = [[ActiveModel::Validations::PresenceValidator, [:requester_id], {:message=>"should be a valid email address"}], [ActiveModel::Validations::NumericalityValidator, [:requester_id, :responder_id], {:only_integer=>true, :allow_nil=>true}], [ActiveModel::Validations::NumericalityValidator, [:source, :status], {:only_integer=>true}], [ActiveModel::Validations::InclusionValidator, [:source], {:in=>1..9}], [ActiveModel::Validations::InclusionValidator, [:priority], {:in=>[1, 2, 3, 4], :message=>"should be a valid priority"}], [ActiveRecord::Validations::UniquenessValidator, [:display_id], {:case_sensitive=>true, :scope=>:account_id}], [ActiveModel::Validations::PresenceValidator, [:group], {:if=>#<Proc:0x007fc63e295de0@/Users/user/Github/Rails3-helpkit/app/models/helpdesk/ticket/validations.rb:11 (lambda)>}], [ActiveModel::Validations::PresenceValidator, [:responder], {:if=>#<Proc:0x007fc63e29f778@/Users/user/Github/Rails3-helpkit/app/models/helpdesk/ticket/validations.rb:12 (lambda)>}], [ActiveModel::Validations::PresenceValidator, [:email_config], {:if=>#<Proc:0x007fc63e29cdc0@/Users/user/Github/Rails3-helpkit/app/models/helpdesk/ticket/validations.rb:13 (lambda)>}], [ActiveModel::Validations::PresenceValidator, [:product], {:if=>#<Proc:0x007fc63e2a62d0@/Users/user/Github/Rails3-helpkit/app/models/helpdesk/ticket/validations.rb:14 (lambda)>}]]
  #   assert_equal expected, actual
  # end
end
