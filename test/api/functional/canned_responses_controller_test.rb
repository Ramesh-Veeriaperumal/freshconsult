require_relative '../test_helper'
['canned_responses_helper.rb', 'group_helper.rb', 'agent_helper.rb', 'ticket_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }
['canned_responses_test_helper.rb', 'canned_response_folders_test_helper.rb', 'attachments_test_helper.rb', 'ticket_fields_test_helper.rb'].each { |file| require "#{Rails.root}/test/api/helpers/#{file}" }
require_relative "#{Rails.root}/lib/helpdesk_access_methods.rb"

class CannedResponsesControllerTest < ActionController::TestCase
  include GroupHelper
  include CannedResponsesHelper
  include CannedResponsesTestHelper
  include CannedResponseFoldersTestHelper
  include HelpdeskAccessMethods
  include AgentHelper
  include TicketHelper
  include AttachmentsTestHelper
  include AwsTestHelper
  include TicketFieldsTestHelper

  def setup
    CannedResponsesController.any_instance.stubs(:accessible_from_esv2).returns(nil)
    super
    before_all
    Account.current.stubs(:ticket_source_revamp_enabled?).returns(true)
  end

  def teardown
    super
    CannedResponsesController.unstub(:accessible_from_esv2)
    Account.current.unstub(:ticket_source_revamp_enabled?)
  end

  @@sample_ticket  = nil
  @@before_all_run = false
  @@ca_folder_all  = nil

  def before_all      
    @account = Account.first.make_current      
    @agent = get_admin
    @ca_folder_personal = @account.canned_response_folders.personal_folder.first

    return if @before_all_run

    @@ca_folder_all = create_cr_folder(name: Faker::Name.name)
    @@sample_ticket ||= create_ticket
    @account.subscription.update_column(:state, 'active')

    @@before_all_run = true
  end

  # tests for show
  # 1. show the response visible to all
  # 2. should show personal responses
  # 3. should not show personal responses of other agents
  # 4. should not show responses visible in particular group to agents not in the group
  # 5. Check with invalid response id

  def test_show_response
    ca_response1 = create_canned_response(@@ca_folder_all.id)
    login_as(@agent)
    get :show, controller_params(version: 'v2', id: ca_response1.id)
    assert_response 200
    match_json(ca_response_show_pattern(ca_response1.id))
  end

  def test_show_responses_in_personal_folder
    ca_response2 = create_canned_response(@ca_folder_personal.id, ::Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:only_me])
    login_as(@agent)
    get :show, controller_params(version: 'v2', id: ca_response2.id)
    assert_response 200
    match_json(ca_response_show_pattern(ca_response2.id))
  end

  def test_show_personal_responses_of_other_agents
    ca_response2 = create_canned_response(@ca_folder_personal.id, ::Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:only_me])
    new_agent = add_agent_to_account(@account, name: Faker::Name.name, active: 1, role: 1)
    login_as(new_agent.user)
    get :show, controller_params(version: 'v2', id: ca_response2.id)
    assert_response 403
  end

  def test_show_with_group_visibility_response
    ca_response3 = create_canned_response(@@ca_folder_all.id, ::Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:group_agents])
    new_agent = add_agent_to_account(@account, name: Faker::Name.name, active: 1, role: 1)
    login_as(new_agent.user)
    get :show, controller_params(version: 'v2', id: ca_response3.id)
    assert_response 403
  end

  def test_show_invalid_folder_id
    get :show, controller_params(version: 'v2', id: 0)
    assert_response 404
  end

  def test_show_with_invalid_ticket_id_and_response
    get :show, controller_params(version: 'v2', id: 10_000, ticket_id: 10_000, include: 'evaluated_response')
    assert_response 404
  end

  def test_show_with_invalid_ticket_id
    ca_response1 = create_canned_response(@@ca_folder_all.id)
    get :show, controller_params(version: 'v2', id: ca_response1.id, ticket_id: 10_000, include: 'evaluated_response')
    assert_response 404
  end

  def test_show_with_invalid_response_id
    get :show, controller_params(version: 'v2', id: 0, ticket_id: @@sample_ticket.display_id, include: 'evaluated_response')
    assert_response 404
  end

  def test_show_with_unauthorized_ticket_id
    ca_response3 = create_canned_response(@@ca_folder_all.id, ::Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:group_agents])
    user_stub_ticket_permission
    get :show, controller_params(version: 'v2', id: ca_response3.id, ticket_id: @@sample_ticket.display_id, include: 'evaluated_response')
    user_unstub_ticket_permission
    assert_response 403
    match_json(request_error_pattern(:access_denied))
  end

  def test_show_with_unauthorized_response_id
    ca_response1 = create_canned_response(@@ca_folder_all.id)
    ::Admin::CannedResponses::Response.any_instance.stubs(:visible_to_me?).returns(false)
    get :show, controller_params(version: 'v2', id: ca_response1.id, ticket_id: @@sample_ticket.display_id, include: 'evaluated_response')
    ::Admin::CannedResponses::Response.any_instance.unstub(:visible_to_me?)
    assert_response 403
    match_json(request_error_pattern(:access_denied))
  end

  def test_show_with_evaluated_response
    ca_response2 = create_canned_response(@ca_folder_personal.id, ::Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:only_me])
    login_as(@agent)
    get :show, controller_params(version: 'v2', id: ca_response2.id, ticket_id: @@sample_ticket.display_id, include: 'evaluated_response')
    assert_response 200
    match_json(ca_response_show_pattern_evaluated_content(ca_response2.id, @@sample_ticket))
  end

  def test_show_with_evaluated_response_new_ticket
    ca_response2 = create_canned_response(@ca_folder_personal.id, ::Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:only_me])
    login_as(@agent)
    get :show, controller_params(version: 'v2', id: ca_response2.id, include: 'evaluated_response')
    assert_response 200
    match_json(ca_response_show_pattern_new_ticket(ca_response2.id))
  end

  def test_show_with_attachments
    file = fixture_file_upload('files/attachment.txt', 'text/plain', :binary)
    @ca_response4 = create_response(
      title: Faker::Lorem.sentence,
      content_html: 'Hi {{ticket.requester.name}}, Faker::Lorem.paragraph Regards, {{ticket.agent.name}}',
      visibility: ::Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:all_agents],
      attachments: {
        resource: file,
        description: ''
      }
    )      
    login_as(@agent)
    get :show, controller_params(version: 'v2', id: @ca_response4.id, ticket_id: @@sample_ticket.display_id, include: 'evaluated_response')
    assert_response 200
    match_json(ca_response_show_pattern_evaluated_content(@ca_response4.id, @@sample_ticket, @ca_response4.attachments_sharable))
  end

  def test_show_with_xss_payload
    ticket = create_ticket(:subject => '<img src=x onerror=prompt("Subject");>')
    ca_response = create_response(
      title: Faker::Lorem.sentence,
      content_html: "<div>{{ticket.subject}}</div>",
      visibility: ::Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:all_agents]
    )      
    login_as(@agent)
    get :show, controller_params(version: 'v2', id: ca_response.id, ticket_id: ticket.display_id, include: 'evaluated_response')
    assert_response 200
    json_response = JSON.parse(response.body)
    evaluated_response = json_response["evaluated_response"]
    assert_equal evaluated_response, "<div>#{h(ticket.subject)}</div>"
  end

  def test_placeholder_helpdesk_name
    ticket = create_ticket(:subject => 'test ticket')
    helpdesk_name = Account.current.helpdesk_name
    ca_response = create_response(
      title: Faker::Lorem.sentence,
      content_html: "<div>{{helpdesk_name}}</div>",
      visibility: ::Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:all_agents]
    )      
    login_as(@agent)
    get :show, controller_params(version: 'v2', id: ca_response.id, ticket_id: ticket.display_id, include: 'evaluated_response')
    assert_response 200
    json_response = JSON.parse(response.body)
    evaluated_response = json_response["evaluated_response"]
    assert_equal evaluated_response, "<div>#{h(helpdesk_name)}</div>"
  end

  def test_placeholder_source_name
    ticket = create_ticket(subject: 'test ticket')
    custom_source = Account.current.helpdesk_sources.visible.custom.last || create_custom_source
    ticket.source = custom_source.account_choice_id
    ticket.save!
    ticket.reload
    source_name = ticket.source_name
    ca_response = create_response(
      title: Faker::Lorem.sentence,
      content_html: '<div>{{ticket.source_name}}</div>',
      visibility: ::Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:all_agents]
    )
    login_as(@agent)
    get :show, controller_params(version: 'v2', id: ca_response.id, ticket_id: ticket.display_id, include: 'evaluated_response')
    assert_response 200
    json_response = JSON.parse(response.body)
    evaluated_response = json_response['evaluated_response']
    assert_equal "<div>#{h(source_name)}</div>", evaluated_response
  end

  def test_placeholder_portal_name
    ticket = create_ticket(:subject => 'test ticket')
    portal_name = Account.current.portal_name
    ca_response = create_response(
      title: Faker::Lorem.sentence,
      content_html: "<div>{{ticket.portal_name}}</div>",
      visibility: ::Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:all_agents]
    )      
    login_as(@agent)
    get :show, controller_params(version: 'v2', id: ca_response.id, ticket_id: ticket.display_id, include: 'evaluated_response')
    assert_response 200
    json_response = JSON.parse(response.body)
    evaluated_response = json_response["evaluated_response"]
    assert_equal evaluated_response, "<div>#{h(portal_name)}</div>"
  end

  def test_show_with_empty_include
    ca_response2 = create_canned_response(@ca_folder_personal.id, ::Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:only_me])
    login_as(@agent)
    get :show, controller_params(version: 'v2', id: ca_response2.id, ticket_id: @@sample_ticket.display_id, include: '')
    assert_response 400
    match_json([bad_request_error_pattern('include', :not_included, list: CannedResponseConstants::ALLOWED_INCLUDE_PARAMS)])
  end

  def test_show_with_wrong_type_include
    ca_response2 = create_canned_response(@ca_folder_personal.id, ::Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:only_me])
    login_as(@agent)
    get :show, controller_params(version: 'v2', id: ca_response2.id, ticket_id: @@sample_ticket.display_id, include: ['test'])
    assert_response 400
    match_json([bad_request_error_pattern('include', :datatype_mismatch, expected_data_type: 'String', prepend_msg: :input_received, given_data_type: 'Array')])
  end

  def test_show_with_invalid_params
    ca_response2 = create_canned_response(@ca_folder_personal.id, ::Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:only_me])
    login_as(@agent)
    get :show, controller_params(version: 'v2', id: ca_response2.id, ticket_id: @@sample_ticket.display_id, includ: 'test')
    assert_response 400
    match_json([bad_request_error_pattern('includ', :invalid_field)])
  end

  # tests for Index
  # 1. 404 when there are no ids
  # 2. 404 when the ids are invalid
  # 3. Show for single id
  # 4. Show for mulitple id all valid ones
  # 5. Show empty array for all invalid ones
  # 6. Combine 2 valid ids and and 2 invalid ids
  # 7. Combine 5 valid ids , continued by an invalid then and and 5 more valid ids. Result would have only 9 responses

  def test_index_404_when_no_ids
    get :index, controller_params(version: 'v2')
    assert_response 404
  end

  def test_index_404_for_invalid_ids
    get :index, controller_params(version: 'v2', ids: 'a,b,c')
    assert_response 404
  end

  def test_index_for_one_ca
    ca_response1 = create_canned_response(@@ca_folder_all.id)
    get :index, controller_params(version: 'v2', ids: ca_response1.id)
    assert_response 200
    match_json([ca_response_search_pattern(ca_response1.id)])
  end

  def test_index_for_multiple_ca
    ca_response1 = create_canned_response(@@ca_folder_all.id)
    ca_response2 = create_canned_response(@ca_folder_personal.id, ::Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:only_me])
    login_as(@agent)
    get :index, controller_params(version: 'v2', ids: [ca_response1, ca_response2].map(&:id).join(', '))
    assert_response 200
    pattern = []
    [ca_response1, ca_response2].each do |ca|
      pattern << ca_response_search_pattern(ca.id)
    end
    match_json(pattern)
  end

  def test_index_for_multiple_ca_with_inaccessible_ids
    ca_response1 = create_canned_response(@@ca_folder_all.id)
    ca_response2 = create_canned_response(@ca_folder_personal.id, ::Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:only_me])
    ca_response3 = create_canned_response(@@ca_folder_all.id, ::Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:group_agents])
    get :index, controller_params(version: 'v2', ids: [ca_response1, ca_response2, ca_response3].map(&:id).join(', '))
    assert_response 200
    pattern = []
    [ca_response1, ca_response2].each do |ca|
      pattern << ca_response_search_pattern(ca.id)
    end
    match_json(pattern)
    # ca_response3 will not be present here.
  end

  def test_index_with_just_inaccessible_ids
    ca_response3 = create_canned_response(@@ca_folder_all.id, ::Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:group_agents])
    get :index, controller_params(version: 'v2', ids: [ca_response3].map(&:id).join(', '))
    assert_response 404
  end

  def test_index_for_multiple_ca_with_invalid_ids
    ca_response1 = create_canned_response(@@ca_folder_all.id)
    ca_response2 = create_canned_response(@ca_folder_personal.id, ::Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:only_me])
    ca_response3 = create_canned_response(@@ca_folder_all.id, ::Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:group_agents])
    get :index, controller_params(version: 'v2', ids: [ca_response1, ca_response2, ca_response3].map(&:id).join(', ') << ',a,b,c')
    assert_response 200
    pattern = []
    [ca_response1, ca_response2].each do |ca|
      pattern << ca_response_search_pattern(ca.id)
    end
    match_json(pattern)
    # ca_response3 will not be present here.
  end

  def test_index_for_limit_in_ids
    ca_response3 = create_canned_response(@@ca_folder_all.id, ::Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:group_agents])
    ca_responses = Array.new(10) { create_canned_response(@@ca_folder_all.id) }

    ids_passed = ca_responses.collect(&:id)
    ids_passed.insert(3, ca_response3.id)
    get :index, controller_params(version: 'v2', ids: ids_passed.join(','))
    assert_response 200
    pattern = []
    ca_responses.first(9).each do |ca|
      pattern << ca_response_search_pattern(ca.id)
    end
    match_json(pattern)
  end

  def test_create_all_users
    post :create, construct_params(build_ca_param(create_ca_response_input(@@ca_folder_all.id, 0)))
    assert_response 201
    match_json(ca_response_show_pattern(ActiveSupport::JSON.decode(response.body)['id']))
  end

  def test_create_with_user_access
    post :create, construct_params(build_ca_param(create_ca_response_input(nil, 1)))
    assert_response 201
    match_json(ca_response_show_pattern(ActiveSupport::JSON.decode(response.body)['id']))
  end

  def test_create_with_group_access
    post :create, construct_params(build_ca_param(create_ca_response_input(@@ca_folder_all.id, 2, [Account.first.groups_from_cache.first.try(:id)])))
    assert_response 201
    match_json(ca_response_show_pattern(ActiveSupport::JSON.decode(response.body)['id']))
  end

  def test_create_all_users_with_multipart
    @request.env['CONTENT_TYPE'] = 'multipart/form-data'
    post :create, construct_params(build_ca_param(create_ca_response_input(@@ca_folder_all.id, 0)))
    assert_response 201
    match_json(ca_response_show_pattern(ActiveSupport::JSON.decode(response.body)['id']))
  end

  def test_create_with_user_access_with_multipart
    @request.env['CONTENT_TYPE'] = 'multipart/form-data'
    post :create, construct_params(build_ca_param(create_ca_response_input(nil, 1)))
    assert_response 201
    match_json(ca_response_show_pattern(ActiveSupport::JSON.decode(response.body)['id']))
  end

  def test_create_with_group_access_with_multipart
    @request.env['CONTENT_TYPE'] = 'multipart/form-data'
    post :create, construct_params(build_ca_param(create_ca_response_input(@@ca_folder_all.id, 2, [Account.first.groups_from_cache.first.try(:id)])))
    assert_response 201
    match_json(ca_response_show_pattern(ActiveSupport::JSON.decode(response.body)['id']))
  end

  def test_create_with_group_visibility_without_group_id
    post :create, construct_params(build_ca_param(create_ca_response_input(@@ca_folder_all.id, 2)))
    match_json(validation_error_pattern(bad_request_error_pattern(:group_ids, 'It should not be blank as this is a mandatory field', code: 'invalid_value')))
    assert_response 400
  end

  def test_create_personal_with_group
    post :create, construct_params(build_ca_param(create_ca_response_input(@ca_folder_personal.id, 2, [Account.first.groups_from_cache.first.try(:id)])))
    assert_response 400
    match_json(validation_error_pattern(bad_request_error_pattern(:folder_id, 'You can only save canned responses just visible to you in the personal folder.', code: 'invalid_value')))
  end

  def test_create_invalid_visibility
    post :create, construct_params(build_ca_param(create_ca_response_input(@@ca_folder_all.id, 10)))
    assert_response 400
    match_json(validation_error_pattern(bad_request_error_pattern(:visibility, "It should be one of these values: '#{Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TYPE.keys.join(',')}'", code: 'invalid_value')))
  end

  def test_craete_invalid_folder_id
    post :create, construct_params(build_ca_param(create_ca_response_input(100, 2, [Account.first.groups_from_cache.first.try(:id)])))
    assert_response 400
    match_json(validation_error_pattern(bad_request_error_pattern(:folder_id, 'Please specify a valid folder ID.', code: 'invalid_value')))
  end

  def test_craete_invalid_group_id
    post :create, construct_params(build_ca_param(create_ca_response_input(@@ca_folder_all.id, 2, [100_000_000])))
    assert_response 400
    match_json(validation_error_pattern(bad_request_error_pattern(:group_id, 'Please specify a valid group ID.', code: 'invalid_value')))
  end

  def test_create_with_invalid_title
    ca_response = create_ca_response_input(@@ca_folder_all.id, 0)
    ca_response[:title] = 'qw'
    post :create, construct_params(build_ca_param(ca_response))
    assert_response 400
    match_json(validation_error_pattern(bad_request_error_pattern(:title, 'Has 2 characters, it should have minimum of 3 characters and can have maximum of 240 characters', code: 'invalid_value')))
  end

  def test_create_with_invalid_content_html
    ca_response = create_ca_response_input(@@ca_folder_all.id, 0)
    ca_response[:content_html] = '{{test}'
    post :create, construct_params(build_ca_param(ca_response))
    assert_response 400
    match_json(validation_error_pattern(bad_request_error_pattern(:content_html, 'Variable &#x27;{{test}&#x27; was not properly terminated with regexp: /\\}\\}/ ', code: 'invalid_value')))
  end

  def test_create_duplicate
    ca_response1 = create_canned_response(@@ca_folder_all.id)
    ca_response2 = create_ca_response_input(@@ca_folder_all.id, 0)
    ca_response2[:title] = ca_response1.title
    post :create, construct_params(build_ca_param(ca_response2))
    assert_response 400
    match_json(validation_error_pattern(bad_request_error_pattern(:base, 'Duplicate response. Title already exists', code: 'invalid_value')))
  end

  def test_create_privilage_check
    User.any_instance.stubs(:privilege?).with(:manage_canned_responses).returns(false)
    post :create, construct_params(build_ca_param(create_ca_response_input(@@ca_folder_all.id, 0)))
    assert_response 403
    match_json(request_error_pattern(:access_denied))
    User.any_instance.unstub(:privilege?)
  end

  def test_create_with_attachment
    file = fixture_file_upload('/files/attachment.txt', 'plain/text', :binary)
    file2 = fixture_file_upload('files/image33kb.jpg', 'image/jpg')
    params = create_ca_response_input(@@ca_folder_all.id, 0)
    params = params.merge('attachments' => [file, file2])
    @request.env['CONTENT_TYPE'] = 'multipart/form-data'
    DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
    post :create, construct_params(build_ca_param(params))
    DataTypeValidator.any_instance.unstub(:valid_type?)
    assert_response 201
    ca_response = @account.canned_responses.find(ActiveSupport::JSON.decode(response.body)['id'])
    match_json(ca_response_show_pattern(ca_response.id, ca_response.attachments_sharable))
  end

  def test_create_with_invalid_attachment_array
    params = create_ca_response_input(@@ca_folder_all.id, 0)
    params = params.merge('attachments' => [1, 2])
    post :create, construct_params(build_ca_param(params))
    assert_response 400
    match_json([bad_request_error_pattern('attachments', :array_datatype_mismatch, expected_data_type: 'valid file format')])
  end

  def test_create_with_invalid_attachment_type
    params = create_ca_response_input(@@ca_folder_all.id, 0)
    params = params.merge('attachments' => 'test')
    post :create, construct_params(build_ca_param(params))
    assert_response 400
    match_json([bad_request_error_pattern('attachments', :datatype_mismatch, expected_data_type: Array, given_data_type: String, prepend_msg: :input_received)])
  end

  def test_attachment_invalid_size_create
    invalid_attachment_limit = @account.attachment_limit + 2
    Rack::Test::UploadedFile.any_instance.stubs(:size).returns(invalid_attachment_limit.megabytes)
    file = fixture_file_upload('/files/attachment.txt', 'plain/text', :binary)
    params = create_ca_response_input(@@ca_folder_all.id, 0)
    params = params.merge('attachments' => [file])
    DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
    post :create, construct_params(build_ca_param(params))
    DataTypeValidator.any_instance.unstub(:valid_type?)
    assert_response 400
    match_json([bad_request_error_pattern('attachments', :invalid_size, max_size: "#{@account.attachment_limit} MB", current_size: "#{invalid_attachment_limit} MB")])
  end

  def test_create_with_attachment_ids
    params = create_ca_response_input(@@ca_folder_all.id, 0)
    attachment_ids = []
    attachment_ids << create_attachment(attachable_type: 'UserDraft', attachable_id: @agent.id).id
    params = params.merge(attachment_ids: attachment_ids)
    stub_attachment_to_io do
      post :create, construct_params(params)
    end
    assert_response 201
    ca_response = @account.canned_responses.find(ActiveSupport::JSON.decode(response.body)['id'])
    assert ca_response.shared_attachments.size == 1
  end

  def test_create_with_invalid_attachment_ids
    params = create_ca_response_input(@@ca_folder_all.id, 0)
    params = params.merge(attachment_ids: [100])
    stub_attachment_to_io do
      post :create, construct_params(params)
    end
    assert_response 400
    match_json(validation_error_pattern(bad_request_error_pattern(:attachment_ids, "There are no records matching the ids: '100'", code: 'invalid_value')))
  end

  def test_create_with_invalid_attachment_ids_array
    params = create_ca_response_input(@@ca_folder_all.id, 0)
    params = params.merge(attachment_ids: ['test'])
    stub_attachment_to_io do
      post :create, construct_params(params)
    end
    assert_response 400
    match_json(validation_error_pattern(bad_request_error_pattern(:attachment_ids, 'It should contain elements of type Positive Integer only', code: 'datatype_mismatch')))
  end

  def test_update_title
    ca_response1 = create_canned_response(@@ca_folder_all.id)
    title = Faker::Lorem.characters(5)
    canned_response = {
      title: title
    }
    put :update, construct_params(build_ca_param(canned_response)).merge(id: ca_response1.id)
    assert_response 200
    assert title == ActiveSupport::JSON.decode(response.body)['title']
    match_json(ca_response_show_pattern(ca_response1.id))
  end

  def test_update_content_html
    ca_response1 = create_canned_response(@@ca_folder_all.id)
    content_html = Faker::App.name
    canned_response = {
      content_html: content_html
    }
    put :update, construct_params(build_ca_param(canned_response)).merge(id: ca_response1.id)
    assert_response 200
    assert content_html == ActiveSupport::JSON.decode(response.body)['content_html']
    match_json(ca_response_show_pattern(ca_response1.id))
  end

  def test_update_visibility_user
    ca_response1 = create_canned_response(@@ca_folder_all.id)
    canned_response = {
      visibility: 1
    }
    put :update, construct_params(build_ca_param(canned_response)).merge(id: ca_response1.id)
    assert_response 200
    ca_response1.reload
    assert Helpdesk::Access.last.user_accesses.first.access_id == ca_response1.helpdesk_accessible.id
    match_json(ca_response_show_pattern(ca_response1.id))
  end

  def test_update_visibility_group
    ca_response1 = create_canned_response(@@ca_folder_all.id)
    canned_response = {
      visibility: 2,
      group_ids: [Account.first.groups_from_cache.first.try(:id)]
    }
    put :update, construct_params(build_ca_param(canned_response)).merge(id: ca_response1.id)
    assert_response 200
    ca_response1.reload
    assert Helpdesk::Access.last.group_accesses.first.access_id == ca_response1.helpdesk_accessible.id
    match_json(ca_response_show_pattern(ca_response1.id))
  end

  def test_update_visibility_user_group_without_folder_id
    ca_response1 = create_canned_response(@ca_folder_personal.id, ::Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:only_me])
    canned_response = {
      visibility: 2,
      group_ids: [Account.first.groups_from_cache.first.try(:id)]
    }
    put :update, construct_params(build_ca_param(canned_response)).merge(id: ca_response1.id)
    assert_response 400
  end

  def test_update_visibility_user_group_with_folder_id
    ca_response1 = create_canned_response(@ca_folder_personal.id, ::Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:only_me])
    canned_response = {
      visibility: 2,
      group_ids: [Account.first.groups_from_cache.first.try(:id)],
      folder_id: @@ca_folder_all.id
    }
    put :update, construct_params(build_ca_param(canned_response)).merge(id: ca_response1.id)
    assert_response 200
    ca_response1.reload
    assert Helpdesk::Access.last.group_accesses.first.access_id == ca_response1.helpdesk_accessible.id
    match_json(ca_response_show_pattern(ca_response1.id))
  end

  def test_update_attachment
    ca_response1 = create_canned_response(@@ca_folder_all.id)
    file = fixture_file_upload('/files/attachment.txt', 'plain/text', :binary)
    file2 = fixture_file_upload('files/image33kb.jpg', 'image/jpg')
    canned_response = {
      attachments: [file, file2]
    }
    @request.env['CONTENT_TYPE'] = 'multipart/form-data'
    DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
    put :update, construct_params(build_ca_param(canned_response)).merge(id: ca_response1.id)
    DataTypeValidator.any_instance.unstub(:valid_type?)
    assert_response 200
    ca_response1.reload
    assert ca_response1.shared_attachments.size == 2
    match_json(ca_response_show_pattern(ca_response1.id, ca_response1.attachments_sharable))
  end

  def test_update_attachment_ids
    ca_response1 = create_canned_response(@@ca_folder_all.id)
    attachment_ids = []
    attachment_ids << create_attachment(attachable_type: 'UserDraft', attachable_id: @agent.id).id
    canned_response = {
      attachment_ids: attachment_ids
    }
    @request.env['CONTENT_TYPE'] = 'multipart/form-data'
    DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
    put :update, construct_params(build_ca_param(canned_response)).merge(id: ca_response1.id)
    DataTypeValidator.any_instance.unstub(:valid_type?)
    assert_response 200
    ca_response1.reload
    assert ca_response1.shared_attachments.size == 1
  end

  def test_update_privilage_check
    ca_response1 = create_canned_response(@@ca_folder_all.id)
    User.any_instance.stubs(:privilege?).with(:manage_canned_responses).returns(false)
    canned_response = {
      title: Faker::App.name
    }
    put :update, construct_params(build_ca_param(canned_response)).merge(id: ca_response1.id)
    assert_response 403
    match_json(request_error_pattern(:access_denied))
    User.any_instance.unstub(:privilege?)
  end

  def test_update_with_invalid_content_html
    ca_response1 = create_canned_response(@@ca_folder_all.id)
    canned_response = {
      content_html: '{{test}'
    }
    put :update, construct_params(build_ca_param(canned_response)).merge(id: ca_response1.id)
    assert_response 400
    match_json(validation_error_pattern(bad_request_error_pattern(:content_html, 'Variable &#x27;{{test}&#x27; was not properly terminated with regexp: /\\}\\}/ ', code: 'invalid_value')))
  end

  def test_folder_responses
    folder_id = @@ca_folder_all.id
    ca_responses = Array.new(10) { create_canned_response(@@ca_folder_all.id) }
    get :folder_responses, controller_params(id: folder_id)
    assert_response 200
    pattern = []
    ca_responses.each do |ca|
      pattern << ca_response_show_pattern(ca.id)
    end
    match_json(pattern)
  end

  def test_folder_responses_with_invalid_folder_id
    get :folder_responses, controller_params(id: Faker::Number.number(6))
    assert_response 404
  end

  def test_folder_responses_with_pagination
    folder_id = @@ca_folder_all.id
    10.times do
      create_canned_response(@@ca_folder_all.id)
    end
    get :folder_responses, controller_params(id: folder_id, per_page: 1)
    assert_response 200
    assert JSON.parse(response.body).count == 1
    get :folder_responses, controller_params(id: folder_id, per_page: 1, page: 2)
    assert_response 200
    assert JSON.parse(response.body).count == 1
  end

  def test_folder_responses_with_pagination_with_default_limit
    folder_id = @@ca_folder_all.id
    40.times do
      create_canned_response(@@ca_folder_all.id)
    end
    get :folder_responses, controller_params(id: folder_id)
    assert_response 200
    assert JSON.parse(response.body).count == ApiConstants::DEFAULT_PAGINATE_OPTIONS[:per_page]
  end

  def test_central_publish_payload_create_cr
    CentralPublisher::Worker.jobs.clear
    post :create, construct_params(build_ca_param(create_ca_response_input(@@ca_folder_all.id, 0)))
    assert_response 201

    match_json(ca_response_show_pattern(ActiveSupport::JSON.decode(response.body)['id']))

    job = CentralPublisher::Worker.jobs.last
    assert_equal 'canned_response_create', job['args'][0]
    CentralPublisher::Worker.jobs.clear
  end

  def test_central_publish_payload_update_cr_content_html
    CentralPublisher::Worker.jobs.clear
    ca_response1 = create_canned_response(@@ca_folder_all.id)
    content_html = Faker::App.name
    prev_content_html = ca_response1.content_html
    canned_response = {
      content_html: content_html
    }
    put :update, construct_params(build_ca_param(canned_response)).merge(id: ca_response1.id)
    assert_response 200
    assert content_html == ActiveSupport::JSON.decode(response.body)['content_html']

    job = CentralPublisher::Worker.jobs.last
    assert_equal 'canned_response_update', job['args'][0]
    assert_equal({ 'content_html' => [prev_content_html, content_html] }, job['args'][1]['model_changes'])
    CentralPublisher::Worker.jobs.clear
  end

  def test_central_publish_payload_delete_cr
    CentralPublisher::Worker.jobs.clear
    ca_response1 = create_canned_response(@@ca_folder_all.id)
    ca_response1.destroy
    job = CentralPublisher::Worker.jobs.last
    assert_equal 'canned_response_destroy', job['args'][0]
    CentralPublisher::Worker.jobs.clear
  end

  def test_create_multiple_valid_ca_response
    uuid = SecureRandom.hex
    request.stubs(:uuid).returns(uuid)
    payload = { 'canned_responses' =>
                    [
                        create_ca_response_input(@@ca_folder_all.id, 0),
                        create_ca_response_input(nil, 1),
                        create_ca_response_input(@@ca_folder_all.id, 2, [Account.first.groups_from_cache.first.try(:id)])
                    ] }
    dynamo_response = { 'payload' => payload['canned_responses'], 'action' => 'create_multiple' }
    BulkApiJobs::Agent.any_instance.stubs(:pick_job).returns(dynamo_response)
    Sidekiq::Testing.inline! do
      post :create_multiple, construct_params(payload)
    end
    assert_response 202
    pattern = { job_id: uuid, href: @account.bulk_job_url(uuid) }
    match_json(pattern)
  ensure
    BulkApiJobs::Agent.any_instance.unstub(:pick_job)
    request.unstub(:uuid)
  end

  def test_create_multiple_ca_response_with_invalid_folder_id
    uuid = SecureRandom.hex
    request.stubs(:uuid).returns(uuid)
    payload = { 'canned_responses' =>
                    [
                        create_ca_response_input(999, 0),
                        create_ca_response_input(999, 2, [Account.first.groups_from_cache.first.try(:id)])
                    ] }
    dynamo_response = { 'payload' => payload['canned_responses'], 'action' => 'create_multiple' }
    BulkApiJobs::Agent.any_instance.stubs(:pick_job).returns(dynamo_response)
    Sidekiq::Testing.inline! do
      post :create_multiple, construct_params(payload)
    end
    assert_response 202
    pattern = { job_id: uuid, href: @account.bulk_job_url(uuid) }
    match_json(pattern)
    @account.reload

    all_titles = payload['canned_responses'].map { |ca| ca[:title] }
    all_titles.each { |title| assert_equal @account.canned_responses.find_by_title(title), nil }
  ensure
    BulkApiJobs::Agent.any_instance.unstub(:pick_job)
    request.unstub(:uuid)
  end

  def test_create_multiple_ca_response_with_invalid_visibility
    uuid = SecureRandom.hex
    request.stubs(:uuid).returns(uuid)
    payload = { 'canned_responses' =>
                    [
                        create_ca_response_input(@@ca_folder_all.id, 999),
                        create_ca_response_input(nil, 999),
                        create_ca_response_input(@@ca_folder_all.id, 999, [Account.first.groups_from_cache.first.try(:id)])
                    ] }
    dynamo_response = { 'payload' => payload['canned_responses'], 'action' => 'create_multiple' }
    BulkApiJobs::Agent.any_instance.stubs(:pick_job).returns(dynamo_response)
    Sidekiq::Testing.inline! do
      post :create_multiple, construct_params(payload)
    end
    assert_response 400
  ensure
    BulkApiJobs::Agent.any_instance.unstub(:pick_job)
    request.unstub(:uuid)
  end

  def test_create_multiple_ca_response_with_invalid_group_id
    uuid = SecureRandom.hex
    request.stubs(:uuid).returns(uuid)
    payload = { 'canned_responses' => [create_ca_response_input(@@ca_folder_all.id, 2, [999])] }
    dynamo_response = { 'payload' => payload['canned_responses'], 'action' => 'create_multiple' }
    BulkApiJobs::Agent.any_instance.stubs(:pick_job).returns(dynamo_response)
    Sidekiq::Testing.inline! do
      post :create_multiple, construct_params(payload)
    end
    assert_response 202
    pattern = { job_id: uuid, href: @account.bulk_job_url(uuid) }
    match_json(pattern)
    @account.reload

    all_titles = payload['canned_responses'].map { |ca| ca[:title] }
    all_titles.each { |title| assert_equal @account.canned_responses.find_by_title(title), nil }
  ensure
    BulkApiJobs::Agent.any_instance.unstub(:pick_job)
    request.unstub(:uuid)
  end
end
