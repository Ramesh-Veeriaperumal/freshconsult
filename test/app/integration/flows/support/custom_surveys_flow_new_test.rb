# frozen_string_literal: true

require_relative '../../../../api/api_test_helper'
['user_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }
['tickets_test_helper.rb'].each { |file| require "#{Rails.root}/test/models/helpers/#{file}" }
['archive_ticket_test_helper.rb'].each { |file| require "#{Rails.root}/test/api/helpers/#{file}" }

class CustomSurveysFlowNewTest < ActionDispatch::IntegrationTest
  include UsersHelper
  include TicketsTestHelper
  include ArchiveTicketTestHelper
  include SurveysTestHelper

  def setup
    super
    create_survey(1, true)
  end

  # new_via_portal related tests

  def test_submit_new_survey_when_no_access
    survey_handle_count_before = CustomSurvey::SurveyHandle.count
    user = add_new_user(@account, active: true)
    user2 = add_new_user(@account, active: true)
    params = { requester_id: user.id, status: 4 }
    ticket = create_ticket_with_params(params)
    set_request_auth_headers(user2)
    get "/support/custom_surveys/#{ticket.display_id}/103"
    assert_response 302
    assert_equal survey_handle_count_before, CustomSurvey::SurveyHandle.count
  end

  def test_submit_new_survey_for_archived_ticket
    @account.add_feature(:archive_tickets)
    user = add_new_user(@account, active: true)
    params = { requester_id: user.id, status: 5 }
    ticket = create_ticket_with_params(params, true)
    set_request_auth_headers(user)
    get "/support/custom_surveys/#{ticket.display_id}/100"
    assert_equal I18n.t('support.surveys.survey_closed'), flash[:notice]
    assert_redirected_to root_path
    assert_response 302
  ensure
    @account.make_current
    @account.revoke_feature(:archive_tickets)
  end

  def test_submit_new_survey_for_wrong_rating
    user = add_new_user(@account, active: true)
    params = { requester_id: user.id, status: 5 }
    ticket = create_ticket_with_params(params)
    set_request_auth_headers(user)
    get "/support/custom_surveys/#{ticket.display_id}/2000"
    assert_equal I18n.t('support.surveys.survey_closed'), flash[:notice]
    assert_response 302
  end

  def test_submit_new_survey_for_open_ticket
    survey_handle_count_before = CustomSurvey::SurveyHandle.count
    user = add_new_user(@account, active: true)
    params = { requester_id: user.id, status: 2 }
    ticket = create_ticket_with_params(params)
    set_request_auth_headers(user)
    get "/support/custom_surveys/#{ticket.display_id}/100"
    assert_equal I18n.t('support.tickets.ticket_survey.survey_on_open_ticket'), flash[:notice]
    assert_equal survey_handle_count_before, CustomSurvey::SurveyHandle.count
  end

  def test_submit_new_survey_for_closed_ticket
    survey_handle_count_before = CustomSurvey::SurveyHandle.count
    user = add_new_user(@account, active: true)
    params = { requester_id: user.id, status: 5 }
    ticket = create_ticket_with_params(params)
    set_request_auth_headers(user)
    get "/support/custom_surveys/#{ticket.display_id}/100"
    assert_equal survey_handle_count_before + 1, CustomSurvey::SurveyHandle.count
    assert_equal 3, CustomSurvey::SurveyHandle.last.sent_while
    survey_link = "custom_surveys/#{CustomSurvey::SurveyHandle.last.id_token}/neutral/new?source=new_via_portal"
    assert response.body.include?(survey_link)
    assert_response 200
  end

  # new_via_handle action related tests
  def test_submit_new_survey_comment_for_resolved_ticket
    user = add_new_user(@account, active: true)
    user.make_current
    params = { requester_id: user.id, status: 4 }
    ticket = create_ticket_with_params(params)
    custom_survey_handle = create_custom_survey(ticket)
    set_request_auth_headers(user)
    get "support/custom_surveys/#{custom_survey_handle.id_token}/neutral/new?source=new_via_portal"
    assert_response 200
  end

  def test_submit_new_survey_for_resolved_ticket_failure
    user = add_new_user(@account, active: true)
    survey_handle_count_before = CustomSurvey::SurveyHandle.count
    params = { requester_id: user.id, status: 4 }
    ticket = create_ticket_with_params(params)
    set_request_auth_headers(user)
    get "/support/custom_surveys/#{ticket.display_id}/100"
    assert_equal survey_handle_count_before + 1, CustomSurvey::SurveyHandle.count
    survey_link = "support/custom_surveys/#{CustomSurvey::SurveyHandle.last.id_token}/neutral/new?source=new_via_portal"
    assert response.body.include?(survey_link)
    @account.make_current
    User.reset_current_user
    user2 = add_agent(@account, active: true)
    set_request_auth_headers(user2)
    get survey_link
    assert_equal I18n.t('support.surveys.agent_feedback_error'), flash[:notice]
    assert_redirected_to root_path
    assert_response 302
  end

  def test_submit_new_survey_when_survey_handle_is_blank
    user = add_new_user(@account, active: true)
    params = { requester_id: user.id, status: 4 }
    ticket = create_ticket_with_params(params)
    custom_survey_handle = create_custom_survey(ticket)
    custom_survey_handle.destroy
    User.reset_current_user
    Support::CustomSurveysController.any_instance.stubs(:current_user).returns(nil)
    survey_link = "support/custom_surveys/#{custom_survey_handle.id_token}/neutral/new?source=new_via_portal"
    get survey_link
    assert_equal I18n.t('support.surveys.handle_expired'), flash[:notice]
    assert_redirected_to root_path
    assert_response 302
  ensure
    Support::CustomSurveysController.any_instance.unstub(:current_user)
  end

  def test_submit_new_survey_when_survey_was_already_rated
    user = add_new_user(@account, active: true)
    params = { requester_id: user.id, status: 4 }
    ticket = create_ticket_with_params(params)
    custom_survey_handle = create_custom_survey(ticket)
    custom_survey_handle.rated = true
    custom_survey_handle.save!
    custom_survey_handle.reload
    set_request_auth_headers(user)
    survey_link = "support/custom_surveys/#{custom_survey_handle.id_token}/neutral/new?source=new_via_portal"
    get survey_link
    assert_equal I18n.t('support.surveys.feedback_already_done'), flash[:notice]
    assert_redirected_to root_path
    assert_response 302
  end

  def test_submit_new_survey_when_ticket_is_archived
    @account.add_feature(:archive_tickets)
    user = add_new_user(@account, active: true)
    params = { requester_id: user.id, status: 5 }
    ticket = create_ticket_with_params(params, true)
    custom_survey_handle = create_custom_survey(ticket)
    set_request_auth_headers(user)
    survey_link = "support/custom_surveys/#{custom_survey_handle.id_token}/neutral/new?source=new_via_portal"
    get survey_link
    assert_equal I18n.t('support.surveys.survey_closed'), flash[:notice]
    assert_response 302
  ensure
    @account.make_current
    @account.revoke_feature(:archive_tickets)
  end

  # preview action related tests
  def test_custom_survey_preview_load_access_denied
    user = add_new_user(@account, active: true)
    params = { requester_id: user.id, status: 4 }
    ticket = create_ticket_with_params(params)
    custom_survey_handle = create_custom_survey(ticket)
    set_request_auth_headers(user)
    Account.any_instance.stubs(:custom_survey_enabled?).returns(false)
    Account.any_instance.stubs(:custom_translations_enabled?).returns(false)
    get "support/custom_surveys/#{custom_survey_handle.survey.id}/preview"
    assert_equal I18n.t(:'flash.general.access_denied'), flash[:notice]
    assert_redirected_to safe_send(Helpdesk::ACCESS_DENIED_ROUTE)
    assert_response 302
  ensure
    Account.any_instance.unstub(:custom_survey_enabled?)
    Account.any_instance.unstub(:custom_translations_enabled?)
  end

  def test_custom_survey_preview_load_render_404
    create_survey(1, true)
    custom_survey_id = @account.custom_surveys.last.id + 1
    Account.any_instance.stubs(:custom_survey_enabled?).returns(true)
    Account.any_instance.stubs(:custom_translations_enabled?).returns(true)
    get "support/custom_surveys/#{custom_survey_id}/preview"
    assert_response 404
  ensure
    Account.any_instance.unstub(:custom_survey_enabled?)
    Account.any_instance.unstub(:custom_translations_enabled?)
  end

  def test_custom_survey_preview_success
    params = { status: 4 }
    ticket = create_ticket_with_params(params)
    custom_survey_handle = create_custom_survey(ticket)
    Account.any_instance.stubs(:custom_survey_enabled?).returns(true)
    Account.any_instance.stubs(:custom_translations_enabled?).returns(true)
    get "/support/custom_surveys/#{custom_survey_handle.survey.id}/preview"
    assert_response 200
  ensure
    Account.any_instance.unstub(:custom_survey_enabled?)
    Account.any_instance.unstub(:custom_translations_enabled?)
  end

  # preview_questions action related tests
  def test_custom_survey_preview_question_success
    params = { status: 4 }
    ticket = create_ticket_with_params(params)
    custom_survey_handle = create_custom_survey(ticket)
    Account.any_instance.stubs(:custom_survey_enabled?).returns(true)
    Account.any_instance.stubs(:custom_translations_enabled?).returns(true)
    get "/support/custom_surveys/#{custom_survey_handle.survey.id}/preview/questions"
    assert_response 200
  ensure
    Account.any_instance.unstub(:custom_survey_enabled?)
    Account.any_instance.unstub(:custom_translations_enabled?)
  end

  private

    def old_ui?
      true
    end

    def create_custom_survey(ticket)
      CustomSurvey::SurveyHandle.create_handle_for_portal(ticket, EmailNotification::TICKET_RESOLVED)
    end

    def create_ticket_with_params(params, archive_ticket = false)
      ticket = create_ticket(params)
      if archive_ticket == true
        @account.enable_ticket_archiving
        convert_ticket_to_archive(ticket)
        ticket = @account.archive_tickets.find_by_ticket_id(ticket.id)
      end
      ticket
    end
end
