require_relative '../api/test_helper'

class HelpdeskSystemController < ApplicationController
  include HelpdeskSystem
  include ActionController::Renderers::All
  include AttachmentsTestHelper
  attr_accessor :attachment

  class FixtureFile
    include ActionDispatch::TestProcess
  end
  def account_activate_check
    check_account_activation
    head 200
  end

  def fake_unprocessable_entity
    unprocessable_entity
    head 200
  end

  def test_custom_define_model
    define_model
    head 200
  end

  def test_custom_define_model_two
    define_model
    head 200
  end

  def test_unrecognized_model
    define_model
    head 200
  end

  def test_check_destroy
    check_destroy_permission
    head 200
  end

  def check_destroy_with_note
    @account = Account.first
    @current_user = User.last
    @items = [create_attachment(content: FixtureFile.new.fixture_file_upload('test/api/fixtures/files/attachment.txt', 'plain/text', :binary), attachable_type: 'Helpdesk::Note', attachable_id: '1')]
    check_destroy_permission
    head 200
  end

  def check_destroy_with_note_and_att_scope
    @account = Account.first
    @current_user = User.last
    @items = [create_attachment(content: FixtureFile.new.fixture_file_upload('test/api/fixtures/files/attachment.txt', 'plain/text', :binary), attachable_type: 'Helpdesk::Note', attachable_id: '1')]
    check_destroy_permission
    head 200
  end

  def check_destroy_with_ticket
    @account = Account.first
    @current_user = User.last
    @items = [create_attachment(content: FixtureFile.new.fixture_file_upload('test/api/fixtures/files/attachment.txt', 'plain/text', :binary), attachable_type: 'Helpdesk::Ticket', attachable_id: '1')]
    check_destroy_permission
    head 200
  end

  def check_destroy_with_solution_article
    @account = Account.first
    @current_user = User.last
    @items = [create_attachment(content: FixtureFile.new.fixture_file_upload('test/api/fixtures/files/attachment.txt', 'plain/text', :binary), attachable_type: 'Solution::Draft', attachable_id: '1')]
    check_destroy_permission
    head 200
  end

  def check_destroy_with_account
    @account = Account.first
    @current_user = User.last
    @items = [create_attachment(content: FixtureFile.new.fixture_file_upload('test/api/fixtures/files/attachment.txt', 'plain/text', :binary), attachable_type: 'Account', attachable_id: '1')]
    check_destroy_permission
    head 200
  end

  def check_destroy_with_post
    @account = Account.first
    @current_user = User.last
    @items = [create_attachment(content: FixtureFile.new.fixture_file_upload('test/api/fixtures/files/attachment.txt', 'plain/text', :binary), attachable_type: 'Post', attachable_id: '1')]
    check_destroy_permission
    head 200
  end

  def check_destroy_with_user
    @account = Account.first
    @current_user = User.last
    @items = [create_attachment(content: FixtureFile.new.fixture_file_upload('test/api/fixtures/files/attachment.txt', 'plain/text', :binary), attachable_type: 'User', attachable_id: '1')]
    check_destroy_permission
    head 200
  end

  def check_destroy_with_user_draft
    @account = Account.first
    @current_user = User.last
    @items = [create_attachment(content: FixtureFile.new.fixture_file_upload('test/api/fixtures/files/attachment.txt', 'plain/text', :binary), attachable_type: 'UserDraft', attachable_id: '1')]
    @attachment = @items[0]
    check_destroy_permission
    head 200
  end

  def check_destroy_with_ticket_template
    @account = Account.first
    @current_user = User.last
    @items = [create_attachment(content: FixtureFile.new.fixture_file_upload('test/api/fixtures/files/attachment.txt', 'plain/text', :binary), attachable_type: 'Helpdesk::TicketTemplate', attachable_id: '1')]
    check_destroy_permission
    head 200
  end
end

class HelpdeskSystemControllerTest < ActionController::TestCase
  def teardown
    destroy_attachments
  end

  def test_account_activate_check
    response = ActionDispatch::TestResponse.new
    Account.any_instance.stubs(:verified?).returns(false)
    @controller.response = response
    @controller.stubs(:action_name).returns('account_activate_check')
    actual = @controller.send(:account_activate_check)
    assert_response 200
  end

  def test_account_activate_js_format
    response = ActionDispatch::TestResponse.new
    Account.any_instance.stubs(:verified?).returns(false)
    @controller.response = response
    @controller.stubs(:action_name).returns('account_activate_check')
    @controller.construct_params(format: 'js')
    @request.env['HTTP_ACCEPT'] = 'text/javascript'
    actual = @controller.send(:account_activate_check)
    assert_response 200
  end

  def test_account_activate_any_format
    response = ActionDispatch::TestResponse.new
    Account.any_instance.stubs(:verified?).returns(false)
    @controller.response = response
    @controller.stubs(:action_name).returns('account_activate_check')
    @controller.construct_params(format: 'any')
    actual = @controller.send(:account_activate_check)
    assert_response 200
  end

  def test_account_activate_json_format
    response = ActionDispatch::TestResponse.new
    Account.any_instance.stubs(:verified?).returns(false)
    @controller.response = response
    @controller.stubs(:action_name).returns('account_activate_check')
    @controller.construct_params(format: 'json')
    @request.env['HTTP_ACCEPT'] = 'application/json'
    actual = @controller.send(:account_activate_check)
    assert_response 200
  end

  def test_account_activate_widget_format
    response = ActionDispatch::TestResponse.new
    Account.any_instance.stubs(:verified?).returns(false)
    @controller.response = response
    @controller.stubs(:action_name).returns('account_activate_check')
    @request.env['HTTP_ACCEPT'] = 'text/plain'
    @controller.construct_params(format: 'widget')
    actual = @controller.send(:account_activate_check)
    assert_response 200
  end

  def test_unprocessable_entity
    response = ActionDispatch::TestResponse.new
    @controller.response = response
    @controller.stubs(:action_name).returns('fake_unprocessable_entity')
    actual = @controller.send(:fake_unprocessable_entity)
    assert_response 200
  end

  def test_unprocessable_entity_different_header
    response = ActionDispatch::TestResponse.new
    @controller.response = response
    @controller.stubs(:action_name).returns('fake_unprocessable_entity')
    @request.headers['X-PJAX'] = '1'
    @request.env['X-PJAX'] = '1'
    actual = @controller.send(:fake_unprocessable_entity)
    assert_response 200
  end

  def test_unprocessable_entity_js_format
    response = ActionDispatch::TestResponse.new
    @controller.response = response
    @controller.stubs(:action_name).returns('fake_unprocessable_entity')
    @controller.construct_params(formats: [:js])
    @request.env['HTTP_ACCEPT'] = 'text/javascript'
    actual = @controller.send(:fake_unprocessable_entity)
    assert_response 200
  end

  def test_unprocessable_entity_json_format
    response = ActionDispatch::TestResponse.new
    @controller.response = response
    @controller.stubs(:action_name).returns('fake_unprocessable_entity')
    @controller.construct_params(formats: [:json])
    @request.env['HTTP_ACCEPT'] = 'application/json'
    actual = @controller.send(:fake_unprocessable_entity)
    assert_response 200
  end

  def test_account_activate_check_no_current_user
    response = ActionDispatch::TestResponse.new
    Account.any_instance.stubs(:verified?).returns(false)
    HelpdeskSystemController.any_instance.stubs(:current_user).returns(nil)
    @controller.response = response
    @controller.stubs(:action_name).returns('account_activate_check')
    actual = @controller.send(:account_activate_check)
    assert_response 200
  end

  def test_account_activate_check_expired_password
    response = ActionDispatch::TestResponse.new
    Account.any_instance.stubs(:verified?).returns(false)
    @controller.response = response
    @controller.stubs(:action_name).returns('account_activate_check')
    HelpdeskSystemController.any_instance.stubs(:current_user).returns(nil)
    HelpdeskSystemController.any_instance.stubs(:password_expired?).returns(true)
    actual = @controller.send(:account_activate_check)
    assert_response 200
  end

  def test_custom_define_model_one
    response = ActionDispatch::TestResponse.new
    @controller.response = response
    @controller.stubs(:action_name).returns('test_custom_define_model')
    HelpdeskSystemController.any_instance.stubs(:controller_name).returns('cloud_files')
    actual = @controller.send(:test_custom_define_model)
    assert_response 200
  end

  def test_custom_define_model_two
    response = ActionDispatch::TestResponse.new
    @controller.response = response
    @controller.stubs(:action_name).returns('test_custom_define_model_two')
    HelpdeskSystemController.any_instance.stubs(:controller_name).returns('attachments')
    actual = @controller.send(:test_custom_define_model_two)
    assert_response 200
  end

  def test_custom_define_model_not_recognized
    response = ActionDispatch::TestResponse.new
    @controller.response = response
    @controller.stubs(:action_name).returns('test_unrecognized_model')
    HelpdeskSystemController.any_instance.stubs(:controller_name).returns('asdfads')
    actual = @controller.send(:test_unrecognized_model)
    assert_response 200
  end

  def test_check_destroy_permission
    response = ActionDispatch::TestResponse.new
    @controller.response = response
    @controller.stubs(:action_name).returns('test_check_destroy')
    actual = @controller.send(:test_check_destroy)
    assert_response 200
  end

  def test_check_destroy_with_note
    response = ActionDispatch::TestResponse.new
    @controller.response = response
    @controller.stubs(:action_name).returns('check_destroy_with_note')
    HelpdeskSystemController.any_instance.stubs(:controller_name).returns('attachments')
    actual = @controller.send(:check_destroy_with_note)
    assert_response 200
  end

  def test_check_destroy_with_ticket
    response = ActionDispatch::TestResponse.new
    @controller.response = response
    @controller.stubs(:action_name).returns('check_destroy_with_ticket')
    HelpdeskSystemController.any_instance.stubs(:controller_name).returns('attachments')
    actual = @controller.send(:check_destroy_with_ticket)
    assert_response 200
  end

  def test_check_destroy_with_solution_article
    response = ActionDispatch::TestResponse.new
    @controller.response = response
    @controller.stubs(:action_name).returns('check_destroy_with_solution_article')
    HelpdeskSystemController.any_instance.stubs(:controller_name).returns('attachments')
    Helpdesk::Attachment.any_instance.stubs(:attachable).returns(User.first)
    User.any_instance.stubs(:user_id).returns(1)
    actual = @controller.send(:check_destroy_with_solution_article)
    assert_response 200
  end

  def test_check_destroy_with_account
    response = ActionDispatch::TestResponse.new
    @controller.response = response
    @controller.stubs(:action_name).returns('check_destroy_with_account')
    HelpdeskSystemController.any_instance.stubs(:controller_name).returns('attachments')
    actual = @controller.send(:check_destroy_with_account)
    assert_response 200
  end

  def test_check_destroy_with_post
    response = ActionDispatch::TestResponse.new
    @controller.response = response
    @controller.stubs(:action_name).returns('check_destroy_with_post')
    HelpdeskSystemController.any_instance.stubs(:controller_name).returns('attachments')
    Helpdesk::Attachment.any_instance.stubs(:attachable).returns(User.first)
    User.any_instance.stubs(:user_id).returns(User.current.id)
    actual = @controller.send(:check_destroy_with_post)
    assert_response 200
  end

  def test_check_destroy_with_user
    response = ActionDispatch::TestResponse.new
    @controller.response = response
    @controller.stubs(:action_name).returns('check_destroy_with_user')
    HelpdeskSystemController.any_instance.stubs(:controller_name).returns('attachments')
    Helpdesk::Attachment.any_instance.stubs(:attachable).returns(User.first)
    actual = @controller.send(:check_destroy_with_user)
    assert_response 200
  end

  def test_check_destroy_with_user_draft
    response = ActionDispatch::TestResponse.new
    @controller.response = response
    @controller.stubs(:action_name).returns('check_destroy_with_user_draft')
    HelpdeskSystemController.any_instance.stubs(:controller_name).returns('attachments')
    Helpdesk::Attachment.any_instance.stubs(:attachable).returns(User.first)
    actual = @controller.send(:check_destroy_with_user_draft)
    assert_response 200
  end

  def test_check_destroy_with_ticket_template
    response = ActionDispatch::TestResponse.new
    @controller.response = response
    @controller.stubs(:action_name).returns('check_destroy_with_ticket_template')
    HelpdeskSystemController.any_instance.stubs(:controller_name).returns('attachments')
    actual = @controller.send(:check_destroy_with_ticket_template)
    assert_response 200
  end

  def test_check_destroy_with_note_and_att_scope
    response = ActionDispatch::TestResponse.new
    @controller.response = response
    @controller.stubs(:action_name).returns('check_destroy_with_note_and_att_scope')
    HelpdeskSystemController.any_instance.stubs(:controller_name).returns('attachments')
    actual = @controller.send(:check_destroy_with_note_and_att_scope)
    assert_response 200
  end

  def destroy_attachments
    acc = Account.first
    return if acc.attachments.count.zero?

    acc.attachments.each(&:destroy)
  end
end
