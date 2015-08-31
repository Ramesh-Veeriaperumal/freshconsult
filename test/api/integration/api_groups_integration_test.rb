require_relative '../test_helper'

class ApiGroupsIntegrationTest < ActionDispatch::IntegrationTest
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

        create: 15,
        show: 14,
        update: 20,
        index: 13,
        destroy: 24
      }

      # create
      v2[:create], v2[:api_create] = count_api_queries { post('/api/v2/groups', v2_group_payload, @write_headers) }
      v1[:create] = count_queries { post('/groups.json', group_payload, @write_headers) }
      id1 = Group.last(2).first.id
      id2 = Group.last.id
      # show
      v2[:show], v2[:api_show] = count_api_queries { get("/api/v2/groups/#{id1}", nil, @headers) }
      v1[:show] = count_queries { get("/groups/#{id2}.json", nil, @headers) }
      # update
      v2[:update], v2[:api_update] = count_api_queries { put("/api/v2/groups/#{id1}", v2_group_payload, @write_headers) }
      v1[:update] = count_queries { put("/groups/#{id2}.json", group_payload, @write_headers) }
      # index
      v2[:index], v2[:api_index] = count_api_queries { get('/api/v2/groups', nil, @headers) }
      v1[:index] = count_queries { get('/groups.json', nil, @headers) }
      # destroy

      v2[:destroy], v2[:api_destroy] = count_api_queries { delete("/api/v2/groups/#{id1}", nil, @headers) }
      v1[:destroy] = count_queries { delete("/groups/#{id2}.json", nil, @headers) }
      
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
