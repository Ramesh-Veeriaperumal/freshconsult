require_relative '../../test_helper'
module Proactive
  class SimpleOutreachesControllerTest < ActionController::TestCase
    include ::Proactive::ProactiveJwtAuth
    include EmailConfigsHelper
    def setup
      super
      Account.find(Account.current.id).make_current
      Account.current.add_feature(:proactive_outreach)
    end

    def wrap_cname(params)
      { simple_outreach: params }
    end

    def create_simple_outreach_params
      {
        name: Faker::Lorem.characters(10),
        description: Faker::Lorem.paragraph(15),
        action: {
          email: {
            subject: Faker::Lorem.paragraph(10),
            description: "<div>#{Faker::Lorem.paragraph(10)}</div>",
            email: Faker::Internet.email,
            email_config_id: 1,
            schedule_details: {
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
          attachment_id: Faker::Number.number(3).to_i,
          attachment_file_name: Faker::Lorem.characters(10),
          fields: {
            name: 2,
            email: 7
          }
        }
      }
    end

    def test_create_after_blacklist
      Account.current.launch(:disable_simple_outreach)
      post :create, construct_params({ version: 'private' }, outreach_params)
      assert_response 403
    end

    def outreach_params
      params_hash = create_simple_outreach_params
      params_hash[:selection] = import_selection
      params_hash
    end
  end
end
