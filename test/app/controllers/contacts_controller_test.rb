require_relative '../../api/test_helper.rb'
require_relative '../../core/helpers/users_test_helper'
require_relative '../../core/helpers/controller_test_helper'

class ContactsControllerTest < ActionController::TestCase
  include UsersTestHelper
  include ControllerTestHelper

  def test_create_contact
    login_admin

    @user = Account.current.account_managers.first.make_current

    user_email = Faker::Internet.email
    post :create_contact, user: { name: Faker::Name.name, email: user_email, time_zone: 'Chennai', language: 'en' }, format: 'xml'
    user = Account.current.users.find_by_email(user_email)
    assert user.present?

    assert_response 201

    user_email = Faker::Internet.email
    post :create_contact, user: { name: Faker::Name.name, email: user_email, time_zone: 'Chennai', language: 'en' }, format: 'json'
    user = Account.current.users.find_by_email(user_email)
    assert user.present?

    assert_response 200

    user_email = Faker::Internet.email
    post :create_contact, user: { name: Faker::Name.name, email: user_email, time_zone: 'Chennai', language: 'en' }, format: 'nmobile'
    user = Account.current.users.find_by_email(user_email)
    assert user.present?

    assert_response 200
    log_out
  end

  def test_create_contact_duplication
    login_admin

    @user = Account.current.account_managers.first.make_current

    user = Account.current.users.first

    post :create_contact, user: { name: user.name, email: user.email, time_zone: 'Chennai', language: 'en' }
    assert_response 200

    post :create_contact, user: { name: user.name, email: user.email, time_zone: 'Chennai', language: 'en' }, format: 'xml'
    assert_response 422
    assert response.body.include?('Email has already been taken')

    post :create_contact, user: { name: user.name, email: user.email, time_zone: 'Chennai', language: 'en' }, format: 'json'
    assert_response 422
    assert_match Hash[JSON.parse(response.body)]['base'], 'Email has already been taken'

    post :create_contact, user: { name: user.name, email: user.email, time_zone: 'Chennai', language: 'en' }, format: 'nmobile'
    assert_response 200
    assert (response.body).include?('Email has already been taken')
    log_out
  end

  def test_index
    login_admin

    @user = Account.current.account_managers.first.make_current

    get :index, user: {}
    assert_response 200

    get :index, user: {}, format: 'xml'
    assert_response 200

    get :index, user: {}, format: 'json'
    assert_response 200

    get :index, user: {}, format: 'nmobile'
    assert_response 200
    log_out
  end

  def test_update_contact
    login_admin

    @user = Account.current.account_managers.first.make_current

    user = add_agent(@account, agent: 0)

    put :update_contact, id: user.id, user: { email: user.email, job_title: 'Developer', phone: "8787687687" }
    assert_response 302

    User.any_instance.stubs(:update_attributes).returns(false)
    put :update_contact, id: user.id, user: { email: user.email, job_title: 'Developasdfer', phone: "8787687" }
    assert_response 200
    User.any_instance.unstub(:update_attributes)

    log_out
  end

  def test_contact_details_for_ticket
    login_admin

    user_email = Faker::Internet.email
    user = Account.current.users.create(name: Faker::Name.name, email: user_email, time_zone: 'Chennai', company_id: nil, language: 'en', phone: 1234567890)
    assert user.present?

    @user = Account.current.account_managers.first.make_current

    get :contact_details_for_ticket, email: user_email
    assert_response 200

    get :contact_details_for_ticket, phone: user.phone
    assert_response 200

    get :contact_details_for_ticket, { email: user_email, phone: user.phone }
    assert_response 200

    get :contact_details_for_ticket, { email: user_email, phone: user.phone }, format: 'json'
    assert_response 200
    log_out
  end

  def test_hover_card
    login_admin

    @user = Account.current.account_managers.first.make_current

    user_email = Faker::Internet.email
    user = Account.current.users.create(name: Faker::Name.name, email: user_email, time_zone: 'Chennai', company_id: nil, language: 'en')
    assert user.present?

    get :hover_card, id: user.id
    assert_response 200
    log_out
  end

  def test_hover_card_in_new_tab
    login_admin

    @user = Account.current.account_managers.first.make_current

    user_email = Faker::Internet.email
    user = Account.current.users.create(name: Faker::Name.name, email: user_email, time_zone: 'Chennai', company_id: nil, language: 'en')
    assert user.present?

    get :hover_card_in_new_tab, id: user.id
    assert_response 200
    log_out
  end

  def test_contact_email
    login_admin

    @user = Account.current.account_managers.first.make_current

    user_email = Faker::Internet.email
    user = Account.current.users.create(name: Faker::Name.name, email: user_email, time_zone: 'Chennai', company_id: nil, language: 'en')
    assert user.present?

    get :contact_email, email: user.email
    assert_response 200

    get :contact_email, email: 'sampleemail@sample.com'
    assert_response 200
    log_out
  end

  def test_verify_email
    login_admin

    @user = Account.current.account_managers.first.make_current

    user_email = Faker::Internet.email
    user = Account.current.users.create(name: Faker::Name.name, email: user_email, time_zone: 'Chennai', company_id: nil, language: 'en')
    assert user.present?

    get :verify_email, email_id: user.id, format: 'js'
    assert_response 200
    log_out
  end

  def test_show_contact
    login_admin

    @user = Account.current.account_managers.first.make_current

    user_email = Faker::Internet.email
    user = Account.current.users.create(name: Faker::Name.name, email: user_email, time_zone: 'Chennai', company_id: nil, language: 'en')
    assert user.present?

    get :show, email: user.email
    assert_response 200

    user_email = Faker::Internet.email
    user = Account.current.users.create(name: Faker::Name.name, email: user_email, time_zone: 'Chennai', company_id: nil, language: 'en')

    user.preferences[:user_preferences][:agent_deleted_forever] = true

    get :show, email: user_email
    assert_response 302

    user.preferences[:user_preferences][:agent_deleted_forever] = false
    log_out
  end

  def test_view_conversations
    login_admin

    @user = Account.current.account_managers.first.make_current

    user_email = Faker::Internet.email
    user = Account.current.users.create(name: Faker::Name.name, email: user_email, time_zone: 'Chennai', company_id: nil, language: 'en')
    assert user.present?

    get :view_conversations, id: user.id
    assert_response 200
    log_out
  end

  def test_make_agent
    login_admin

    @user = Account.current.account_managers.first.make_current

    user = Account.current.users.create(name: Faker::Name.name, email: Faker::Internet.email, time_zone: 'Chennai', company_id: nil, language: 'en')
    assert user.present?

    get :make_agent, id: user.id
    assert_response 302

    assert Agent.find_by_user_id(user.id).present?
    
    user = Account.current.users.create(name: Faker::Name.name, email: Faker::Internet.email, time_zone: 'Chennai', company_id: nil, language: 'en')
    assert user.present?
    
    User.any_instance.stubs(:make_agent).returns(false)
    get :make_agent, id: user.id
    assert_response 302

    User.any_instance.unstub(:make_agent)

    user = Account.current.users.create(name: Faker::Name.name, email: Faker::Internet.email, time_zone: 'Chennai', company_id: nil, language: 'en')
    assert user.present?

    user.email = ""
    user.save
    assert user.has_email? == false

    get :make_agent, id: user.id, format: 'xml'
    assert_response 400

    get :make_agent, id: user.id, format: 'json'
    assert_response 400

    user = Account.current.users.create(name: Faker::Name.name, email: Faker::Internet.email, time_zone: 'Chennai', company_id: nil, language: 'en')
    assert user.present?

    Account.any_instance.stubs(:reached_agent_limit?).returns(true)

    get :make_agent, id: user.id
    assert_response 302

    get :make_agent, id: user.id, format: 'xml'
    assert_response 400

    get :make_agent, id: user.id, format: 'json'
    assert_response 400

    Account.any_instance.unstub(:reached_agent_limit?)
    log_out
  end

  def test_new_template
    login_admin

    @user = Account.current.account_managers.first.make_current
    get :new, user: {}
    assert_response 200
    log_out
  end

  def test_make_occasional_agent
    login_admin

    @user = Account.current.account_managers.first.make_current

    user_email = Faker::Internet.email
    user = Account.current.users.create(name: Faker::Name.name, email: user_email, time_zone: 'Chennai', company_id: nil, language: 'en')
    assert user.present?

    get :make_occasional_agent, id: user.id
    assert_response 302

    user = Account.current.users.create(name: Faker::Name.name, email: Faker::Internet.email, time_zone: 'Chennai', company_id: nil, language: 'en')
    assert user.present?
    
    User.any_instance.stubs(:make_agent).returns(false)
    get :make_occasional_agent, id: user.id
    assert_response 302

    User.any_instance.unstub(:make_agent)
    log_out
  end

  def test_change_password
    login_admin

    @user = Account.current.account_managers.first.make_current

    user = Account.current.users.create(name: Faker::Name.name, email: Faker::Internet.email, time_zone: 'Chennai', company_id: nil, language: 'en')
    assert user.present?

    get :change_password, id: user.id, user: { email: user.email }
    assert_response 200

    get :change_password, id: user.id, tag: 'ASDFSADF', user: { email: user.email }
    assert_response 404
    log_out
  end

  def test_update_password
    login_admin

    @user = Account.current.account_managers.first.make_current

    user = add_new_user(@account)

    post :update_password, id: user.id, user: { email: user.email, password: 'test1234', password_confirmation: 'test1234' }
    assert_response 302

    post :update_password, id: user.id, user: { email: user.email, password: 'test234', password_confirmation: 'test1234' }
    assert_response 302

    User.any_instance.stubs(:save).returns(false)
    
    post :update_password, id: user.id, user: { email: user.email, password: 'test1234', password_confirmation: 'test1234' }
    assert_response 302

    User.any_instance.unstub(:save)
    log_out
  end

  def test_quick_contact
    login_admin

    @user = Account.current.account_managers.first.make_current

    company = Account.current.companies.create(name: 'ABCD')
    user_email = Faker::Internet.email

    post :quick_contact_with_company, user: { name: Faker::Name.name, email: user_email, time_zone: 'Chennai', company_id: company.id, language: 'en' }
    assert_response 302
  
    User.any_instance.stubs(:signup!).returns(false)
    post :quick_contact_with_company, user: { name: Faker::Name.name, email: user_email, time_zone: 'Chennai', company_id: company.id, language: 'en' }
    assert_response 302
    User.any_instance.unstub(:signup!)
    log_out
  end

  def test_update_description_and_tags
    login_admin

    @user = Account.current.account_managers.first.make_current

    user = add_new_user(@account)

    put :update_description_and_tags, id: user.id, user: { email: user.email, tag: 'test_user, first_tag' }
    assert_response 302

    User.any_instance.stubs(:update_attributes).returns(false)

    put :update_description_and_tags, id: user.id, user: { email: user.email, tag: 'test_user, first_tag' }
    assert_response 200

    put :update_description_and_tags, id: user.id, user: { email: user.email, tag: 'test_user, first_tag' }, format: 'json'
    assert_response 422

    User.any_instance.unstub(:update_attributes)

    User.any_instance.stubs(:update_attributes).raises(RuntimeError)
    Account.current.features.send(:archive_tickets).create

    put :update_description_and_tags, id: user.id, user: { email: user.email, tag: 'test_user, first_tag' }, format: 'json'
    assert_response 200
    Account.current.features.archive_tickets.destroy
    User.any_instance.unstub(:update_attributes)
    log_out
  end

  def test_restore
    login_admin

    @user = Account.current.account_managers.first.make_current

    user = add_new_user(@account)

    user.preferences[:user_preferences][:agent_deleted_forever] = true

    post :restore, id: user.id, user: { email: user.email }
    assert_response 302

    post :restore, id: user.id, user: { email: user.email }, format: 'xml'
    assert_response 400

    post :restore, id: user.id, user: { email: user.email }, format: 'json'
    assert_response 400

    user.preferences[:user_preferences][:agent_deleted_forever] = false
    log_out
  end

  def test_export_csv
    login_admin

    @user = Account.current.account_managers.first.make_current

    post :export_csv
    assert_response 302

    data = Account.current.data_exports.last

    assert data.present?
    assert (data.user_id == @user.id)

    # post :export_csv
    # assert_response 302

    data.status = 5
    data.save

    Account.current.data_exports.each { |x| x.destroy }
    log_out
  end

  def test_configure_export
    login_admin

    @user = Account.current.account_managers.first.make_current
    
    get :configure_export
    assert_response 200
    log_out
  end

  def test_unblock
    login_admin

    @user = Account.current.account_managers.first.make_current

    user = add_new_user(@account, blocked: 1)

    get :unblock, id: user.id, user: { email: user.email }
    assert_response 302
    log_out
  end

  # Create a new company & check whether the company is listed in the autocomplete
  def test_autocomplete
    login_admin

    @user = Account.current.account_managers.first.make_current
    
    company = Account.current.companies.create(name: 'test_company')

    get :autocomplete, id: company.id, v: ['test'], format: 'json'
    response_array = JSON.parse(response.body)

    assert_response 200 # success

    resulted_strings = response_array['results'].first.map { |x, y| y if x == 'value' }
    assert resulted_strings.include?(company.name)
    log_out
  end
end
