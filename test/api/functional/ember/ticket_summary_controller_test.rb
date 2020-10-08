require_relative '../../test_helper'
['canned_responses_helper.rb', 'dynamo_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }
class TicketSummaryControllerTest < ActionController::TestCase
  include ConversationsTestHelper
  include AttachmentsTestHelper
  include CannedResponsesHelper
  include ApiTicketsTestHelper
  include DynamoHelper
  include AwsTestHelper

  BULK_ATTACHMENT_CREATE_COUNT = 2
  def setup
    super
    MixpanelWrapper.stubs(:send_to_mixpanel).returns(true)
    Account.stubs(:current).returns(Account.first || create_test_account)
    Account.find(Account.current.id).make_current
  end

  def teardown
    MixpanelWrapper.unstub(:send_to_mixpanel)
    Account.unstub(:current)
    super
  end
  def wrap_cname(params)
    { ticket_summary: params }
  end

  def ticket
    ticket = Helpdesk::Ticket.last || create_ticket(ticket_params_hash)
  end

  def user
    user = other_user
  end

  def account
    @account ||= create_test_account
  end

  def ticket_summary
    Helpdesk::Note.where(source: Account.current.helpdesk_sources.note_source_keys_by_token['summary'], deleted: false).first ||
                   create_note(user_id: @agent.id, ticket_id: ticket.id, source: 13)
  end

  def update_ticket_summary_params_hash
    body = Faker::Lorem.paragraph
    params_hash = { body: body }
  end

  def test_create_summary_note_with_incorrect_attachment_type
    Account.current.add_feature(:ticket_summary_feature)
    Account.current.enable_setting(:ticket_summary)
    ticket = create_ticket
    attachment_ids = %w(A B C)
    params_hash = update_ticket_summary_params_hash.merge(attachment_ids: attachment_ids)
    put :update, construct_params({ version: 'private', ticket_id: ticket.display_id }, params_hash)
    match_json([bad_request_error_pattern(:attachment_ids, :array_datatype_mismatch, expected_data_type: 'Positive Integer')])
    assert_response 400
    Account.current.disable_setting(:ticket_summary)
    Account.current.revoke_feature(:ticket_summary_feature)
  end

  def test_create_summary_note_with_invalid_attachment_ids
    Account.current.add_feature(:ticket_summary_feature)
    Account.current.enable_setting(:ticket_summary)
    ticket = create_ticket
    attachment_ids = []
    attachment_ids << create_attachment(attachable_type: 'UserDraft', attachable_id: @agent.id).id
    invalid_ids = [attachment_ids.last + 10, attachment_ids.last + 20]
    params_hash = update_ticket_summary_params_hash.merge(attachment_ids: (attachment_ids | invalid_ids))
    put :update, construct_params({ version: 'private', ticket_id: ticket.display_id }, params_hash)
    match_json([bad_request_error_pattern(:attachment_ids, :invalid_list, list: invalid_ids.join(', '))])
    assert_response 400
    Account.current.disable_setting(:ticket_summary)
    Account.current.revoke_feature(:ticket_summary_feature)
  end

  def test_create_summary_note_with_invalid_attachment_size_with_launch_25_limit
    Account.current.add_feature(:ticket_summary_feature)
    Account.current.enable_setting(:ticket_summary)
    Account.current.launch(:outgoing_attachment_limit_25)
    ticket = create_ticket
    # delete :destroy, construct_params(id: ticket.summary.id) if ticket.summary
    attachment_id = create_attachment(attachable_type: 'UserDraft', attachable_id: @agent.id).id
    params_hash = update_ticket_summary_params_hash.merge(attachment_ids: [attachment_id])
    Helpdesk::Attachment.any_instance.stubs(:content_file_size).returns(30_000_000)
    put :update, construct_params({ version: 'private', ticket_id: ticket.display_id }, params_hash)
    Helpdesk::Attachment.any_instance.unstub(:content_file_size)
    match_json([bad_request_error_pattern(:attachment_ids, :invalid_size, max_size: '25 MB', current_size: '28.6 MB')])
    assert_response 400
    Account.current.rollback(:outgoing_attachment_limit_25)
    Account.current.disable_setting(:ticket_summary)
    Account.current.revoke_feature(:ticket_summary_feature)
  end

  def test_create_summary_note_with_invalid_attachment_size_without_launch_25_limit
    Account.current.add_feature(:ticket_summary_feature)
    Account.current.enable_setting(:ticket_summary)
    ticket = create_ticket
    # delete :destroy, construct_params(id: ticket.summary.id) if ticket.summary
    attachment_id = create_attachment(attachable_type: 'UserDraft', attachable_id: @agent.id).id
    params_hash = update_ticket_summary_params_hash.merge(attachment_ids: [attachment_id])
    Helpdesk::Attachment.any_instance.stubs(:content_file_size).returns(25_000_000)
    put :update, construct_params({ version: 'private', ticket_id: ticket.display_id }, params_hash)
    Helpdesk::Attachment.any_instance.unstub(:content_file_size)
    match_json([bad_request_error_pattern(:attachment_ids, :invalid_size, max_size: '20 MB', current_size: '23.8 MB')])
    assert_response 400
    Account.current.disable_setting(:ticket_summary)
    Account.current.revoke_feature(:ticket_summary_feature)
  end

  def test_create_summary_note_with_attachment_ids
    Account.current.add_feature(:ticket_summary_feature)
    Account.current.enable_setting(:ticket_summary)
    ticket = create_ticket
    attachment_ids = []
    BULK_ATTACHMENT_CREATE_COUNT.times do
      attachment_ids << create_attachment(attachable_type: 'UserDraft', attachable_id: @agent.id).id
    end
    params_hash = update_ticket_summary_params_hash.merge(attachment_ids: attachment_ids)
    put :update, construct_params({ version: 'private', ticket_id: ticket.display_id }, params_hash)
    assert_response 200
    match_json(private_ticket_summary_pattern(params_hash, Helpdesk::Note.last))
    match_json(private_ticket_summary_pattern({}, Helpdesk::Note.last))
    assert Helpdesk::Note.last.attachments.size == attachment_ids.size
    Account.current.disable_setting(:ticket_summary)
    Account.current.revoke_feature(:ticket_summary_feature)
  end

  def test_create_summary_note_with_inline_attachment_ids
    Account.current.add_feature(:ticket_summary_feature)
    Account.current.enable_setting(:ticket_summary)
    ticket = create_ticket
    inline_attachment_ids = []
    BULK_ATTACHMENT_CREATE_COUNT.times do
      inline_attachment_ids << create_attachment(attachable_type: 'Tickets Image Upload').id
    end
    params_hash = update_ticket_summary_params_hash.merge(inline_attachment_ids: inline_attachment_ids)
    put :update, construct_params({ version: 'private', ticket_id: ticket.display_id }, params_hash)
    assert_response 200
    match_json(private_ticket_summary_pattern(params_hash, Helpdesk::Note.last))
    match_json(private_ticket_summary_pattern({}, Helpdesk::Note.last))
    assert Helpdesk::Note.last.inline_attachments.size == inline_attachment_ids.size
    assert Helpdesk::Note.last.inline_attachment_ids.sort == inline_attachment_ids.sort
    Account.current.disable_setting(:ticket_summary)
    Account.current.revoke_feature(:ticket_summary_feature)
  end

  def test_create_summary_note_with_invalid_inline_attachment_ids
    Account.current.add_feature(:ticket_summary_feature)
    Account.current.enable_setting(:ticket_summary)
    ticket = create_ticket
    inline_attachment_ids, valid_ids, invalid_ids = [], [], []
    BULK_ATTACHMENT_CREATE_COUNT.times do
      invalid_ids << create_attachment(attachable_type: 'Forums Image Upload').id
    end
    invalid_ids << 0
    BULK_ATTACHMENT_CREATE_COUNT.times do
      valid_ids << create_attachment(attachable_type: 'Tickets Image Upload').id
    end
    inline_attachment_ids = invalid_ids + valid_ids
    params_hash = update_ticket_summary_params_hash.merge(inline_attachment_ids: inline_attachment_ids)
    put :update, construct_params({ version: 'private', ticket_id: ticket.display_id }, params_hash)
    assert_response 400
    match_json([bad_request_error_pattern('inline_attachment_ids', :invalid_inline_attachments_list, invalid_ids: invalid_ids.join(', '))])
  end

  def test_create_summary_note_with_attachment_and_attachment_ids
    Account.current.add_feature(:ticket_summary_feature)
    Account.current.enable_setting(:ticket_summary)
    ticket = create_ticket
    attachment_id = create_attachment(attachable_type: 'UserDraft', attachable_id: @agent.id).id
    file1 = fixture_file_upload('files/attachment.txt', 'text/plain', :binary)
    file2 = fixture_file_upload('files/image33kb.jpg', 'image/jpg')
    attachments = [file1, file2]
    params_hash = update_ticket_summary_params_hash.merge(attachment_ids: [attachment_id], attachments: attachments)
    DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
    @request.env['CONTENT_TYPE'] = 'multipart/form-data'
    put :update, construct_params({ version: 'private', ticket_id: ticket.display_id }, params_hash)
    DataTypeValidator.any_instance.unstub(:valid_type?)
    assert_response 200
    match_json(private_ticket_summary_pattern(params_hash, Helpdesk::Note.last))
    match_json(private_ticket_summary_pattern({}, Helpdesk::Note.last))
    assert Helpdesk::Note.last.attachments.size == (attachments.size + 1)
    Account.current.disable_setting(:ticket_summary)
    Account.current.revoke_feature(:ticket_summary_feature)
  end

  # def test_create_summary_note_with_cloud_files_upload
  #   Account.current.add_feature(:ticket_summary)
  #   ticket = create_ticket
  #   cloud_file_params = [{ filename: 'image.jpg', url: CLOUD_FILE_IMAGE_URL, application_id: 20 }]
  #   params = update_ticket_summary_params_hash.merge(cloud_files: cloud_file_params)
  #   put :update, construct_params({ version: 'private', ticket_id: ticket.display_id }, params)
  #   assert_response 200
  #   latest_note = Helpdesk::Note.last
  #   match_json(private_ticket_summary_pattern(params, latest_note))
  #   match_json(private_ticket_summary_pattern({}, latest_note))
  #   assert latest_note.cloud_files.count == 1
  #   Account.current.revoke_feature(:ticket_summary)
  # end

  def test_create_summary_note_with_shared_attachments
    Account.current.add_feature(:ticket_summary_feature)
    Account.current.enable_setting(:ticket_summary)
    ticket = create_ticket
    canned_response = create_response(
      title: Faker::Lorem.sentence,
      content_html: Faker::Lorem.paragraph,
      visibility: ::Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:all_agents],
      attachments: { resource: fixture_file_upload('files/attachment.txt', 'text/plain', :binary) }
    )
    params = update_ticket_summary_params_hash.
             merge(attachment_ids: canned_response.shared_attachments.map(&:attachment_id))
    stub_attachment_to_io do
      put :update, construct_params({ version: 'private', ticket_id: ticket.display_id }, params)
    end
    assert_response 200
    latest_note = Helpdesk::Note.last
    match_json(private_ticket_summary_pattern(params, latest_note))
    match_json(private_ticket_summary_pattern({}, latest_note))
    assert latest_note.attachments.count == 1
    Account.current.disable_setting(:ticket_summary)
    Account.current.revoke_feature(:ticket_summary_feature)
  end

  def test_create_summary_note_with_spam_ticket
    Account.current.add_feature(:ticket_summary_feature)
    Account.current.enable_setting(:ticket_summary)
    t = create_ticket(spam: true)
    put :update, construct_params({ version: 'private', ticket_id: t.display_id }, update_ticket_summary_params_hash)
    assert_response 403
  ensure
    t.update_attributes(spam: false)
    Account.current.disable_setting(:ticket_summary)
    Account.current.revoke_feature(:ticket_summary_feature)
  end

  def test_create_summary_note_without_parent_ticket
    Account.current.add_feature(:ticket_summary_feature)
    Account.current.enable_setting(:ticket_summary)
    t = create_ticket
    put :update, construct_params({ version: 'private', ticket_id: 100000 }, update_ticket_summary_params_hash)
    assert_response 404
  ensure
    Account.current.disable_setting(:ticket_summary)
    Account.current.revoke_feature(:ticket_summary_feature)
  end

  def test_create_summary_note_with_invalid_user_id
    Account.current.add_feature(:ticket_summary_feature)
    Account.current.enable_setting(:ticket_summary)
    ticket = create_ticket
    params_hash = update_ticket_summary_params_hash.merge(user_id: user.id)
    put :update, construct_params({ version: 'private', ticket_id: ticket.display_id }, params_hash)
    match_json([bad_request_error_pattern(:agent_id, 'There is no agent matching the given agent_id')])
    assert_response 400
    Account.current.disable_setting(:ticket_summary)
    Account.current.revoke_feature(:ticket_summary_feature)
  end

  def test_create_summary_note_without_feature
    ticket = create_ticket
    put :update, construct_params({ version: 'private', ticket_id: ticket.display_id },
                                    update_ticket_summary_params_hash)
    match_json({"code"=>"app_unavailable",
         "message"=> "The Ticket summary feature is not enabled. Please make sure to install Summary app"})
    assert_response 403
  end

  def test_create_summary_note_for_parent_ticket
    Account.current.add_feature(:ticket_summary_feature)
    Account.current.enable_setting(:ticket_summary)
    ticket = create_ticket
    enable_adv_ticketing([:parent_child_tickets]) do
      parent_id = create_parent_ticket.display_id
      put :update, construct_params({ version: 'private', ticket_id: parent_id }, update_ticket_summary_params_hash)
      match_json({
        code: "cant_access_summary",
        message: "The Ticket Summary feature is not available for Parent and Tracker Tickets"
      })
      assert_response 403
      end
    Account.current.disable_setting(:ticket_summary)
    Account.current.revoke_feature(:ticket_summary_feature)
  end

  def test_create_summary_note_for_tracker_ticket
    Account.current.add_feature(:ticket_summary_feature)
    Account.current.enable_setting(:ticket_summary)
    ticket = create_ticket
    enable_adv_ticketing([:link_tickets]) do
      tracker_id = create_tracker_ticket.display_id
      put :update, construct_params({ version: 'private', ticket_id: tracker_id }, update_ticket_summary_params_hash)
      match_json({
        code: "cant_access_summary",
        message: "The Ticket Summary feature is not available for Parent and Tracker Tickets"
      })
      assert_response 403
      end
    Account.current.disable_setting(:ticket_summary)
    Account.current.revoke_feature(:ticket_summary_feature)
  end


  def test_update_without_ticket_access
    Account.current.add_feature(:ticket_summary_feature)
    Account.current.enable_setting(:ticket_summary)
    User.any_instance.stubs(:has_ticket_permission?).returns(false)
    t = create_ticket
    note = create_ticket_summary(t)
    put :update, construct_params({ version: 'private', ticket_id: t.display_id }, update_ticket_summary_params_hash)
    assert_response 403
    match_json(request_error_pattern(:access_denied))
    User.any_instance.unstub(:has_ticket_permission?)
    Account.current.disable_setting(:ticket_summary)
    Account.current.revoke_feature(:ticket_summary_feature)
  end

  def test_update_success
    Account.current.add_feature(:ticket_summary_feature)
    Account.current.enable_setting(:ticket_summary)
    t = create_ticket
    note = create_ticket_summary(t)
    params_hash = update_ticket_summary_params_hash
    put :update, construct_params({ version: 'private', ticket_id: t.display_id }, params_hash)
    assert_response 200
    note = Helpdesk::Note.find(note.id)
    match_json(update_private_ticket_summary_pattern(params_hash, note))
    match_json(update_private_ticket_summary_pattern({}, note))
    Account.current.disable_setting(:ticket_summary)
    Account.current.revoke_feature(:ticket_summary_feature)
  end

  def test_update_with_attachments
    Account.current.add_feature(:ticket_summary_feature)
    Account.current.enable_setting(:ticket_summary)
    file = fixture_file_upload('/files/attachment.txt', 'plain/text', :binary)
    attachment_id = create_attachment(attachable_type: 'UserDraft', attachable_id: @agent.id).id
    canned_response = create_response(
      title: Faker::Lorem.sentence,
      content_html: Faker::Lorem.paragraph,
      visibility: ::Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:all_agents],
      attachments: { resource: fixture_file_upload('files/attachment.txt', 'text/plain', :binary) }
    )
    params_hash = update_ticket_summary_params_hash.merge('attachments' => [file],
                  'attachment_ids' => [attachment_id] | canned_response.shared_attachments.map(&:attachment_id))
    t = create_ticket
    note = create_ticket_summary(t)
    DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
    stub_attachment_to_io do
      put :update, construct_params({ version: 'private', ticket_id: t.display_id }, params_hash)
    end
    DataTypeValidator.any_instance.unstub(:valid_type?)
    assert_response 200
    note = Helpdesk::Note.find(note.id)
    match_json(update_private_ticket_summary_pattern(params_hash, note))
    match_json(update_private_ticket_summary_pattern({}, note))
    assert_equal 3, note.attachments.count
    Account.current.disable_setting(:ticket_summary)
    Account.current.revoke_feature(:ticket_summary_feature)
  end

  def test_update_with_inline_attachment_ids
    Account.current.add_feature(:ticket_summary_feature)
    Account.current.enable_setting(:ticket_summary)
    inline_attachment_ids = []
    BULK_ATTACHMENT_CREATE_COUNT.times do
      inline_attachment_ids << create_attachment(attachable_type: 'Tickets Image Upload').id
    end
    params_hash = update_ticket_summary_params_hash.merge(inline_attachment_ids: inline_attachment_ids)
    t = create_ticket
    note = create_ticket_summary(t)
    put :update, construct_params({ version: 'private', ticket_id: t.display_id }, params_hash)
    assert_response 200
    note = Helpdesk::Note.find(note.id)
    match_json(update_private_ticket_summary_pattern(params_hash, note))
    match_json(update_private_ticket_summary_pattern({}, note))
    assert_equal inline_attachment_ids.sort, note.inline_attachment_ids.sort
    Account.current.disable_setting(:ticket_summary)
    Account.current.revoke_feature(:ticket_summary_feature)
  end

  def test_update_with_invalid_inline_attachment_ids
    Account.current.add_feature(:ticket_summary_feature)
    Account.current.enable_setting(:ticket_summary)
    inline_attachment_ids, valid_ids, invalid_ids = [], [], []
    BULK_ATTACHMENT_CREATE_COUNT.times do
      invalid_ids << create_attachment(attachable_type: 'Forums Image Upload').id
    end
    invalid_ids << 0
    BULK_ATTACHMENT_CREATE_COUNT.times do
      valid_ids << create_attachment(attachable_type: 'Tickets Image Upload').id
    end
    inline_attachment_ids = invalid_ids + valid_ids
    params_hash = update_ticket_summary_params_hash.merge(inline_attachment_ids: inline_attachment_ids)
    t = create_ticket
    note = create_ticket_summary(t)
    put :update, construct_params({ version: 'private', ticket_id: t.display_id }, params_hash)
    assert_response 400
    match_json([bad_request_error_pattern('inline_attachment_ids', :invalid_inline_attachments_list, invalid_ids: invalid_ids.join(', '))])
  end

  # def test_update_with_cloud_files
  #   Account.current.add_feature(:ticket_summary)
  #   cloud_file_params = [{ filename: 'image.jpg', url: CLOUD_FILE_IMAGE_URL, application_id: 20 }]
  #   params_hash = update_ticket_summary_params_hash.merge(cloud_files: cloud_file_params)
  #   t = create_ticket
  #   note = create_ticket_summary(t)
  #   put :update, construct_params({ version: 'private', ticket_id: note.notable_id }, params_hash)
  #   assert_response 200
  #   note = Helpdesk::Note.find(note.id)
  #   match_json(update_private_ticket_summary_pattern(params_hash, note))
  #   match_json(update_private_ticket_summary_pattern({}, note))
  #   assert_equal 1, note.cloud_files.count
  #   Account.current.revoke_feature(:ticket_summary)
  # end

  def test_update_on_spammed_ticket
    Account.current.add_feature(:ticket_summary_feature)
    Account.current.enable_setting(:ticket_summary)
    t = create_ticket(spam: true)
    note = create_ticket_summary(t)
    put :update, construct_params({ version: 'private', ticket_id: t.display_id },
                                    update_ticket_summary_params_hash)
    assert_response 403
  ensure
    t.update_attributes(spam: false)
    Account.current.disable_setting(:ticket_summary)
    Account.current.revoke_feature(:ticket_summary_feature)
  end

  def test_update_summary_note_with_invalid_last_edited_user_id
    Account.current.add_feature(:ticket_summary_feature)
    Account.current.enable_setting(:ticket_summary)
    ticket = create_ticket
    note = create_ticket_summary(ticket)
    params_hash = update_ticket_summary_params_hash.merge(user_id: user.id)
    put :update, construct_params({ version: 'private', ticket_id: ticket.display_id }, params_hash)
    match_json([bad_request_error_pattern('last_edited_user_id', :"is invalid")])
    assert_response 400
    Account.current.disable_setting(:ticket_summary)
    Account.current.revoke_feature(:ticket_summary_feature)
  end

  def test_show_summary_note
    Account.current.add_feature(:ticket_summary_feature)
    Account.current.enable_setting(:ticket_summary)
    ticket = create_ticket
    note = create_ticket_summary(ticket)
    get :show, construct_params(version: 'private', ticket_id: ticket.display_id)
    assert_response 200
    Account.current.disable_setting(:ticket_summary)
    Account.current.revoke_feature(:ticket_summary_feature)
  end

  def test_show_uncreated_summary_note
    Account.current.add_feature(:ticket_summary_feature)
    Account.current.enable_setting(:ticket_summary)
    ticket = create_ticket
    get :show, construct_params(version: 'private', ticket_id: ticket.display_id)
    assert_response 204
    Account.current.disable_setting(:ticket_summary)
    Account.current.revoke_feature(:ticket_summary_feature)
  end

  def test_show_summary_note_without_feature
    ticket = create_ticket
    note = create_ticket_summary(ticket)
    get :show, construct_params(version: 'private', ticket_id: ticket.display_id)
    match_json('code' => 'app_unavailable',
               'message' => 'The Ticket summary feature is not enabled. Please make sure to install Summary app')
    assert_response 403
  end

  def test_show_summary_note_without_parent_ticket
    Account.current.add_feature(:ticket_summary_feature)
    Account.current.enable_setting(:ticket_summary)
    get :show, construct_params(version: 'private', ticket_id: 100_000)
    assert_response 404
    Account.current.disable_setting(:ticket_summary)
    Account.current.revoke_feature(:ticket_summary_feature)
  end
end
