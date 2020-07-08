require_relative '../test_helper'
require 'sidekiq/testing'
Sidekiq::Testing.fake!

['social_tickets_creation_helper.rb', 'twitter_helper.rb', 'note_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }

class ConversationsControllerTest < ActionController::TestCase
  include ConversationsTestHelper
  include AttachmentsTestHelper
  include SocialTestHelper
  include SocialTicketsCreationHelper
  include TwitterHelper
  include NoteHelper
  include ContactSegmentsTestHelper
  include Redis::UndoSendRedis
  include Redis::RedisKeys
  include Redis::OthersRedis
  include Redis::TicketsRedis

  SEND_CC_EMAIL_JOB_STRING = "handler LIKE '%send_cc_email%'".freeze

  def setup
    super
    Social::CustomTwitterWorker.stubs(:perform_async).returns(true)
    @twitter_handle = get_twitter_handle
    @default_stream = @twitter_handle.default_stream
  end

  def teardown
    super
    Social::CustomTwitterWorker.unstub(:perform_async)
  end

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
    @agent.preferences[:agent_preferences][:undo_send] = false
    Helpdesk::Note.where(source: Account.current.helpdesk_sources.note_source_keys_by_token['note'], deleted: false).first || create_note(user_id: @agent.id, ticket_id: ticket.id, source: 2)
  end

  def reply_note_params_hash
    body = Faker::Lorem.paragraph
    email = [Faker::Internet.email, Faker::Internet.email, "\"#{Faker::Name.name}\" <#{Faker::Internet.email}>"]
    bcc_emails = [Faker::Internet.email, Faker::Internet.email, "\"#{Faker::Name.name}\" <#{Faker::Internet.email}>"]
    email_config = @account.email_configs.where(active: true).first || create_email_config
    params_hash = { body: body, cc_emails: email, bcc_emails: bcc_emails, from_email: email_config.reply_email }
    params_hash
  end

  def create_note_params_hash
    body = Faker::Lorem.paragraph
    agent_emails = Account.current.technicians.limit(2).collect(&:email)
    if agent_emails.count != 2
      (2 - agent_emails.count).times do
        agent_emails << add_test_agent(@account, role: Role.find_by_name('Agent').id).email
      end
    end
    params_hash = { body: body, notify_emails: agent_emails, private: true }
    params_hash
  end

  def update_note_params_hash
    body = Faker::Lorem.paragraph
    params_hash = { body: body }
    params_hash
  end

  def twitter_dm_reply_params_hash
    body = Faker::Lorem.characters(rand(1..140))
    twitter_handle_id = @twitter_handle.twitter_user_id
    tweet_type = 'dm'
    params_hash = { body: body, twitter: { tweet_type: tweet_type, twitter_handle_id: twitter_handle_id } }
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
    match_json(v2_note_pattern(params_hash, Helpdesk::Note.last))
    match_json(v2_note_pattern({}, Helpdesk::Note.last))
  end

  def test_create_public_note
    params_hash = create_note_params_hash.merge(private: false)
    post :create, construct_params({ id: ticket.display_id }, params_hash)
    assert_response 201
    match_json(v2_note_pattern(params_hash, Helpdesk::Note.last))
    match_json(v2_note_pattern({}, Helpdesk::Note.last))
  end

  # Note content having the protocol 'notes://' will also be auto-linked like 'http://'
  # Test case 1 - lotes notes protocol (notes://)
  def test_create_public_note_for_lotes_notes
    body = 'notes://domino02/C1258106002EBFEA/4B75A35B5C1FE7DE482572F4002B516C/CF870A2907AA7CBCC12581AF00254B9F'
    params_hash = { body: body }
    post :create, construct_params({ id: ticket.display_id }, params_hash)
    autolinked_custom = "<a href=\\\"notes://domino02/C1258106002EBFEA/4B75A35B5C1FE7DE482572F4002B516C/CF870A2907AA7CBCC12581AF00254B9F\\\">notes://domino02/C1258106002EBFEA/4B75A35B5C1FE7DE482572F4002B516C/CF870A2907AA7CBCC12581AF00254B9F</a>"
    assert_response 201
    assert response.body.include?(autolinked_custom)
  end

  # Test case 2 - lotes notes protocol (notes://) doesn't break existing protocols (http://)
  def test_create_public_note_for_lotes_notes_http
    body = 'notes://domino02/C1258106002EBFEA/4B75A35B5C1FE7DE482572F4002B516C/CF870A2907AA7CBCC12581AF00254B9F http://google.com'
    params_hash = { body: body }
    post :create, construct_params({ id: ticket.display_id }, params_hash)
    autolinked_normal = "<a href=\\\"http://google.com\\\" rel=\\\"noreferrer\\\">http://google.com</a>"
    assert_response 201
    assert response.body.include?(autolinked_normal)
  end

  def test_create_with_user_id_valid
    params_hash = create_note_params_hash.merge(user_id: user.id)
    post :create, construct_params({ id: ticket.display_id }, params_hash)
    assert_response 201
    match_json(v2_note_pattern(params_hash, Helpdesk::Note.last))
    match_json(v2_note_pattern({}, Helpdesk::Note.last))
  end

  def test_create_with_user_id_invalid_privilege
    sample_user = other_user
    params_hash = create_note_params_hash.merge(user_id: sample_user.id)
    controller.class.any_instance.stubs(:is_allowed_to_assume?).returns(false)
    post :create, construct_params({ id: ticket.display_id }, params_hash)
    assert_response 403
    match_json(request_error_pattern('invalid_user', id: sample_user.id, name: sample_user.name))
    controller.class.any_instance.unstub(:is_allowed_to_assume?)
  end

  def test_create_numericality_invalid
    params_hash = { user_id: 'x', body: Faker::Lorem.paragraph }
    post :create, construct_params({ id: ticket.display_id }, params_hash)
    assert_response 400
    match_json([bad_request_error_pattern('user_id', :datatype_mismatch, expected_data_type: 'Positive Integer', prepend_msg: :input_received, given_data_type: String)])
  end

  def test_create_inclusion_invalid
    params_hash = { private: 'x', incoming: 'x', body: Faker::Lorem.paragraph }
    post :create, construct_params({ id: ticket.display_id }, params_hash)
    assert_response 400
    match_json([bad_request_error_pattern('incoming', :datatype_mismatch, expected_data_type: 'Boolean', prepend_msg: :input_received, given_data_type: String),
                bad_request_error_pattern('private', :datatype_mismatch, expected_data_type: 'Boolean', prepend_msg: :input_received, given_data_type: String)])
  end

  def test_create_datatype_invalid
    params_hash = { notify_emails: 'x', attachments: 'x', body: true }
    post :create, construct_params({ id: ticket.display_id }, params_hash)
    match_json([bad_request_error_pattern('notify_emails', :datatype_mismatch, expected_data_type: Array, prepend_msg: :input_received, given_data_type: String),
                bad_request_error_pattern('attachments', :datatype_mismatch, expected_data_type: Array, prepend_msg: :input_received, given_data_type: String),
                bad_request_error_pattern('body', :datatype_mismatch, expected_data_type: String, prepend_msg: :input_received, given_data_type: 'Boolean')])
    assert_response 400
  end

  def test_create_email_format_invalid
    params_hash = { notify_emails: ['tyt@'], body: Faker::Lorem.paragraph }
    post :create, construct_params({ id: ticket.display_id }, params_hash)
    match_json([bad_request_error_pattern('notify_emails', :array_invalid_format, accepted: 'valid email address')])
    assert_response 400
  end

  def test_create_email_format_invalid_new_regex
    Account.stubs(:current).returns(Account.first || create_test_account)
    Account.any_instance.stubs(:new_email_regex_enabled?).returns(true)
    params_hash = { notify_emails: ['test.@test.com'], body: Faker::Lorem.paragraph }
    post :create, construct_params({ id: ticket.display_id }, params_hash)
    match_json([bad_request_error_pattern('notify_emails', :array_invalid_format, accepted: 'valid email address')])
    assert_response 400
  ensure
    Account.any_instance.unstub(:new_email_regex_enabled?)
    Account.unstub(:current)
  end

  def test_create_invalid_ticket_id
    params_hash = { body: 'test' }
    post :create, construct_params({ id: 789_789_789 }, params_hash)
    assert_response :missing
  end

  def test_create_invalid_model
    params_hash = { body: 'test', user_id: 789_789_789 }
    post :create, construct_params({ id: ticket.display_id }, params_hash)
    assert_response 400
    match_json([bad_request_error_pattern('user_id', :absent_in_db, resource: :contact, attribute: :user_id)])
  end

  def test_create_extra_params
    params_hash = { body: 'test', junk: 'test' }
    post :create, construct_params({ id: ticket.display_id }, params_hash)
    assert_response 400
    match_json([bad_request_error_pattern('junk', :invalid_field)])
  end

  def test_create_missing_params
    post :create, construct_params({ id: ticket.display_id }, {})
    assert_response 400
    match_json([bad_request_error_pattern('body', :datatype_mismatch, code: :missing_field, expected_data_type: String)])
  end

  def test_create_returns_location_header
    params_hash = create_note_params_hash
    post :create, construct_params({ id: ticket.display_id }, params_hash)
    assert_response 201
    match_json(v2_note_pattern(params_hash, Helpdesk::Note.last))
    match_json(v2_note_pattern({}, Helpdesk::Note.last))
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
    match_json(v2_note_pattern(params, Helpdesk::Note.last))
    match_json(v2_note_pattern({}, Helpdesk::Note.last))
    assert Helpdesk::Note.last.attachments.count == 2
  end

  def test_create_with_invalid_attachment_params_format
    params = create_note_params_hash.merge('attachments' => [1, 2])
    post :create, construct_params({ id: ticket.display_id }, params)
    assert_response 400
    match_json([bad_request_error_pattern('attachments', :array_datatype_mismatch, expected_data_type: 'valid file format')])
  end

  def test_attachment_invalid_size_create
    invalid_attachment_limit = @account.attachment_limit + 2
    Rack::Test::UploadedFile.any_instance.stubs(:size).returns(invalid_attachment_limit.megabytes)
    file = fixture_file_upload('/files/attachment.txt', 'plain/text', :binary)
    params = create_note_params_hash.merge('attachments' => [file])
    DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
    post :create, construct_params({ id: ticket.display_id }, params)
    DataTypeValidator.any_instance.unstub(:valid_type?)
    assert_response 400
    match_json([bad_request_error_pattern('attachments', :invalid_size, max_size: "#{@account.attachment_limit} MB", current_size: "#{invalid_attachment_limit} MB")])
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
    match_json([bad_request_error_pattern('notify_emails', :too_long, element_type: :values, max_count: "#{ApiTicketConstants::MAX_EMAIL_COUNT}", current_count: 51)])
  end

  def test_reply_with_invalid_cc_emails_count
    cc_emails = []
    50.times do
      cc_emails << Faker::Internet.email
    end
    params = reply_note_params_hash.merge(cc_emails: cc_emails, bcc_emails: cc_emails)
    post :reply, construct_params({ id: ticket.display_id }, params)
    assert_response 400
    match_json([bad_request_error_pattern('cc_emails', :too_long, element_type: :values, max_count: "#{ApiTicketConstants::MAX_EMAIL_COUNT}", current_count: 50),
                bad_request_error_pattern('bcc_emails', :too_long, element_type: :values, max_count: "#{ApiTicketConstants::MAX_EMAIL_COUNT}", current_count: 50)])
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
    match_json(v2_reply_note_pattern(params_hash, Helpdesk::Note.last))
    match_json(v2_reply_note_pattern({}, Helpdesk::Note.last))
  end

  def test_reply_without_kbase_email
    params_hash = reply_note_params_hash
    article_count = Solution::Article.count
    post :reply, construct_params({ id: ticket.display_id }, params_hash)
    assert_response 201
    match_json(v2_reply_note_pattern(params_hash, Helpdesk::Note.last))
    match_json(v2_reply_note_pattern({}, Helpdesk::Note.last))
    assert article_count == Solution::Article.count
  end

  def test_reply_with_cc_kbase_mail
    article_count = Solution::Article.count
    parent_ticket = ticket
    parent_ticket.update_column(:subject, 'More than 3 letters')
    params_hash = reply_note_params_hash.merge(cc_emails: [@account.kbase_email])
    post :reply, construct_params({ id: parent_ticket.display_id }, params_hash)
    assert_response 201
    match_json(v2_reply_note_pattern(params_hash.merge(cc_emails: nil), Helpdesk::Note.last))
    match_json(v2_reply_note_pattern({}, Helpdesk::Note.last))
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
    match_json(v2_reply_note_pattern(params_hash.merge(bcc_emails: nil), Helpdesk::Note.last))
    match_json(v2_reply_note_pattern({}, Helpdesk::Note.last))
    assert (article_count + 1) == Solution::Article.count
    assert Solution::Article.last.title == parent_ticket.subject
    assert Solution::Article.last.description == Helpdesk::Note.last.body_html
    refute Helpdesk::Note.last.bcc_emails.include?(@account.kbase_email)
  end

  def test_reply_with_cc_kbase_mail_without_privilege
    article_count = Solution::Article.count
    User.any_instance.stubs(:privilege?).with(:manage_tickets).returns(true)
    User.any_instance.stubs(:privilege?).with(:reply_ticket).returns(true)
    User.any_instance.stubs(:privilege?).with(:create_and_edit_article).returns(false).at_most_once
    params_hash = reply_note_params_hash.merge(cc_emails: [@account.kbase_email])
    post :reply, construct_params({ id: ticket.display_id }, params_hash)
    User.any_instance.unstub(:privilege?)
    assert_response 201
    match_json(v2_reply_note_pattern(params_hash.merge(cc_emails: nil), Helpdesk::Note.last))
    match_json(v2_reply_note_pattern({}, Helpdesk::Note.last))
    assert article_count == Solution::Article.count
  end

  def test_reply_with_bcc_kbase_mail_without_privilege
    article_count = Solution::Article.count
    User.any_instance.stubs(:privilege?).with(:manage_tickets).returns(true)
    User.any_instance.stubs(:privilege?).with(:reply_ticket).returns(true)
    User.any_instance.stubs(:privilege?).with(:create_and_edit_article).returns(false).at_most_once
    params_hash = reply_note_params_hash.merge(bcc_emails: [@account.kbase_email])
    post :reply, construct_params({ id: ticket.display_id }, params_hash)
    User.any_instance.unstub(:privilege?)
    assert_response 201
    match_json(v2_reply_note_pattern(params_hash.merge(bcc_emails: nil), Helpdesk::Note.last))
    match_json(v2_reply_note_pattern({}, Helpdesk::Note.last))
    assert article_count == Solution::Article.count
  end

  def test_reply_with_cc_kbase_mail_short_subject
    article_count = Solution::Article.count
    t = create_ticket(subject: 'ui')
    params_hash = reply_note_params_hash.merge(cc_emails: [@account.kbase_email])
    post :reply, construct_params({ id: t.display_id }, params_hash)
    assert_response 201
    match_json(v2_reply_note_pattern(params_hash.merge(cc_emails: nil), Helpdesk::Note.last))
    match_json(v2_reply_note_pattern({}, Helpdesk::Note.last))
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
    match_json(v2_reply_note_pattern(params_hash, Helpdesk::Note.last))
    match_json(v2_reply_note_pattern({}, Helpdesk::Note.last))
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
    match_json([bad_request_error_pattern('user_id', :datatype_mismatch, expected_data_type: 'Positive Integer', prepend_msg: :input_received, given_data_type: String)])
  end

  def test_reply_datatype_invalid
    params_hash = { cc_emails: 'x', attachments: 'x', bcc_emails: 'x', body: Faker::Lorem.paragraph }
    post :reply, construct_params({ id: ticket.display_id }, params_hash)
    assert_response 400
    match_json([bad_request_error_pattern('cc_emails', :datatype_mismatch, expected_data_type: Array, prepend_msg: :input_received, given_data_type: String),
                bad_request_error_pattern('attachments', :datatype_mismatch, expected_data_type: Array, prepend_msg: :input_received, given_data_type: String),
                bad_request_error_pattern('bcc_emails', :datatype_mismatch, expected_data_type: Array, prepend_msg: :input_received, given_data_type: String)])
  end

  def test_reply_email_format_invalid
    params_hash = { cc_emails: ['tyt@'], bcc_emails: ['hj#'], from_email: 'df@', body: Faker::Lorem.paragraph }
    post :reply, construct_params({ id: ticket.display_id }, params_hash)
    assert_response 400
    match_json([bad_request_error_pattern('cc_emails', :array_invalid_format, accepted: 'valid email address'),
                bad_request_error_pattern('bcc_emails', :array_invalid_format, accepted: 'valid email address'),
                bad_request_error_pattern('from_email', :invalid_format, accepted: 'valid email address')])
  end

  def test_reply_invalid_id
    params_hash = { body: 'test' }
    post :reply, construct_params({ id: '6786878' }, params_hash)
    assert_response :missing
  end

  def test_reply_invalid_model
    params_hash = { body: 'test', user_id: 789_789_789 }
    post :reply, construct_params({ id: ticket.display_id }, params_hash)
    assert_response 400
    match_json([bad_request_error_pattern('user_id', :absent_in_db, resource: :contact, attribute: :user_id)])
  end

  def test_reply_invalid_from_email
    params_hash = { body: 'test', from_email: Faker::Internet.email }
    post :reply, construct_params({ id: ticket.display_id }, params_hash)
    assert_response 400
    match_json([bad_request_error_pattern('from_email', :absent_in_db, resource: :"active email_config", attribute: :from_email)])
  end

  def test_reply_without_from_email_and_personalized_replies
    @account.features.personalized_email_replies.create
    @account.reload
    Account.current.reload
    params_hash = reply_note_params_hash
    params_hash.delete(:from_email)
    post :reply, construct_params({ id: ticket.display_id }, params_hash)
    assert_response 201
    latest_note = Helpdesk::Note.last

    assert_equal ticket.friendly_reply_email_personalize(@agent.name), latest_note.from_email
    match_json(v2_reply_note_pattern(params_hash, latest_note))
    match_json(v2_reply_note_pattern({}, latest_note))
  end

  def test_reply_without_from_email
    @account.features.personalized_email_replies.destroy
    @account.reload
    Account.current.reload
    params_hash = reply_note_params_hash
    params_hash.delete(:from_email)
    post :reply, construct_params({ id: ticket.display_id }, params_hash)
    assert_response 201
    latest_note = Helpdesk::Note.last
    assert_equal ticket.selected_reply_email, latest_note.from_email
    match_json(v2_reply_note_pattern(params_hash, latest_note))
    match_json(v2_reply_note_pattern({}, latest_note))
  end

  def test_reply_with_from_address_personalized_replies
    @account.features.personalized_email_replies.create
    @account.reload
    email_config = create_email_config
    params_hash = reply_note_params_hash.merge(from_email: email_config.reply_email)
    post :reply, construct_params({ id: ticket.display_id }, params_hash)
    assert_response 201
    latest_note = Helpdesk::Note.last
    assert_equal email_config.friendly_email_personalize(@agent.name), latest_note.from_email
    match_json(v2_reply_note_pattern(params_hash, latest_note))
    match_json(v2_reply_note_pattern({}, latest_note))
  end

  def test_reply_with_from_address_without_personalized_replies
    @account.features.personalized_email_replies.destroy
    @account.reload
    email_config = create_email_config
    params_hash = reply_note_params_hash.merge(from_email: email_config.reply_email)
    post :reply, construct_params({ id: ticket.display_id }, params_hash)
    assert_response 201
    latest_note = Helpdesk::Note.last
    assert_equal email_config.friendly_email, latest_note.from_email
    match_json(v2_reply_note_pattern(params_hash, latest_note))
    match_json(v2_reply_note_pattern({}, latest_note))
  end

  def test_reply_new_email_config
    email_config = create_email_config
    params_hash = reply_note_params_hash.merge(from_email: email_config.reply_email)
    post :reply, construct_params({ id: ticket.display_id }, params_hash)
    assert_response 201
    note = Helpdesk::Note.last
    assert_equal email_config.id, note.email_config_id
    match_json(v2_reply_note_pattern(params_hash, note))
    match_json(v2_reply_note_pattern({}, note))
  end

  def test_reply_with_only_body
    params_hash = {body: Faker::Lorem.paragraph}
    post :reply, construct_params({ id: ticket.display_id }, params_hash)
    assert_response 201
    note = Helpdesk::Note.last
    match_json(v2_reply_note_pattern(params_hash, note))
    match_json(v2_reply_note_pattern({}, note))
  end

  def test_reply_inactive_email_config
    email_config = create_email_config
    email_config.active = false
    email_config.save
    params_hash = reply_note_params_hash.merge(from_email: email_config.reply_email)
    post :reply, construct_params({ id: ticket.display_id }, params_hash)
    assert_response 400
    match_json([bad_request_error_pattern('from_email', :absent_in_db, resource: :"active email_config", attribute: :from_email)])
  end

  def test_reply_extra_params
    params_hash = { body_html: 'test', junk: 'test' }
    post :reply, construct_params({ id: ticket.display_id }, params_hash)
    assert_response 400
    match_json([bad_request_error_pattern('junk', :invalid_field), bad_request_error_pattern('body_html', :invalid_field)])
  end

  def test_reply_returns_location_header
    params_hash = reply_note_params_hash
    post :reply, construct_params({ id: ticket.display_id }, params_hash)
    assert_response 201
    match_json(v2_reply_note_pattern(params_hash, Helpdesk::Note.last))
    match_json(v2_reply_note_pattern({}, Helpdesk::Note.last))
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
    match_json(v2_reply_note_pattern(params, Helpdesk::Note.last))
    match_json(v2_reply_note_pattern({}, Helpdesk::Note.last))
    assert Helpdesk::Note.last.attachments.count == 2
  end

  def test_attachments_invalid_size_reply
    invalid_attachment_limit = @account.attachment_limit + 2
    Rack::Test::UploadedFile.any_instance.stubs(:size).returns(invalid_attachment_limit.megabytes)
    file = fixture_file_upload('/files/attachment.txt', 'plain/text', :binary)
    params = reply_note_params_hash.merge('attachments' => [file])
    DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
    post :reply, construct_params({ id: ticket.display_id }, params)
    DataTypeValidator.any_instance.unstub(:valid_type?)
    assert_response 400
    match_json([bad_request_error_pattern('attachments', :invalid_size, max_size: "#{@account.attachment_limit} MB", current_size: "#{invalid_attachment_limit} MB")])
  end

  def test_reply_with_invalid_attachment_params_format
    params = reply_note_params_hash.merge('attachments' => [1, 2])
    post :reply, construct_params({ id: ticket.display_id }, params)
    assert_response 400
    match_json([bad_request_error_pattern('attachments', :array_datatype_mismatch, expected_data_type: 'valid file format')])
  end

  def test_reply_without_privilege
    User.any_instance.stubs(:privilege?).with(:reply_ticket).returns(false).at_most_once
    params_hash = reply_note_params_hash
    post :reply, construct_params({ id: ticket.display_id }, params_hash)
    User.any_instance.unstub(:privilege?)
    assert_response 403
    match_json(request_error_pattern(:access_denied))
  end

  def test_facebook_reply_post_success
    @account.launch(:facebook_public_api)
    ticket = create_ticket_from_fb_post
    params_hash = { body: Faker::Lorem.paragraph }
    post :reply, construct_params({ id: ticket.display_id }, params_hash)
    assert_response 201
    match_json(v2_reply_note_pattern(params_hash, Helpdesk::Note.last))
    match_json(v2_reply_note_pattern({}, Helpdesk::Note.last))
  ensure
    @account.rollback(:facebook_public_api)
    ticket.destroy
  end

  def test_facebook_reply_post_without_params
    @account.launch(:facebook_public_api)
    ticket = create_ticket_from_fb_post
    post :reply, construct_params({ id: ticket.display_id }, {})
    assert_response 400
    match_json([bad_request_error_pattern('body', :missing_field, code: :missing_field)])
  ensure
    @account.rollback(:facebook_public_api)
    ticket.destroy
  end

  def test_facebook_reply_post_with_params_empty
    @account.launch(:facebook_public_api)
    ticket = create_ticket_from_fb_post
    params_hash = { body: '', attachments: [] }
    post :reply, construct_params({ id: ticket.display_id }, params_hash)
    assert_response 400
    response_params = params_hash.except(:attachments)
    match_json([bad_request_error_pattern('body', :missing_field, code: :missing_field)])
  ensure
    @account.rollback(:facebook_public_api)
    ticket.destroy
  end

  def test_facebook_reply_post_success_with_user_id_valid
    @account.launch(:facebook_public_api)
    ticket = create_ticket_from_fb_post
    params_hash = { body: Faker::Lorem.paragraph, user_id: @agent.id }
    post :reply, construct_params({ id: ticket.display_id }, params_hash)
    assert_response 201
    match_json(v2_reply_note_pattern(params_hash, Helpdesk::Note.last))
    match_json(v2_reply_note_pattern({}, Helpdesk::Note.last))
  ensure
    @account.rollback(:facebook_public_api)
    ticket.destroy
  end

  def test_facebook_reply_post_with_user_id_invalid_privilege
    @account.launch(:facebook_public_api)
    ticket = create_ticket_from_fb_post
    sample_user = other_user
    params_hash = { body: Faker::Lorem.paragraph, user_id: sample_user.id }
    controller.class.any_instance.stubs(:is_allowed_to_assume?).returns(false)
    post :reply, construct_params({ id: ticket.display_id }, params_hash)
    controller.class.any_instance.unstub(:is_allowed_to_assume?)
    assert_response 403
    match_json(request_error_pattern('invalid_user', id: sample_user.id, name: sample_user.name))
  ensure
    @account.rollback(:facebook_public_api)
    ticket.destroy
  end

  def test_facebook_reply_post_with_empty_user_id
    @account.launch(:facebook_public_api)
    ticket = create_ticket_from_fb_post
    params_hash = { body: Faker::Lorem.paragraph, user_id: '' }
    post :reply, construct_params({ id: ticket.display_id }, params_hash)
    assert_response 400
    match_json([bad_request_error_pattern('user_id', :datatype_mismatch, expected_data_type: 'Positive Integer', prepend_msg: :input_received, given_data_type: String)])
  ensure
    @account.rollback(:facebook_public_api)
    ticket.destroy
  end

  def test_facebook_reply_post_with_invalid_parent_note_id
    @account.launch(:facebook_public_api)
    ticket = create_ticket_from_fb_post
    invalid_id = (Helpdesk::Note.last.try(:id) || 0) + 10
    params_hash = { body: Faker::Lorem.paragraph, parent_note_id: invalid_id }
    post :reply, construct_params({ id: ticket.display_id }, params_hash)
    assert_response 400
    match_json([bad_request_error_pattern('parent_note_id', 'is invalid')])
  ensure
    @account.rollback(:facebook_public_api)
    ticket.destroy
  end

  def test_facebook_reply_post_with_empty_parent_note_id
    @account.launch(:facebook_public_api)
    ticket = create_ticket_from_fb_post
    params_hash = { body: Faker::Lorem.paragraph, parent_note_id: '' }
    post :reply, construct_params({ id: ticket.display_id }, params_hash)
    assert_response 400
    match_json([bad_request_error_pattern('parent_note_id', :datatype_mismatch, expected_data_type: 'Positive Integer', prepend_msg: :input_received, given_data_type: String)])
  ensure
    @account.rollback(:facebook_public_api)
    ticket.destroy
  end

  def test_facebook_reply_post_success_with_parent_note
    @account.launch(:facebook_public_api)
    ticket = create_ticket_from_fb_post(true)
    put_comment_id = "#{(Time.now.ago(2.minutes).utc.to_f * 100_000).to_i}_#{(Time.now.ago(6.minutes).utc.to_f * 100_000).to_i}"
    sample_put_comment = { 'id' => put_comment_id }
    fb_comment_note = ticket.notes.where(source: Account.current.helpdesk_sources.note_source_keys_by_token['facebook']).first
    Koala::Facebook::API.any_instance.stubs(:put_comment).returns(sample_put_comment)
    params_hash = { body: Faker::Lorem.paragraph, parent_note_id: fb_comment_note.id }
    post :reply, construct_params({ id: ticket.display_id }, params_hash)
    Koala::Facebook::API.any_instance.unstub(:put_comment)
    assert_response 201
    match_json(v2_reply_note_pattern(params_hash, Helpdesk::Note.last))
    match_json(v2_reply_note_pattern({}, Helpdesk::Note.last))
  ensure
    @account.rollback(:facebook_public_api)
    ticket.destroy
  end

  def test_facebook_reply_post_success_with_attachment_only
    @account.launch(:facebook_public_api)
    ticket = create_ticket_from_fb_post
    file = fixture_file_upload('files/image33kb.jpg', 'image/jpg')
    params_hash = { attachments: [file] }
    DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
    post :reply, construct_params({ id: ticket.display_id }, params_hash)
    DataTypeValidator.any_instance.unstub(:valid_type?)
    assert_response 201
    response_params = params_hash.except(:attachments)
    match_json(v2_reply_note_pattern(params_hash, Helpdesk::Note.last))
    match_json(v2_reply_note_pattern({}, Helpdesk::Note.last))
    assert Helpdesk::Note.last.attachments.count == 1
  ensure
    @account.rollback(:facebook_public_api)
    ticket.destroy
  end

  def test_facebook_reply_post_success_with_body_attachment
    @account.launch(:facebook_public_api)
    ticket = create_ticket_from_fb_post
    file = fixture_file_upload('files/image33kb.jpg', 'image/jpg')
    params_hash = { body: Faker::Lorem.paragraph, attachments: [file] }
    DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
    post :reply, construct_params({ id: ticket.display_id }, params_hash)
    DataTypeValidator.any_instance.unstub(:valid_type?)
    assert_response 201
    response_params = params_hash.except(:attachments)
    match_json(v2_reply_note_pattern(params_hash, Helpdesk::Note.last))
    match_json(v2_reply_note_pattern({}, Helpdesk::Note.last))
    assert Helpdesk::Note.last.attachments.count == 1
  ensure
    @account.rollback(:facebook_public_api)
    ticket.destroy
  end

  def test_facebook_reply_post_with_more_than_one_attachment
    @account.launch(:facebook_public_api)
    ticket = create_ticket_from_fb_post
    file = fixture_file_upload('files/image6mb.jpg', 'image/jpg')
    file2 = fixture_file_upload('files/image33kb.jpg', 'image/jpg')
    params_hash = { body: Faker::Lorem.paragraph, attachments: [file, file2] }
    DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
    post :reply, construct_params({ id: ticket.display_id }, params_hash)
    DataTypeValidator.any_instance.unstub(:valid_type?)
    assert_response 400
    response_params = params_hash.except(:attachments)
    match_json([bad_request_error_pattern('attachments', :too_long, current_count: 2, element_type: :characters, max_count: 1)])
  ensure
    @account.rollback(:facebook_public_api)
    ticket.destroy
  end

  def test_facebook_reply_post_with_invalid_attachment_params_format
    @account.launch(:facebook_public_api)
    ticket = create_ticket_from_fb_post
    params_hash = { body: Faker::Lorem.paragraph, attachments: [1] }
    post :reply, construct_params({ id: ticket.display_id }, params_hash)
    assert_response 400
    match_json([bad_request_error_pattern('attachments', :array_datatype_mismatch, expected_data_type: 'valid file format')])
  ensure
    @account.rollback(:facebook_public_api)
    ticket.destroy
  end

  def test_facebook_reply_post_with_invalid_attachment_size_create
    @account.launch(:facebook_public_api)
    ticket = create_ticket_from_fb_post
    invalid_attachment_limit = @account.attachment_limit + 2
    Rack::Test::UploadedFile.any_instance.stubs(:size).returns(invalid_attachment_limit.megabytes)
    file = fixture_file_upload('files/image33kb.jpg', 'image/jpg')
    params_hash = { body: Faker::Lorem.paragraph, attachments: [file] }
    DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
    post :reply, construct_params({ id: ticket.display_id }, params_hash)
    DataTypeValidator.any_instance.unstub(:valid_type?)
    assert_response 400
    response_params = params_hash.except(:attachments)
    match_json([bad_request_error_pattern('attachments', :invalid_size, max_size: "#{@account.attachment_limit} MB", current_size: "#{invalid_attachment_limit} MB")])
  ensure
    @account.launch(:facebook_public_api)
    ticket.destroy
  end

  def test_facebook_reply_with_fb_page_reauth_required_error
    @account.launch(:facebook_public_api)
    ticket = create_ticket_from_fb_post(true)
    fb_page = ticket.fb_post.facebook_page
    fb_page.reauth_required = true
    fb_page.save
    fb_comment_note = ticket.notes.where(source: Account.current.helpdesk_sources.note_source_keys_by_token['facebook']).first
    put_comment_id = "#{(Time.now.ago(2.minutes).utc.to_f * 100_000).to_i}_#{(Time.now.ago(6.minutes).utc.to_f * 100_000).to_i}"
    sample_put_comment = { 'id' => put_comment_id }
    Koala::Facebook::API.any_instance.stubs(:put_comment).returns(sample_put_comment)
    params_hash = { body: Faker::Lorem.paragraph }
    post :reply, construct_params({ id: ticket.display_id }, params_hash)
    Koala::Facebook::API.any_instance.unstub(:put_comment)
    assert_response 400
    match_json([bad_request_error_pattern('fb_page_id', :reauthorization_required, app_name: 'Facebook')])
  ensure
    fb_page.reauth_required = false
    fb_page.save
    @account.rollback(:facebook_public_api)
    ticket.destroy
  end

  def test_facebook_reply_without_fb_page
    @account.launch(:facebook_public_api)
    Social::FacebookPage.any_instance.stubs(:gateway_facebook_page_mapping_details).returns(nil)
    ticket = create_ticket_from_fb_post(true, true)
    fb_page = ticket.fb_post.facebook_page
    fb_page.destroy
    params_hash = { body: Faker::Lorem.paragraph }
    post :reply, construct_params({ id: ticket.display_id }, params_hash)
    assert_response 400
    match_json([bad_request_error_pattern('fb_page_id', :invalid_facebook_id)])
  ensure
    @account.rollback(:facebook_public_api)
    ticket.destroy
  end

  def test_facebook_reply_dm_success
    @account.launch(:facebook_public_api)
    ticket = create_ticket_from_fb_direct_message
    sample_reply_dm = { 'id' => Time.now.utc.to_i + 5 }
    Koala::Facebook::API.any_instance.stubs(:put_object).returns(sample_reply_dm)
    params_hash = { body: Faker::Lorem.paragraph }
    post :reply, construct_params({ id: ticket.display_id }, params_hash)
    Koala::Facebook::API.any_instance.unstub(:put_object)
    assert_response 201
    match_json(v2_reply_note_pattern(params_hash, Helpdesk::Note.last))
    match_json(v2_reply_note_pattern({}, Helpdesk::Note.last))
  ensure
    @account.rollback(:facebook_public_api)
    ticket.destroy
  end

  def test_facebook_reply_dm_success_with_attachment
    @account.launch(:facebook_public_api)
    file = fixture_file_upload('files/image33kb.jpg', 'image/jpg')
    params_hash = { attachments: [file] }
    ticket = create_ticket_from_fb_direct_message
    sample_reply_dm = { 'id' => Time.now.utc.to_i + 5 }
    Koala::Facebook::API.any_instance.stubs(:put_object).returns(sample_reply_dm)
    DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
    post :reply, construct_params({ id: ticket.display_id }, params_hash)
    DataTypeValidator.any_instance.unstub(:valid_type?)
    Koala::Facebook::API.any_instance.unstub(:put_object)
    assert_response 201
    response_params = params_hash.except(:attachments)
    match_json(v2_reply_note_pattern(params_hash, Helpdesk::Note.last))
    match_json(v2_reply_note_pattern({}, Helpdesk::Note.last))
  ensure
    @account.rollback(:facebook_public_api)
    ticket.destroy
  end

  def test_facebook_reply_dm_failure_with_body_and_attachment
    @account.launch(:facebook_public_api)
    file = fixture_file_upload('files/image33kb.jpg', 'image/jpg')
    params_hash = { body: Faker::Lorem.paragraph, attachments: [file] }
    ticket = create_ticket_from_fb_direct_message
    sample_reply_dm = { 'id' => Time.now.utc.to_i + 5 }
    Koala::Facebook::API.any_instance.stubs(:put_object).returns(sample_reply_dm)
    DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
    post :reply, construct_params({ id: ticket.display_id }, params_hash)
    DataTypeValidator.any_instance.unstub(:valid_type?)
    Koala::Facebook::API.any_instance.unstub(:put_object)
    assert_response 400
    response_params = params_hash.except(:attachments)
    match_json([bad_request_error_pattern('attachments', :can_have_only_one_field, list: 'body, attachments')])
  ensure
    @account.rollback(:facebook_public_api)
    ticket.destroy
  end

  def test_create_public_note_with_fb_api_feature_lauched
    @account.launch(:facebook_public_api)
    Social::FacebookPage.any_instance.stubs(:gateway_facebook_page_mapping_details).returns(nil)
    ticket = create_ticket_from_fb_post(true, true)
    params_hash = create_note_params_hash.merge(private: false)
    post :create, construct_params({ id: ticket.display_id }, params_hash)
    assert_response 201
    match_json(v2_note_pattern(params_hash, Helpdesk::Note.last))
    match_json(v2_note_pattern({}, Helpdesk::Note.last))
  ensure
    @account.rollback(:facebook_public_api)
  end

  def test_create_private_note_with_fb_api_feature_launched
    @account.launch(:facebook_public_api)
    Social::FacebookPage.any_instance.stubs(:gateway_facebook_page_mapping_details).returns(nil)
    ticket = create_ticket_from_fb_post(true, true)
    params_hash = create_note_params_hash.merge(private: true)
    post :create, construct_params({ id: ticket.display_id }, params_hash)
    assert_response 201
    match_json(v2_note_pattern(params_hash, Helpdesk::Note.last))
    match_json(v2_note_pattern({}, Helpdesk::Note.last))
  ensure
    @account.rollback(:facebook_public_api)
  end

  def test_tweet_reply_without_params
    @account.launch(:twitter_public_api)
    ticket = create_twitter_ticket
    post :reply, construct_params({ id: ticket.display_id }, {})
    assert_response 400
    match_json([bad_request_error_pattern('body', :datatype_mismatch, code: :missing_field, expected_data_type: String)])
  ensure
    @account.rollback(:twitter_public_api)
    ticket.destroy
  end

  def test_tweet_reply_with_invalid_twitter_params_type
    @account.launch(:twitter_public_api)
    ticket = create_twitter_ticket
    params_hash = {
      body: Faker::Lorem.sentence[0..130],
      twitter: 'dm'
    }
    post :reply, construct_params({ id: ticket.display_id }, params_hash)
    assert_response 400
  ensure
    @account.rollback(:twitter_public_api)
    ticket.destroy
  end

  def test_tweet_reply_with_invalid_twitter_params
    @account.launch(:twitter_public_api)
    ticket = create_twitter_ticket
    params_hash = {
      body: Faker::Lorem.sentence[0..130],
      twitter: { tweet_type: 'dm', twitter_handle_id: @twitter_handle.twitter_user_id, tweet_id: 9 }
    }
    post :reply, construct_params({ id: ticket.display_id }, params_hash)
    assert_response 400
  ensure
    @account.rollback(:twitter_public_api)
    ticket.destroy
  end

  def test_tweet_reply_with_invalid_tweet_type_params
    @account.launch(:twitter_public_api)
    ticket = create_twitter_ticket
    params_hash = {
      body: Faker::Lorem.sentence[0..130],
      twitter: { tweet_type: 'post', twitter_handle_id: @twitter_handle.twitter_user_id }
    }
    post :reply, construct_params({ id: ticket.display_id }, params_hash)
    assert_response 400
  ensure
    @account.rollback(:twitter_public_api)
    ticket.destroy
  end

  def test_tweet_reply_with_invalid_twitter_handle_id_params
    @account.launch(:twitter_public_api)
    ticket = create_twitter_ticket
    params_hash = {
      body: Faker::Lorem.sentence[0..130],
      twitter: { twitter_handle_id: 'post' }
    }
    post :reply, construct_params({ id: ticket.display_id }, params_hash)
    assert_response 400
  ensure
    @account.rollback(:twitter_public_api)
    ticket.destroy
  end

  def test_tweet_reply_with_invalid_body
    @account.launch(:twitter_public_api)
    ticket = create_twitter_ticket
    params_hash = { body: 2 }
    post :reply, construct_params({ id: ticket.display_id }, params_hash)
    assert_response 400
    match_json([bad_request_error_pattern('body', :datatype_mismatch, expected_data_type: String, prepend_msg: :input_received, given_data_type: 'Integer')])
  ensure
    @account.rollback(:twitter_public_api)
    ticket.destroy
  end

  def test_tweet_reply_with_invalid_body_length
    @account.launch(:twitter_public_api)
    ticket = create_twitter_ticket
    params_hash = {
      body: Faker::Lorem.characters(1000),
      twitter: { tweet_type: 'mention' }
    }
    post :reply, construct_params({ id: ticket.display_id }, params_hash)
    assert_response 400
  ensure
    @account.rollback(:twitter_public_api)
    ticket.destroy
  end

  def test_twitter_reply_to_tweet_ticket
    Sidekiq::Testing.inline! do
      with_twitter_update_stubbed do
        ticket = create_twitter_ticket
        @account.launch(:twitter_public_api)
        params_hash = {
          body: Faker::Lorem.sentence[0..130],
          twitter: { tweet_type: 'dm', twitter_handle_id: @twitter_handle.twitter_user_id }
        }
        post :reply, construct_params({ id: ticket.display_id }, params_hash)
        assert_response 201
        latest_note = Helpdesk::Note.last
        match_json(v2_reply_note_pattern(params_hash, latest_note))
        match_json(v2_reply_note_pattern({}, latest_note))
        @account.rollback(:twitter_public_api)
        ticket.destroy
      end
    end
  end

  def test_twitter_reply_to_tweet_ticket_with_attachments
    @account.launch(:twitter_public_api)
    file = fixture_file_upload('files/image4kb.png', 'image/png')
    ticket = create_twitter_ticket
    params_hash = {
      body: Faker::Lorem.sentence[0..130],
      twitter: { tweet_type: 'mention', twitter_handle_id: @twitter_handle.twitter_user_id },
      attachments: [file]
    }
    DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
    Sidekiq::Testing.inline! do
      with_twitter_update_stubbed do
        post :reply, construct_params({ id: ticket.display_id }, params_hash)
        DataTypeValidator.any_instance.unstub(:valid_type?)
        assert_response 201
        response_params = params_hash.except(:attachments)
        match_json(v2_reply_note_pattern(params_hash, Helpdesk::Note.last))
        match_json(v2_reply_note_pattern({}, Helpdesk::Note.last))
        assert Helpdesk::Note.last.attachments.count == 1
      end
    end
    ticket.destroy
  ensure
    @account.rollback(:twitter_public_api)
  end

  def test_twitter_reply_with_invalid_attachments_count
    @account.launch(:twitter_public_api)
    file = fixture_file_upload('files/image4kb.png', 'image/png')
    file1 = fixture_file_upload('files/image4kb.png', 'image/png')
    file2 = fixture_file_upload('files/image4kb.png', 'image/png')
    file3 = fixture_file_upload('files/image4kb.png', 'image/png')
    file4 = fixture_file_upload('files/image4kb.png', 'image/png')
    ticket = create_twitter_ticket
    params_hash = {
      body: Faker::Lorem.sentence[0..130],
      twitter: { tweet_type: 'mention', twitter_handle_id: @twitter_handle.twitter_user_id },
      attachments: [file, file1, file2, file3, file4]
    }
    DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
    post :reply, construct_params({ id: ticket.display_id }, params_hash)
    DataTypeValidator.any_instance.unstub(:valid_type?)
    assert_response 400
    match_json([bad_request_error_pattern('attachments', :twitter_attachment_file_limit, code: :invalid_value, maxLimit: 4, fileType: 'image')])
    ticket.destroy
  ensure
    @account.rollback(:twitter_public_api)
  end

  def test_twitter_reply_with_invalid_attachments_type
    @account.launch(:twitter_public_api)
    file = fixture_file_upload('files/image4kb.png', 'image/png')
    file1 = fixture_file_upload('files/attachment.txt', 'text/plain')
    ticket = create_twitter_ticket
    params_hash = {
      body: Faker::Lorem.sentence[0..130],
      twitter: { tweet_type: 'mention', twitter_handle_id: @twitter_handle.twitter_user_id },
      attachments: [file, file1]
    }
    DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
    post :reply, construct_params({ id: ticket.display_id }, params_hash)
    DataTypeValidator.any_instance.unstub(:valid_type?)
    assert_response 400
    match_json([bad_request_error_pattern('attachments', 'twitter_attachment_file_invalid')])
    ticket.destroy
  ensure
    @account.rollback(:twitter_public_api)
  end

  def test_tweet_reply_with_invalid_handle
    @account.launch(:twitter_public_api)
    ticket = create_twitter_ticket
    params_hash = {
      body: Faker::Lorem.sentence[0..130],
      twitter: { tweet_type: 'dm', twitter_handle_id: 123 }
    }
    post :reply, construct_params({ id: ticket.display_id }, params_hash)
    assert_response 400
    match_json([bad_request_error_pattern('twitter_handle_id', 'is invalid')])
  ensure
    @account.rollback(:twitter_public_api)
    ticket.destroy
  end

  def test_tweet_reply_with_requth
    @account.launch(:twitter_public_api)
    ticket = create_twitter_ticket
    Social::TwitterHandle.any_instance.stubs(:reauth_required?).returns(true)
    params_hash = {
      body: Faker::Lorem.sentence[0..130],
      twitter: { tweet_type: 'dm', twitter_handle_id: get_twitter_handle.twitter_user_id }
    }
    post :reply, construct_params({ id: ticket.display_id }, params_hash)
    assert_response 400
    match_json([bad_request_error_pattern('twitter_handle_id', 'requires re-authorization')])
    Social::TwitterHandle.any_instance.stubs(:reauth_required?).returns(false)
  ensure
    @account.rollback(:twitter_public_api)
    ticket.destroy
  end

  def test_tweet_reply_with_app_blocked
    @account.launch(:twitter_public_api)
    set_others_redis_key(TWITTER_APP_BLOCKED, true, 5)
    twitter_handle = get_twitter_handle
    ticket = create_twitter_ticket(twitter_handle: twitter_handle)
    params_hash = {
      body: Faker::Lorem.sentence[0..130],
      twitter: { tweet_type: 'dm', twitter_handle_id: twitter_handle.twitter_user_id }
    }
    post :reply, construct_params({ id: ticket.display_id }, params_hash)
    assert_response 400
    match_json(validation_error_pattern(bad_request_error_pattern('twitter', :twitter_write_access_blocked)))
  ensure
    @account.rollback(:twitter_public_api)
    ticket.destroy
    remove_others_redis_key TWITTER_APP_BLOCKED
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
    match_json(v2_update_note_pattern(params, Helpdesk::Note.find(n.id)))
    match_json(v2_update_note_pattern({}, Helpdesk::Note.find(n.id)))
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
    file = fixture_file_upload('files/attachment.txt', 'plain/text', :binary)
    file2 = fixture_file_upload('files/image33kb.jpg', 'image/jpg')
    params = update_note_params_hash.merge('attachments' => [file, file2])
    n =  create_note(user_id: @agent.id, ticket_id: ticket.id, source: 2)
    DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
    n.instance_variable_set("@note_body_content", nil)
    put :update, construct_params({ id: n.id }, params)
    DataTypeValidator.any_instance.unstub(:valid_type?)
    assert_response 200
    response_params = params.except(:attachments)
    match_json(v2_update_note_pattern(params, n.reload))
    match_json(v2_update_note_pattern({}, n.reload))
    assert_equal n.attachments.count, 2
  end

  def test_attachments_invalid_size_update
    n = note
    attachment = create_attachment(attachable_type: 'UserDraft', attachable_id: @agent.id)
    invalid_attachment_limit = @account.attachment_limit + 2
    Helpdesk::Attachment.any_instance.stubs(:content_file_size).returns(invalid_attachment_limit.megabytes)
    Helpdesk::Attachment.any_instance.stubs(:size).returns(invalid_attachment_limit.megabytes)
    params = update_note_params_hash.merge('attachments' => [attachment])
    DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
    Helpdesk::Note.any_instance.stubs(:attachments).returns([attachment])
    put :update, construct_params({ id: n.id }, params)
    DataTypeValidator.any_instance.unstub(:valid_type?)
    Helpdesk::Attachment.any_instance.unstub(:content_file_size)
    Helpdesk::Attachment.any_instance.unstub(:size)
    Helpdesk::Note.any_instance.unstub(:attachments)
    assert_response 400
    match_json([bad_request_error_pattern('attachments', :invalid_size, max_size: "#{@account.attachment_limit} MB", current_size: "#{2 * invalid_attachment_limit} MB")])
  end

  def test_update_with_invalid_attachment_params_format
    params = update_note_params_hash.merge('attachments' => [1, 2])
    put :update, construct_params({ id: note.id }, params)
    assert_response 400
    match_json([bad_request_error_pattern('attachments', :array_datatype_mismatch, expected_data_type: 'valid file format')])
  end

  def test_update_without_privilege
    User.any_instance.stubs(:privilege?).with(:edit_note).returns(false).at_most_once
    User.any_instance.stubs(:owns_object?).returns(false).at_most_once
    params = update_note_params_hash
    n = note
    put :update, construct_params({ id: n.id }, params)
    User.any_instance.unstub(:privilege?)
    User.any_instance.unstub(:owns_object?) 
    assert_response 403
    match_json(request_error_pattern(:access_denied))
  end

  #def test_update_with_owns_object_privilege
  #  User.any_instance.stubs(:privilege?).with(:manage_tickets).returns(true)
  #  User.any_instance.stubs(:privilege?).with(:edit_note).returns(false).at_most_once
  #  params = update_note_params_hash
  #  n = note
  #  put :update, construct_params({ id: n.id }, params)
  #  User.any_instance.unstub(:privilege?)
  #  assert_response 200
  #  match_json(v2_update_note_pattern(params, n.reload))
  #  match_json(v2_update_note_pattern({}, n.reload))
  #end

  def test_update_reply
    n = create_note(user_id: @agent.id, ticket_id: ticket.id, source: 0)
    params = update_note_params_hash
    put :update, construct_params({ id: n.id }, params)
    assert_response 405
    response.body.must_match_json_expression(base_error_pattern('method_not_allowed', methods: 'DELETE', fired_method: 'PUT'))
    assert_equal 'DELETE', response.headers['Allow']
  end

  def test_update_not_note_or_reply
    n = create_note(user_id: @agent.id, ticket_id: ticket.id, source: 1)
    params = update_note_params_hash
    put :update, construct_params({ id: n.id }, params)
    assert_response 405
    response.body.must_match_json_expression(base_error_pattern('method_not_allowed', methods: 'DELETE', fired_method: 'PUT'))
    assert_equal 'DELETE', response.headers['Allow']
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

  def test_update_private_note
    user = add_new_user(@account)
    n = create_note(user_id: @agent.id, ticket_id: ticket.id, source: 2, private: true)
    params = update_note_params_hash
    put :update, construct_params({ id: n.id }, params)
    assert_response 200
    latest_note = Helpdesk::Note.find(n.id)
    assert latest_note.private
    match_json(v2_update_note_pattern(params, latest_note))
    match_json(v2_update_note_pattern({}, latest_note))
  end

  def test_private_note_has_no_quoted_text
    user = add_new_user(@account)
    note = create_note(user_id: @agent.id, ticket_id: ticket.id, source: 2, private: true)
    params = update_note_params_hash
    put :update, construct_params({ id: note.id }, params)
    assert_response 200
    assert_equal JSON.parse(response.body)['has_quoted_text'], nil
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
    @controller.stubs(:decorate_objects).returns([])
    @controller.stubs(:render).returns(true)
    get :ticket_conversations, controller_params(id: parent_ticket.display_id)
    assert controller.instance_variable_get(:@items).all? { |x| x.association(:attachments).loaded? }
    assert controller.instance_variable_get(:@items).all? { |x| x.association(:schema_less_note).loaded? }
    assert controller.instance_variable_get(:@items).all? { |x| x.association(:note_body).loaded? }
  ensure
    @controller.unstub(:decorate_objects)
    @controller.unstub(:render)
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
      create_note(user_id: @agent.id, ticket_id: parent_ticket.id, source: 2)
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

  def test_ticket_conversation_with_twitter
    @twitter_handle = get_twitter_handle
    @default_stream = @twitter_handle.default_stream
    ticket = create_twitter_ticket
    with_twitter_update_stubbed do
      create_twitter_note(ticket)
    end
    get :ticket_conversations, controller_params(id: ticket.display_id)
    result_pattern = []
    ticket.notes.visible.exclude_source('meta').each do |n|
      result_pattern << index_note_pattern(n)
    end
    assert_response 200
    match_json(result_pattern)
  end

  def test_reply_with_nil_array_fields
    params_hash = reply_note_params_hash.merge(cc_emails: [], bcc_emails: [], attachments: [])
    post :reply, construct_params({ id: ticket.display_id }, params_hash)
    match_json(v2_reply_note_pattern(params_hash, Helpdesk::Note.last))
    match_json(v2_reply_note_pattern({}, Helpdesk::Note.last))
    assert_response 201
  end

  def test_non_agent_email_id_in_note_creation
    non_agent_emails = [Faker::Internet.email, Faker::Internet.email]
    notify_emails = non_agent_emails | [@agent.email]
    params_hash = create_note_params_hash.merge(notify_emails: notify_emails)
    post :create, construct_params({ id: ticket.display_id }, params_hash)
    match_json([bad_request_error_pattern('notify_emails', :invalid_agent_emails, invalid_emails: "#{non_agent_emails.join(', ')}")])
    assert_response 400
  end

  def test_agent_email_id_case_insensitive_in_note_creation
    agent_emails = [@agent.email.slice(0, 1).capitalize + @agent.email.slice(1..-1)]
    params_hash = create_note_params_hash.merge(notify_emails: agent_emails)
    post :create, construct_params({ id: ticket.display_id }, params_hash)
    assert_response 201
    notify_emails = JSON.parse(@response.body)['to_emails']
    assert_equal notify_emails, agent_emails.map(&:downcase)
  end

  def test_create_datatype_nil_array_fields
    params_hash = { notify_emails: [], attachments: [], body: Faker::Lorem.paragraph }
    post :create, construct_params({ id: ticket.display_id }, params_hash)
    match_json(v2_note_pattern({}, Helpdesk::Note.last))
    assert_response 201
  end

  def test_email_notification_without_notifying_emails
    current_account = Account.current
    assigned_agent = add_test_agent(@account)
    ticket = create_ticket(requester_id: assigned_agent.id)
    params_hash = create_note_params_hash.merge(private: true, notify_emails: [])
    count_of_delayed_jobs_before = Delayed::Job.count
    post :create, construct_params({ version: 'private', id: ticket.display_id, user_id: assigned_agent.id }, params_hash)
    assert_equal count_of_delayed_jobs_before + 1, Delayed::Job.count
  end

  def test_avoid_duplicate_email_notification_for_cc
    user = create_contact
    notification_count_before_note_creation = Delayed::Job.where(SEND_CC_EMAIL_JOB_STRING).all.count
    ticket = create_ticket(source: 1, subject: 'TEST_TICKET', description: 'Test duplicate notify to cc', requester_id: user.id, cc_emails: [user.email, 'cc1@gmail.com', 'cc2@gmail.com'])
    note = create_note(source: 0, incoming: 1, private: false, body: '<div>Requester Reply</div>', ticket_id: ticket.id, user_id: user.id)
    notification_count_after_note_creation = Delayed::Job.where(SEND_CC_EMAIL_JOB_STRING).all.count
    assert_equal notification_count_after_note_creation, notification_count_before_note_creation + 1
  end

  def test_send_comment_added_notification_to_cc_when_requester_adds_comment
    user = create_contact
    notification_count_before_note_creation = Delayed::Job.where(SEND_CC_EMAIL_JOB_STRING).all.count
    ticket = create_ticket(source: 1, subject: 'TEST_TICKET', description: 'Test send comment notification to cc', requester_id: user.id, cc_emails: ['cc1@gmail.com', 'cc2@gmail.com'])
    note = create_note(source: 0, incoming: 1, private: false, body: '<div>Requester Reply</div>', ticket_id: ticket.id, user_id: user.id)
    notification_count_after_note_creation = Delayed::Job.where(SEND_CC_EMAIL_JOB_STRING).all.count
    assert_equal notification_count_after_note_creation, notification_count_before_note_creation + 1
  end

  def test_send_comment_added_notification_when_cc_adds_comment
    requester = create_contact
    cc = create_contact
    notification_count_before_note_creation = Delayed::Job.where(SEND_CC_EMAIL_JOB_STRING).all.count
    ticket = create_ticket(source: 1, subject: 'TEST_TICKET', description: 'Test send comment notification to cc', requester_id: requester.id, cc_emails: [cc.email])
    note = create_note(source: 0, incoming: 1, private: false, body: '<div>CC Reply</div>', ticket_id: ticket.id, user_id: cc.id)
    notification_count_after_note_creation = Delayed::Job.where(SEND_CC_EMAIL_JOB_STRING).all.count
    assert_equal notification_count_after_note_creation, notification_count_before_note_creation + 1
  end
end
