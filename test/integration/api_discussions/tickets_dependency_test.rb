require_relative '../../test_helper'

class TicketsDependencyTest < ActionDispatch::IntegrationTest
  def test_before_filters_web_tickets_controller
    expected_filters =  [:determine_pod, :response_headers, :restrict_params, :activate_authlogic, :select_shard, :unset_current_account,
                         :unset_current_portal, :set_current_account, :ensure_proper_protocol, :check_privilege,
                         :check_account_state, :set_time_zone, :check_day_pass_usage, :force_utf8_params,
                         :set_affiliate_cookie, :verify_authenticity_token, :load_object, :check_params,
                         :validate_params, :manipulate_params, :build_object, :load_objects, :load_association,
                         :assign_protected, :verify_ticket_permission, :has_ticket_permission?]
    actual_filters = TicketsController._process_action_callbacks.map { |c| c.filter.to_s }.reject { |f| f.starts_with?('_') }.compact
    assert_equal expected_filters.map(&:to_s).sort, actual_filters.sort
  end

  # def test_validations_ticket
  #   actual = Helpdesk::Ticket.validators.collect { |x| [x.class, x.attributes, x.options] }
  #   expected = [[ActiveModel::Validations::PresenceValidator, [:requester_id], {:message=>"should be a valid email address"}], [ActiveModel::Validations::NumericalityValidator, [:requester_id, :responder_id], {:only_integer=>true, :allow_nil=>true}], [ActiveModel::Validations::NumericalityValidator, [:source, :status], {:only_integer=>true}], [ActiveModel::Validations::InclusionValidator, [:source], {:in=>1..9}], [ActiveModel::Validations::InclusionValidator, [:priority], {:in=>[1, 2, 3, 4], :message=>"should be a valid priority"}], [ActiveRecord::Validations::UniquenessValidator, [:display_id], {:case_sensitive=>true, :scope=>:account_id}], [ActiveModel::Validations::PresenceValidator, [:group], {:if=>#<Proc:0x007fc63e295de0@/Users/user/Github/Rails3-helpkit/app/models/helpdesk/ticket/validations.rb:11 (lambda)>}], [ActiveModel::Validations::PresenceValidator, [:responder], {:if=>#<Proc:0x007fc63e29f778@/Users/user/Github/Rails3-helpkit/app/models/helpdesk/ticket/validations.rb:12 (lambda)>}], [ActiveModel::Validations::PresenceValidator, [:email_config], {:if=>#<Proc:0x007fc63e29cdc0@/Users/user/Github/Rails3-helpkit/app/models/helpdesk/ticket/validations.rb:13 (lambda)>}], [ActiveModel::Validations::PresenceValidator, [:product], {:if=>#<Proc:0x007fc63e2a62d0@/Users/user/Github/Rails3-helpkit/app/models/helpdesk/ticket/validations.rb:14 (lambda)>}]]
  #   assert_equal expected, actual
  # end
end
