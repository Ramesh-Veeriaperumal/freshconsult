require_relative '../test_helper'

class ApiGroupsIntegrationTest < ActionDispatch::IntegrationTest
  include Helpers::GroupsHelper
  def test_query_count
    skip_bullet do
      v2 = {}
      v1 = {}
      v2_expected = {
        api_create: 9,
        api_show: 1,
        api_update: 7,
        api_index: 0,
        api_destroy: 11,

        create: 23,
        show: 13,
        update: 21,
        index: 12,
        destroy: 36
      }

      v2_payload = v2_group_payload

      # create
      v2[:create], v2[:api_create], v2[:create_queries] = count_api_queries do
        post('/api/v2/groups', v2_payload, @write_headers)
        assert_response 201
      end
      v1[:create] = count_queries do
        post('/groups.json', group_payload, @write_headers)
        assert_response 201
      end
      id1 = Group.last(2).first.id
      id2 = Group.last.id
      # show
      v2[:show], v2[:api_show], v2[:show_queries] = count_api_queries do
        get("/api/v2/groups/#{id1}", nil, @headers)
        assert_response 200
      end
      v1[:show] = count_queries do
        get("/groups/#{id2}.json", nil, @headers)
        assert_response 200
      end
      # update
      v2[:update], v2[:api_update], v2[:update_queries] = count_api_queries do
        put("/api/v2/groups/#{id1}", v2_payload, @write_headers)
        assert_response 200
      end
      v1[:update] = count_queries do
        put("/groups/#{id2}.json", group_payload, @write_headers)
        assert_response 200
      end
      # index
      v2[:index], v2[:api_index], v2[:index_queries] = count_api_queries do
        get('/api/v2/groups', nil, @headers)
        assert_response 200
      end
      v1[:index] = count_queries do
        get('/groups.json', nil, @headers)
        assert_response 200
      end
      # destroy

      v2[:destroy], v2[:api_destroy], v2[:destroy_queries] = count_api_queries do
        delete("/api/v2/groups/#{id1}", nil, @headers)
        assert_response 204
      end
      v1[:destroy] = count_queries do
        delete("/groups/#{id2}.json", nil, @headers)
        assert_response 200
      end

      write_to_file(v1, v2)

      v1.keys.each do |key|
        api_key = "api_#{key}".to_sym
        assert v2[key] <= (v1[key] + 1) # Plus 1 because of the cache usage in api_groups_controller for features check
        assert_equal v2_expected[api_key], v2[api_key]
        assert_equal v2_expected[key], v2[key]
      end
    end
  end
end
