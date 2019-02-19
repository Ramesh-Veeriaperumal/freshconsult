require_relative '../../unit_test_helper'

module Proactive
  class SimpleOutreachValidationTest < ActionView::TestCase

    def create_simple_outreach_params
      {
         name: Faker::Lorem.characters(10),
         description:Faker::Lorem.paragraph(15),
         action:{
            email: {
               subject: Faker::Lorem.paragraph(10),
               description: "<div>#{Faker::Lorem.paragraph(10)}</div>",
               email: Faker::Internet.email,
               email_config_id: 1,
               schedule_details:{
                  type: 'immediately'
               }
            }
         }
      }
    end

    def import_selection
      {
        type: 'import',
        contact_import: {
          attachment_id: Faker::Number.number(3),
          attachment_file_name: Faker::Lorem.characters(10),
          fields: {
            name: 2, 
            email: 7
          }
        }
      }
    end

    def test_simple_outreach_without_type
      params_hash = create_simple_outreach_params
      params_hash[:selection] = import_selection
      params_hash[:selection].delete(:type)
      validator = ::Proactive::SimpleOutreachValidation.new(params_hash)
      refute validator.valid?(:create)
    end

    def test_simple_outreach_with_import
      params_hash = create_simple_outreach_params
      params_hash[:selection] = import_selection
      validator = ::Proactive::SimpleOutreachValidation.new(params_hash)
      assert validator.valid?(:create)
    end

    def test_simple_outreach_with_invalid_type
      params_hash = create_simple_outreach_params
      params_hash[:selection] = import_selection
      params_hash[:selection][:type] = 'imports'
      validator = ::Proactive::SimpleOutreachValidation.new(params_hash)
      refute validator.valid?(:create)
    end

    def test_simple_outreach_without_contact_import
      params_hash = create_simple_outreach_params
      params_hash[:selection] = import_selection
      params_hash[:selection].delete(:contact_import)
      validator = ::Proactive::SimpleOutreachValidation.new(params_hash)
      refute validator.valid?(:create)
    end

    def test_simple_outreach_with_contact_import_blank
      params_hash = create_simple_outreach_params
      params_hash[:selection] = import_selection
      params_hash[:selection][:contact_import] = {}
      validator = ::Proactive::SimpleOutreachValidation.new(params_hash)
      refute validator.valid?(:create)
    end
  end
end
