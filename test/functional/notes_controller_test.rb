require_relative '../test_helper'

class NotesControllerTest < ActionController::TestCase
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
    params_hash = { body: body, notify_emails: email, ticket_id: ticket.display_id, private: true }
    params_hash
  end

  def update_note_params_hash
    body = Faker::Lorem.paragraph
    params_hash = { body: body }
    params_hash
  end

  def test_create
    params_hash = create_note_params_hash
    post :create, construct_params({}, params_hash)
    assert_response :created
    match_json(note_pattern(params_hash, Helpdesk::Note.last))
    match_json(note_pattern({}, Helpdesk::Note.last))
  end

  def test_create_public_note
    params_hash = create_note_params_hash.merge(private: false)
    post :create, construct_params({}, params_hash)
    assert_response :created
    match_json(note_pattern(params_hash, Helpdesk::Note.last))
    match_json(note_pattern({}, Helpdesk::Note.last))
  end

  def test_create_with_user_id_valid
    params_hash = create_note_params_hash.merge(user_id: user.id)
    post :create, construct_params({}, params_hash)
    assert_response :created
    match_json(note_pattern(params_hash, Helpdesk::Note.last))
    match_json(note_pattern({}, Helpdesk::Note.last))
  end

  def test_create_with_user_id_invalid_privilege
    params_hash = create_note_params_hash.merge(user_id: user.id)
    controller.class.any_instance.stubs(:is_allowed_to_assume?).returns(false)
    post :create, construct_params({}, params_hash)
    assert_response :forbidden
    match_json(request_error_pattern('access_denied', id: user.id, name: user.name))
    controller.class.any_instance.unstub(:is_allowed_to_assume?)
  end

  def test_create_numericality_invalid
    params_hash = { user_id: 'x', ticket_id: 'x' }
    post :create, construct_params({}, params_hash)
    assert_response :bad_request
    match_json([bad_request_error_pattern('user_id', 'is not a number'),
                bad_request_error_pattern('ticket_id', 'is not a number')])
  end

  def test_create_inclusion_invalid
    params_hash = { private: 'x', incoming: 'x', ticket_id: ticket.id }
    post :create, construct_params({}, params_hash)
    assert_response :bad_request
    match_json([bad_request_error_pattern('incoming', 'Should be a value in the list true,false'),
                bad_request_error_pattern('private', 'Should be a value in the list true,false')])
  end

  def test_create_datatype_invalid
    params_hash = { notify_emails: 'x', attachments: 'x', ticket_id: ticket.id }
    post :create, construct_params({}, params_hash)
    assert_response :bad_request
    match_json([bad_request_error_pattern('notify_emails', 'is not a/an Array'),
                bad_request_error_pattern('attachments', 'is not a/an Array')])
  end

  def test_create_email_format_invalid
    params_hash = { notify_emails: ['tyt@'], ticket_id: ticket.id }
    post :create, construct_params({}, params_hash)
    assert_response :bad_request
    match_json([bad_request_error_pattern('notify_emails', 'is not a valid email')])
  end

  def test_create_invalid_ticket_id
    params_hash = { body_html: 'test', ticket_id: 789_789_789 }
    post :create, construct_params({}, params_hash)
    assert_response :bad_request
    match_json([bad_request_error_pattern('ticket', "can't be blank")])
  end

  def test_create_invalid_model
    params_hash = { body_html: 'test', user_id: 789_789_789, ticket_id: ticket.id }
    post :create, construct_params({}, params_hash)
    assert_response :bad_request
    match_json([bad_request_error_pattern('user_id', "can't be blank")])
  end

  def test_create_extra_params
    params_hash = { body_html: 'test', junk: 'test' }
    post :create, construct_params({}, params_hash)
    assert_response :bad_request
    match_json([bad_request_error_pattern('junk', 'invalid_field')])
  end

  def test_create_missing_params
    post :create, construct_params({}, {})
    assert_response :bad_request
    match_json([bad_request_error_pattern('ticket', "can't be blank")])
  end

  def test_create_returns_location_header
    params_hash = create_note_params_hash
    post :create, construct_params({}, params_hash)
    assert_response :created
    match_json(note_pattern(params_hash, Helpdesk::Note.last))
    match_json(note_pattern({}, Helpdesk::Note.last))
    result = parse_response(@response.body)
    assert_equal true, response.headers.include?('Location')
    assert_equal "http://#{@request.host}/api/v2/notes/#{result['id']}", response.headers['Location']
  end

  def test_create_with_attachment
    file = fixture_file_upload('/files/attachment.txt', 'plain/text', :binary)
    file2 = fixture_file_upload('files/image33kb.jpg', 'image/jpg')
    params = create_note_params_hash.merge('attachments' => [file, file2])
    DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
    post :create, construct_params({}, params)
    DataTypeValidator.any_instance.unstub(:valid_type?)
    assert_response :created
    response_params = params.except(:attachments)
    match_json(note_pattern(params, Helpdesk::Note.last))
    match_json(note_pattern({}, Helpdesk::Note.last))
    assert Helpdesk::Note.last.attachments.count == 2
  end

  def test_create_with_invalid_attachment_params_format
    params = create_note_params_hash.merge('attachments' => [1, 2])
    post :create, construct_params({}, params)
    assert_response :bad_request
    match_json([bad_request_error_pattern('attachments', 'invalid_format')])
  end

  def test_create_without_privilege
    User.any_instance.stubs(:privilege?).with(:manage_tickets).returns(false).at_most_once
    params_hash = create_note_params_hash
    post :create, construct_params({}, params_hash)
    assert_response :forbidden
    match_json(request_error_pattern('access_denied'))
  end

  def test_reply
    params_hash = reply_note_params_hash
    post :reply, construct_params({ ticket_id: ticket.display_id }, params_hash)
    assert_response :created
    match_json(reply_note_pattern(params_hash, Helpdesk::Note.last))
    match_json(reply_note_pattern({}, Helpdesk::Note.last))
  end

  def test_reply_without_kbase_email
    params_hash = reply_note_params_hash
    article_count = Solution::Article.count
    post :reply, construct_params({ ticket_id: ticket.display_id }, params_hash)
    assert_response :created
    match_json(reply_note_pattern(params_hash, Helpdesk::Note.last))
    match_json(reply_note_pattern({}, Helpdesk::Note.last))
    assert article_count == Solution::Article.count
  end

  def test_reply_with_cc_kbase_mail
    article_count = Solution::Article.count
    params_hash = reply_note_params_hash.merge(cc_emails: [@account.kbase_email])
    post :reply, construct_params({ ticket_id: ticket.display_id }, params_hash)
    assert_response :created
    match_json(reply_note_pattern(params_hash.merge(cc_emails: []), Helpdesk::Note.last))
    match_json(reply_note_pattern({}, Helpdesk::Note.last))
    assert (article_count + 1) == Solution::Article.count
    assert Solution::Article.last.title == ticket.subject
    assert Solution::Article.last.description == Helpdesk::Note.last.body_html
    refute Helpdesk::Note.last.cc_emails.include?(@account.kbase_email)
  end

  def test_reply_with_bcc_kbase_mail
    article_count = Solution::Article.count
    params_hash = reply_note_params_hash.merge(bcc_emails: [@account.kbase_email])
    post :reply, construct_params({ ticket_id: ticket.display_id }, params_hash)
    assert_response :created
    match_json(reply_note_pattern(params_hash.merge(bcc_emails: []), Helpdesk::Note.last))
    match_json(reply_note_pattern({}, Helpdesk::Note.last))
    assert (article_count + 1) == Solution::Article.count
    assert Solution::Article.last.title == ticket.subject
    assert Solution::Article.last.description == Helpdesk::Note.last.body_html
    refute Helpdesk::Note.last.bcc_emails.include?(@account.kbase_email)
  end

  def test_reply_with_cc_kbase_mail_without_privilege
    article_count = Solution::Article.count
    User.any_instance.stubs(:privilege?).with(:reply_ticket).returns(true)
    User.any_instance.stubs(:privilege?).with(:publish_solution).returns(false).at_most_once
    params_hash = reply_note_params_hash.merge(cc_emails: [@account.kbase_email])
    post :reply, construct_params({ ticket_id: ticket.display_id }, params_hash)
    assert_response :created
    match_json(reply_note_pattern(params_hash.merge(cc_emails: []), Helpdesk::Note.last))
    match_json(reply_note_pattern({}, Helpdesk::Note.last))
    assert article_count == Solution::Article.count
  end

  def test_reply_with_bcc_kbase_mail_without_privilege
    article_count = Solution::Article.count
    User.any_instance.stubs(:privilege?).with(:reply_ticket).returns(true)
    User.any_instance.stubs(:privilege?).with(:publish_solution).returns(false).at_most_once
    params_hash = reply_note_params_hash.merge(bcc_emails: [@account.kbase_email])
    post :reply, construct_params({ ticket_id: ticket.display_id }, params_hash)
    assert_response :created
    match_json(reply_note_pattern(params_hash.merge(bcc_emails: []), Helpdesk::Note.last))
    match_json(reply_note_pattern({}, Helpdesk::Note.last))
    assert article_count == Solution::Article.count
  end

  def test_reply_with_cc_kbase_mail_short_subject
    article_count = Solution::Article.count
    t = create_ticket(subject: 'ui')
    params_hash = reply_note_params_hash.merge(cc_emails: [@account.kbase_email])
    post :reply, construct_params({ ticket_id: t.display_id }, params_hash)
    assert_response :created
    match_json(reply_note_pattern(params_hash.merge(cc_emails: []), Helpdesk::Note.last))
    match_json(reply_note_pattern({}, Helpdesk::Note.last))
    assert (article_count + 1) == Solution::Article.count
    refute Solution::Article.last.title == ticket.subject
    assert Solution::Article.last.title == "Ticket:#{t.display_id} subject is too short to be an article title"
    assert Solution::Article.last.description == Helpdesk::Note.last.body_html
    refute Helpdesk::Note.last.cc_emails.include?(@account.kbase_email)
  end

  def test_reply_with_user_id_valid
    params_hash = reply_note_params_hash.merge(user_id: user.id)
    post :reply, construct_params({ ticket_id: ticket.display_id }, params_hash)
    assert_response :created
    match_json(reply_note_pattern(params_hash, Helpdesk::Note.last))
    match_json(reply_note_pattern({}, Helpdesk::Note.last))
  end

  def test_reply_with_user_id_invalid_privilege
    params_hash = reply_note_params_hash.merge(user_id: user.id)
    controller.class.any_instance.stubs(:is_allowed_to_assume?).returns(false)
    post :reply, construct_params({ ticket_id: ticket.display_id }, params_hash)
    assert_response :forbidden
    match_json(request_error_pattern('access_denied', id: user.id, name: user.name))
    controller.class.any_instance.unstub(:is_allowed_to_assume?)
  end

  def test_reply_numericality_invalid
    params_hash = { user_id: 'x' }
    post :reply, construct_params({ ticket_id: ticket.display_id }, params_hash)
    assert_response :bad_request
    match_json([bad_request_error_pattern('user_id', 'is not a number')])
  end

  def test_reply_datatype_invalid
    params_hash = { cc_emails: 'x', attachments: 'x', bcc_emails: 'x' }
    post :reply, construct_params({ ticket_id: ticket.display_id }, params_hash)
    assert_response :bad_request
    match_json([bad_request_error_pattern('cc_emails', 'is not a/an Array'),
                bad_request_error_pattern('attachments', 'is not a/an Array'),
                bad_request_error_pattern('bcc_emails', 'is not a/an Array')])
  end

  def test_reply_email_format_invalid
    params_hash = { cc_emails: ['tyt@'], bcc_emails: ['hj#'] }
    post :reply, construct_params({ ticket_id: ticket.display_id }, params_hash)
    assert_response :bad_request
    match_json([bad_request_error_pattern('cc_emails', 'is not a valid email'),
                bad_request_error_pattern('bcc_emails', 'is not a valid email')])
  end

  def test_reply_invalid_ticket_id
    params_hash = { body_html: 'test' }
    post :reply, construct_params({ ticket_id: '6786878' }, params_hash)
    assert_response :not_found
  end

  def test_reply_invalid_model
    params_hash = { body_html: 'test', user_id: 789_789_789 }
    post :reply, construct_params({ ticket_id: ticket.display_id }, params_hash)
    assert_response :bad_request
    match_json([bad_request_error_pattern('user_id', "can't be blank")])
  end

  def test_reply_extra_params
    params_hash = { body_html: 'test', junk: 'test' }
    post :reply, construct_params({ ticket_id: ticket.display_id }, params_hash)
    assert_response :bad_request
    match_json([bad_request_error_pattern('junk', 'invalid_field')])
  end

  def test_reply_returns_location_header
    params_hash = reply_note_params_hash
    post :reply, construct_params({ ticket_id: ticket.display_id }, params_hash)
    assert_response :created
    match_json(reply_note_pattern(params_hash, Helpdesk::Note.last))
    match_json(reply_note_pattern({}, Helpdesk::Note.last))
    result = parse_response(@response.body)
    assert_equal true, response.headers.include?('Location')
    assert_equal "http://#{@request.host}/api/v2/notes/#{result['id']}", response.headers['Location']
  end

  def test_reply_with_attachment
    file = fixture_file_upload('/files/attachment.txt', 'plain/text', :binary)
    file2 = fixture_file_upload('files/image33kb.jpg', 'image/jpg')
    params = reply_note_params_hash.merge('attachments' => [file, file2])
    DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
    post :reply, construct_params({ ticket_id: ticket.display_id }, params)
    DataTypeValidator.any_instance.unstub(:valid_type?)
    assert_response :created
    response_params = params.except(:attachments)
    match_json(reply_note_pattern(params, Helpdesk::Note.last))
    match_json(reply_note_pattern({}, Helpdesk::Note.last))
    assert Helpdesk::Note.last.attachments.count == 2
  end

  def test_reply_with_invalid_attachment_params_format
    params = reply_note_params_hash.merge('attachments' => [1, 2])
    post :reply, construct_params({ ticket_id: ticket.display_id }, params)
    assert_response :bad_request
    match_json([bad_request_error_pattern('attachments', 'invalid_format')])
  end

  def test_reply_without_privilege
    User.any_instance.stubs(:privilege?).with(:reply_ticket).returns(false).at_most_once
    params_hash = reply_note_params_hash
    post :reply, construct_params({ ticket_id: ticket.display_id }, params_hash)
    assert_response :forbidden
    match_json(request_error_pattern('access_denied'))
  end

  def test_update
    params = update_note_params_hash
    n = note
    put :update, construct_params({ id: n.id }, params)
    assert_response :success
    match_json(note_pattern(params, n.reload))
    match_json(note_pattern({}, n.reload))
  end

  def test_update_deleted
    params = update_note_params_hash
    n = note
    n.update_column(:deleted, true)
    put :update, construct_params({ id: n.id }, params)
    assert_response :not_found
    n.update_column(:deleted, false)
  end

  def test_update_extra_params
    params = update_note_params_hash.merge(notify_emails: [Faker::Internet.email])
    n = note
    put :update, construct_params({ id: n.id }, params)
    assert_response :bad_request
    match_json([bad_request_error_pattern('notify_emails', 'invalid_field')])
  end

  def test_update_empty_params
    n = note
    put :update, construct_params({ id: n.id }, {})
    assert_response :bad_request
    match_json(request_error_pattern('missing_params'))
  end

  def test_update_with_attachment
    file = fixture_file_upload('/files/attachment.txt', 'plain/text', :binary)
    file2 = fixture_file_upload('files/image33kb.jpg', 'image/jpg')
    params = update_note_params_hash.merge('attachments' => [file, file2])
    n =  note
    DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
    put :update, construct_params({ id: n.id }, params)
    DataTypeValidator.any_instance.unstub(:valid_type?)
    assert_response :success
    response_params = params.except(:attachments)
    match_json(note_pattern(params, n.reload))
    match_json(note_pattern({}, n.reload))
    assert n.attachments.count == 2
  end

  def test_update_with_invalid_attachment_params_format
    params = update_note_params_hash.merge('attachments' => [1, 2])
    put :update, construct_params({ id: note.id }, params)
    assert_response :bad_request
    match_json([bad_request_error_pattern('attachments', 'invalid_format')])
  end

  def test_update_without_privilege
    User.any_instance.stubs(:privilege?).with(:edit_note).returns(false).at_most_once
    User.any_instance.stubs(:owns_object?).returns(false).at_most_once
    params = update_note_params_hash
    n = note
    put :update, construct_params({ id: n.id }, params)
    assert_response :forbidden
    match_json(request_error_pattern('access_denied'))
  end

  def test_update_with_owns_object_privilege
    User.any_instance.stubs(:privilege?).with(:edit_note).returns(false).at_most_once
    params = update_note_params_hash
    n = note
    put :update, construct_params({ id: n.id }, params)
    assert_response :success
    match_json(note_pattern(params, n.reload))
    match_json(note_pattern({}, n.reload))
  end

  def test_update_reply
    n = create_note(user_id: @agent.id, ticket_id: ticket.id, source: 0)
    params = update_note_params_hash
    put :update, construct_params({ id: n.id }, params)
    assert_response :method_not_allowed
    match_json(base_error_pattern('method_not_allowed', methods: 'DELETE'))
  end

  def test_update_not_note_or_reply
    n = create_note(user_id: @agent.id, ticket_id: ticket.id, source: 1)
    params = update_note_params_hash
    put :update, construct_params({ id: n.id }, params)
    assert_response :method_not_allowed
    match_json(base_error_pattern('method_not_allowed', methods: 'DELETE'))
  end

  def test_delete_not_note_or_reply
    n = create_note(user_id: @agent.id, ticket_id: ticket.id, source: 1)
    delete :destroy, construct_params(id: n.id)
    assert_response :no_content
    assert Helpdesk::Note.find(n.id).deleted == true
  end

  def test_update_user_note
    user = add_new_user(@account)
    n = create_note(user_id: user.id, ticket_id: ticket.id, source: 2)
    params = update_note_params_hash
    put :update, construct_params({ id: n.id }, params)
    assert_response :forbidden
    match_json(request_error_pattern('access_denied'))
  end

  def test_destroy
    n = create_note(user_id: @agent.id, ticket_id: ticket.id, source: 2)
    delete :destroy, construct_params(id: n.id)
    assert_response :no_content
    assert Helpdesk::Note.find(n.id).deleted == true
  end

  def test_destroy_reply
    n = create_note(user_id: @agent.id, ticket_id: ticket.id, source: 0)
    delete :destroy, construct_params(id: n.id)
    assert_response :no_content
    assert Helpdesk::Note.find(n.id).deleted == true
  end

  def test_destroy_invalid_id
    delete :destroy, construct_params(id: 'x')
    assert_response :not_found
  end

  def test_detroy_deleted
    n = note
    n.update_column(:deleted, true)
    delete :destroy, construct_params(id: n.id)
    assert_response :not_found
    n.update_column(:deleted, false)
  end

  def test_delete_user_reply
    user = add_new_user(@account)
    n = create_note(user_id: user.id, ticket_id: ticket.id, source: 0)
    delete :destroy, construct_params(id: n.id)
    assert_response :forbidden
    match_json(request_error_pattern('access_denied'))
  end

  def test_delete_user_note
    user = add_new_user(@account)
    n = create_note(user_id: user.id, ticket_id: ticket.id, source: 2)
    delete :destroy, construct_params(id: n.id)
    assert_response :forbidden
    match_json(request_error_pattern('access_denied'))
  end

  def test_delete_without_privilege
    User.any_instance.stubs(:privilege?).with(:edit_conversation).returns(false).at_most_once
    delete :destroy, construct_params(id: Helpdesk::Note.first.id)
    assert_response :forbidden
    match_json(request_error_pattern('access_denied'))
  end
end
