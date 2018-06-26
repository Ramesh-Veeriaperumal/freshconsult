require_relative '../../test_helper'
module Ember
  class CustomerImportsControllerTest < ActionController::TestCase

    def setup
      super
      before_all
    end

    def before_all
      @request.env['CONTENT_TYPE'] = 'multipart/form-data'
    end

    def wrap_cname(params)
      { customer_import: params }
    end

    def test_index_with_no_existing_contact_import
      remove_contact_import_if_exists
      get :index, controller_params({version: 'private'})
      assert_response 404
    end

    def test_index_with_no_existing_company_import
      remove_company_import_if_exists
      @request.path = '/api/_/companies/import'
      get :index, controller_params({version: 'private'})
      assert_response 404
    end

    def test_index_with_existing_contact_import
      @account.create_contact_import(import_status: ::Admin::DataImport::IMPORT_STATUS[:started]) if @account.reload.contact_import.nil?
      get :index, controller_params({version: 'private'})
      assert_response 204
    end

    def test_index_with_existing_company_import
      @request.path = '/api/_/companies/import'
      @account.create_company_import(import_status: ::Admin::DataImport::IMPORT_STATUS[:started]) if @account.reload.company_import.nil?
      get :index, controller_params({version: 'private'})
      assert_response 204
    end

    def test_import_contacts
      remove_contact_import_if_exists
      post :create, construct_params(import_contacts_params)
      assert_response 204
    end

    def test_contact_import_destroy
      @account.create_contact_import(import_status: ::Admin::DataImport::IMPORT_STATUS[:started]) if @account.reload.contact_import.nil?
      delete :destroy, construct_params({version: 'private'})
      assert_response 200
      assert_equal true, @account.reload.contact_import.nil?
      match_json({ total_rows: 0, completed_rows: 0 })
    end

    def test_company_import_destroy
      @account.create_company_import(import_status: ::Admin::DataImport::IMPORT_STATUS[:started]) if @account.reload.company_import.nil?
      @request.path = '/api/_/companies/import'
      delete :destroy, construct_params({version: 'private'})
      assert_response 200
      assert_equal true, @account.reload.company_import.nil?
      match_json({ total_rows: 0, completed_rows: 0 })
    end

    def test_contact_import_destroy_when_no_import_is_running
      remove_contact_import_if_exists
      delete :destroy, controller_params({version: 'private'})
      assert_response 404
    end

    def test_company_import_destroy_when_no_import_is_running
      remove_company_import_if_exists
      @request.path = '/api/_/companies/import'
      delete :destroy, controller_params({version: 'private'})
      assert_response 404
    end

    def test_import_companies
      remove_company_import_if_exists
      @request.path = 'api/_/companies/import'
      post :create, construct_params(import_companies_params)
      assert_response 204
    end

    def test_create_import_for_400_on_invalid_file_format
      remove_contact_import_if_exists
      request_params = {
        version: 'private',
        file: fixture_file_upload("/files/attachment.txt", 'txt'),
        fields: { name: "1",
                  email: "0",
                  job_title: "3" 
                }
      }
      post :create, construct_params(request_params)
      assert_response 400
    end

    def test_upload_csv_for_409_on_existing_import_in_progress
      @account.create_contact_import(import_status: ::Admin::DataImport::IMPORT_STATUS[:started]) if @account.reload.contact_import.nil?
      @account.reload
      post :create, construct_params(import_contacts_params)
      assert_response 409
    end

    def test_status_when_no_import_is_running
      remove_contact_import_if_exists
      get :status, controller_params({version: 'private'})
      assert_response 409
    end

    def test_import_status
      @account.create_contact_import(import_status: ::Admin::DataImport::IMPORT_STATUS[:started]) if @account.reload.contact_import.nil?
      @account.reload
      get :status, controller_params({version: 'private'})
      assert_response 200
      match_json import_status_result
    end

    def remove_contact_import_if_exists
      if @account.reload.contact_import
        @account.contact_import.destroy
        @account.reload
      end
    end

    def remove_company_import_if_exists
      if @account.company_import
        @account.company_import.destroy
        @account.reload
      end
    end

    def import_contacts_params
      { version: 'private',
        file: fixture_file_upload('files/contacts_import.csv', 'text/csv', :binary),
        fields: { name: "1",
        email: "0",
        job_title: "3" } }
    end

    def import_companies_params
      { version: 'private',
        file: fixture_file_upload('files/companies_import.csv', 'text/csv', :binary),
        fields: { name: "1",
        email: "0",
        job_title: "3" } }
    end

    def import_status_result
      { 
        total_rows: 2,
        completed_rows: 0,
        percentage: nil,
        time_remaining: nil
      }
    end
  end
end