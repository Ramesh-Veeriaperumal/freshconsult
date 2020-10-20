require_relative '../../test_helper'

class DefaultTicketTest < ActiveSupport::TestCase

DEFAULT_TICKET_SOURCES = [:email, :feedback_widget, :chat]

include AccountTestHelper

  def setup
    if @account.nil?
      create_test_account
    end

    @responder = @account.all_users.find_by_email(Helpdesk::AGENT[:email])
    
    DEFAULT_TICKET_SOURCES.each do |type|
      instance_variable_set("@#{type}_ticket", @account.tickets.order(:created_at).find_by_source(Helpdesk::Source.default_ticket_source_keys_by_token[type]))
      instance_variable_set("@#{type}_note", instance_variable_get("@#{type}_ticket").notes.find_by_source(Account.current.helpdesk_sources.note_source_keys_by_token["email"]))
      instance_variable_set("@expected_#{type}_ticket", eval("Fixtures::Default#{type.to_s.camelize()}Ticket").new )
    end
  end

  DEFAULT_TICKET_SOURCES.each do |type|

    define_method("test_for_#{type.to_s}_requester_name_and_email") do
      assert_equal instance_variable_get("@#{type}_ticket").requester.name, Helpdesk::DEFAULT_TICKET_PROPERTIES["#{type}_ticket".to_sym][:name]
      assert_equal instance_variable_get("@#{type}_ticket").requester.email, Helpdesk::DEFAULT_TICKET_PROPERTIES["#{type}_ticket".to_sym][:email]
    end

    define_method("test_for_#{type.to_s}_ticket_creation_and_attributes") do
      to_evaluate_ticket = instance_variable_get("@#{type}_ticket")
      expected_ticket = instance_variable_get("@expected_#{type}_ticket")
      assert_present instance_variable_get("@#{type}_ticket")
      assert_equal to_evaluate_ticket.subject, I18n.t("default.ticket.#{type}.subject")
      assert_equal to_evaluate_ticket.instance_eval { status }, expected_ticket.instance_eval { status }
      assert_equal to_evaluate_ticket.instance_eval { source } , expected_ticket.instance_eval { source }
      assert_equal to_evaluate_ticket.instance_eval { priority }, expected_ticket.instance_eval { priority }
    end

    define_method("test_for_#{type.to_s}_reply_note_creation_and_attributes") do
      if(instance_variable_get("@#{type}_note"))
        assert_present instance_variable_get("@#{type}_note")
        assert_equal instance_variable_get("@#{type}_note").user_id, @responder.id
        assert_equal instance_variable_get("@#{type}_note").source, Account.current.helpdesk_sources.note_source_keys_by_token["email"]
        assert_equal instance_variable_get("@#{type}_note").private, false
      end
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
    meta_note = @feedback_widget_ticket.notes.find_by_source(Account.current.helpdesk_sources.note_source_keys_by_token["meta"])
    meta_data = YAML::load(meta_note.body)
    required_meta_data = Helpdesk::DEFAULT_TICKET_PROPERTIES[:feedback_widget_ticket][:meta]
    assert_equal meta_data["user_agent"] , required_meta_data[:user_agent]
    assert_equal meta_data["referrer"] , required_meta_data[:referrer]
  end
end