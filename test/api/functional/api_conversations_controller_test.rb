require_relative '../test_helper'

require 'sidekiq/testing'
Sidekiq::Testing.fake!
['canned_responses_helper.rb', 'group_helper.rb', 'social_tickets_creation_helper.rb', 'twitter_helper.rb', 'dynamo_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }

class ApiConversationsControllerTest < ActionController::TestCase
  include ConversationsTestHelper
  include AttachmentsTestHelper
  include CannedResponsesHelper
  include ApiTicketsTestHelper
  include AwsTestHelper

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
    Helpdesk::Note.where(source: Account.current.helpdesk_sources.note_source_keys_by_token['note'], deleted: false).first || create_note(user_id: @agent.id, ticket_id: ticket.id, source: 2)
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

  def test_forward_with_cc_kbase_mail
    article_count = Solution::Article.count
    parent_ticket = ticket
    cc_emails = [@account.kbase_email]
    params = forward_note_params_hash.merge(cc_emails: cc_emails)
    post :forward, construct_params({ id: parent_ticket.display_id }, params)
    assert_response 201
    match_json(private_note_pattern(params.merge(cc_emails: []), Helpdesk::Note.last))
    match_json(private_note_pattern({}, Helpdesk::Note.last))
    assert (article_count + 1) == Solution::Article.count
    assert Solution::Article.last.title == parent_ticket.subject
    assert Solution::Article.last.description == Helpdesk::Note.last.body_html
    refute Helpdesk::Note.last.cc_emails.include?(@account.kbase_email)
  end

  def test_forward_with_bcc_kbase_mail
    article_count = Solution::Article.count
    parent_ticket = ticket
    parent_ticket.update_column(:subject, 'More than 3 letters')
    params_hash = forward_note_params_hash.merge(bcc_emails: [@account.kbase_email])
    post :forward, construct_params({ id: parent_ticket.display_id }, params_hash)
    assert_response 201
    match_json(private_note_pattern(params_hash.merge(bcc_emails: nil), Helpdesk::Note.last))
    match_json(private_note_pattern({}, Helpdesk::Note.last))
    assert (article_count + 1) == Solution::Article.count
    assert Solution::Article.last.title == parent_ticket.subject
    assert Solution::Article.last.description == Helpdesk::Note.last.body_html
    refute Helpdesk::Note.last.bcc_emails.include?(@account.kbase_email)
  end

  def test_forward_with_cc_kbase_mail_without_privilege
    article_count = Solution::Article.count
    User.any_instance.stubs(:privilege?).with(:manage_tickets).returns(true)
    User.any_instance.stubs(:privilege?).with(:forward_ticket).returns(true)
    User.any_instance.stubs(:privilege?).with(:create_and_edit_article).returns(false).at_most_once
    params_hash = forward_note_params_hash.merge(cc_emails: [@account.kbase_email])
    post :forward, construct_params({ id: ticket.display_id }, params_hash)
    User.any_instance.unstub(:privilege?)
    assert_response 201
    match_json(private_note_pattern(params_hash.merge(cc_emails: nil), Helpdesk::Note.last))
    match_json(private_note_pattern({}, Helpdesk::Note.last))
    assert article_count == Solution::Article.count
  end

  def test_forward_with_bcc_kbase_mail_without_privilege
    article_count = Solution::Article.count
    User.any_instance.stubs(:privilege?).with(:manage_tickets).returns(true)
    User.any_instance.stubs(:privilege?).with(:forward_ticket).returns(true)
    User.any_instance.stubs(:privilege?).with(:create_and_edit_article).returns(false).at_most_once
    params_hash = forward_note_params_hash.merge(bcc_emails: [@account.kbase_email])
    post :forward, construct_params({ id: ticket.display_id }, params_hash)
    User.any_instance.unstub(:privilege?)
    assert_response 201
    match_json(private_note_pattern(params_hash.merge(bcc_emails: nil), Helpdesk::Note.last))
    match_json(private_note_pattern({}, Helpdesk::Note.last))
    assert article_count == Solution::Article.count
  end

  def test_forward_with_cc_kbase_mail_short_subject
    article_count = Solution::Article.count
    t = create_ticket(subject: 'ui')
    params_hash = forward_note_params_hash.merge(cc_emails: [@account.kbase_email])
    post :forward, construct_params({ id: t.display_id }, params_hash)
    assert_response 201
    match_json(private_note_pattern(params_hash.merge(cc_emails: nil), Helpdesk::Note.last))
    match_json(private_note_pattern({}, Helpdesk::Note.last))
    assert (article_count + 1) == Solution::Article.count
    refute Solution::Article.last.title == ticket.subject
    assert Solution::Article.last.title == "Ticket:#{t.display_id} subject is too short to be an article title"
    assert Solution::Article.last.description == Helpdesk::Note.last.body_html
    refute Helpdesk::Note.last.cc_emails.include?(@account.kbase_email)
  end

  def test_forward_with_invalid_cc_emails_count
    cc_emails = []
    50.times do
      cc_emails << Faker::Internet.email
    end
    params = forward_note_params_hash.merge(cc_emails: cc_emails, bcc_emails: cc_emails)
    post :forward, construct_params({ id: ticket.display_id }, params)
    assert_response 400
    match_json([bad_request_error_pattern('cc_emails', :too_long, element_type: :values, max_count: ApiTicketConstants::MAX_EMAIL_COUNT.to_s, current_count: 50),
                bad_request_error_pattern('bcc_emails', :too_long, element_type: :values, max_count: ApiTicketConstants::MAX_EMAIL_COUNT.to_s, current_count: 50)])
  end

  def test_forward_new_email_config
    email_config = create_email_config
    params_hash = forward_note_params_hash.merge(from_email: email_config.reply_email)
    post :forward, construct_params({ id: ticket.display_id }, params_hash)
    assert_response 201
    note = Helpdesk::Note.last
    assert_equal email_config.id, note.email_config_id
    match_json(private_note_pattern(params_hash, note))
    match_json(private_note_pattern({}, note))
  end

  def test_forward_with_ticket_trashed
    Helpdesk::SchemaLessTicket.any_instance.stubs(:trashed).returns(true)
    params_hash = forward_note_params_hash
    post :forward, construct_params({ id: ticket.display_id }, params_hash)
    Helpdesk::SchemaLessTicket.any_instance.unstub(:trashed)
    assert_response 403
    match_json(request_error_pattern(:access_denied))
  end

  def test_forward_without_ticket_privilege
    User.any_instance.stubs(:has_ticket_permission?).returns(false)
    params_hash = forward_note_params_hash
    post :forward, construct_params({ id: ticket.display_id }, params_hash)
    User.any_instance.unstub(:has_ticket_permission?)
    assert_response 403
    match_json(request_error_pattern(:access_denied))
  end

  def test_forward
    params_hash = forward_note_params_hash
    post :forward, construct_params({ id: ticket.display_id }, params_hash)
    assert_response 201
    latest_note = Helpdesk::Note.last
    match_json(private_note_pattern(params_hash, latest_note))
    match_json(private_note_pattern({}, latest_note))
    assert_equal true, latest_note.private, 'Forward Note should be added as a private note only'
  end

  def test_forward_without_from_email
    # Without personalized_email_replies
    @account.disable_setting(:personalized_email_replies)
    @account.reload
    Account.current.reload

    params_hash = forward_note_params_hash
    params_hash.delete(:from_email)
    post :forward, construct_params({ id: ticket.display_id }, params_hash)
    assert_response 201
    latest_note = Helpdesk::Note.last
    assert_equal ticket.selected_reply_email, latest_note.from_email
    match_json(private_note_pattern(params_hash, latest_note))
    match_json(private_note_pattern({}, latest_note))
  end

  def test_forward_without_from_email_and_personalized_email_replies
    # WITH personalized_email_replies
    @account.enable_setting(:personalized_email_replies)
    @account.reload
    Account.current.reload

    params_hash = forward_note_params_hash
    params_hash.delete(:from_email)
    post :forward, construct_params({ version: 'private', id: ticket.display_id }, params_hash)
    assert_response 201
    latest_note = Helpdesk::Note.last
    assert_equal ticket.friendly_reply_email_personalize(@agent.name), latest_note.from_email
    match_json(private_note_pattern(params_hash, latest_note))
    match_json(private_note_pattern({}, latest_note))
  end

  def test_forward_with_user_id_valid
    user = add_test_agent(account, role: account.roles.find_by_name('Agent').id)
    params_hash = forward_note_params_hash.merge(agent_id: user.id)
    post :forward, construct_params({ id: ticket.display_id }, params_hash)
    assert_response 201
    latest_note = Helpdesk::Note.last
    match_json(private_note_pattern(params_hash, latest_note))
    match_json(private_note_pattern({}, latest_note))
  end

  def test_forward_with_user_id_invalid_privilege
    params_hash = forward_note_params_hash.merge(agent_id: other_user.id)
    controller.class.any_instance.stubs(:is_allowed_to_assume?).returns(false)
    post :forward, construct_params({ id: ticket.display_id }, params_hash)
    assert_response 403
    match_json(request_error_pattern('invalid_user', id: other_user.id, name: other_user.name))
    controller.class.any_instance.unstub(:is_allowed_to_assume?)
  end

  def test_forward_numericality_invalid
    params_hash = { agent_id: 'x', body: Faker::Lorem.paragraph, to_emails: [Faker::Internet.email] }
    post :forward, construct_params({ id: ticket.display_id }, params_hash)
    assert_response 400
    match_json([bad_request_error_pattern('agent_id', :datatype_mismatch, expected_data_type: 'Positive Integer', prepend_msg: :input_received, given_data_type: String)])
  end

  def test_forward_datatype_invalid
    params_hash = { to_emails: 'x', cc_emails: 'x', attachments: 'x', bcc_emails: 'x', body: Faker::Lorem.paragraph }
    post :forward, construct_params({ id: ticket.display_id }, params_hash)
    assert_response 400
    match_json([bad_request_error_pattern('to_emails', :datatype_mismatch, expected_data_type: Array, prepend_msg: :input_received, given_data_type: String),
                bad_request_error_pattern('cc_emails', :datatype_mismatch, expected_data_type: Array, prepend_msg: :input_received, given_data_type: String),
                bad_request_error_pattern('attachments', :datatype_mismatch, expected_data_type: Array, prepend_msg: :input_received, given_data_type: String),
                bad_request_error_pattern('bcc_emails', :datatype_mismatch, expected_data_type: Array, prepend_msg: :input_received, given_data_type: String)])
  end

  def test_forward_email_format_invalid
    params_hash = { to_emails: ['dj#'], cc_emails: ['tyt@'], bcc_emails: ['hj#'], from_email: 'dg#', body: Faker::Lorem.paragraph }
    post :forward, construct_params({ id: ticket.display_id }, params_hash)
    assert_response 400
    match_json([bad_request_error_pattern('to_emails', :array_invalid_format, accepted: 'valid email address'),
                bad_request_error_pattern('cc_emails', :array_invalid_format, accepted: 'valid email address'),
                bad_request_error_pattern('bcc_emails', :array_invalid_format, accepted: 'valid email address'),
                bad_request_error_pattern('from_email', :invalid_format, accepted: 'valid email address')])
  end

  def test_forward_invalid_id
    params_hash = { body: 'test', to_emails: [Faker::Internet.email] }
    post :forward, construct_params({ id: '6786878' }, params_hash)
    assert_response :missing
  end

  def test_forward_invalid_model
    params_hash = { body: 'test', agent_id: 789_789_789, to_emails: [Faker::Internet.email] }
    post :forward, construct_params({ id: ticket.display_id }, params_hash)
    assert_response 400
    match_json([bad_request_error_pattern('agent_id', :absent_in_db, resource: :agent, attribute: :agent_id)])
  end

  def test_forward_invalid_from_email
    params_hash = { body: 'test', to_emails: [Faker::Internet.email], from_email: Faker::Internet.email }
    post :forward, construct_params({ id: ticket.display_id }, params_hash)
    assert_response 400
    match_json([bad_request_error_pattern('from_email', :absent_in_db, resource: :"active email_config", attribute: :from_email)])
  end

  def test_forward_inactive_email_config
    t = create_ticket
    email_config = create_email_config
    email_config.active = false
    email_config.save
    params_hash = forward_note_params_hash.merge(from_email: email_config.reply_email)
    post :forward, construct_params({ id: t.display_id }, params_hash)
    assert_response 400
    match_json([bad_request_error_pattern('from_email', :absent_in_db, resource: :"active email_config", attribute: :from_email)])
  end

  def test_forward_extra_params
    params_hash = { body_html: 'test', junk: 'test', to_emails: [Faker::Internet.email] }
    post :forward, construct_params({ id: ticket.display_id }, params_hash)
    assert_response 400
    match_json([bad_request_error_pattern('junk', :invalid_field), bad_request_error_pattern('body_html', :invalid_field)])
  end

  def test_forward_invalid_agent
    user = add_new_user(account)
    params_hash = forward_note_params_hash.merge(agent_id: user.id)
    post :forward, construct_params({ id: ticket.display_id }, params_hash)
    assert_response 400
    match_json([bad_request_error_pattern('agent_id', :absent_in_db, resource: :agent, attribute: :agent_id)])
  end

  def test_forward_with_attachment
    t = create_ticket
    file = fixture_file_upload('files/attachment.txt', 'text/plain', :binary)
    file2 = fixture_file_upload('files/image33kb.jpg', 'image/jpg')
    params = forward_note_params_hash.merge('attachments' => [file, file2])
    DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
    post :forward, construct_params({ id: t.display_id }, params)
    DataTypeValidator.any_instance.unstub(:valid_type?)
    assert_response 201
    response_params = params.except(:attachments)
    match_json(private_note_pattern(params, Helpdesk::Note.last))
    match_json(private_note_pattern({}, Helpdesk::Note.last))
    assert Helpdesk::Note.last.attachments.count == 2
  end

  def test_forward_with_child_description_attachment_ids
    Account.any_instance.stubs(:parent_child_tickets_enabled?).returns(true)
    child_attachment_ids = []
    create_parent_child_tickets
    child_attachment_ids << create_attachment(attachable_type: 'Helpdesk::Ticket', attachable_id: @child_ticket.id).id
    params_hash = forward_note_params_hash.merge(attachment_ids: child_attachment_ids, include_original_attachments: false)
    stub_attachment_to_io do
      post :forward, construct_params({ id: @parent_ticket.display_id }, params_hash)
    end
    assert_response 201
    match_json(private_note_pattern(params_hash, @account.notes.last))
    match_json(private_note_pattern({}, @account.notes.last))
    assert @account.notes.last.attachments.size == child_attachment_ids.size
    Account.any_instance.unstub(:parent_child_tickets_enabled?)
  end

  def test_forward_with_ticket_with_attachment
    t = create_ticket(attachments: { resource: fixture_file_upload('files/attachment.txt', 'plain/text', :binary) })
    params = forward_note_params_hash
    stub_attachment_to_io do
      post :forward, construct_params({ id: t.display_id }, params)
    end
    assert_response 201
    match_json(private_note_pattern(params, Helpdesk::Note.last))
    match_json(private_note_pattern({}, Helpdesk::Note.last))
    assert Helpdesk::Note.last.attachments.count == 1
  end

  def test_forward_with_ticket_with_cloud_attachment
    t = create_ticket(cloud_files:  [Helpdesk::CloudFile.new(filename: 'image.jpg', url: CLOUD_FILE_IMAGE_URL, application_id: 20)])
    params = forward_note_params_hash
    post :forward, construct_params({ id: t.display_id }, params)
    assert_response 201
    match_json(private_note_pattern(params, Helpdesk::Note.last))
    match_json(private_note_pattern({}, Helpdesk::Note.last))
    assert Helpdesk::Note.last.cloud_files.count == 1
  end

  def test_forward_with_attachments_invalid_size
    invalid_attachment_limit = @account.attachment_limit + 2
    Rack::Test::UploadedFile.any_instance.stubs(:size).returns(invalid_attachment_limit.megabytes)
    file = fixture_file_upload('files/attachment.txt', 'text/plain', :binary)
    params = forward_note_params_hash.merge('attachments' => [file])
    DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
    post :forward, construct_params({ id: ticket.display_id }, params)
    DataTypeValidator.any_instance.unstub(:valid_type?)
    assert_response 400
    match_json([bad_request_error_pattern('attachments', :invalid_size, max_size: "#{@account.attachment_limit} MB", current_size: "#{invalid_attachment_limit} MB")])
  end

  def test_forward_with_invalid_attachment_params_format
    params = forward_note_params_hash.merge('attachments' => [1, 2])
    post :forward, construct_params({ id: ticket.display_id }, params)
    assert_response 400
    match_json([bad_request_error_pattern('attachments', :array_datatype_mismatch, expected_data_type: 'valid file format')])
  end

  def test_forward_without_privilege
    User.any_instance.stubs(:privilege?).with(:forward_ticket).returns(false).at_most_once
    params_hash = forward_note_params_hash
    post :forward, construct_params({ id: ticket.display_id }, params_hash)
    User.any_instance.unstub(:privilege?)
    assert_response 403
    match_json(request_error_pattern(:access_denied))
  end

  def test_forward_without_quoted_text_and_empty_body
    params = forward_note_params_hash.merge(include_quoted_text: false)
    params.delete(:body)
    post :forward, construct_params({ id: ticket.display_id }, params)
    assert_response 400
    match_json([bad_request_error_pattern('body', :missing_field)])
  end

  def test_forward_without_quoted_text
    params = forward_note_params_hash.merge(include_quoted_text: false)
    stub_attachment_to_io do
      post :forward, construct_params({ id: ticket.display_id }, params)
    end
    assert_response 201
    latest_note = Helpdesk::Note.last
    match_json(private_note_pattern(params, latest_note))
    match_json(private_note_pattern({}, latest_note))
  end

  def test_forward_with_full_text
    params = forward_note_params_hash.merge(full_text: Faker::Lorem.paragraph(10))
    post :forward, construct_params({ id: ticket.display_id }, params)
    assert_response 201
    latest_note = Helpdesk::Note.last
    match_json(private_note_pattern(params, latest_note))
    match_json(private_note_pattern({}, latest_note))
  end

  def test_forward_with_invalid_draft_attachment_ids
    attachment_ids = []
    attachment_ids << create_attachment(attachable_type: 'UserDraft', attachable_id: @agent.id).id
    invalid_ids = [attachment_ids.last + 10, attachment_ids.last + 20]
    params_hash = forward_note_params_hash.merge(attachment_ids: (attachment_ids | invalid_ids))
    post :forward, construct_params({ id: ticket.display_id }, params_hash)
    assert_response 400
    match_json([bad_request_error_pattern(:attachment_ids, :invalid_list, list: invalid_ids.join(', '))])
  end

  def test_forward_with_draft_attachment_ids
    attachment_ids = []
    BULK_ATTACHMENT_CREATE_COUNT.times do
      attachment_ids << create_attachment(attachable_type: 'UserDraft', attachable_id: @agent.id).id
    end
    params_hash = forward_note_params_hash.merge(attachment_ids: attachment_ids, agent_id: @agent.id)
    post :forward, construct_params({ id: ticket.display_id }, params_hash)
    assert_response 201
    latest_note = Helpdesk::Note.last
    match_json(private_note_pattern(params_hash, latest_note))
    match_json(private_note_pattern({}, latest_note))
    assert latest_note.attachments.size == attachment_ids.size
  end

  def test_forward_without_original_attachments
    t = create_ticket(attachments: { resource: fixture_file_upload('files/attachment.txt', 'text/plain', :binary) })
    params = forward_note_params_hash.merge(include_original_attachments: false)
    post :forward, construct_params({ id: t.display_id }, params)
    assert_response 201
    latest_note = Helpdesk::Note.last
    match_json(private_note_pattern(params, latest_note))
    match_json(private_note_pattern({}, latest_note))
    assert latest_note.attachments.count == 0
  end

  def test_forward_with_ticket_attachment_ids
    t = create_ticket(attachments: { resource: fixture_file_upload('files/attachment.txt', 'text/plain', :binary) })
    params = forward_note_params_hash.merge(include_original_attachments: false, attachment_ids: [t.attachments.first.id])
    stub_attachment_to_io do
      post :forward, construct_params({ id: t.display_id }, params)
    end
    assert_response 201
    latest_note = Helpdesk::Note.last
    match_json(private_note_pattern(params, latest_note))
    match_json(private_note_pattern({}, latest_note))
    assert latest_note.attachments.count == 1
  end

  def test_forward_dup_removal_of_attachments
    t = create_ticket(attachments: { resource: fixture_file_upload('files/attachment.txt', 'text/plain', :binary) })
    create_shared_attachment(t)
    attachment_ids = t.all_attachments.map(&:id)
    params = forward_note_params_hash.merge(include_original_attachments: true, attachment_ids: attachment_ids)
    stub_attachment_to_io do
      post :forward, construct_params({ id: t.display_id }, params)
    end
    assert_response 201
    latest_note = Helpdesk::Note.last
    match_json(private_note_pattern(params, latest_note))
    match_json(private_note_pattern({}, latest_note))
    assert latest_note.attachments.count == 2
  end

  def test_forward_with_attachment_and_draft_attachment_ids
    t = create_ticket
    attachment_id = create_attachment(attachable_type: 'UserDraft', attachable_id: @agent.id).id
    file1 = fixture_file_upload('files/attachment.txt', 'text/plain', :binary)
    file2 = fixture_file_upload('files/image33kb.jpg', 'image/jpg')
    attachments = [file1, file2]
    params_hash = forward_note_params_hash.merge(agent_id: @agent.id, attachment_ids: [attachment_id], attachments: attachments)
    DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
    @request.env['CONTENT_TYPE'] = 'application/json'
    post :forward, construct_params({ id: t.display_id }, params_hash)
    DataTypeValidator.any_instance.unstub(:valid_type?)
    assert_response 201
    latest_note = Helpdesk::Note.last
    match_json(private_note_pattern(params_hash, latest_note))
    match_json(private_note_pattern({}, latest_note))
    assert latest_note.attachments.size == (attachments.size + 1)
  end

  def test_forward_with_inline_attachment_ids
    t = create_ticket
    inline_attachment_ids = []
    BULK_ATTACHMENT_CREATE_COUNT.times do
      inline_attachment_ids << create_attachment(attachable_type: 'Tickets Image Upload').id
    end
    params_hash = forward_note_params_hash.merge(inline_attachment_ids: inline_attachment_ids, agent_id: @agent.id)
    post :forward, construct_params({ id: ticket.display_id }, params_hash)
    assert_response 201
    note = Helpdesk::Note.last
    match_json(private_note_pattern(params_hash, note))
    match_json(private_note_pattern({}, note))
    assert_equal inline_attachment_ids.size, note.inline_attachments.size
  end

  def test_forward_with_invalid_inline_attachment_ids
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
    params_hash = forward_note_params_hash.merge(inline_attachment_ids: inline_attachment_ids, agent_id: @agent.id)
    post :forward, construct_params({ id: ticket.display_id }, params_hash)
    assert_response 400
    match_json([bad_request_error_pattern('inline_attachment_ids', :invalid_inline_attachments_list, invalid_ids: invalid_ids.join(', '))])
  end

  def test_forward_with_cloud_file_ids_error
    params = forward_note_params_hash.merge(include_original_attachments: true, cloud_file_ids: [100, 200])
    post :forward, construct_params({ id: ticket.display_id }, params)
    assert_response 400
    match_json([bad_request_error_pattern('cloud_file_ids', :included_original_attachments, code: :incompatible_field)])
  end

  def test_forward_with_invalid_cloud_file_ids
    latest_cloud_file = Helpdesk::CloudFile.last.try(:id) || 0
    invalid_ids = [latest_cloud_file + 10, latest_cloud_file + 20]
    params = forward_note_params_hash.merge(include_original_attachments: false, cloud_file_ids: invalid_ids)
    post :forward, construct_params({ id: ticket.display_id }, params)
    assert_response 400
    match_json([bad_request_error_pattern(:cloud_file_ids, :invalid_list, list: invalid_ids.join(', '))])
  end

  def test_forward_with_cloud_file_ids
    t = create_ticket(cloud_files:  [Helpdesk::CloudFile.new(filename: 'image.jpg', url: CLOUD_FILE_IMAGE_URL, application_id: 20)])
    params = forward_note_params_hash.merge(include_original_attachments: false, cloud_file_ids: [t.cloud_files.first.id])
    post :forward, construct_params({ id: t.display_id }, params)
    assert_response 201
    latest_note = Helpdesk::Note.last
    match_json(private_note_pattern(params, latest_note))
    match_json(private_note_pattern({}, latest_note))
    assert latest_note.cloud_files.count == 1
  end

  def test_forward_with_all_attachments_and_attachment_ids
    draft_attachment_id = create_attachment(attachable_type: 'UserDraft', attachable_id: @agent.id).id
    file1 = fixture_file_upload('files/attachment.txt', 'text/plain', :binary)
    file2 = fixture_file_upload('files/image33kb.jpg', 'image/jpg')
    new_attachments = [file1, file2]
    t = create_ticket(attachments: { resource: fixture_file_upload('files/attachment.txt', 'text/plain', :binary) },
                      cloud_files:  [Helpdesk::CloudFile.new(filename: 'image.jpg', url: CLOUD_FILE_IMAGE_URL, application_id: 20)])
    create_shared_attachment(t)
    params = forward_note_params_hash.merge(include_original_attachments: true,
                                            attachments: new_attachments, attachment_ids: [draft_attachment_id])
    DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
    stub_attachment_to_io do
      post :forward, construct_params({ id: t.display_id }, params)
    end
    DataTypeValidator.any_instance.unstub(:valid_type?)
    assert_response 201
    latest_note = Helpdesk::Note.last
    match_json(private_note_pattern(params, latest_note))
    match_json(private_note_pattern({}, latest_note))
    assert latest_note.attachments.count == 5
    assert latest_note.cloud_files.count == 1
  end

  def test_forward_with_cloud_files_upload
    t = create_ticket
    cloud_file_params = [{ name: 'image.jpg', url: CLOUD_FILE_IMAGE_URL, application_id: 20 }]
    params = forward_note_params_hash.merge(cloud_files: cloud_file_params)
    post :forward, construct_params({ id: t.display_id }, params)
    assert_response 201
    latest_note = Helpdesk::Note.last
    match_json(private_note_pattern(params, latest_note))
    match_json(private_note_pattern({}, latest_note))
    assert latest_note.cloud_files.count == 1
  end

  def test_forward_with_invalid_cloud_files
    t = create_ticket
    cloud_file_params = [{ name: 'image.jpg', url: CLOUD_FILE_IMAGE_URL, application_id: 10_000 }]
    params = forward_note_params_hash.merge(cloud_files: cloud_file_params)
    post :forward, construct_params({ id: t.display_id }, params)
    assert_response 400
    match_json([bad_request_error_pattern(:application_id, :invalid_list, list: '10000')])
  end

  def test_forward_with_existing_and_new_cloud_files
    t = create_ticket(cloud_files:  [Helpdesk::CloudFile.new(filename: 'image.jpg', url: CLOUD_FILE_IMAGE_URL, application_id: 20)])
    cloud_file_params = [{ name: 'image.jpg', url: CLOUD_FILE_IMAGE_URL, application_id: 20 }]
    params = forward_note_params_hash.merge(cloud_files: cloud_file_params)
    post :forward, construct_params({id: t.display_id }, params)
    assert_response 201
    latest_note = Helpdesk::Note.last
    match_json(private_note_pattern(params, latest_note))
    match_json(private_note_pattern({}, latest_note))
    assert latest_note.cloud_files.count == 2
  end

  def test_forward_with_shared_attachments
    canned_response = create_response(
      title: Faker::Lorem.sentence,
      content_html: Faker::Lorem.paragraph,
      visibility: ::Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:all_agents],
      attachments: { resource: fixture_file_upload('files/attachment.txt', 'text/plain', :binary) }
    )
    params = forward_note_params_hash.merge(attachment_ids: canned_response.shared_attachments.map(&:attachment_id))
    stub_attachment_to_io do
      post :forward, construct_params({ id: create_ticket.display_id }, params)
    end
    assert_response 201
    latest_note = Helpdesk::Note.last
    match_json(private_note_pattern(params, latest_note))
    match_json(private_note_pattern({}, latest_note))
    assert latest_note.attachments.count == 1
  end

  def test_forward_with_existing_attachment
    conversation = create_note(user_id: @agent.id, ticket_id: ticket.id, source: 2)
    attachment = create_attachment(attachable_type: 'Helpdesk::Note', attachable_id: conversation.id)
    params_hash = forward_note_params_hash.merge(attachment_ids: [attachment.id], include_original_attachments: false)
    stub_attachment_to_io do
      post :forward, construct_params({ id: ticket.display_id }, params_hash)
    end
    assert_response 201
    match_json(private_note_pattern(params_hash, Helpdesk::Note.last))
    match_json(private_note_pattern({}, Helpdesk::Note.last))
    note_attachment = Helpdesk::Note.last.attachments.first
    refute note_attachment.id == attachment.id
    assert attachment_content_hash(note_attachment) == attachment_content_hash(attachment)
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
    User.any_instance.stubs(:privilege?).with(:create_and_edit_article).returns(false).at_most_once
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
    User.any_instance.stubs(:privilege?).with(:create_and_edit_article).returns(false).at_most_once
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
