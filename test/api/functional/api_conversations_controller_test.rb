require_relative '../test_helper'

require 'sidekiq/testing'
Sidekiq::Testing.fake!
['canned_responses_helper.rb', 'group_helper.rb', 'social_tickets_creation_helper.rb', 'twitter_helper.rb', 'dynamo_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }

class ApiConversationsControllerTest < ActionController::TestCase
  include ConversationsTestHelper
  include AttachmentsTestHelper
  include SurveysTestHelper
  include CannedResponsesHelper
  include TicketsTestHelper
  include SocialTestHelper
  include SocialTicketsCreationHelper
  include TwitterHelper
  include DynamoHelper
  include SurveysTestHelper
  include AwsTestHelper
  include ArchiveTicketTestHelper
  include GroupHelper


  BULK_ATTACHMENT_CREATE_COUNT = 2

  def wrap_cname(params)
    { api_conversation: params }
  end

  def ticket
    ticket = Helpdesk::Ticket.last || create_ticket(ticket_params_hash)
    ticket
  end

  def user
    user = other_user
    user
  end

  def note
    @agent.preferences[:agent_preferences][:undo_send] = false
    Helpdesk::Note.where(source: Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['note'], deleted: false).first || create_note(user_id: @agent.id, ticket_id: ticket.id, source: 2)
  end

  def account
    @account ||= create_test_account
  end

  def forward_note_params_hash
    body = Faker::Lorem.paragraph
    to_emails = [Faker::Internet.email]
    cc_emails = [Faker::Internet.email, Faker::Internet.email]
    bcc_emails = [Faker::Internet.email, Faker::Internet.email]
    email_config = @account.email_configs.where(active: true).first || create_email_config
    params_hash = { body: body, to_emails: to_emails, cc_emails: cc_emails, bcc_emails: bcc_emails, from_email: email_config.reply_email }
    params_hash
  end

  def test_reply_to_forward
    params_hash = forward_note_params_hash
    post :reply_to_forward, construct_params({ id: ticket.display_id }, params_hash)
    assert_response 201
    latest_note = Helpdesk::Note.last
    match_json(private_note_pattern(params_hash, latest_note))
    match_json(private_note_pattern({}, latest_note))
    assert_equal true, latest_note.private, 'Reply to Forward Note should be added as a private note only'
  end

  def test_reply_to_forward_with_invalid_cc_emails_count
    cc_emails = []
    50.times do
      cc_emails << Faker::Internet.email
    end
    params = forward_note_params_hash.merge(cc_emails: cc_emails, bcc_emails: cc_emails)
    post :reply_to_forward, construct_params({ id: ticket.display_id }, params)
    assert_response 400
    match_json([bad_request_error_pattern('cc_emails', :too_long, element_type: :values, max_count: ApiTicketConstants::MAX_EMAIL_COUNT.to_s, current_count: 50),
                bad_request_error_pattern('bcc_emails', :too_long, element_type: :values, max_count: ApiTicketConstants::MAX_EMAIL_COUNT.to_s, current_count: 50)])
  end

  def test_reply_to_forward_with_ticket_trashed
    Helpdesk::SchemaLessTicket.any_instance.stubs(:trashed).returns(true)
    params_hash = forward_note_params_hash
    post :reply_to_forward, construct_params({ id: ticket.display_id }, params_hash)
    Helpdesk::SchemaLessTicket.any_instance.unstub(:trashed)
    assert_response 403
    match_json(request_error_pattern(:access_denied))
  end

  def test_reply_to_forward_without_ticket_privilege
    User.any_instance.stubs(:has_ticket_permission?).returns(false)
    params_hash = forward_note_params_hash
    post :reply_to_forward, construct_params({ id: ticket.display_id }, params_hash)
    User.any_instance.unstub(:has_ticket_permission?)
    assert_response 403
    match_json(request_error_pattern(:access_denied))
  end

  def test_reply_to_forward_datatype_invalid
    params_hash = { to_emails: 'x', cc_emails: 'x', attachments: 'x', bcc_emails: 'x', body: Faker::Lorem.paragraph }
    post :reply_to_forward, construct_params({ id: ticket.display_id }, params_hash)
    assert_response 400
    match_json([bad_request_error_pattern('to_emails', :datatype_mismatch, expected_data_type: Array, prepend_msg: :input_received, given_data_type: String),
                bad_request_error_pattern('cc_emails', :datatype_mismatch, expected_data_type: Array, prepend_msg: :input_received, given_data_type: String),
                bad_request_error_pattern('attachments', :datatype_mismatch, expected_data_type: Array, prepend_msg: :input_received, given_data_type: String),
                bad_request_error_pattern('bcc_emails', :datatype_mismatch, expected_data_type: Array, prepend_msg: :input_received, given_data_type: String)])
  end

  def test_reply_to_forward_email_format_invalid
    params_hash = { to_emails: ['dj#'], cc_emails: ['tyt@'], bcc_emails: ['hj#'], from_email: 'dg#', body: Faker::Lorem.paragraph }
    post :reply_to_forward, construct_params({ id: ticket.display_id }, params_hash)
    assert_response 400
    match_json([bad_request_error_pattern('to_emails', :array_invalid_format, accepted: 'valid email address'),
                bad_request_error_pattern('cc_emails', :array_invalid_format, accepted: 'valid email address'),
                bad_request_error_pattern('bcc_emails', :array_invalid_format, accepted: 'valid email address'),
                bad_request_error_pattern('from_email', :invalid_format, accepted: 'valid email address')])
  end

  def test_reply_to_forward_invalid_id
    params_hash = { body: 'test', to_emails: [Faker::Internet.email] }
    post :reply_to_forward, construct_params({ id: '6786878' }, params_hash)
    assert_response :missing
  end

  def test_reply_to_forward_invalid_from_email
    params_hash = { body: 'test', to_emails: [Faker::Internet.email], from_email: Faker::Internet.email }
    post :reply_to_forward, construct_params({ id: ticket.display_id }, params_hash)
    assert_response 400
    match_json([bad_request_error_pattern('from_email', :absent_in_db, resource: :"active email_config", attribute: :from_email)])
  end

  def test_reply_to_forward_inactive_email_config
    email_config = create_email_config
    email_config.active = false
    email_config.save
    params_hash = forward_note_params_hash.merge(from_email: email_config.reply_email)
    post :reply_to_forward, construct_params({ id: ticket.display_id }, params_hash)
    assert_response 400
    match_json([bad_request_error_pattern('from_email', :absent_in_db, resource: :"active email_config", attribute: :from_email)])
  end

  def test_reply_to_forward_extra_params
    params_hash = { body_html: 'test', junk: 'test', to_emails: [Faker::Internet.email] }
    post :reply_to_forward, construct_params({ id: ticket.display_id }, params_hash)
    assert_response 400
    match_json([bad_request_error_pattern('junk', :invalid_field), bad_request_error_pattern('body_html', :invalid_field)])
  end

  def test_reply_to_forward_with_attachment
    t = create_ticket
    file = fixture_file_upload('files/attachment.txt', 'text/plain', :binary)
    file2 = fixture_file_upload('files/image33kb.jpg', 'image/jpg')
    params = forward_note_params_hash.merge('attachments' => [file, file2])
    DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
    post :reply_to_forward, construct_params({ id: t.display_id }, params)
    DataTypeValidator.any_instance.unstub(:valid_type?)
    assert_response 201
    response_params = params.except(:attachments)
    match_json(private_note_pattern(params, Helpdesk::Note.last))
    match_json(private_note_pattern({}, Helpdesk::Note.last))
    assert Helpdesk::Note.last.attachments.count == 2
  end

  def test_reply_to_forward_with_attachments_invalid_size
    invalid_attachment_limit = @account.attachment_limit + 2
    Rack::Test::UploadedFile.any_instance.stubs(:size).returns(invalid_attachment_limit.megabytes)
    file = fixture_file_upload('files/attachment.txt', 'text/plain', :binary)
    params = forward_note_params_hash.merge('attachments' => [file])
    DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
    post :reply_to_forward, construct_params({ id: ticket.display_id }, params)
    DataTypeValidator.any_instance.unstub(:valid_type?)
    assert_response 400
    match_json([bad_request_error_pattern('attachments', :invalid_size, max_size: "#{@account.attachment_limit} MB", current_size: "#{invalid_attachment_limit} MB")])
  end

  def test_reply_to_forward_with_invalid_attachment_params_format
    params = forward_note_params_hash.merge('attachments' => [1, 2])
    post :reply_to_forward, construct_params({ id: ticket.display_id }, params)
    assert_response 400
    match_json([bad_request_error_pattern('attachments', :array_datatype_mismatch, expected_data_type: 'valid file format')])
  end

  def test_reply_to_forward_without_privilege
    User.any_instance.stubs(:privilege?).with(:forward_ticket).returns(false).at_most_once
    params_hash = forward_note_params_hash
    post :reply_to_forward, construct_params({ id: ticket.display_id }, params_hash)
    User.any_instance.unstub(:privilege?)
    assert_response 403
    match_json(request_error_pattern(:access_denied))
  end

  def test_reply_to_forward_with_full_text
    params = forward_note_params_hash.merge(full_text: Faker::Lorem.paragraph(10))
    post :reply_to_forward, construct_params({ id: ticket.display_id }, params)
    assert_response 201
    latest_note = Helpdesk::Note.last
    match_json(private_note_pattern(params, latest_note))
    match_json(private_note_pattern({}, latest_note))
  end

  def test_reply_to_forward_with_invalid_draft_attachment_ids
    attachment_ids = []
    attachment_ids << create_attachment(attachable_type: 'UserDraft', attachable_id: @agent.id).id
    invalid_ids = [attachment_ids.last + 10, attachment_ids.last + 20]
    params_hash = forward_note_params_hash.merge(attachment_ids: (attachment_ids | invalid_ids))
    post :reply_to_forward, construct_params({ id: ticket.display_id }, params_hash)
    assert_response 400
    match_json([bad_request_error_pattern(:attachment_ids, :invalid_list, list: invalid_ids.join(', '))])
  end

  def test_reply_to_forward_with_draft_attachment_ids
    attachment_ids = []
    BULK_ATTACHMENT_CREATE_COUNT.times do
      attachment_ids << create_attachment(attachable_type: 'UserDraft', attachable_id: @agent.id).id
    end
    params_hash = forward_note_params_hash.merge(attachment_ids: attachment_ids)
    post :reply_to_forward, construct_params({ id: ticket.display_id }, params_hash)
    assert_response 201
    latest_note = Helpdesk::Note.last
    match_json(private_note_pattern(params_hash, latest_note))
    match_json(private_note_pattern({}, latest_note))
    assert latest_note.attachments.size == attachment_ids.size
  end

  def test_reply_to_forward_with_attachment_and_draft_attachment_ids
    t = create_ticket
    attachment_id = create_attachment(attachable_type: 'UserDraft', attachable_id: @agent.id).id
    file1 = fixture_file_upload('files/attachment.txt', 'text/plain', :binary)
    file2 = fixture_file_upload('files/image33kb.jpg', 'image/jpg')
    attachments = [file1, file2]
    params_hash = forward_note_params_hash.merge(attachment_ids: [attachment_id], attachments: attachments)
    DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
    @request.env['CONTENT_TYPE'] = 'application/json'
    post :reply_to_forward, construct_params({ id: t.display_id }, params_hash)
    DataTypeValidator.any_instance.unstub(:valid_type?)
    assert_response 201
    latest_note = Helpdesk::Note.last
    match_json(private_note_pattern(params_hash, latest_note))
    match_json(private_note_pattern({}, latest_note))
    assert latest_note.attachments.size == (attachments.size + 1)
  end

  def test_reply_to_forward_with_inline_attachment_ids
    t = create_ticket
    inline_attachment_ids = []
    BULK_ATTACHMENT_CREATE_COUNT.times do
      inline_attachment_ids << create_attachment(attachable_type: 'Tickets Image Upload').id
    end
    params_hash = forward_note_params_hash.merge(inline_attachment_ids: inline_attachment_ids)
    post :reply_to_forward, construct_params({ id: ticket.display_id }, params_hash)
    assert_response 201
    note = Helpdesk::Note.last
    match_json(private_note_pattern(params_hash, note))
    match_json(private_note_pattern({}, note))
    assert_equal inline_attachment_ids.size, note.inline_attachments.size
  end

  def test_reply_to_forward_with_invalid_inline_attachment_ids
    t = create_ticket
    inline_attachment_ids, valid_ids, invalid_ids = [], [], []
    BULK_ATTACHMENT_CREATE_COUNT.times do
      invalid_ids << create_attachment(attachable_type: 'Forums Image Upload').id
    end
    invalid_ids << 0
    BULK_ATTACHMENT_CREATE_COUNT.times do
      valid_ids << create_attachment(attachable_type: 'Tickets Image Upload').id
    end
    inline_attachment_ids = invalid_ids + valid_ids
    params_hash = forward_note_params_hash.merge(inline_attachment_ids: inline_attachment_ids)
    post :reply_to_forward, construct_params({ id: ticket.display_id }, params_hash)
    assert_response 400
    match_json([bad_request_error_pattern('inline_attachment_ids', :invalid_inline_attachments_list, invalid_ids: invalid_ids.join(', '))])
  end

  def test_reply_to_forward_with_shared_attachments
    canned_response = create_response(
      title: Faker::Lorem.sentence,
      content_html: Faker::Lorem.paragraph,
      visibility: ::Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:all_agents],
      attachments: { resource: fixture_file_upload('files/attachment.txt', 'text/plain', :binary) }
    )
    params = forward_note_params_hash.merge(attachment_ids: canned_response.shared_attachments.map(&:attachment_id))
    stub_attachment_to_io do
      post :reply_to_forward, construct_params({ id: create_ticket.display_id }, params)
    end
    assert_response 201
    latest_note = Helpdesk::Note.last
    match_json(private_note_pattern(params, latest_note))
    match_json(private_note_pattern({}, latest_note))
    assert latest_note.attachments.count == 1
  end

  def test_reply_to_forward_with_cc_kbase_mail
    article_count = Solution::Article.count
    parent_ticket = ticket
    cc_emails = [@account.kbase_email]
    params = forward_note_params_hash.merge(cc_emails: cc_emails)
    post :reply_to_forward, construct_params({ id: parent_ticket.display_id }, params)
    assert_response 201
    match_json(private_note_pattern(params.merge(cc_emails: []), Helpdesk::Note.last))
    match_json(private_note_pattern({}, Helpdesk::Note.last))
    assert (article_count + 1) == Solution::Article.count
    assert Solution::Article.last.title == parent_ticket.subject
    assert Solution::Article.last.description == Helpdesk::Note.last.body_html
    refute Helpdesk::Note.last.cc_emails.include?(@account.kbase_email)
  end

  def test_reply_to_forward_with_bcc_kbase_mail
    article_count = Solution::Article.count
    parent_ticket = ticket
    parent_ticket.update_column(:subject, 'More than 3 letters')
    params_hash = forward_note_params_hash.merge(bcc_emails: [@account.kbase_email])
    post :reply_to_forward, construct_params({ id: parent_ticket.display_id }, params_hash)
    assert_response 201
    match_json(private_note_pattern(params_hash.merge(bcc_emails: nil), Helpdesk::Note.last))
    match_json(private_note_pattern({}, Helpdesk::Note.last))
    assert (article_count + 1) == Solution::Article.count
    assert Solution::Article.last.title == parent_ticket.subject
    assert Solution::Article.last.description == Helpdesk::Note.last.body_html
    refute Helpdesk::Note.last.bcc_emails.include?(@account.kbase_email)
  end

  def test_reply_to_forward_with_cc_kbase_mail_without_privilege
    article_count = Solution::Article.count
    User.any_instance.stubs(:privilege?).with(:manage_tickets).returns(true)
    User.any_instance.stubs(:privilege?).with(:forward_ticket).returns(true)
    User.any_instance.stubs(:privilege?).with(:publish_solution).returns(false).at_most_once
    params_hash = forward_note_params_hash.merge(cc_emails: [@account.kbase_email])
    post :reply_to_forward, construct_params({ id: ticket.display_id }, params_hash)
    User.any_instance.unstub(:privilege?)
    assert_response 201
    match_json(private_note_pattern(params_hash.merge(cc_emails: nil), Helpdesk::Note.last))
    match_json(private_note_pattern({}, Helpdesk::Note.last))
    assert article_count == Solution::Article.count
  end

  def test_reply_to_forward_with_bcc_kbase_mail_without_privilege
    article_count = Solution::Article.count
    User.any_instance.stubs(:privilege?).with(:manage_tickets).returns(true)
    User.any_instance.stubs(:privilege?).with(:forward_ticket).returns(true)
    User.any_instance.stubs(:privilege?).with(:publish_solution).returns(false).at_most_once
    params_hash = forward_note_params_hash.merge(bcc_emails: [@account.kbase_email])
    post :reply_to_forward, construct_params({ id: ticket.display_id }, params_hash)
    User.any_instance.unstub(:privilege?)
    assert_response 201
    match_json(private_note_pattern(params_hash.merge(bcc_emails: nil), Helpdesk::Note.last))
    match_json(private_note_pattern({}, Helpdesk::Note.last))
    assert article_count == Solution::Article.count
  end

  def test_reply_to_forward_with_cc_kbase_mail_short_subject
    article_count = Solution::Article.count
    t = create_ticket(subject: 'ui')
    params_hash = forward_note_params_hash.merge(cc_emails: [@account.kbase_email])
    post :reply_to_forward, construct_params({ id: t.display_id }, params_hash)
    assert_response 201
    match_json(private_note_pattern(params_hash.merge(cc_emails: nil), Helpdesk::Note.last))
    match_json(private_note_pattern({}, Helpdesk::Note.last))
    assert (article_count + 1) == Solution::Article.count
    refute Solution::Article.last.title == ticket.subject
    assert Solution::Article.last.title == "Ticket:#{t.display_id} subject is too short to be an article title"
    assert Solution::Article.last.description == Helpdesk::Note.last.body_html
    refute Helpdesk::Note.last.cc_emails.include?(@account.kbase_email)
  end

end
