require_relative '../../test_helper'
# ['ticket_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }
class Companies::MiscControllerTest < ActionController::TestCase
  include CompaniesTestHelper
  include ContactFieldsHelper
  include UsersTestHelper
  include CustomFieldsTestHelper

  BULK_CREATE_COMPANY_COUNT = 2

  def setup
    super
    initial_setup
  end

  @@initial_setup_run = false

  def initial_setup
    @private_api = true
    return if @@initial_setup_run
    @@initial_setup_run = true
  end


  def create_company(options = {})
    company = @account.companies.find_by_name(options[:name])
    return company if company
    name = options[:name] || Faker::Name.name
    company = FactoryGirl.build(:company, name: name)
    company.account_id = @account.id
    company.avatar = options[:avatar] if options[:avatar]
    company.domains = options[:domains].join(',') if options[:domains].present?
    company.health_score = options[:health_score] if options[:health_score]
    company.account_tier = options[:account_tier] if options[:account_tier]
    company.industry = options[:industry] if options[:industry]
    company.renewal_date = options[:renewal_date] if options[:renewal_date]
    company.save!
    company
  end

  def test_export_csv_with_no_params
    BULK_CREATE_COMPANY_COUNT.times do
      create_company
    end
    DataExport.destroy_all(source: DataExport::EXPORT_TYPE[:company], account_id: @account.id)
    company_form = @account.company_form
    post :export, construct_params(fields: {})
    assert_response 400
    match_json([bad_request_error_pattern(:fields, :blank)])
  end

  def test_export_csv_sidekiq
    create_company_field(company_params(type: 'text', field_type: 'custom_text', label: 'Location', editable_in_signup: 'true'))
    create_company_field(company_params(type: 'boolean', field_type: 'custom_checkbox', label: 'Area of specification', editable_in_signup: 'true'))
    DataExport.destroy_all(source: DataExport::EXPORT_TYPE[:company], account_id: @account.id)
    BULK_CREATE_COMPANY_COUNT.times do
      create_company(@account)
    end

    default_fields = @account.company_form.default_company_fields
    custom_fields = @account.company_form.custom_company_fields
    Export::CompanyWorker.jobs.clear
    params_hash = { fields: { default_fields: default_fields.map(&:name), custom_fields: custom_fields.map(&:name).collect { |x| x[3..-1] } } }
    post :export, construct_params(params_hash)
    assert_response 200
    sidekiq_jobs = Export::CompanyWorker.jobs
    assert_equal 1, sidekiq_jobs.size
    csv_hash = (default_fields | custom_fields).collect { |x| { x.label => x.name } }.inject(&:merge)
    assert_equal csv_hash, sidekiq_jobs.first['args'][0]['csv_hash']
    assert_equal User.current.id, sidekiq_jobs.first['args'][0]['user']
    Export::CompanyWorker.jobs.clear
  end

  def test_export_csv_with_invalid_params
    BULK_CREATE_COMPANY_COUNT.times do
      create_company
    end
    DataExport.destroy_all(source: DataExport::EXPORT_TYPE[:company], account_id: @account.id)

    company_form = @account.company_form
    create_company_field(company_params(type: 'text', field_type: 'custom_text', label: 'Location', editable_in_signup: 'true'))
    params_hash = { fields: { default_fields: [Faker::Lorem.word], custom_fields: [Faker::Lorem.word] } }
    post :export, construct_params(params_hash)
    assert_response 400
    match_json([bad_request_error_pattern(:default_fields, :not_included, list: company_form.default_company_fields.map(&:name).join(',')),
                bad_request_error_pattern(:custom_fields, :not_included, list: company_form.custom_company_fields.map(&:name).collect { |x| x[3..-1] }.join(','))])
  end

  def test_export_csv_with_limit_reach
    create_company_field(company_params(type: 'text', field_type: 'custom_text', label: 'Area', editable_in_signup: 'true'))
    create_company_field(company_params(type: 'boolean', field_type: 'custom_checkbox', label: 'Metropolitian City', editable_in_signup: 'true'))
    create_company_field(company_params(type: 'date', field_type: 'custom_date', label: 'Joining date', editable_in_signup: 'true'))
    BULK_CREATE_COMPANY_COUNT.times do
      create_company(@account)
    end
    default_fields = @account.company_form.default_company_fields
    custom_fields = @account.company_form.custom_company_fields
    DataExport.company_export_limit.times do
      export_entry = @account.data_exports.new(source: DataExport::EXPORT_TYPE['company'.to_sym],
                                               user: User.current,
                                               status: DataExport::EXPORT_STATUS[:started])
      export_entry.save
    end
    params_hash = { fields: { default_fields: default_fields.map(&:name) - ['tag_names'], custom_fields: custom_fields.map(&:name).collect { |x| x[3..-1] } } }
    post :export, construct_params(params_hash)
    assert_response 429
  end

  def test_export_csv_details_completed
    DataExport.destroy_all(source: DataExport::EXPORT_TYPE[:company], account_id: @account.id)
    export_entry = @account.data_exports.new(source: DataExport::EXPORT_TYPE['company'.to_sym],
                                             user: User.current,
                                             status: DataExport::EXPORT_STATUS[:completed],
                                             token: Faker::Number.number(10))
    export_entry.save
    attachment = create_attachment(attachable_type: 'DataExport', attachable_id: export_entry.id)
    AwsWrapper::S3.stubs(:presigned_url).returns('spec/fixtures/files/attachment.csv')
    get :export_details, construct_params(id: export_entry.token)
    assert_response 200
    match_json(id: export_entry.token,
               status: 'completed',
               download_url: 'spec/fixtures/files/attachment.csv')
    AwsWrapper::S3.unstub(:presigned_url)
  end

  def test_export_csv_details_with_invalid_token
    DataExport.destroy_all(source: DataExport::EXPORT_TYPE[:company], account_id: @account.id)
    export_entry = @account.data_exports.new(source: DataExport::EXPORT_TYPE['company'.to_sym],
                                             user: User.current,
                                             status: DataExport::EXPORT_STATUS[:started],
                                             token: Faker::Number.number(10))
    export_entry.save
    get :export_details, construct_params(id: 'abc')
    assert_response 404
  end

  def test_export_csv_details_with_invalid_source
    DataExport.destroy_all(source: DataExport::EXPORT_TYPE[:company], account_id: @account.id)
    export_entry = @account.data_exports.new(
      source: DataExport::EXPORT_TYPE['contact'.to_sym],
      user: User.current,
      status: DataExport::EXPORT_STATUS[:started],
      token: Faker::Number.number(10)
    )
    export_entry.save
    get :export_details, construct_params(id: export_entry.token)
    assert_response 404
  end

  def test_export_csv_details_in_progress
    DataExport.destroy_all(source: DataExport::EXPORT_TYPE[:company], account_id: @account.id)
    export_entry = @account.data_exports.new(
      source: DataExport::EXPORT_TYPE['company'.to_sym],
      user: User.current,
      status: DataExport::EXPORT_STATUS[:started],
      token: Faker::Number.number(10)
    )
    export_entry.save
    get :export_details, construct_params(id: export_entry.token)
    assert_response 200
    match_json(
      id: export_entry.token,
      status: 'in_progress'
    )
  end

  def test_export_csv_without_privilege
    DataExport.destroy_all(source: DataExport::EXPORT_TYPE[:company], account_id: @account.id)
    User.any_instance.stubs(:privilege?).with(:export_customers).returns(false)
    create_company_field(company_params(type: 'text', field_type: 'custom_text', label: 'Area', editable_in_signup: 'true'))
    default_fields = @account.company_form.default_company_fields
    custom_fields = @account.company_form.custom_company_fields
    params_hash = { fields: { default_fields: default_fields.map(&:name) - ['tag_names'], custom_fields: custom_fields.map(&:name).collect { |x| x[3..-1] } } }
    post :export, construct_params(params_hash)
    assert_response 403
    User.any_instance.unstub(:privilege?)
  end

  def test_export_details_without_privilege
    User.any_instance.stubs(:privilege?).with(:export_customers).returns(false)
    DataExport.destroy_all(source: DataExport::EXPORT_TYPE[:company], account_id: @account.id)
    export_entry = @account.data_exports.new(
      source: DataExport::EXPORT_TYPE['company'.to_sym],
      user: User.current,
      status: DataExport::EXPORT_STATUS[:started],
      token: Faker::Number.number(10)
    )
    export_entry.save
    post :export_details, construct_params(id: export_entry.token)
    assert_response 403
    User.any_instance.unstub(:privilege?)
  end

  def test_export_csv_with_invalid_field_params
    BULK_CREATE_COMPANY_COUNT.times do
      create_company(@account)
    end
    contact_form = @account.contact_form
    DataExport.destroy_all(source: DataExport::EXPORT_TYPE[:company], account_id: @account.id)
    post :export, construct_params(invalid_fields: {})
    assert_response 400
  end
end
