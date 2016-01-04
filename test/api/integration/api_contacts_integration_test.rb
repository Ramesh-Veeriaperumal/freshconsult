require_relative '../test_helper'

class ApiContactsIntegrationTest < ActionDispatch::IntegrationTest
  include Helpers::UsersTestHelper
  def test_multipart_form_data
    skip_bullet do
      post('/api/v2/contacts', v2_multipart_payload, @write_headers.merge('CONTENT_TYPE' => 'multipart/form-data'))
      assert_response 201
    end
  end

  def test_query_count
    skip_bullet do
      v2 = {}
      v1 = {}
      v2_expected = {
        api_create: 3,
        api_update: 4,
        api_show: 3,
        api_index: 2,
        api_destroy: 6,
        api_make_agent: 4,

        create: 37,
        update: 32,
        show: 18,
        index: 18,
        destroy: 22,
        make_agent: 46
      }

      # Assigning in prior so that query invoked as part of contruction of this payload will not be counted.
      create_v1_payload = v1_contact_payload
      create_v2_payload = v2_contact_payload

      # create
      v1[:create] = count_queries do
        post('/contacts.json', create_v1_payload, @write_headers)
        assert_response 200
      end
      v2[:create], v2[:api_create], v2[:create_queries] = count_api_queries do
        post('/api/v2/contacts', create_v2_payload, @write_headers)
        assert_response 201
      end

      id1 = User.where(helpdesk_agent: false, deleted: false).last(2).first.id
      id2 = User.where(helpdesk_agent: false, deleted: false).last.id

      # update
      v1[:update] = count_queries do
        put("/contacts/#{id2}.json", v1_contact_update_payload, @write_headers)
        assert_response 200
      end
      v2[:update], v2[:api_update], v2[:update_queries] = count_api_queries do
        put("/api/contacts/#{id1}", v2_contact_update_payload, @write_headers)
        assert_response 200
      end

      # Queries that will be part of the User attributes 'avatar' and 'tags'.
      # These attributes are introduced in V2, hence subtracting it
      v2[:update] -= 2

      v1[:update] += 2 # trusted_ip

      # show
      v1[:show] = count_queries do
        get("/contacts/#{id2}.json", nil, @headers)
        assert_response 200
      end
      v2[:show], v2[:api_show], v2[:show_queries] = count_api_queries do
        get("/api/v2/contacts/#{id1}", nil, @headers)
        assert_response 200
      end

      v1[:show] += 2 # account suspended check is done in v2 alone & trusted_ip

      # Queries that will be part of the User attributes 'avatar' and 'tags'.
      # These attributes are introduced in V2, hence subtracting it
      v2[:show] -= 2

      # index
      v1[:index] = count_queries do
        get('/contacts.json', nil, @headers)
        assert_response 200
      end
      v2[:index], v2[:api_index], v2[:index_queries] = count_api_queries do
        get('/api/v2/contacts', nil, @headers)
        assert_response 200
      end

      v1[:index] += 1 # trusted_ip

      # destroy
      v1[:destroy] = count_queries do
        delete("/contacts/#{id2}.json", nil, @headers)
        assert_response 200
      end
      v2[:destroy], v2[:api_destroy], v2[:destroy_queries] = count_api_queries do
        delete("/api/v2/contacts/#{id1}", nil, @headers)
        assert_response 204
      end

      id1 = User.where(helpdesk_agent: false, deleted: false, customer_id: nil).last(2).first.id
      id2 = User.where(helpdesk_agent: false, deleted: false, customer_id: nil).last.id

      # make_agent
      v1[:make_agent] = count_queries do
        put("/contacts/#{id2}/make_agent.json", {}.to_json, @write_headers)
        assert_response 200
      end
      v2[:make_agent], v2[:api_make_agent], v2[:make_agent_queries] = count_api_queries do
        put("/api/v2/contacts/#{id1}/make_agent", {}.to_json, @write_headers)
        assert_response 200
      end

      v1[:make_agent] += 2 # trusted_ip

      write_to_file(v1, v2)

      v1.keys.each do |key|
        api_key = "api_#{key}".to_sym
        assert v2[key] <= v1[key]
        assert_equal v2_expected[api_key], v2[api_key]
        assert_equal v2_expected[key], v2[key]
      end
    end
  end
end
