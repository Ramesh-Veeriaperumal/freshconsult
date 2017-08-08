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
      get :index, controller_params({version: 'private', type: "contact"})
      assert_response 404
    end

    def test_index_with_no_existing_company_import
      remove_company_import_if_exists
      get :index, controller_params({version: 'private', type: "company"})
      assert_response 404
    end

    def test_index_with_existing_contact_import
      @account.create_contact_import({ import_status: Admin::DataImport::IMPORT_STATUS[:started] }) if @account.reload.contact_import.nil?
      get :index, controller_params({version: 'private', type: "contact"})
      assert_response 204
    end

    def test_index_with_existing_company_import
      @account.create_company_import({ import_status: Admin::DataImport::IMPORT_STATUS[:started] }) if @account.reload.company_import.nil?
      get :index, controller_params({version: 'private', type: "company"})
      assert_response 204
    end

    def test_index_with_invalid_type_param
      get :index, controller_params({version: 'private', type: Faker::Lorem.characters(8)})
      match_json(invalid_type_error_response)
      assert_response 400
    end

    def test_import_contacts
      remove_contact_import_if_exists
      post :create, construct_params(import_contacts_params)
      assert_response 204
    end

    def test_import_companies
      remove_company_import_if_exists
      post :create, construct_params(import_companies_params)
      assert_response 204
    end

    def test_create_import_for_400_on_invalid_file_format
      remove_contact_import_if_exists
      request_params = { version: 'private', 
          type: 'contact', 
          file: fixture_file_upload("/files/attachment.txt", 'txt'),
          fields: { name: "1",
          email: "0",
          job_title: "3" }
           }
      post :create, construct_params(request_params)
      assert_response 400
    end

    def test_upload_csv_for_409_on_existing_import_in_progress
      @account.create_contact_import({ import_status: Admin::DataImport::IMPORT_STATUS[:started] }) if @account.reload.contact_import.nil?
      @account.reload
      post :create, construct_params(import_contacts_params)
      assert_response 409
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
        type: 'contact', 
        file: fixture_file_upload('files/contacts_import.csv', 'text/csv', :binary),
        fields: { name: "1",
        email: "0",
        job_title: "3" } }
    end

    def import_companies_params
      { version: 'private', 
        type: 'company', 
        file: fixture_file_upload('files/companies_import.csv', 'text/csv', :binary),
        fields: { name: "1",
        email: "0",
        job_title: "3" } }
    end    

    def invalid_type_error_response
      { "description" => "Validation failed", 
        "errors"      => [ {  "field"  =>"type",
                              "message"=>"It should be one of these values: 'contact,company'",
                              "code"   =>"invalid_value"
                            } ]
      }
    end
  end
end