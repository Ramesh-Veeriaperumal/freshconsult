require_relative '../test_helper'

class ApiGroupsIntegrationTest < ActionDispatch::IntegrationTest
  def test_query_count
    v2 = {}
    v1 = {}
    v2_expected = {
      create: 7,
      show: 4,
      update: 8,
      index: 8,
      destroy: 11
    }

    # create
    v2[:create], v2[:api_create] = count_api_queries { post('/api/v2/groups', group_payload, @write_headers) }
    v1[:create] = count_queries { post('/groups.json', group_payload, @write_headers) }
    id1 = Group.last(2).first.id
    id2 = Group.last.id
    # show
    v2[:show], v2[:api_show] = count_api_queries { get("/api/v2/groups/#{id1}", nil, @headers) }
    v1[:show] = count_queries { get("/groups/#{id2}.json", nil, @headers) }
    # update
    v2[:update], v2[:api_update] = count_api_queries { put("/api/v2/groups/#{id1}", group_payload, @write_headers) }
    v1[:update] = count_queries { put("/groups/#{id2}.json", group_payload, @write_headers) }
    # index
    v2[:index], v2[:api_index] = count_api_queries { get('/api/v2/groups', nil, @headers) }
    v1[:index] = count_queries { get('/groups.json', nil, @headers) }
    # destroy
    v2[:destroy], v2[:api_destroy] = count_api_queries { delete("/api/v2/groups/#{id1}", nil, @headers) }
    v1[:destroy] = count_queries { delete("/groups/#{id2}.json", nil, @headers) }
    v1.keys.each do |key|
      api_key = "api_#{key}".to_sym
      assert v2[key] <= v1[key]
      assert_equal v2_expected[key], v2[api_key]
    end
  end
end
