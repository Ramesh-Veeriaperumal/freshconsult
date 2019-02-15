require_relative '../../unit_test_helper'

module Proactive
  class CustomerImportValidationTest < ActionView::TestCase


    def create_import_params
      {
        attachment_id: Faker::Number.number(3).to_i,
        attachment_file_name: Faker::Lorem.characters(10),
        fields: {
          name: 2,
          email: 7
        }
      }
    end


    def test_valid_outreach_import
      customer_import_validation = create_customer_import_validation(create_import_params)
      assert customer_import_validation.valid?(:outreach_create)
    end

    def test_invalid_data_type_attachement_id
      params_hash = create_import_params
      params_hash[:attachment_id] = Faker::Number.number(3)
      customer_import_validation = create_customer_import_validation(params_hash)
      refute customer_import_validation.valid?(:outreach_create)
    end

    def test_attachment_id_not_present
      params_hash = create_import_params
      params_hash.delete(:attachment_id)
      customer_import_validation = create_customer_import_validation(params_hash)
      refute customer_import_validation.valid?(:outreach_create)
    end

    def test_attachment_file_name_not_present
      params_hash = create_import_params
      params_hash.delete(:attachment_file_name)
      customer_import_validation = create_customer_import_validation(params_hash)
      refute customer_import_validation.valid?(:outreach_create)
    end

    private
      def create_customer_import_validation(request_param = {}, import_type = 'contact')
        Account.stubs(:current).returns(Account.first)
        params_hash = request_param.merge(import_type: import_type)
        Proactive::CustomerImportValidation.new(params_hash, nil)
      end
  end
end