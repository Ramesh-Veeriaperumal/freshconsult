require_relative '../../test_helper'

class ApiRolesQueriesTest < ActionDispatch::IntegrationTest
  include RolesTestHelper
  def test_query_count
    v1 = {}
    v2 = {}
    v2_expected = {
      api_show: 1,
      api_index: 1,

      show: 11,
      index: 11
    }

    role = create_role(name: Faker::Name.name, privilege_list: ['manage_tickets', 'edit_ticket_properties', 'view_forums', 'view_contacts',
                                                                'view_reports', '', '0', '0', '0', '0'])
    id1 = role.id
    id2 = create_role(name: Faker::Name.name, privilege_list: ['view_forums', 'view_contacts', 'view_reports', '', '0', '0', '0', '0']).id
    # show
    v2[:show], v2[:api_show], v2[:show_queries] = count_api_queries do
      get("/api/v2/roles/#{id1}", nil, @headers)
      assert_response 200
    end

    v1[:show] = count_queries do
      get("/admin/roles/#{id2}.json", nil, @headers)
      assert_response 302
    end

    # index
    v2[:index], v2[:api_index], v2[:index_queries] = count_api_queries do
      get('/api/v2/products', nil, @headers)
      assert_response 200
    end
    v1[:index] = count_queries do
      get('/admin/roles.json', nil, @headers)
      assert_response 200
    end

    write_to_file(nil, v2)

    Rails.logger.error "V1: #{v1.inspect}, V2: #{v2.inspect}, V2_Expected: #{v2_expected.inspect}"

    v1.keys.each do |key|
      api_key = "api_#{key}".to_sym
      assert v2[key] <= v1[key]
      assert_equal v2_expected[api_key], v2[api_key]
      assert_equal v2_expected[key], v2[key]
    end
  end
end
