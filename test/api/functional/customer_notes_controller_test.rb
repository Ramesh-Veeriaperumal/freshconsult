require_relative '../test_helper'
class CustomerNotesControllerTest < ActionController::TestCase
  include UsersTestHelper
  include AttachmentsTestHelper
  include CustomerNotesTestHelper
  include AwsTestHelper
  include CompaniesTestHelper

  PRIVATE = 'private'.freeze
  BULK_ATTACHMENT_CREATE_COUNT = 2

  def setup
    super
    initial_setup
  end

  def initial_setup
    @contact = User.last || add_new_user(@account)
    @created_by_contact = add_new_user(@account)
    @company = Company.last || create_company
  end

  def wrap_cname(params)
    { note: params }
  end

  def create_note_params_hash
    {
      title: Faker::Lorem.characters(150),
      body: Faker::Lorem.paragraph
    }
  end

  def update_note_params_hash
    {
      title: Faker::Lorem.characters(150),
      body: Faker::Lorem.paragraph
    }
  end

  def contact_unwrapped_params
    @unwrapped_params ||= begin
      { version: PRIVATE, contact_id: @contact.id }
    end
  end

  def company_unwrapped_params
    @unwrapped_params ||= begin
      { version: PRIVATE, company_id: @company.id }
    end
  end
  # test contact notes

  def test_create_contact_note
    params_hash = create_note_params_hash
    post :create, construct_params(contact_unwrapped_params, params_hash)
    assert_response 201
    match_json(contact_note_pattern(params_hash, ContactNote.last))
    match_json(contact_note_pattern({}, ContactNote.last))
  end

  def test_create_contact_note_to_invalid_contact
    post :create, construct_params({version: PRIVATE, contact_id: (User.last.id + 100)}, {})
    assert_response 404
  end

  def test_create_contact_note_to_agent
    post :create, construct_params({version: PRIVATE, contact_id: @agent.id}, {})
    assert_response 404
  end

  def test_create_contact_note_by_invalid_title_length
    params_hash = create_note_params_hash.merge(title: Faker::Lorem.characters(257))
    post :create, construct_params(contact_unwrapped_params, params_hash)
    assert_response 400
    match_json([bad_request_error_pattern(
      :title, :"is too long (maximum is 256 characters)",
      code: :invalid_value
    )])
  end

  def test_create_contact_note_without_body
    params_hash = create_note_params_hash.except(:body)
    post :create, construct_params(contact_unwrapped_params, params_hash)
    assert_response 400
    match_json([bad_request_error_pattern(
      :body, :"can't be blank",
      code: :invalid_value
    )])
  end

  def test_create_contact_note_invalid_attachment_ids_type
    attachment_ids = %w(A B C)
    params_hash = create_note_params_hash.merge(attachment_ids: attachment_ids)
    post :create, construct_params(contact_unwrapped_params, params_hash)
    match_json([bad_request_error_pattern(
      :attachment_ids,
      :array_datatype_mismatch,
      expected_data_type: 'Positive Integer'
    )])
    assert_response 400
  end

  def test_create_contact_note_invalid_attachment_ids
    attachment_ids = []
    attachment_ids << create_attachment(attachable_type: 'UserDraft', attachable_id: @created_by_contact).id
    invalid_ids = [attachment_ids.last + 50, attachment_ids.last + 60]
    params_hash = create_note_params_hash.merge(attachment_ids: (attachment_ids | invalid_ids))
    post :create, construct_params(contact_unwrapped_params, params_hash)
    match_json([bad_request_error_pattern(:attachment_ids, :invalid_list, list: invalid_ids.join(', '))])
    assert_response 400
  end

  def test_create_contact_note_invalid_attachment_size
    attachment_ids = []
    attachment_ids << create_attachment(attachable_type: 'UserDraft', attachable_id: @created_by_contact).id
    invalid_attachment_limit = @account.attachment_limit + 1
    Helpdesk::Attachment.any_instance.stubs(:content_file_size).returns(invalid_attachment_limit.megabytes)
    params_hash = create_note_params_hash.merge(attachment_ids: attachment_ids)
    post :create, construct_params(contact_unwrapped_params, params_hash)
    Helpdesk::Attachment.any_instance.unstub(:content_file_size)
    match_json([bad_request_error_pattern(:attachment_ids, :invalid_size, max_size: "#{@account.attachment_limit} MB", current_size: "#{invalid_attachment_limit} MB")])
    assert_response 400
  end

  def test_create_contact_note_attachment_id
    attachment_id = create_attachment(attachable_type: 'UserDraft', attachable_id: @created_by_contact).id
    params_hash = create_note_params_hash.merge(attachment_ids: [attachment_id])
    post :create, construct_params(contact_unwrapped_params, params_hash)
    assert_response 201
    match_json(contact_note_pattern(params_hash, ContactNote.last))
    match_json(contact_note_pattern({}, ContactNote.last))
    assert ContactNote.last.attachments.size == 1
  end

  def test_create_contact_note_with_attachment_ids
    attachment_ids = []
    BULK_ATTACHMENT_CREATE_COUNT.times do
      attachment_ids << create_attachment(attachable_type: 'UserDraft', attachable_id: @created_by_contact.id).id
    end
    params_hash = create_note_params_hash.merge(attachment_ids: attachment_ids)
    post :create, construct_params(contact_unwrapped_params, params_hash)
    assert_response 201
    match_json(contact_note_pattern(params_hash, ContactNote.last))
    match_json(contact_note_pattern({}, ContactNote.last))
    assert ContactNote.last.attachments.size == attachment_ids.size
  end

  def test_create_contact_note_with_attachment
    file = fixture_file_upload('files/attachment.txt', 'plain/text', :binary)
    file2 = fixture_file_upload('files/image33kb.jpg', 'image/jpg')
    params = create_note_params_hash.merge('attachments' => [file, file2])
    DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
    post :create, construct_params(contact_unwrapped_params, params)
    DataTypeValidator.any_instance.unstub(:valid_type?)
    assert_response 201
    response_params = params.except(:attachments)
    match_json(contact_note_pattern(params, ContactNote.last))
    match_json(contact_note_pattern({}, ContactNote.last))
    assert ContactNote.last.attachments.count == 2
  end

  def test_create_contact_note_with_attachment_and_attachment_ids
    attachment_id = create_attachment(attachable_type: 'UserDraft', attachable_id: @agent.id).id
    file1 = fixture_file_upload('files/attachment.txt', 'text/plain', :binary)
    file2 = fixture_file_upload('files/image33kb.jpg', 'image/jpg')
    attachments = [file1, file2]
    params_hash = create_note_params_hash.merge(attachment_ids: [attachment_id], attachments: attachments)
    DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
    @request.env['CONTENT_TYPE'] = 'multipart/form-data'
    post :create, construct_params(contact_unwrapped_params, params_hash)
    DataTypeValidator.any_instance.unstub(:valid_type?)
    assert_response 201
    match_json(contact_note_pattern(params_hash, ContactNote.last))
    match_json(contact_note_pattern({}, ContactNote.last))
    assert ContactNote.last.attachments.size == (attachments.size + 1)
  end

  def test_create_contact_note_with_invalid_attachment_params_format
    params = create_note_params_hash.merge('attachments' => [1, 2])
    post :create, construct_params(contact_unwrapped_params, params)
    assert_response 400
    match_json([bad_request_error_pattern('attachments', :array_datatype_mismatch, expected_data_type: 'valid file format')])
  end

  def test_create_contact_note_with_attachment_invalid_size
    Rack::Test::UploadedFile.any_instance.stubs(:size).returns(20_000_000)
    file = fixture_file_upload('/files/attachment.txt', 'plain/text', :binary)
    params = create_note_params_hash.merge('attachments' => [file])
    DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
    post :create, construct_params(contact_unwrapped_params, params)
    DataTypeValidator.any_instance.unstub(:valid_type?)
    assert_response 400
    match_json([bad_request_error_pattern('attachments', :invalid_size, max_size: '15 MB', current_size: '19.1 MB')])
  end

  # def test_create_contact_note_with_cloud_files_upload
  #   cloud_file_params = [{ filename: 'image.jpg', url: CLOUD_FILE_IMAGE_URL, application_id: 20 }]
  #   params = create_note_params_hash.merge(cloud_files: cloud_file_params)
  #   post :create, construct_params(contact_unwrapped_params, params)
  #   assert_response 201
  #   match_json(contact_note_pattern(params, ContactNote.last))
  #   match_json(contact_note_pattern({}, ContactNote.last))
  #   assert ContactNote.last.cloud_files.count == 1
  # end

  def test_update_contact_note_to_invalid_contact
    note = _create_contact_note(@contact, @agent)
    put :update, construct_params({ version: PRIVATE, contact_id: (User.last.id + 100) }.merge(id: note.id), {})
    assert_response 404
  end

  def test_update_contact_note_to_invalid_note
    note = _create_contact_note(@contact, @agent)
    put :update, construct_params({ version: PRIVATE, contact_id: (User.last.id + 100) }.merge(id: note.id + 100), {})
    assert_response 404
  end

  def test_update_contact_note_success
    note = _create_contact_note(@contact, @agent)
    params_hash = update_note_params_hash
    put :update, construct_params(contact_unwrapped_params.merge(id: note.id), params_hash)
    assert_response 200
    note = ContactNote.find(note.id)
    match_json(contact_note_pattern(params_hash, note))
    match_json(contact_note_pattern({}, note))
  end

  def test_update_contact_note_with_attachment_and_attachment_ids
    note = _create_contact_note(@contact, @agent)
    attachment_id = create_attachment(attachable_type: 'UserDraft', attachable_id: @agent.id).id
    file1 = fixture_file_upload('files/attachment.txt', 'text/plain', :binary)
    file2 = fixture_file_upload('files/image33kb.jpg', 'image/jpg')
    attachments = [file1, file2]
    params_hash = update_note_params_hash.merge(attachment_ids: [attachment_id], attachments: attachments)
    DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
    @request.env['CONTENT_TYPE'] = 'multipart/form-data'
    put :update, construct_params(contact_unwrapped_params.merge(id: note.id), params_hash)
    DataTypeValidator.any_instance.unstub(:valid_type?)
    assert_response 200
    note = ContactNote.find(note.id)
    match_json(contact_note_pattern(params_hash, note))
    match_json(contact_note_pattern({}, note))
    assert note.attachments.size == (attachments.size + 1)
  end

  # def test_update_contact_note_with_cloud_files
  #   cloud_file_params = [{ filename: 'image.jpg', url: CLOUD_FILE_IMAGE_URL, application_id: 20 }]
  #   params_hash = update_note_params_hash.merge(cloud_files: cloud_file_params)
  #   note = _create_contact_note(@contact, @agent)
  #   put :update, construct_params(contact_unwrapped_params.merge(id: note.id), params_hash)
  #   assert_response 200
  #   note = ContactNote.find(note.id)
  #   match_json(contact_note_pattern(params_hash, note))
  #   match_json(contact_note_pattern({}, note))
  #   assert_equal 1, note.cloud_files.count
  # end

  def test_delete_contact_note
    note = _create_contact_note(@contact, @agent)
    delete :destroy, construct_params(contact_unwrapped_params.merge(id: note.id), {})
    assert_response 204
    assert_nil @contact.contact_notes.find_by_id(note.id)
  end

  def test_show_contact_note
    note = _create_contact_note(@contact, @agent)
    get :show, construct_params(contact_unwrapped_params.merge(id: note.id), {})
    assert_response 200
    match_json(contact_note_pattern({}, note))
  end

  def test_index_contact_note_per_page
    user = add_new_user(@account)
    contact_notes = []
    3.times do
      contact_notes << _create_contact_note(user, @agent)
    end
    per_page = user.contact_notes.count - 1
    get :index, controller_params(version: PRIVATE, contact_id: user.id, per_page: per_page)
    assert_response 200
    assert JSON.parse(response.body).count == per_page
    assert_equal "<http://#{@request.host}/api/_/contacts/#{user.id}/notes?per_page=#{per_page}&page=2>; rel=\"next\"", response.headers['Link']

    get :index, controller_params(version: PRIVATE, contact_id: user.id, per_page: per_page, page: 2)
    assert_response 200
    assert JSON.parse(response.body).count == 1
    assert_nil response.headers['Link']
  end

  def test_index_contact_note_pattern
    contact_notes = []
    3.times do
      contact_notes << _create_contact_note(@contact, @agent)
    end
    get :index, controller_params(contact_unwrapped_params)
    assert_response 200
    assert JSON.parse(response.body).count == contact_notes.count
    match_json(contact_notes.map { |note| contact_note_pattern({}, note) })
  end

  def test_index_contact_note_max_per_page
    get :index, controller_params(contact_unwrapped_params.merge(per_page: 101))
    assert_response 400
    match_json([bad_request_error_pattern(:per_page, :per_page_invalid, max_value: '100', code: :invalid_value)])
  end

  def test_index_contact_note_invalid_contact
    get :index, controller_params(contact_unwrapped_params.merge(per_page: 1, contact_id: User.last.id + 10))
    assert_response 404
  end

  def test_create_contact_note_without_feature
    @account.revoke_feature(:contact_company_notes)
    params_hash = create_note_params_hash
    post :create, construct_params(contact_unwrapped_params, params_hash)
    assert_response 403
    match_json(request_error_pattern('require_feature', feature: 'Contact Company Notes'))
    @account.add_feature(:contact_company_notes)
  end

  def test_create_contact_note_with_xss_payload
    params_hash = create_note_params_hash
    params_hash['body'] = "<div>xss check<style onload=alert(document.cookie)></div>"
    post :create, construct_params(contact_unwrapped_params, params_hash)
    assert_response 201
    parsed_response = parse_response response.body
    assert_equal(parsed_response['body'], '<div>xss check</div>')
  end

  def test_update_contact_note_with_xss_payload
    note = _create_contact_note(@contact, @agent)
    params_hash = update_note_params_hash
    params_hash['body'] = "<div>xss check<style onload=alert(document.cookie)></div>"
    put :update, construct_params(contact_unwrapped_params.merge(id: note.id), params_hash)
    assert_response 200
    parsed_response = parse_response response.body
    assert_equal(parsed_response['body'], '<div>xss check</div>')
  end

  # Company notes test cases

  def test_create_company_note
    params_hash = create_note_params_hash
    post :create, construct_params(company_unwrapped_params, params_hash)
    assert_response 201
    match_json(company_note_pattern(params_hash, CompanyNote.last))
    match_json(company_note_pattern({}, CompanyNote.last))
  end

  def test_create_company_note_with_category_id
    params_hash = create_note_params_hash.merge(category_id: 1)
    post :create, construct_params(company_unwrapped_params, params_hash)
    assert_response 201
    match_json(company_note_pattern(params_hash, CompanyNote.last))
    match_json(company_note_pattern({}, CompanyNote.last))
  end

  def test_create_company_note_with_invalid_category_id
    params_hash = create_note_params_hash.merge(category_id: 3)
    post :create, construct_params(company_unwrapped_params, params_hash)
    assert_response 400
    match_json([bad_request_error_pattern(:category_id, :"is not included in the list", code: :invalid_value)])
  end

  def test_create_company_note_to_invalid_company
    post :create, construct_params({ version: PRIVATE, company_id: (Company.last.id + 100) }, {})
    assert_response 404
  end

  def test_create_company_note_by_invalid_title_length
    params_hash = create_note_params_hash.merge(title: Faker::Lorem.characters(257))
    post :create, construct_params(company_unwrapped_params, params_hash)
    assert_response 400
    match_json([bad_request_error_pattern(
      :title, :"is too long (maximum is 256 characters)",
      code: :invalid_value
    )])
  end

  def test_create_company_note_invalid_attachment_ids_type
    attachment_ids = %w(A B C)
    params_hash = create_note_params_hash.merge(attachment_ids: attachment_ids)
    post :create, construct_params(company_unwrapped_params, params_hash)
    match_json([bad_request_error_pattern(
      :attachment_ids,
      :array_datatype_mismatch,
      expected_data_type: 'Positive Integer'
    )])
    assert_response 400
  end

  def test_create_company_note_invalid_attachment_ids
    attachment_ids = []
    attachment_ids << create_attachment(attachable_type: 'UserDraft', attachable_id: @created_by_contact).id
    invalid_ids = [attachment_ids.last + 50, attachment_ids.last + 60]
    params_hash = create_note_params_hash.merge(attachment_ids: (attachment_ids | invalid_ids))
    post :create, construct_params(company_unwrapped_params, params_hash)
    match_json([bad_request_error_pattern(:attachment_ids, :invalid_list, list: invalid_ids.join(', '))])
    assert_response 400
  end

  def test_create_company_note_invalid_attachment_size
    attachment_ids = []
    attachment_ids << create_attachment(attachable_type: 'UserDraft', attachable_id: @created_by_contact).id
    invalid_attachment_limit = @account.attachment_limit + 1
    Helpdesk::Attachment.any_instance.stubs(:content_file_size).returns(invalid_attachment_limit.megabytes)
    params_hash = create_note_params_hash.merge(attachment_ids: attachment_ids)
    post :create, construct_params(company_unwrapped_params, params_hash)
    Helpdesk::Attachment.any_instance.unstub(:content_file_size)
    match_json([bad_request_error_pattern(:attachment_ids, :invalid_size, max_size: "#{@account.attachment_limit} MB", current_size: "#{invalid_attachment_limit} MB")])
    assert_response 400
  end

  def test_create_company_note_attachment_id
    attachment_id = create_attachment(attachable_type: 'UserDraft', attachable_id: @created_by_contact).id
    params_hash = create_note_params_hash.merge(attachment_ids: [attachment_id])
    post :create, construct_params(company_unwrapped_params, params_hash)
    assert_response 201
    match_json(company_note_pattern(params_hash, CompanyNote.last))
    match_json(company_note_pattern({}, CompanyNote.last))
    assert CompanyNote.last.attachments.size == 1
  end

  def test_create_company_note_with_attachment_ids
    attachment_ids = []
    BULK_ATTACHMENT_CREATE_COUNT.times do
      attachment_ids << create_attachment(attachable_type: 'UserDraft', attachable_id: @created_by_contact.id).id
    end
    params_hash = create_note_params_hash.merge(attachment_ids: attachment_ids)
    post :create, construct_params(company_unwrapped_params, params_hash)
    assert_response 201
    match_json(company_note_pattern(params_hash, CompanyNote.last))
    match_json(company_note_pattern({}, CompanyNote.last))
    assert CompanyNote.last.attachments.size == attachment_ids.size
  end

  def test_create_company_note_with_attachment
    file = fixture_file_upload('files/attachment.txt', 'plain/text', :binary)
    file2 = fixture_file_upload('files/image33kb.jpg', 'image/jpg')
    params = create_note_params_hash.merge('attachments' => [file, file2])
    DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
    post :create, construct_params(company_unwrapped_params, params)
    DataTypeValidator.any_instance.unstub(:valid_type?)
    assert_response 201
    response_params = params.except(:attachments)
    match_json(company_note_pattern(params, CompanyNote.last))
    match_json(company_note_pattern({}, CompanyNote.last))
    assert CompanyNote.last.attachments.count == 2
  end

  def test_create_company_note_with_attachment_and_attachment_ids
    attachment_id = create_attachment(attachable_type: 'UserDraft', attachable_id: @agent.id).id
    file1 = fixture_file_upload('files/attachment.txt', 'text/plain', :binary)
    file2 = fixture_file_upload('files/image33kb.jpg', 'image/jpg')
    attachments = [file1, file2]
    params_hash = create_note_params_hash.merge(attachment_ids: [attachment_id], attachments: attachments)
    DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
    @request.env['CONTENT_TYPE'] = 'multipart/form-data'
    post :create, construct_params(company_unwrapped_params, params_hash)
    DataTypeValidator.any_instance.unstub(:valid_type?)
    assert_response 201
    match_json(company_note_pattern(params_hash, CompanyNote.last))
    match_json(company_note_pattern({}, CompanyNote.last))
    assert CompanyNote.last.attachments.size == (attachments.size + 1)
  end

  def test_create_company_note_with_invalid_attachment_params_format
    params = create_note_params_hash.merge('attachments' => [1, 2])
    post :create, construct_params(company_unwrapped_params, params)
    assert_response 400
    match_json([bad_request_error_pattern('attachments', :array_datatype_mismatch, expected_data_type: 'valid file format')])
  end

  def test_create_company_note_with_attachment_invalid_size
    Rack::Test::UploadedFile.any_instance.stubs(:size).returns(20_000_000)
    file = fixture_file_upload('/files/attachment.txt', 'plain/text', :binary)
    params = create_note_params_hash.merge('attachments' => [file])
    DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
    post :create, construct_params(company_unwrapped_params, params)
    DataTypeValidator.any_instance.unstub(:valid_type?)
    assert_response 400
    match_json([bad_request_error_pattern('attachments', :invalid_size, max_size: '15 MB', current_size: '19.1 MB')])
  end

  # def test_create_company_note_with_cloud_files_upload
  #   cloud_file_params = [{ filename: 'image.jpg', url: CLOUD_FILE_IMAGE_URL, application_id: 20 }]
  #   params = create_note_params_hash.merge(cloud_files: cloud_file_params)
  #   post :create, construct_params(company_unwrapped_params, params)
  #   assert_response 201
  #   match_json(company_note_pattern(params, CompanyNote.last))
  #   match_json(company_note_pattern({}, CompanyNote.last))
  #   assert CompanyNote.last.cloud_files.count == 1
  # end

  def test_update_company_note_to_invalid_company
    note = _create_company_note(@company, @agent)
    put :update, construct_params({ version: PRIVATE, company_id: (Company.last.id + 100) }.merge(id: note.id), {})
    assert_response 404
  end

  def test_update_company_note_to_invalid_note
    note = _create_company_note(@company, @agent)
    put :update, construct_params({ version: PRIVATE, company_id: (Company.last.id) }.merge(id: note.id + 100), {})
    assert_response 404
  end

  def test_update_company_note_success
    note = _create_company_note(@company, @agent)
    params_hash = update_note_params_hash
    put :update, construct_params(company_unwrapped_params.merge(id: note.id), params_hash)
    assert_response 200
    note = CompanyNote.find(note.id)
    match_json(company_note_pattern(params_hash, note))
    match_json(company_note_pattern({}, note))
  end

  def test_update_company_note_with_attachment_and_attachment_ids
    note = _create_company_note(@company, @agent)
    attachment_id = create_attachment(attachable_type: 'UserDraft', attachable_id: @agent.id).id
    file1 = fixture_file_upload('files/attachment.txt', 'text/plain', :binary)
    file2 = fixture_file_upload('files/image33kb.jpg', 'image/jpg')
    attachments = [file1, file2]
    params_hash = update_note_params_hash.merge(attachment_ids: [attachment_id], attachments: attachments)
    DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
    @request.env['CONTENT_TYPE'] = 'multipart/form-data'
    put :update, construct_params(company_unwrapped_params.merge(id: note.id), params_hash)
    DataTypeValidator.any_instance.unstub(:valid_type?)
    assert_response 200
    note = CompanyNote.find(note.id)
    match_json(company_note_pattern(params_hash, note))
    match_json(company_note_pattern({}, note))
    assert note.attachments.size == (attachments.size + 1)
  end

  # def test_update_company_note_with_cloud_files
  #   cloud_file_params = [{ filename: 'image.jpg', url: CLOUD_FILE_IMAGE_URL, application_id: 20 }]
  #   params_hash = update_note_params_hash.merge(cloud_files: cloud_file_params)
  #   note = _create_company_note(@company, @agent)
  #   put :update, construct_params(company_unwrapped_params.merge(id: note.id), params_hash)
  #   assert_response 200
  #   note = CompanyNote.find(note.id)
  #   match_json(company_note_pattern(params_hash, note))
  #   match_json(company_note_pattern({}, note))
  #   assert_equal 1, note.cloud_files.count
  # end

  def test_delete_company_note
    note = _create_company_note(@company, @agent)
    delete :destroy, construct_params(company_unwrapped_params.merge(id: note.id), {})
    assert_response 204
    assert_nil @company.notes.find_by_id(note.id)
  end

  def test_show_company_note
    note = _create_company_note(@company, @agent)
    get :show, construct_params(company_unwrapped_params.merge(id: note.id), {})
    assert_response 200
    match_json(company_note_pattern({}, note))
  end

  def test_index_company_note_per_page
    company = create_company
    company_notes = []
    3.times do
      company_notes << _create_company_note(company, @agent)
    end
    per_page = company.notes.count - 1
    get :index, controller_params(version: PRIVATE, company_id: company.id, per_page: per_page)
    assert_response 200
    assert JSON.parse(response.body).count == per_page
    assert_equal "<http://#{@request.host}/api/_/companies/#{company.id}/notes?per_page=#{per_page}&page=2>; rel=\"next\"", response.headers['Link']

    get :index, controller_params(version: PRIVATE, company_id: company.id, per_page: per_page, page: 2)
    assert_response 200
    assert JSON.parse(response.body).count == 1
    assert_nil response.headers['Link']
  end

  def test_index_company_note_pattern
    company = create_company
    company_notes = []
    3.times do
      company_notes << _create_company_note(company, @agent)
    end
    get :index, controller_params(version: PRIVATE, company_id: company.id)
    assert_response 200
    assert JSON.parse(response.body).count == 3
    match_json(company_notes.map { |note| company_note_pattern({}, note) })
  end

  def test_index_company_note_max_per_page
    get :index, controller_params(company_unwrapped_params.merge(per_page: 101))
    assert_response 400
    match_json([bad_request_error_pattern(:per_page, :per_page_invalid, max_value: '100', code: :invalid_value)])
  end

  def test_index_company_note_invalid_company
    get :index, controller_params(company_unwrapped_params.merge(per_page: 1, company_id: Company.last.id + 10))
    assert_response 404
  end

  def test_create_company_note_without_feature
    @account.revoke_feature(:contact_company_notes)
    params_hash = create_note_params_hash
    post :create, construct_params(company_unwrapped_params, params_hash)
    assert_response 403
    match_json(request_error_pattern('require_feature', feature: 'Contact Company Notes'))
    @account.add_feature(:contact_company_notes)
  end

  def test_create_company_note_with_xss_payload
    params_hash = create_note_params_hash
    params_hash['body'] = "<div>xss check<style onload=alert(document.cookie)></div>"
    post :create, construct_params(company_unwrapped_params, params_hash)
    assert_response 201
    parsed_response = parse_response response.body
    assert_equal(parsed_response['body'], '<div>xss check</div>')
  end

  def test_update_company_note_with_xss_payload
    note = _create_contact_note(@contact, @agent)
    params_hash = update_note_params_hash
    params_hash['body'] = "<div>xss check<style onload=alert(document.cookie)></div>"
    put :update, construct_params(company_unwrapped_params.merge(id: note.id), params_hash)
    assert_response 200
    parsed_response = parse_response response.body
    assert_equal(parsed_response['body'], '<div>xss check</div>')
  end
end
