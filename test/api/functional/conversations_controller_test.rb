require_relative '../test_helper'

class ConversationsControllerTest < ActionController::TestCase
  include ConversationsTestHelper
  def wrap_cname(params)
    { conversation: params }
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
    Helpdesk::Note.where(source: Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['note'], deleted: false).first || create_note(user_id: @agent.id, ticket_id: ticket.id, source: 2)
  end

  def reply_note_params_hash
    body = Faker::Lorem.paragraph
    email = [Faker::Internet.email, Faker::Internet.email]
    bcc_emails = [Faker::Internet.email, Faker::Internet.email]
    params_hash = { body: body, cc_emails: email, bcc_emails: bcc_emails }
    params_hash
  end

  def create_note_params_hash
    body = Faker::Lorem.paragraph
    email = [Faker::Internet.email, Faker::Internet.email]
    params_hash = { body: body, notify_emails: email, private: true }
    params_hash
  end

  def update_note_params_hash
    body = Faker::Lorem.paragraph
    params_hash = { body: body }
    params_hash
  end

  def test_create_with_ticket_trashed
    Helpdesk::SchemaLessTicket.any_instance.stubs(:trashed).returns(true)
    params_hash = create_note_params_hash
    post :create, construct_params({ id: ticket.display_id }, params_hash)
    Helpdesk::SchemaLessTicket.any_instance.unstub(:trashed)
    assert_response 403
    match_json(request_error_pattern(:access_denied))
  end

  def test_create_without_ticket_privilege
    User.any_instance.stubs(:has_ticket_permission?).returns(false)
    params_hash = create_note_params_hash
    post :create, construct_params({ id: ticket.display_id }, params_hash)
    User.any_instance.unstub(:has_ticket_permission?)
    assert_response 403
    match_json(request_error_pattern(:access_denied))
  end

  def test_create
    params_hash = create_note_params_hash
    post :create, construct_params({ id: ticket.display_id }, params_hash)
    assert_response 201
    match_json(note_pattern(params_hash, Helpdesk::Note.last))
    match_json(note_pattern({}, Helpdesk::Note.last))
  end

  def test_create_public_note
    params_hash = create_note_params_hash.merge(private: false)
    post :create, construct_params({ id: ticket.display_id }, params_hash)
    assert_response 201
    match_json(note_pattern(params_hash, Helpdesk::Note.last))
    match_json(note_pattern({}, Helpdesk::Note.last))
  end

  def test_create_with_user_id_valid
    params_hash = create_note_params_hash.merge(user_id: user.id)
    post :create, construct_params({ id: ticket.display_id }, params_hash)
    assert_response 201
    match_json(note_pattern(params_hash, Helpdesk::Note.last))
    match_json(note_pattern({}, Helpdesk::Note.last))
  end

  def test_create_with_user_id_invalid_privilege
    params_hash = create_note_params_hash.merge(user_id: other_user.id)
    controller.class.any_instance.stubs(:is_allowed_to_assume?).returns(false)
    post :create, construct_params({ id: ticket.display_id }, params_hash)
    assert_response 403
    match_json(request_error_pattern('invalid_user', id: other_user.id, name: other_user.name))
    controller.class.any_instance.unstub(:is_allowed_to_assume?)
  end

  def test_create_numericality_invalid
    params_hash = { user_id: 'x', body: Faker::Lorem.paragraph }
    post :create, construct_params({ id: ticket.display_id }, params_hash)
    assert_response 400
    match_json([bad_request_error_pattern('user_id', :data_type_mismatch, expected_data_type: 'Positive Integer', prepend_msg: :input_received, given_data_type: String)])
  end

  def test_create_inclusion_invalid
    params_hash = { private: 'x', incoming: 'x', body: Faker::Lorem.paragraph }
    post :create, construct_params({ id: ticket.display_id }, params_hash)
    assert_response 400
    match_json([bad_request_error_pattern('incoming', :data_type_mismatch, expected_data_type: 'Boolean', prepend_msg: :input_received, given_data_type: String),
                bad_request_error_pattern('private', :data_type_mismatch, expected_data_type: 'Boolean', prepend_msg: :input_received, given_data_type: String)])
  end

  def test_create_datatype_invalid
    params_hash = { notify_emails: 'x', attachments: 'x', body: true, body_html: true }
    post :create, construct_params({ id: ticket.display_id }, params_hash)
    match_json([bad_request_error_pattern('notify_emails', :data_type_mismatch, expected_data_type: Array, prepend_msg: :input_received, given_data_type: String),
                bad_request_error_pattern('attachments', :data_type_mismatch, expected_data_type: Array, prepend_msg: :input_received, given_data_type: String),
                bad_request_error_pattern('body', :data_type_mismatch, expected_data_type: String, prepend_msg: :input_received, given_data_type: 'Boolean'),
                bad_request_error_pattern('body_html', :data_type_mismatch, expected_data_type: String, prepend_msg: :input_received, given_data_type: 'Boolean')])
    assert_response 400
  end

  def test_create_email_format_invalid
    params_hash = { notify_emails: ['tyt@'], body: Faker::Lorem.paragraph }
    post :create, construct_params({ id: ticket.display_id }, params_hash)
    match_json([bad_request_error_pattern('notify_emails', :array_invalid_format, accepted: 'valid email address')])
    assert_response 400
  end

  def test_create_invalid_ticket_id
    params_hash = { body_html: 'test' }
    post :create, construct_params({ id: 789_789_789 }, params_hash)
    assert_response :missing
  end

  def test_create_invalid_model
    params_hash = { body_html: 'test', user_id: 789_789_789 }
    post :create, construct_params({ id: ticket.display_id }, params_hash)
    assert_response 400
    match_json([bad_request_error_pattern('user_id', :"can't be blank")])
  end

  def test_create_extra_params
    params_hash = { body_html: 'test', junk: 'test' }
    post :create, construct_params({ id: ticket.display_id }, params_hash)
    assert_response 400
    match_json([bad_request_error_pattern('junk', :invalid_field)])
  end

  def test_create_missing_params
    post :create, construct_params({ id: ticket.display_id }, {})
    assert_response 400
    match_json([bad_request_error_pattern('body', :data_type_mismatch, code: :missing_field, expected_data_type: String)])
  end

  def test_create_returns_location_header
    params_hash = create_note_params_hash
    post :create, construct_params({ id: ticket.display_id }, params_hash)
    assert_response 201
    match_json(note_pattern(params_hash, Helpdesk::Note.last))
    match_json(note_pattern({}, Helpdesk::Note.last))
    result = parse_response(@response.body)
    assert_equal true, response.headers.include?('Location')
    assert_equal "http://#{@request.host}/api/v2/conversations/#{result['id']}", response.headers['Location']
  end

  def test_create_with_attachment
    file = fixture_file_upload('files/attachment.txt', 'plain/text', :binary)
    file2 = fixture_file_upload('files/image33kb.jpg', 'image/jpg')
    params = create_note_params_hash.merge('attachments' => [file, file2])
    DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
    post :create, construct_params({ id: ticket.display_id }, params)
    DataTypeValidator.any_instance.unstub(:valid_type?)
    assert_response 201
    response_params = params.except(:attachments)
    match_json(note_pattern(params, Helpdesk::Note.last))
    match_json(note_pattern({}, Helpdesk::Note.last))
    assert Helpdesk::Note.last.attachments.count == 2
  end

  def test_create_with_invalid_attachment_params_format
    params = create_note_params_hash.merge('attachments' => [1, 2])
    post :create, construct_params({ id: ticket.display_id }, params)
    assert_response 400
    match_json([bad_request_error_pattern('attachments', :array_data_type_mismatch, expected_data_type: 'valid file format')])
  end

  def test_attachment_invalid_size_create
    Rack::Test::UploadedFile.any_instance.stubs(:size).returns(20_000_000)
    file = fixture_file_upload('/files/attachment.txt', 'plain/text', :binary)
    params = create_note_params_hash.merge('attachments' => [file])
    DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
    post :create, construct_params({ id: ticket.display_id }, params)
    DataTypeValidator.any_instance.unstub(:valid_type?)
    assert_response 400
    match_json([bad_request_error_pattern('attachments', :invalid_size, max_size: '15 MB', current_size: '19.1 MB')])
  end

  def test_create_without_privilege
    User.any_instance.stubs(:privilege?).with(:manage_tickets).returns(false).at_most_once
    params_hash = create_note_params_hash
    post :create, construct_params({ id: ticket.display_id }, params_hash)
    User.any_instance.unstub(:privilege?)
    assert_response 403
    match_json(request_error_pattern(:access_denied))
  end

  def test_create_with_invalid_notify_emails_count
    notify_emails = []
    51.times do
      notify_emails << Faker::Internet.email
    end
    params = create_note_params_hash.merge(notify_emails: notify_emails)
    post :create, construct_params({ id: ticket.display_id }, params)
    assert_response 400
    match_json([bad_request_error_pattern('notify_emails', :too_long, entities: :values, max_count: "#{ApiTicketConstants::MAX_EMAIL_COUNT}", current_count: 51)])
  end

  def test_reply_with_invalid_cc_emails_count
    cc_emails = []
    50.times do
      cc_emails << Faker::Internet.email
    end
    params = reply_note_params_hash.merge(cc_emails: cc_emails, bcc_emails: cc_emails)
    post :reply, construct_params({ id: ticket.display_id }, params)
    assert_response 400
    match_json([bad_request_error_pattern('cc_emails', :too_long, entities: :values, max_count: "#{ApiTicketConstants::MAX_EMAIL_COUNT}", current_count: 50),
                bad_request_error_pattern('bcc_emails', :too_long, entities: :values, max_count: "#{ApiTicketConstants::MAX_EMAIL_COUNT}", current_count: 50)])
  end

  def test_reply_with_ticket_trashed
    Helpdesk::SchemaLessTicket.any_instance.stubs(:trashed).returns(true)
    params_hash = reply_note_params_hash
    post :reply, construct_params({ id: ticket.display_id }, params_hash)
    Helpdesk::SchemaLessTicket.any_instance.unstub(:trashed)
    assert_response 403
    match_json(request_error_pattern(:access_denied))
  end

  def test_reply_without_ticket_privilege
    User.any_instance.stubs(:has_ticket_permission?).returns(false)
    params_hash = reply_note_params_hash
    post :reply, construct_params({ id: ticket.display_id }, params_hash)
    User.any_instance.unstub(:has_ticket_permission?)
    assert_response 403
    match_json(request_error_pattern(:access_denied))
  end

  def test_reply
    params_hash = reply_note_params_hash
    post :reply, construct_params({ id: ticket.display_id }, params_hash)
    assert_response 201
    match_json(reply_note_pattern(params_hash, Helpdesk::Note.last))
    match_json(reply_note_pattern({}, Helpdesk::Note.last))
  end

  def test_reply_without_kbase_email
    params_hash = reply_note_params_hash
    article_count = Solution::Article.count
    post :reply, construct_params({ id: ticket.display_id }, params_hash)
    assert_response 201
    match_json(reply_note_pattern(params_hash, Helpdesk::Note.last))
    match_json(reply_note_pattern({}, Helpdesk::Note.last))
    assert article_count == Solution::Article.count
  end

  def test_reply_with_cc_kbase_mail
    article_count = Solution::Article.count
    parent_ticket = ticket
    parent_ticket.update_column(:subject, 'More than 3 letters')
    params_hash = reply_note_params_hash.merge(cc_emails: [@account.kbase_email])
    post :reply, construct_params({ id: parent_ticket.display_id }, params_hash)
    assert_response 201
    match_json(reply_note_pattern(params_hash.merge(cc_emails: nil), Helpdesk::Note.last))
    match_json(reply_note_pattern({}, Helpdesk::Note.last))
    assert (article_count + 1) == Solution::Article.count
    assert Solution::Article.last.title == parent_ticket.subject
    assert Solution::Article.last.description == Helpdesk::Note.last.body_html
    refute Helpdesk::Note.last.cc_emails.include?(@account.kbase_email)
  end

  def test_reply_with_bcc_kbase_mail
    article_count = Solution::Article.count
    parent_ticket = ticket
    parent_ticket.update_column(:subject, 'More than 3 letters')
    params_hash = reply_note_params_hash.merge(bcc_emails: [@account.kbase_email])
    post :reply, construct_params({ id: parent_ticket.display_id }, params_hash)
    assert_response 201
    match_json(reply_note_pattern(params_hash.merge(bcc_emails: nil), Helpdesk::Note.last))
    match_json(reply_note_pattern({}, Helpdesk::Note.last))
    assert (article_count + 1) == Solution::Article.count
    assert Solution::Article.last.title == parent_ticket.subject
    assert Solution::Article.last.description == Helpdesk::Note.last.body_html
    refute Helpdesk::Note.last.bcc_emails.include?(@account.kbase_email)
  end

  def test_reply_with_cc_kbase_mail_without_privilege
    article_count = Solution::Article.count
    User.any_instance.stubs(:privilege?).with(:manage_tickets).returns(true)
    User.any_instance.stubs(:privilege?).with(:reply_ticket).returns(true)
    User.any_instance.stubs(:privilege?).with(:publish_solution).returns(false).at_most_once
    params_hash = reply_note_params_hash.merge(cc_emails: [@account.kbase_email])
    post :reply, construct_params({ id: ticket.display_id }, params_hash)
    User.any_instance.unstub(:privilege?)
    assert_response 201
    match_json(reply_note_pattern(params_hash.merge(cc_emails: nil), Helpdesk::Note.last))
    match_json(reply_note_pattern({}, Helpdesk::Note.last))
    assert article_count == Solution::Article.count
  end

  def test_reply_with_bcc_kbase_mail_without_privilege
    article_count = Solution::Article.count
    User.any_instance.stubs(:privilege?).with(:manage_tickets).returns(true)
    User.any_instance.stubs(:privilege?).with(:reply_ticket).returns(true)
    User.any_instance.stubs(:privilege?).with(:publish_solution).returns(false).at_most_once
    params_hash = reply_note_params_hash.merge(bcc_emails: [@account.kbase_email])
    post :reply, construct_params({ id: ticket.display_id }, params_hash)
    User.any_instance.unstub(:privilege?)
    assert_response 201
    match_json(reply_note_pattern(params_hash.merge(bcc_emails: nil), Helpdesk::Note.last))
    match_json(reply_note_pattern({}, Helpdesk::Note.last))
    assert article_count == Solution::Article.count
  end

  def test_reply_with_cc_kbase_mail_short_subject
    article_count = Solution::Article.count
    t = create_ticket(subject: 'ui')
    params_hash = reply_note_params_hash.merge(cc_emails: [@account.kbase_email])
    post :reply, construct_params({ id: t.display_id }, params_hash)
    assert_response 201
    match_json(reply_note_pattern(params_hash.merge(cc_emails: nil), Helpdesk::Note.last))
    match_json(reply_note_pattern({}, Helpdesk::Note.last))
    assert (article_count + 1) == Solution::Article.count
    refute Solution::Article.last.title == ticket.subject
    assert Solution::Article.last.title == "Ticket:#{t.display_id} subject is too short to be an article title"
    assert Solution::Article.last.description == Helpdesk::Note.last.body_html
    refute Helpdesk::Note.last.cc_emails.include?(@account.kbase_email)
  end

  def test_reply_with_user_id_valid
    params_hash = reply_note_params_hash.merge(user_id: user.id)
    post :reply, construct_params({ id: ticket.display_id }, params_hash)
    assert_response 201
    match_json(reply_note_pattern(params_hash, Helpdesk::Note.last))
    match_json(reply_note_pattern({}, Helpdesk::Note.last))
  end

  def test_reply_with_user_id_invalid_privilege
    params_hash = reply_note_params_hash.merge(user_id: other_user.id)
    controller.class.any_instance.stubs(:is_allowed_to_assume?).returns(false)
    post :reply, construct_params({ id: ticket.display_id }, params_hash)
    assert_response 403
    match_json(request_error_pattern('invalid_user', id: other_user.id, name: other_user.name))
    controller.class.any_instance.unstub(:is_allowed_to_assume?)
  end

  def test_reply_numericality_invalid
    params_hash = { user_id: 'x', body: Faker::Lorem.paragraph }
    post :reply, construct_params({ id: ticket.display_id }, params_hash)
    assert_response 400
    match_json([bad_request_error_pattern('user_id', :data_type_mismatch, expected_data_type: 'Positive Integer', prepend_msg: :input_received, given_data_type: String)])
  end

  def test_reply_datatype_invalid
    params_hash = { cc_emails: 'x', attachments: 'x', bcc_emails: 'x', body: Faker::Lorem.paragraph }
    post :reply, construct_params({ id: ticket.display_id }, params_hash)
    assert_response 400
    match_json([bad_request_error_pattern('cc_emails', :data_type_mismatch, expected_data_type: Array, prepend_msg: :input_received, given_data_type: String),
                bad_request_error_pattern('attachments', :data_type_mismatch, expected_data_type: Array, prepend_msg: :input_received, given_data_type: String),
                bad_request_error_pattern('bcc_emails', :data_type_mismatch, expected_data_type: Array, prepend_msg: :input_received, given_data_type: String)])
  end

  def test_reply_email_format_invalid
    params_hash = { cc_emails: ['tyt@'], bcc_emails: ['hj#'], body: Faker::Lorem.paragraph }
    post :reply, construct_params({ id: ticket.display_id }, params_hash)
    assert_response 400
    match_json([bad_request_error_pattern('cc_emails', :array_invalid_format, accepted: 'valid email address'),
                bad_request_error_pattern('bcc_emails', :array_invalid_format, accepted: 'valid email address')])
  end

  def test_reply_invalid_id
    params_hash = { body_html: 'test' }
    post :reply, construct_params({ id: '6786878' }, params_hash)
    assert_response :missing
  end

  def test_reply_invalid_model
    params_hash = { body_html: 'test', user_id: 789_789_789 }
    post :reply, construct_params({ id: ticket.display_id }, params_hash)
    assert_response 400
    match_json([bad_request_error_pattern('user_id', :"can't be blank")])
  end

  def test_reply_extra_params
    params_hash = { body_html: 'test', junk: 'test' }
    post :reply, construct_params({ id: ticket.display_id }, params_hash)
    assert_response 400
    match_json([bad_request_error_pattern('junk', :invalid_field)])
  end

  def test_reply_returns_location_header
    params_hash = reply_note_params_hash
    post :reply, construct_params({ id: ticket.display_id }, params_hash)
    assert_response 201
    match_json(reply_note_pattern(params_hash, Helpdesk::Note.last))
    match_json(reply_note_pattern({}, Helpdesk::Note.last))
    result = parse_response(@response.body)
    assert_equal true, response.headers.include?('Location')
    assert_equal "http://#{@request.host}/api/v2/conversations/#{result['id']}", response.headers['Location']
  end

  def test_reply_with_attachment
    file = fixture_file_upload('files/attachment.txt', 'plain/text', :binary)
    file2 = fixture_file_upload('files/image33kb.jpg', 'image/jpg')
    params = reply_note_params_hash.merge('attachments' => [file, file2])
    DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
    post :reply, construct_params({ id: ticket.display_id }, params)
    DataTypeValidator.any_instance.unstub(:valid_type?)
    assert_response 201
    response_params = params.except(:attachments)
    match_json(reply_note_pattern(params, Helpdesk::Note.last))
    match_json(reply_note_pattern({}, Helpdesk::Note.last))
    assert Helpdesk::Note.last.attachments.count == 2
  end

  def test_attachments_invalid_size_reply
    Rack::Test::UploadedFile.any_instance.stubs(:size).returns(20_000_000)
    file = fixture_file_upload('/files/attachment.txt', 'plain/text', :binary)
    params = reply_note_params_hash.merge('attachments' => [file])
    DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
    post :reply, construct_params({ id: ticket.display_id }, params)
    DataTypeValidator.any_instance.unstub(:valid_type?)
    assert_response 400
    match_json([bad_request_error_pattern('attachments', :invalid_size, max_size: '15 MB', current_size: '19.1 MB')])
  end

  def test_reply_with_invalid_attachment_params_format
    params = reply_note_params_hash.merge('attachments' => [1, 2])
    post :reply, construct_params({ id: ticket.display_id }, params)
    assert_response 400
    match_json([bad_request_error_pattern('attachments', :array_data_type_mismatch, expected_data_type: 'valid file format')])
  end

  def test_reply_without_privilege
    User.any_instance.stubs(:privilege?).with(:reply_ticket).returns(false).at_most_once
    params_hash = reply_note_params_hash
    post :reply, construct_params({ id: ticket.display_id }, params_hash)
    User.any_instance.unstub(:privilege?)
    assert_response 403
    match_json(request_error_pattern(:access_denied))
  end

  def test_update_with_ticket_trashed
    Helpdesk::SchemaLessTicket.any_instance.stubs(:trashed).returns(true)
    params = update_note_params_hash
    n = note
    put :update, construct_params({ id: n.id }, params)
    Helpdesk::SchemaLessTicket.any_instance.unstub(:trashed)
    assert_response 403
    match_json(request_error_pattern(:access_denied))
  end

  def test_update_without_ticket_privilege
    User.any_instance.stubs(:has_ticket_permission?).returns(false)
    params = update_note_params_hash
    n = note
    put :update, construct_params({ id: n.id }, params)
    User.any_instance.unstub(:has_ticket_permission?)
    assert_response 403
    match_json(request_error_pattern(:access_denied))
  end

  def test_update
    params = update_note_params_hash
    n = note
    put :update, construct_params({ id: n.id }, params)
    assert_response 200
    match_json(note_pattern(params, n.reload))
    match_json(note_pattern({}, n.reload))
  end

  def test_update_deleted
    params = update_note_params_hash
    n = note
    n.update_column(:deleted, true)
    put :update, construct_params({ id: n.id }, params)
    assert_response :missing
    n.update_column(:deleted, false)
  end

  def test_update_extra_params
    params = update_note_params_hash.merge(notify_emails: [Faker::Internet.email])
    n = note
    put :update, construct_params({ id: n.id }, params)
    assert_response 400
    match_json([bad_request_error_pattern('notify_emails', :invalid_field)])
  end

  def test_update_empty_params
    n = note
    put :update, construct_params({ id: n.id }, {})
    assert_response 400
    match_json(request_error_pattern(:missing_params))
  end

  def test_update_with_attachment
    file = fixture_file_upload('/files/attachment.txt', 'plain/text', :binary)
    file2 = fixture_file_upload('files/image33kb.jpg', 'image/jpg')
    params = update_note_params_hash.merge('attachments' => [file, file2])
    n =  note
    DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
    put :update, construct_params({ id: n.id }, params)
    DataTypeValidator.any_instance.unstub(:valid_type?)
    assert_response 200
    response_params = params.except(:attachments)
    match_json(note_pattern(params, n.reload))
    match_json(note_pattern({}, n.reload))
    assert n.attachments.count == 2
  end

  def test_attachments_invalid_size_update
    n = note
    file = fixture_file_upload('/files/attachment.txt', 'plain/text', :binary)
    params = update_note_params_hash.merge('attachments' => [file])
    DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
    attachments = [mock('attachment')]
    attachments.stubs(:sum).returns(20_000_000)
    Helpdesk::Note.any_instance.stubs(:attachments).returns(attachments)
    put :update, construct_params({ id: n.id }, params)
    DataTypeValidator.any_instance.unstub(:valid_type?)
    assert_response 400
    match_json([bad_request_error_pattern('attachments', :invalid_size, max_size: '15 MB', current_size: '19.1 MB')])
  end

  def test_update_with_invalid_attachment_params_format
    params = update_note_params_hash.merge('attachments' => [1, 2])
    put :update, construct_params({ id: note.id }, params)
    assert_response 400
    match_json([bad_request_error_pattern('attachments', :array_data_type_mismatch, expected_data_type: 'valid file format')])
  end

  def test_update_without_privilege
    User.any_instance.stubs(:privilege?).with(:edit_note).returns(false).at_most_once
    User.any_instance.stubs(:owns_object?).returns(false).at_most_once
    params = update_note_params_hash
    n = note
    put :update, construct_params({ id: n.id }, params)
    User.any_instance.unstub(:privilege?, :owns_object?)
    assert_response 403
    match_json(request_error_pattern(:access_denied))
  end

  def test_update_with_owns_object_privilege
    User.any_instance.stubs(:privilege?).with(:manage_tickets).returns(true)
    User.any_instance.stubs(:privilege?).with(:edit_note).returns(false).at_most_once
    params = update_note_params_hash
    n = note
    put :update, construct_params({ id: n.id }, params)
    User.any_instance.unstub(:privilege?)
    assert_response 200
    match_json(note_pattern(params, n.reload))
    match_json(note_pattern({}, n.reload))
  end

  def test_update_reply
    n = create_note(user_id: @agent.id, ticket_id: ticket.id, source: 0)
    params = update_note_params_hash
    put :update, construct_params({ id: n.id }, params)
    assert_response 405
  end

  def test_update_not_note_or_reply
    n = create_note(user_id: @agent.id, ticket_id: ticket.id, source: 1)
    params = update_note_params_hash
    put :update, construct_params({ id: n.id }, params)
    assert_response 405
  end

  def test_delete_not_note_or_reply
    n = create_note(user_id: @agent.id, ticket_id: ticket.id, source: 1)
    delete :destroy, construct_params(id: n.id)
    assert_response 204
    assert Helpdesk::Note.find(n.id).deleted == true
  end

  def test_update_user_note
    user = add_new_user(@account)
    n = create_note(user_id: user.id, ticket_id: ticket.id, source: 2)
    params = update_note_params_hash
    put :update, construct_params({ id: n.id }, params)
    assert_response 403
    match_json(request_error_pattern(:access_denied))
  end

  def test_destroy
    n = create_note(user_id: @agent.id, ticket_id: ticket.id, source: 2)
    delete :destroy, construct_params(id: n.id)
    assert_response 204
    assert Helpdesk::Note.find(n.id).deleted == true
  end

  def test_destroy_reply
    n = create_note(user_id: @agent.id, ticket_id: ticket.id, source: 0)
    delete :destroy, construct_params(id: n.id)
    assert_response 204
    assert Helpdesk::Note.find(n.id).deleted == true
  end

  def test_destroy_meta_note
    n = create_note(user_id: @agent.id, ticket_id: ticket.id, source: 4)
    delete :destroy, construct_params(id: n.id)
    assert_response 404
  end

  def test_destroy_invalid_id
    delete :destroy, construct_params(id: 'x')
    assert_response 404
  end

  def test_detroy_deleted
    n = note
    n.update_column(:deleted, true)
    delete :destroy, construct_params(id: n.id)
    assert_response 404
    n.update_column(:deleted, false)
  end

  def test_delete_user_reply
    user = add_new_user(@account)
    n = create_note(user_id: user.id, ticket_id: ticket.id, source: 0)
    delete :destroy, construct_params(id: n.id)
    assert_response 403
    match_json(request_error_pattern(:access_denied))
  end

  def test_delete_user_note
    user = add_new_user(@account)
    n = create_note(user_id: user.id, ticket_id: ticket.id, source: 2)
    delete :destroy, construct_params(id: n.id)
    assert_response 403
    match_json(request_error_pattern(:access_denied))
  end

  def test_delete_without_privilege
    User.any_instance.stubs(:privilege?).with(:edit_conversation).returns(false).at_most_once
    delete :destroy, construct_params(id: Helpdesk::Note.first.id)
    User.any_instance.unstub(:privilege?)
    assert_response 403
    match_json(request_error_pattern(:access_denied))
  end

  def test_destroy_with_ticket_trashed
    Helpdesk::SchemaLessTicket.any_instance.stubs(:trashed).returns(true)
    n = create_note(ticket_id: ticket.id, source: 2, user_id: @agent.id)
    delete :destroy, construct_params(id: n.id)
    Helpdesk::SchemaLessTicket.any_instance.unstub(:trashed)
    assert_response 403
    match_json(request_error_pattern(:access_denied))
  end

  def test_destroy_without_ticket_privilege
    User.any_instance.stubs(:has_ticket_permission?).returns(false)
    n = create_note(ticket_id: ticket.id, source: 2, user_id: @agent.id)
    delete :destroy, construct_params(id: n.id)
    User.any_instance.unstub(:has_ticket_permission?)
    assert_response 403
    match_json(request_error_pattern(:access_denied))
  end

  def test_ticket_conversations
    parent_ticket = ticket
    4.times do
      create_note(user_id: @agent.id, ticket_id: parent_ticket.id, source: 2)
    end
    get :ticket_conversations, controller_params(id: parent_ticket.display_id)
    assert_response 200
    result_pattern = []
    parent_ticket.notes.visible.exclude_source('meta').order(:created_at).each do |n|
      result_pattern << index_note_pattern(n)
    end
    match_json(result_pattern.ordered!)
  end

  def test_ticket_conversations_return_only_non_deleted_notes
    parent_ticket = ticket
    create_note(user_id: @agent.id, ticket_id: parent_ticket.id, source: 2)

    get :ticket_conversations, controller_params(id: parent_ticket.display_id)
    assert_response 200
    result_pattern = []
    parent_ticket.notes.visible.exclude_source('meta').each do |n|
      result_pattern << index_note_pattern(n)
    end
    assert JSON.parse(response.body).count == parent_ticket.notes.visible.exclude_source('meta').count
    match_json(result_pattern)

    Helpdesk::Note.where(notable_id: parent_ticket.id, notable_type: 'Helpdesk::Ticket').update_all(deleted: true)
    get :ticket_conversations, controller_params(id: parent_ticket.display_id)
    assert_response 200
    result_pattern = []
    parent_ticket.notes.visible.exclude_source('meta').each do |n|
      result_pattern << index_note_pattern(n)
    end
    assert JSON.parse(response.body).count == 0
    match_json(result_pattern)
  end

  def test_ticket_conversations_without_privilege
    parent_ticket = ticket
    User.any_instance.stubs(:privilege?).with(:manage_tickets).returns(false).at_most_once
    get :ticket_conversations, controller_params(id: parent_ticket.display_id)
    User.any_instance.unstub(:privilege?)
    assert_response 403
    match_json(request_error_pattern(:access_denied))
  end

  def test_ticket_conversations_invalid_id
    get :ticket_conversations, controller_params(id: 56_756_767)
    assert_response :missing
    assert_equal ' ', @response.body
  end

  def test_ticket_conversations_eager_loaded_association
    parent_ticket = ticket
    get :ticket_conversations, controller_params(id: parent_ticket.display_id)
    assert_response 200
    assert controller.instance_variable_get(:@ticket_conversations).all? { |x| x.association(:attachments).loaded? }
    assert controller.instance_variable_get(:@ticket_conversations).all? { |x| x.association(:schema_less_note).loaded? }
    assert controller.instance_variable_get(:@ticket_conversations).all? { |x| x.association(:note_old_body).loaded? }
  end

  def test_ticket_conversations_with_pagination
    t = create_note(user_id: @agent.id, ticket_id: ticket.id, source: 2).notable
    3.times do
      create_note(user_id: @agent.id, ticket_id: t.id, source: 2)
    end
    get :ticket_conversations, controller_params(id: t.display_id, per_page: 1)
    assert_response 200
    assert JSON.parse(response.body).count == 1
    get :ticket_conversations, controller_params(id: t.display_id, per_page: 1, page: 2)
    assert_response 200
    assert JSON.parse(response.body).count == 1
  end

  def test_ticket_conversations_with_pagination_exceeds_limit
    get :ticket_conversations, controller_params(id: ticket.display_id, per_page: 101)
    assert_response 400
    match_json([bad_request_error_pattern('per_page', :per_page_invalid, max_value: 100)])
  end

  def test_ticket_conversations_with_link_header
    parent_ticket = ticket
    3.times do
      create_note(user_id: @agent.id, ticket_id: parent_ticket.display_id, source: 2)
    end
    per_page = parent_ticket.notes.visible.exclude_source('meta').count - 1
    get :ticket_conversations, controller_params(id: parent_ticket.display_id, per_page: per_page)
    assert_response 200
    assert JSON.parse(response.body).count == per_page
    assert_equal "<http://#{@request.host}/api/v2/tickets/#{parent_ticket.display_id}/conversations?per_page=#{per_page}&page=2>; rel=\"next\"", response.headers['Link']

    get :ticket_conversations, controller_params(id: parent_ticket.display_id, per_page: per_page, page: 2)
    assert_response 200
    assert JSON.parse(response.body).count == 1
    assert_nil response.headers['Link']
  end

  def test_ticket_conversations_with_ticket_trashed
    parent_ticket = ticket
    Helpdesk::SchemaLessTicket.any_instance.stubs(:trashed).returns(true)
    get :ticket_conversations, controller_params(id: parent_ticket.display_id)
    Helpdesk::SchemaLessTicket.any_instance.unstub(:trashed)
    assert_response 403
    match_json(request_error_pattern(:access_denied))
  end

  def test_ticket_conversations_without_ticket_privilege
    parent_ticket = ticket
    User.any_instance.stubs(:has_ticket_permission?).returns(false)
    get :ticket_conversations, controller_params(id: parent_ticket.display_id)
    User.any_instance.unstub(:has_ticket_permission?)
    assert_response 403
    match_json(request_error_pattern(:access_denied))
  end

  def test_reply_with_nil_array_fields
    params_hash = reply_note_params_hash.merge(cc_emails: [], bcc_emails: [], attachments: [])
    post :reply, construct_params({ id: ticket.display_id }, params_hash)
    match_json(reply_note_pattern(params_hash, Helpdesk::Note.last))
    match_json(reply_note_pattern({}, Helpdesk::Note.last))
    assert_response 201
  end

  def test_create_datatype_nil_array_fields
    params_hash = { notify_emails: [], attachments: [], body: Faker::Lorem.paragraph }
    post :create, construct_params({ id: ticket.display_id }, params_hash)
    match_json(note_pattern({}, Helpdesk::Note.last))
    assert_response 201
  end
end
