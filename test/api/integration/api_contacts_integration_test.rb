require_relative '../test_helper'

class ApiContactsIntegrationTest < ActionDispatch::IntegrationTest
  def test_multipart_form_data
    skip_bullet do
      post('/api/v2/contacts', v2_multipart_payload, @write_headers.merge('CONTENT_TYPE' => 'multipart/form-data'))
      assert_response :created
    end
  end

  def test_query_count
    skip_bullet do
      v2 = {}
      v1 = {}
      v2_expected = {
        api_create: 3,
        api_update: 10,
        api_show: 3,
        api_index: 3,
        api_destroy: 5,
        api_restore: 5,
        api_make_agent: 4,

        create: 38,
        update: 30,
        show: 16,
        index: 17,
        destroy: 21,
        restore: 19,
        make_agent: 48
      }

      # Assigning in prior so that query invoked as part of contruction of this payload will not be counted.
      create_v1_payload = v1_contact_payload
      create_v2_payload = v2_contact_payload

      # create
      v2[:create], v2[:api_create] = count_api_queries { post('/api/v2/contacts', create_v2_payload, @write_headers) }
      v1[:create] = count_queries { post('/contacts.json', create_v1_payload, @write_headers) }

      id1 = User.last(2).first.id
      id2 = User.last.id

      # update
      v2[:update], v2[:api_update] = count_api_queries { put("/api/contacts/#{id1}", v2_contact_update_payload, @write_headers) }
      v1[:update] = count_queries { put("/contacts/#{id2}.json", v1_contact_update_payload, @write_headers) }

      # Queries that will be part of the User attributes 'client_manager', 'avatar' and 'tags'.
      # These attributes are introduced in V2, hence subtracting it
      v2[:update] -= 3

      # show
      v2[:show], v2[:api_show] = count_api_queries { get("/api/v2/contacts/#{id1}", nil, @headers) }
      v1[:show] = count_queries { get("/contacts/#{id2}.json", nil, @headers) }

      # Queries that will be part of the User attributes 'client_manager', 'avatar' and 'tags'.
      # These attributes are introduced in V2, hence subtracting it
      v2[:show] -= 3

      # index
      v2[:index], v2[:api_index] = count_api_queries { get('/api/v2/contacts', nil, @headers) }
      v1[:index] = count_queries { get('/contacts.json', nil, @headers) }

      # destroy
      v2[:destroy], v2[:api_destroy] = count_api_queries { delete("/api/v2/contacts/#{id1}", nil, @headers) }
      v1[:destroy] = count_queries { delete("/contacts/#{id2}.json", nil, @headers) }

      # restore
      v2[:restore], v2[:api_restore] = count_api_queries { put("/api/v2/contacts/#{id1}/restore", {}.to_json, @write_headers) }
      v1[:restore] = count_queries { put("/contacts/#{id2}/restore.json", {}.to_json, @write_headers) }

      # make_agent
      v2[:make_agent], v2[:api_make_agent] = count_api_queries { put("/api/v2/contacts/#{id1}/make_agent", {}.to_json, @write_headers) }
      v1[:make_agent] = count_queries { put("/contacts/#{id2}/make_agent.json", {}.to_json, @write_headers) }

      v1.keys.each do |key|
        api_key = "api_#{key}".to_sym
        Rails.logger.debug "key : #{api_key}, v1: #{v1[key]}, v2 : #{v2[key]}, v2_api: #{v2[api_key]}, v2_expected: #{v2_expected[key]}"
      end

      p v1
      p v2

      v1.keys.each do |key|
        api_key = "api_#{key}".to_sym
        Rails.logger.debug "key : #{api_key}, v1: #{v1[key]}, v2 : #{v2[key]}, v2_api: #{v2[api_key]}, v2_expected: #{v2_expected[key]}"
        assert v2[key] <= v1[key]
        assert_equal v2_expected[api_key], v2[api_key]
        assert_equal v2_expected[key], v2[key]
      end
    end
  end
end
