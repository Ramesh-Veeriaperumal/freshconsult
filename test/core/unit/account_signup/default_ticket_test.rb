require_relative '../../test_helper'

class DefaultTicketTest < ActiveSupport::TestCase

DEFAULT_TICKET_SOURCES = [:email, :feedback_widget]

include AccountTestHelper

  def setup
    if @account.nil?
      create_test_account
    end

    @responder = @account.all_users.find_by_email(Helpdesk::AGENT[:email])
    
    DEFAULT_TICKET_SOURCES.each do |type|
      instance_variable_set("@#{type}_ticket", @account.tickets.order(:created_at).find_by_source(TicketConstants::SOURCE_KEYS_BY_TOKEN["#{type}".to_sym]))
      instance_variable_set("@#{type}_note", instance_variable_get("@#{type}_ticket").notes.find_by_source(Helpdesk::Note::SOURCE_KEYS_BY_TOKEN["email"]))    
    end
  end

  DEFAULT_TICKET_SOURCES.each do |type|

    define_method("test_for_#{type.to_s}_requester_name_and_email") do
      assert_equal Helpdesk::DEFAULT_TICKET_PROPERTIES["#{type}_ticket".to_sym][:name] , instance_variable_get("@#{type}_ticket").requester.name
      assert_equal Helpdesk::DEFAULT_TICKET_PROPERTIES["#{type}_ticket".to_sym][:email] , instance_variable_get("@#{type}_ticket").requester.email
    end

    define_method("test_for_#{type.to_s}_ticket_creation_and_attributes") do
      assert_present instance_variable_get("@#{type}_ticket")
      assert_equal instance_variable_get("@#{type}_ticket").subject , I18n.t("default.ticket.#{type}.subject")
      assert_equal instance_variable_get("@#{type}_ticket").status , Helpdesk::TicketStatus::OPEN
      assert_equal instance_variable_get("@#{type}_ticket").source , TicketConstants::SOURCE_KEYS_BY_TOKEN["#{type}".to_sym]
      assert_equal instance_variable_get("@#{type}_ticket").priority , TicketConstants::PRIORITY_KEYS_BY_TOKEN[:high]
    end

    define_method("test_for_#{type.to_s}_reply_note_creation_and_attributes") do
      assert_present instance_variable_get("@#{type}_note")
      assert_equal instance_variable_get("@#{type}_note").user_id, @responder.id
      assert_equal instance_variable_get("@#{type}_note").source, Helpdesk::Note::SOURCE_KEYS_BY_TOKEN["email"]
      assert_equal instance_variable_get("@#{type}_note").private, false
    end
  end

  def test_for_agent_name_and_email
    assert_equal Helpdesk::AGENT[:name],@responder.name
    assert_equal Helpdesk::AGENT[:email],@responder.email
  end

  def test_email_ticket_for_survey_creation_and_attributes
    survey_result = @email_ticket.survey_results.first
    default_survey = @account.custom_surveys.default.first
    assert_present survey_result
    assert_equal survey_result.rating, ::Survey::HAPPY
    assert_equal survey_result.survey_id, default_survey.id
  end

  def test_feedback_widget_ticket_for_meta_data
    meta_note = @feedback_widget_ticket.notes.find_by_source(Helpdesk::Note::SOURCE_KEYS_BY_TOKEN["meta"])
    meta_data = YAML::load(meta_note.body)
    required_meta_data = Helpdesk::DEFAULT_TICKET_PROPERTIES[:feedback_widget_ticket][:meta]
    assert_equal meta_data["user_agent"] , required_meta_data[:user_agent]
    assert_equal meta_data["referrer"] , required_meta_data[:referrer]
  end
end