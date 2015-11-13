require_relative '../test_helper'

class NotesControllerTest < ActionController::TestCase
  include Helpers::NotesTestHelper
  def wrap_cname(params)
    { note: params }
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
    match_json([bad_request_error_pattern('user_id', :data_type_mismatch, data_type: 'Positive Integer')])
  end

  def test_create_inclusion_invalid
    params_hash = { private: 'x', incoming: 'x', body: Faker::Lorem.paragraph }
    post :create, construct_params({ id: ticket.display_id }, params_hash)
    assert_response 400
    match_json([bad_request_error_pattern('incoming', :data_type_mismatch, data_type: 'Boolean'),
                bad_request_error_pattern('private', :data_type_mismatch, data_type: 'Boolean')])
  end

  def test_create_datatype_invalid
    params_hash = { notify_emails: 'x', attachments: 'x', body: Faker::Lorem.paragraph }
    post :create, construct_params({ id: ticket.display_id }, params_hash)
    match_json([bad_request_error_pattern('notify_emails', :data_type_mismatch, data_type: 'Array'),
                bad_request_error_pattern('attachments', :data_type_mismatch, data_type: 'Array')])
    assert_response 400
  end

  def test_create_email_format_invalid
    params_hash = { notify_emails: ['tyt@'], body: Faker::Lorem.paragraph }
    post :create, construct_params({ id: ticket.display_id }, params_hash)
    match_json([bad_request_error_pattern('notify_emails', 'not_a_valid_email')])
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
    match_json([bad_request_error_pattern('body', :missing_field)])
  end

  def test_create_returns_location_header
    params_hash = create_note_params_hash
    post :create, construct_params({ id: ticket.display_id }, params_hash)
    assert_response 201
    match_json(note_pattern(params_hash, Helpdesk::Note.last))
    match_json(note_pattern({}, Helpdesk::Note.last))
    result = parse_response(@response.body)
    assert_equal true, response.headers.include?('Location')
    assert_equal "http://#{@request.host}/api/v2/notes/#{result['id']}", response.headers['Location']
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
    match_json([bad_request_error_pattern('attachments', :data_type_mismatch, data_type: 'valid format')])
  end

  def test_attachment_invalid_size_create
    Rack::Test::UploadedFile.any_instance.stubs(:size).returns(20_000_000)
    file = fixture_file_upload('/files/attachment.txt', 'plain/text', :binary)
    params = create_note_params_hash.merge('attachments' => [file])
    DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
    post :create, construct_params({ id: ticket.display_id }, params)
    DataTypeValidator.any_instance.unstub(:valid_type?)
    assert_response 400
    match_json([bad_request_error_pattern('attachments', :invalid_size, max_size: '15 MB')])
  end

  def test_create_without_privilege
    User.any_instance.stubs(:privilege?).with(:manage_tickets).returns(false).at_most_once
    params_hash = create_note_params_hash
    post :create, construct_params({ id: ticket.display_id }, params_hash)
    User.any_instance.unstub(:privilege?)
    assert_response 403
    match_json(request_error_pattern(:access_denied))
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
    match_json([bad_request_error_pattern('user_id', :data_type_mismatch, data_type: 'Positive Integer')])
  end

  def test_reply_datatype_invalid
    params_hash = { cc_emails: 'x', attachments: 'x', bcc_emails: 'x', body: Faker::Lorem.paragraph }
    post :reply, construct_params({ id: ticket.display_id }, params_hash)
    assert_response 400
    match_json([bad_request_error_pattern('cc_emails', :data_type_mismatch, data_type: 'Array'),
                bad_request_error_pattern('attachments', :data_type_mismatch, data_type: 'Array'),
                bad_request_error_pattern('bcc_emails', :data_type_mismatch, data_type: 'Array')])
  end

  def test_reply_email_format_invalid
    params_hash = { cc_emails: ['tyt@'], bcc_emails: ['hj#'], body: Faker::Lorem.paragraph }
    post :reply, construct_params({ id: ticket.display_id }, params_hash)
    assert_response 400
    match_json([bad_request_error_pattern('cc_emails', 'not_a_valid_email'),
                bad_request_error_pattern('bcc_emails', 'not_a_valid_email')])
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
    assert_equal "http://#{@request.host}/api/v2/notes/#{result['id']}", response.headers['Location']
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
    match_json([bad_request_error_pattern('attachments', :invalid_size, max_size: '15 MB')])
  end

  def test_reply_with_invalid_attachment_params_format
    params = reply_note_params_hash.merge('attachments' => [1, 2])
    post :reply, construct_params({ id: ticket.display_id }, params)
    assert_response 400
    match_json([bad_request_error_pattern('attachments', :data_type_mismatch, data_type: 'valid format')])
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
    match_json([bad_request_error_pattern('attachments', :invalid_size, max_size: '15 MB')])
  end

  def test_update_with_invalid_attachment_params_format
    params = update_note_params_hash.merge('attachments' => [1, 2])
    put :update, construct_params({ id: note.id }, params)
    assert_response 400
    match_json([bad_request_error_pattern('attachments', :data_type_mismatch, data_type: 'valid format')])
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
    match_json(base_error_pattern('method_not_allowed', methods: 'DELETE'))
  end

  def test_update_not_note_or_reply
    n = create_note(user_id: @agent.id, ticket_id: ticket.id, source: 1)
    params = update_note_params_hash
    put :update, construct_params({ id: n.id }, params)
    assert_response 405
    match_json(base_error_pattern('method_not_allowed', methods: 'DELETE'))
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

  def test_destroy_invalid_id
    delete :destroy, construct_params(id: 'x')
    assert_response :missing
  end

  def test_detroy_deleted
    n = note
    n.update_column(:deleted, true)
    delete :destroy, construct_params(id: n.id)
    assert_response :missing
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

  def test_notes
    parent_ticket = ticket
    4.times do
      create_note(user_id: @agent.id, ticket_id: parent_ticket.id, source: 2)
    end
    get :ticket_notes, construct_params(id: parent_ticket.display_id)
    assert_response 200
    result_pattern = []
    parent_ticket.notes.visible.exclude_source('meta').order(:created_at).each do |n|
      result_pattern << note_pattern(n)
    end
    match_json(result_pattern.ordered!)
  end

  def test_notes_return_only_non_deleted_notes
    parent_ticket = ticket
    create_note(user_id: @agent.id, ticket_id: parent_ticket.id, source: 2)

    get :ticket_notes, construct_params(id: parent_ticket.display_id)
    assert_response 200
    result_pattern = []
    parent_ticket.notes.visible.exclude_source('meta').each do |n|
      result_pattern << note_pattern(n)
    end
    assert JSON.parse(response.body).count == parent_ticket.notes.visible.exclude_source('meta').count
    match_json(result_pattern)

    Helpdesk::Note.where(notable_id: parent_ticket.id, notable_type: 'Helpdesk::Ticket').update_all(deleted: true)
    get :ticket_notes, construct_params(id: parent_ticket.display_id)
    assert_response 200
    result_pattern = []
    parent_ticket.notes.visible.exclude_source('meta').each do |n|
      result_pattern << note_pattern(n)
    end
    assert JSON.parse(response.body).count == 0
    match_json(result_pattern)
  end

  def test_notes_without_privilege
    parent_ticket = ticket
    User.any_instance.stubs(:privilege?).with(:manage_tickets).returns(false).at_most_once
    get :ticket_notes, construct_params(id: parent_ticket.display_id)
    User.any_instance.unstub(:privilege?)
    assert_response 403
    match_json(request_error_pattern(:access_denied))
  end

  def test_notes_invalid_id
    get :ticket_notes, construct_params(id: 56_756_767)
    assert_response :missing
    assert_equal ' ', @response.body
  end

  def test_notes_eager_loaded_association
    parent_ticket = ticket
    get :ticket_notes, construct_params(id: parent_ticket.display_id)
    assert_response 200
    assert controller.instance_variable_get(:@notes).all? { |x| x.association(:attachments).loaded? }
    assert controller.instance_variable_get(:@notes).all? { |x| x.association(:schema_less_note).loaded? }
    assert controller.instance_variable_get(:@notes).all? { |x| x.association(:note_old_body).loaded? }
  end

  def test_notes_with_pagination
    t = create_note(user_id: @agent.id, ticket_id: ticket.id, source: 2).notable
    3.times do
      create_note(user_id: @agent.id, ticket_id: t.id, source: 2)
    end
    get :ticket_notes, construct_params(id: t.display_id, per_page: 1)
    assert_response 200
    assert JSON.parse(response.body).count == 1
    get :ticket_notes, construct_params(id: t.display_id, per_page: 1, page: 2)
    assert_response 200
    assert JSON.parse(response.body).count == 1
  end

  def test_notes_with_pagination_exceeds_limit
    ApiConstants::DEFAULT_PAGINATE_OPTIONS.stubs(:[]).with(:max_per_page).returns(3)
    ApiConstants::DEFAULT_PAGINATE_OPTIONS.stubs(:[]).with(:per_page).returns(2)
    ApiConstants::DEFAULT_PAGINATE_OPTIONS.stubs(:[]).with(:page).returns(1)
    get :ticket_notes, construct_params(id: ticket.display_id, per_page: 4)
    assert_response 200
    assert JSON.parse(response.body).count == 3
    ApiConstants::DEFAULT_PAGINATE_OPTIONS.unstub(:[])
  end

  def test_notes_with_link_header
    parent_ticket = ticket
    3.times do
      create_note(user_id: @agent.id, ticket_id: parent_ticket.display_id, source: 2)
    end
    per_page = parent_ticket.notes.visible.exclude_source('meta').count - 1
    get :ticket_notes, construct_params(id: parent_ticket.display_id, per_page: per_page)
    assert_response 200
    assert JSON.parse(response.body).count == per_page
    assert_equal "<http://#{@request.host}/api/v2/tickets/#{parent_ticket.display_id}/notes?per_page=#{per_page}&page=2>; rel=\"next\"", response.headers['Link']

    get :ticket_notes, construct_params(id: parent_ticket.display_id, per_page: per_page, page: 2)
    assert_response 200
    assert JSON.parse(response.body).count == 1
    assert_nil response.headers['Link']
  end

  def test_notes_with_ticket_trashed
    parent_ticket = ticket
    Helpdesk::SchemaLessTicket.any_instance.stubs(:trashed).returns(true)
    get :ticket_notes, construct_params(id: parent_ticket.display_id)
    Helpdesk::SchemaLessTicket.any_instance.unstub(:trashed)
    assert_response 403
    match_json(request_error_pattern(:access_denied))
  end

  def test_notes_without_ticket_privilege
    parent_ticket = ticket
    User.any_instance.stubs(:has_ticket_permission?).returns(false)
    get :ticket_notes, construct_params(id: parent_ticket.display_id)
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
