# frozen_string_literal: true

require_relative '../../../api/api_test_helper'
['user_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }
['tickets_test_helper.rb'].each { |file| require "#{Rails.root}/test/core/helpers/#{file}" }
['archive_ticket_test_helper.rb'].each { |file| require "#{Rails.root}/test/api/helpers/#{file}" }
['company_helper.rb'].each { |file| require "#{Rails.root}/test/lib/helpers/#{file}" }

class Support::ArchiveTicketsControllerFlowTest < ActionDispatch::IntegrationTest
  include CoreTicketsTestHelper
  include UsersHelper
  include ArchiveTicketTestHelper
  include ExportCsvUtil
  include Support::ArchiveTicketsHelper
  include PrivilegesHelper
  include ApiCompanyHelper
  ARCHIVE_DAYS = 120

  def test_show_archive_tickets
    @account.enable_ticket_archiving(ARCHIVE_DAYS)
    @account.features.send(:archive_tickets).create
    user = add_new_user(@account, active: true)
    create_archive_ticket_with_assoc(created_at: 150.days.ago, updated_at: 150.days.ago, create_association: true, requester_id: user.id)
    Account.any_instance.stubs(:features_included?).returns(true)
    Helpdesk::ArchiveTicket.any_instance.stubs(:read_from_s3).returns(@archive_association)
    set_request_auth_headers(user)
    account_wrap(user) do
      get "/support/tickets/archived/#{@archive_ticket.display_id}", version: :private
    end
    assert response.body.include? @archive_ticket.subject
  ensure
    Account.any_instance.unstub(:features_included?)
    Helpdesk::ArchiveTicket.any_instance.unstub(:read_from_s3)
  end

  def test_show_archive_tickets_without_feature
    @account.enable_ticket_archiving(ARCHIVE_DAYS)
    @account.features.send(:archive_tickets).create
    user = add_new_user(@account, active: true)
    create_archive_ticket_with_assoc(created_at: 150.days.ago, updated_at: 150.days.ago, create_association: true, requester_id: user.id)
    Account.any_instance.stubs(:features_included?).returns(true)
    Account.any_instance.stubs(:features_included?).with(:archive_tickets).returns(false)
    Account.any_instance.stubs(:features_included?).with(:single_session_per_user).returns(false)
    Helpdesk::ArchiveTicket.any_instance.stubs(:read_from_s3).returns(@archive_association)
    set_request_auth_headers(user)
    account_wrap(user) do
      get "/support/tickets/archived/#{@archive_ticket.display_id}", version: :private
    end
    assert_redirected_to support_tickets_url
  ensure
    Helpdesk::ArchiveTicket.any_instance.unstub(:read_from_s3)
    Account.any_instance.unstub(:features_included?)
  end

  def test_show_archive_tickets_without_scope
    @account.enable_ticket_archiving(ARCHIVE_DAYS)
    @account.features.send(:archive_tickets).create
    user = add_new_user(@account, active: true)
    create_archive_ticket_with_assoc(created_at: 150.days.ago, updated_at: 150.days.ago, create_association: true, requester_id: user.id)
    Account.any_instance.stubs(:features_included?).returns(true)
    User.any_instance.stubs(:has_customer_ticket_permission?).returns(false)
    Helpdesk::ArchiveTicket.any_instance.stubs(:read_from_s3).returns(@archive_association)
    set_request_auth_headers(user)
    account_wrap(user) do
      get "/support/tickets/archived/#{@archive_ticket.display_id}", version: :private
    end
    assert_redirected_to safe_send(Helpdesk::ACCESS_DENIED_ROUTE)
  ensure
    Helpdesk::ArchiveTicket.any_instance.unstub(:read_from_s3)
    User.any_instance.unstub(:has_customer_ticket_permission?)
    Account.any_instance.unstub(:features_included?)
  end

  def test_show_archive_tickets_with_current_user_as_agent_not_restricted_in_helpdesk
    @account.enable_ticket_archiving(ARCHIVE_DAYS)
    @account.features.send(:archive_tickets).create
    create_archive_ticket_with_assoc(created_at: 150.days.ago, updated_at: 150.days.ago, create_association: true)
    user = add_test_agent(@account, active: true)
    Account.any_instance.stubs(:features_included?).returns(true)
    Helpdesk::ArchiveTicket.any_instance.stubs(:read_from_s3).returns(@archive_association)
    Helpdesk::ArchiveTicket.any_instance.stubs(:restricted_in_helpdesk?).returns(false)
    set_request_auth_headers(user)
    account_wrap(user) do
      get "/support/tickets/archived/#{@archive_ticket.display_id}", version: :private
    end
    assert_redirected_to helpdesk_ticket_url
  ensure
    Helpdesk::ArchiveTicket.any_instance.unstub(:read_from_s3)
    Helpdesk::ArchiveTicket.any_instance.unstub(:restricted_in_helpdesk?)
    Account.any_instance.unstub(:features_included?)
  end

  def test_show_archive_tickets_without_login
    @account.enable_ticket_archiving(ARCHIVE_DAYS)
    @account.features.send(:archive_tickets).create
    create_archive_ticket_with_assoc(created_at: 150.days.ago, updated_at: 150.days.ago, create_association: true)
    Account.any_instance.stubs(:features_included?).returns(true)
    Helpdesk::ArchiveTicket.any_instance.stubs(:read_from_s3).returns(@archive_association)
    reset_request_headers
    account_wrap do
      get "/support/tickets/archived/#{@archive_ticket.display_id}", version: :private
    end
    assert_redirected_to login_url
  ensure
    Helpdesk::ArchiveTicket.any_instance.unstub(:read_from_s3)
    Account.any_instance.unstub(:features_included?)
  end

  def test_index_archive_tickets
    @account.enable_ticket_archiving(ARCHIVE_DAYS)
    @account.features.send(:archive_tickets).create
    user = add_new_user(@account, active: true)
    create_archive_ticket_with_assoc(created_at: 150.days.ago, updated_at: 150.days.ago, create_association: true, requester_id: user.id)
    Account.any_instance.stubs(:features_included?).returns(true)
    Helpdesk::ArchiveTicket.any_instance.stubs(:read_from_s3).returns(@archive_association)
    set_request_auth_headers(user)
    account_wrap(user) do
      get '/support/tickets/archived', version: :private
    end
    assert response.body.include? support_archive_ticket_path(@archive_ticket.display_id)
  ensure
    Helpdesk::ArchiveTicket.any_instance.unstub(:read_from_s3)
    Account.any_instance.unstub(:features_included?)
  end

  def test_index_archive_tickets_with_contractor_privilege
    @account.enable_ticket_archiving(ARCHIVE_DAYS)
    @account.features.send(:archive_tickets).create
    primary_contact_company = create_company
    user = add_new_contractor(@account, company_ids: [primary_contact_company.id])
    create_archive_ticket_with_assoc(created_at: 150.days.ago, updated_at: 150.days.ago, create_association: true, requester_id: user.id)
    Account.any_instance.stubs(:features_included?).returns(true)
    Helpdesk::ArchiveTicket.any_instance.stubs(:read_from_s3).returns(@archive_association)
    set_request_auth_headers(user)
    User.any_instance.stubs(:privilege?).returns(true)
    account_wrap(user) do
      get '/support/tickets/archived', version: :private, requested_by_company: 0
    end
    assert response.body.include? support_archive_ticket_path(@archive_ticket.display_id)
  ensure
    User.any_instance.unstub(:privilege?)
    Helpdesk::ArchiveTicket.any_instance.unstub(:read_from_s3)
    Account.any_instance.unstub(:features_included?)
  end

  def test_index_archive_tickets_with_contractor_privilege_without_companies
    @account.enable_ticket_archiving(ARCHIVE_DAYS)
    @account.features.send(:archive_tickets).create
    primary_contact_company = create_company
    user = add_new_user(@account, active: true)
    create_archive_ticket_with_assoc(created_at: 150.days.ago, updated_at: 150.days.ago, create_association: true, requester_id: user.id)
    Account.any_instance.stubs(:features_included?).returns(true)
    Helpdesk::ArchiveTicket.any_instance.stubs(:read_from_s3).returns(@archive_association)
    set_request_auth_headers(user)
    User.any_instance.stubs(:privilege?).returns(true)
    account_wrap(user) do
      get '/support/tickets/archived', version: :private, requested_by_company: primary_contact_company.id
    end
    assert_equal response.body.include?(support_archive_ticket_path(@archive_ticket.display_id)), false
    assert_response 200
  ensure
    User.any_instance.unstub(:privilege?)
    Helpdesk::ArchiveTicket.any_instance.unstub(:read_from_s3)
    Account.any_instance.unstub(:features_included?)
  end

  def test_index_archive_tickets_with_contractor_privilege_with_requested_by_company
    @account.enable_ticket_archiving(ARCHIVE_DAYS)
    @account.features.send(:archive_tickets).create
    primary_contact_company = create_company
    user = add_new_contractor(@account, company_ids: [primary_contact_company.id])
    add_privilege(user, :contractor)
    create_archive_ticket_with_assoc(created_at: 150.days.ago, updated_at: 150.days.ago, create_association: true, requester_id: user.id)
    Account.any_instance.stubs(:features_included?).returns(true)
    Helpdesk::ArchiveTicket.any_instance.stubs(:read_from_s3).returns(@archive_association)
    set_request_auth_headers(user)
    User.any_instance.stubs(:privilege?).returns(true)
    account_wrap(user) do
      get '/support/tickets/archived', version: :private, requested_by_company: primary_contact_company.id
    end
    assert response.body.include? support_archive_ticket_path(@archive_ticket.display_id)
  ensure
    User.any_instance.unstub(:privilege?)
    Helpdesk::ArchiveTicket.any_instance.unstub(:read_from_s3)
    Account.any_instance.unstub(:features_included?)
  end

  def test_index_archive_tickets_with_client_manager
    @account.enable_ticket_archiving(ARCHIVE_DAYS)
    @account.features.send(:archive_tickets).create
    primary_contact_company = create_company
    user = add_new_contractor(@account, company_ids: [primary_contact_company.id])
    create_archive_ticket_with_assoc(created_at: 150.days.ago, updated_at: 150.days.ago, create_association: true, requester_id: user.id)
    Account.any_instance.stubs(:features_included?).returns(true)
    Helpdesk::ArchiveTicket.any_instance.stubs(:read_from_s3).returns(@archive_association)
    User.any_instance.stubs(:company_client_manager?).returns(true)
    set_request_auth_headers(user)
    account_wrap(user) do
      get '/support/tickets/archived', version: :private
    end
    assert response.body.include? support_archive_ticket_path(@archive_ticket.display_id)
  ensure
    User.any_instance.unstub(:company_client_manager?)
    Helpdesk::ArchiveTicket.any_instance.unstub(:read_from_s3)
    Account.any_instance.unstub(:features_included?)
  end

  def test_index_archive_tickets_with_client_manager_with_another_requested_by
    @account.enable_ticket_archiving(ARCHIVE_DAYS)
    @account.features.send(:archive_tickets).create
    primary_contact_company = create_company
    user = add_new_contractor(@account, company_ids: [primary_contact_company.id])
    create_archive_ticket_with_assoc(created_at: 150.days.ago, updated_at: 150.days.ago, create_association: true, requester_id: user.id)
    Account.any_instance.stubs(:features_included?).returns(true)
    Helpdesk::ArchiveTicket.any_instance.stubs(:read_from_s3).returns(@archive_association)
    User.any_instance.stubs(:company_client_manager?).returns(true)
    set_request_auth_headers(user)
    account_wrap(user) do
      get '/support/tickets/archived', version: :private, requested_by: user.id
    end
    assert response.body.include? support_archive_ticket_path(@archive_ticket.display_id)
  ensure
    User.any_instance.unstub(:company_client_manager?)
    Helpdesk::ArchiveTicket.any_instance.unstub(:read_from_s3)
    Account.any_instance.unstub(:features_included?)
  end

  def test_index_archive_tickets_without_feature
    @account.enable_ticket_archiving(ARCHIVE_DAYS)
    @account.features.send(:archive_tickets).create
    create_archive_ticket_with_assoc(created_at: 150.days.ago, updated_at: 150.days.ago, create_association: true)
    user = add_new_user(@account, active: true)
    Account.any_instance.stubs(:features_included?).returns(true)
    Account.any_instance.stubs(:features_included?).with(:archive_tickets).returns(false)
    Account.any_instance.stubs(:features_included?).with(:single_session_per_user).returns(false)
    Helpdesk::ArchiveTicket.any_instance.stubs(:read_from_s3).returns(@archive_association)
    set_request_auth_headers(user)
    account_wrap(user) do
      get '/support/tickets/archived', version: :private
    end
    assert_redirected_to support_tickets_url
  ensure
    Account.any_instance.unstub(:features_included?)
    Helpdesk::ArchiveTicket.any_instance.unstub(:read_from_s3)
  end

  def test_index_archive_tickets_without_login
    @account.enable_ticket_archiving(ARCHIVE_DAYS)
    @account.features.send(:archive_tickets).create
    create_archive_ticket_with_assoc(created_at: 150.days.ago, updated_at: 150.days.ago, create_association: true)
    Account.any_instance.stubs(:features_included?).returns(true)
    Helpdesk::ArchiveTicket.any_instance.stubs(:read_from_s3).returns(@archive_association)
    reset_request_headers
    account_wrap do
      get '/support/tickets/archived', version: :private
    end
    assert_redirected_to login_url
  ensure
    Helpdesk::ArchiveTicket.any_instance.unstub(:read_from_s3)
    Account.any_instance.unstub(:features_included?)
  end

  def test_filter_archive_tickets
    @account.enable_ticket_archiving(ARCHIVE_DAYS)
    @account.features.send(:archive_tickets).create
    user = add_new_user(@account, active: true)
    create_archive_ticket_with_assoc(created_at: 150.days.ago, updated_at: 150.days.ago, create_association: true, requester_id: user.id)
    Account.any_instance.stubs(:features_included?).returns(true)
    Helpdesk::ArchiveTicket.any_instance.stubs(:read_from_s3).returns(@archive_association)
    set_request_auth_headers(user)
    account_wrap(user) do
      get '/support/archive_tickets/filter?requested_by=0&wf_filter=archived', version: :private
    end
    assert response.body.include? support_archive_ticket_path(@archive_ticket.display_id)
  ensure
    Helpdesk::ArchiveTicket.any_instance.unstub(:read_from_s3)
    Account.any_instance.unstub(:features_included?)
  end

  def test_filter_archive_tickets_without_feature
    @account.enable_ticket_archiving(ARCHIVE_DAYS)
    @account.features.send(:archive_tickets).create
    create_archive_ticket_with_assoc(created_at: 150.days.ago, updated_at: 150.days.ago, create_association: true)
    user = add_new_user(@account, active: true)
    Account.any_instance.stubs(:features_included?).returns(true)
    Account.any_instance.stubs(:features_included?).with(:archive_tickets).returns(false)
    Account.any_instance.stubs(:features_included?).with(:single_session_per_user).returns(false)
    Helpdesk::ArchiveTicket.any_instance.stubs(:read_from_s3).returns(@archive_association)
    set_request_auth_headers(user)
    account_wrap(user) do
      get '/support/archive_tickets/filter?requested_by=0&wf_filter=archived', version: :private
    end
    assert_redirected_to support_tickets_url
  ensure
    Account.any_instance.unstub(:features_included?)
    Helpdesk::ArchiveTicket.any_instance.unstub(:read_from_s3)
  end

  def test_filter_archive_tickets_without_login
    @account.enable_ticket_archiving(ARCHIVE_DAYS)
    @account.features.send(:archive_tickets).create
    create_archive_ticket_with_assoc(created_at: 150.days.ago, updated_at: 150.days.ago, create_association: true)
    Account.any_instance.stubs(:features_included?).returns(true)
    Helpdesk::ArchiveTicket.any_instance.stubs(:read_from_s3).returns(@archive_association)
    reset_request_headers
    account_wrap do
      get '/support/archive_tickets/filter?requested_by=0&wf_filter=archived', version: :private
    end
    assert_redirected_to login_url
  ensure
    Helpdesk::ArchiveTicket.any_instance.unstub(:read_from_s3)
    Account.any_instance.unstub(:features_included?)
  end

  def test_configure_export_archive_tickets
    @account.features.send(:archive_tickets).create
    account_wrap do
      get '/support/archive_tickets/configure_export', version: :private
    end
    ['display_id', 'status', 'created_at', 'updated_at', 'requester_name'].each do |field_name|
      assert response.body.include?(field_name), "#{field_name} is not included"
    end
  end

  def test_export_xls_archive_tickets
    @account.enable_ticket_archiving(ARCHIVE_DAYS)
    @account.features.send(:archive_tickets).create
    user = add_new_user(@account, active: true)
    create_archive_ticket_with_assoc(created_at: 150.days.ago, updated_at: 150.days.ago, create_association: true, requester_id: user.id)
    Account.any_instance.stubs(:features_included?).returns(true)
    Helpdesk::ArchiveTicket.any_instance.stubs(:read_from_s3).returns(@archive_association)
    set_request_auth_headers(user)
    account_wrap(user) do
      post '/support/archive_tickets/export_csv', version: :private, data_hash: '', format: :xls, date_filter: 180, start_date: 180.days.ago.strftime('%d %b, %Y'), end_date: Time.zone.now.strftime('%d %b, %Y'), export_fields: { display_id: 'ID do ticket', subject: 'Assunto', description: 'test', status_name: 'Status', requester_info: 'E-mail' }
    end
    assert_response 200
  ensure
    Helpdesk::ArchiveTicket.any_instance.unstub(:read_from_s3)
    Account.any_instance.unstub(:features_included?)
  end

  def test_export_csv_archive_tickets
    @account.enable_ticket_archiving(ARCHIVE_DAYS)
    @account.features.send(:archive_tickets).create
    user = add_new_user(@account, active: true)
    create_archive_ticket_with_assoc(created_at: 150.days.ago, updated_at: 150.days.ago, create_association: true, requester_id: user.id)
    Account.any_instance.stubs(:features_included?).returns(true)
    Helpdesk::ArchiveTicket.any_instance.stubs(:read_from_s3).returns(@archive_association)
    set_request_auth_headers(user)
    account_wrap(user) do
      post '/support/archive_tickets/export_csv', version: :private, data_hash: '', format: :csv, date_filter: 180, start_date: 180.days.ago.strftime('%d %b, %Y'), end_date: Time.zone.now.strftime('%d %b, %Y'), a: 'c', i: @archive_ticket.display_id, export_fields: { display_id: 'ID', subject: 'subject', description: 'test', status_name: 'Status', requester_info: 'E-mail' }
    end
    assert_response 200
  ensure
    Helpdesk::ArchiveTicket.any_instance.unstub(:read_from_s3)
    Account.any_instance.unstub(:features_included?)
  end

  private

    def old_ui?
      true
    end
end
