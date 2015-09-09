require_relative '../test_helper'

class ApiGroupsIntegrationTest < ActionDispatch::IntegrationTest
  include Helpers::GroupsHelper
  def test_query_count
    skip_bullet do
      v2 = {}
      v1 = {}
      v2_expected = {
        api_create: 1,
        api_show: 1,
        api_update: 5,
        api_index: 0,
        api_destroy: 8,

        create: 14,
        show: 13,
        update: 19,
        index: 13,
        destroy: 23
      }

      # create
      v2[:create], v2[:api_create], v2[:create_queries] = count_api_queries do
        post('/api/v2/groups', v2_group_payload, @write_headers)
        assert_response :created
      end
      v1[:create] = count_queries do
        post('/groups.json', group_payload, @write_headers)
        assert_response :created
      end
      id1 = Group.last(2).first.id
      id2 = Group.last.id
      # show
      v2[:show], v2[:api_show], v2[:show_queries] = count_api_queries do
        get("/api/v2/groups/#{id1}", nil, @headers)
        assert_response :success
      end
      v1[:show] = count_queries do
        get("/groups/#{id2}.json", nil, @headers)
        assert_response :success
      end
      # update
      v2[:update], v2[:api_update], v2[:update_queries] = count_api_queries do
        put("/api/v2/groups/#{id1}", v2_group_payload, @write_headers)
        assert_response :success
      end
      v1[:update] = count_queries do
        put("/groups/#{id2}.json", group_payload, @write_headers)
        assert_response :success
      end
      # index
      v2[:index], v2[:api_index], v2[:index_queries] = count_api_queries do
        get('/api/v2/groups', nil, @headers)
        assert_response :success
      end
      v1[:index] = count_queries do
        get('/groups.json', nil, @headers)
        assert_response :success
      end
      # destroy

      v2[:destroy], v2[:api_destroy], v2[:destroy_queries] = count_api_queries do
        delete("/api/v2/groups/#{id1}", nil, @headers)
        assert_response :no_content
      end
      v1[:destroy] = count_queries do
        delete("/groups/#{id2}.json", nil, @headers)
        assert_response :success
      end

      p v1
      p v2

      v1.keys.each do |key|
        api_key = "api_#{key}".to_sym
        assert v2[key] <= (v1[key] + 1) # Plus 1 because of the cache usage in api_groups_controller for features check
        assert_equal v2_expected[api_key], v2[api_key]
        assert_equal v2_expected[key], v2[key]
      end
    end
  end
end
