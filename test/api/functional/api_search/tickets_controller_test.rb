require_relative '../../test_helper'
module ApiSearch
  class TicketsControllerTest < ActionController::TestCase
    include SearchTestHelper

    CUSTOM_FIELDS = %w(number checkbox text)

    def setup
      super
      initial_setup
    end

    @@initial_setup_run = false

    def initial_setup
      return if @@initial_setup_run
      CUSTOM_FIELDS.each do |custom_field|
        create_custom_field("test_custom_#{custom_field}", custom_field)
      end
      clear_es(@account.id)
      20.times { create_search_ticket(ticket_params_hash) }
      write_data_to_es(@account.id)
      @@initial_setup_run = true
    end

    def wrap_cname(params)
      { api_search: params }
    end

    def ticket_params_hash
      special_chars = ['!', '#', '$', '%', '&', '(', ')', '*', '+', ',', '-', '.', '/', ':', ';', '<', '=', '>', '?', '@', '[', '\\', ']', '^', '_', '`', '{', '|', '}', '~']
      cc_emails = [Faker::Internet.email, Faker::Internet.email]
      subject = Faker::Lorem.words(10).join(' ')
      description = Faker::Lorem.paragraph
      email = Faker::Internet.email
      tags = [Faker::Name.name, Faker::Name.name]
      priority = rand(4) + 1
      status = ticket_statuses[rand(ticket_statuses.size)]
      custom_fields = { test_custom_number_1: rand(5) + 1, test_custom_checkbox_1: rand(5) % 2 ? true : false, test_custom_text_1: Faker::Lorem.word + " " + special_chars.shuffle[0..8].join }
      group = create_group_with_agents(@account, agent_list: [@agent.id])
      params_hash = { email: email, cc_emails: cc_emails, description: description, subject: subject,
                      priority: priority, status: status, type: 'Problem', responder_id: @agent.id, source: 1, tags: tags,
                      due_by: 14.days.since.iso8601, fr_due_by: 1.days.since.iso8601, group_id: group.id, custom_field: custom_fields }
      params_hash
    end

    def test_tickets_invalid_query_format
      get :index, controller_params(query: "priority:1 OR priority:2")
      assert_response 400
      match_json([bad_request_error_pattern('query', :query_format_invalid)])
    end

    def test_tickets_max_query_length
      q = '"' + 'a' * 512 + '"'
      get :index, controller_params(query: q)
      assert_response 400
      match_json([bad_request_error_pattern('query', :too_long, max_count: ApiSearchConstants::QUERY_SIZE, current_count: q.length, element_type: :characters )])
    end

    def test_tickets_query_without_operators
      get :index, controller_params(query: '"priority:111 status:1111 group_id:1111"')
      assert_response 400
    end

    def test_tickets_query_with_invalid_string
      get :index, controller_params(query: '"priority:111 xxx"')
      assert_response 400
    end

    def test_tickets_invalid_priority_status_group_and_requester
      get :index, controller_params(query: '"priority:111 OR status:1111 OR group_id:1111"')
      assert_response 400
      match_json([bad_request_error_pattern('priority', :not_included, list: '1,2,3,4'),
                bad_request_error_pattern('status', :not_included, list: '2,3,4,5,6,7')])
    end

    def test_tickets_invalid_fields_in_query
      get :index, controller_params(query: '"priority:111 OR status:1111 OR group_id:1111 OR xxx:yyy"')
      assert_response 400
      match_json([bad_request_error_pattern('xxx', :invalid_field)])
    end

    def test_tickets_with_page_and_per_page
      get :index, controller_params(query: '"priority:111 OR status:1111 OR group_id:1111"', page:2, per_page:20)
      assert_response 400
      match_json([bad_request_error_pattern('per_page', :invalid_field),
                  bad_request_error_pattern('page', :invalid_field)])
    end

    def test_tickets_custom_fields
      tickets = @account.tickets.select{|x| x.custom_field["test_custom_number_1"] == 1 || x.custom_field["test_custom_checkbox_1"] == false || x.priority == 2 }
      get :index, controller_params(query: '"test_custom_number:1 OR test_custom_checkbox:false OR priority:2"')
      assert_response 200
      response = parse_response @response.body
      pattern = tickets.map { |ticket| index_ticket_pattern(ticket) }
      match_json({results: pattern, total: tickets.size})
    end

    def test_tickets_custom_fields_invalid_values
      get :index, controller_params(query: '"(test_custom_number:a OR test_custom_checkbox:b) OR priority:c OR test_custom_checkbox:d OR test_custom_checkbox:e"')
      assert_response 400
      match_json([bad_request_error_pattern('priority', :not_included, list: '1,2,3,4'),
                bad_request_error_pattern('test_custom_number',:array_datatype_mismatch, expected_data_type: 'Integer'),
                bad_request_error_pattern('test_custom_checkbox',:array_datatype_mismatch, expected_data_type: 'Boolean')])
    end

    def test_tickets_priority
      tickets = @account.tickets.select { |x|  [1,2].include?(x.priority) }
      get :index, controller_params(query: '"priority:1 OR priority:2"')
      assert_response 200
      response = parse_response @response.body
      pattern = tickets.map { |ticket| index_ticket_pattern(ticket) }
      match_json({results: pattern, total: tickets.size})
    end

    def test_tickets_case_indepdent_keywords_and_opertors
      tickets = @account.tickets.select { |x|  [1,2].include?(x.priority) }
      get :index, controller_params(query: '"PRIORITY:1 or priority:2"')
      assert_response 200
      response = parse_response @response.body
      pattern = tickets.map { |ticket| index_ticket_pattern(ticket) }
      match_json({results: pattern, total: tickets.size})
    end

    def test_tickets_custom_text_special_characters
      tickets = @account.tickets.last(2)
      text1 = tickets.first.custom_field["test_custom_text_1"]
      text2 = tickets.last.custom_field["test_custom_text_1"]
      get :index, controller_params(query: "\"test_custom_text:'#{text1}' or test_custom_text:'#{text2}'\"")
      assert_response 200
      response = parse_response @response.body
      pattern = tickets.map { |ticket| index_ticket_pattern(ticket) }
      match_json({results: pattern, total: tickets.size})
    end

    def test_tickets_custom_text_invalid_special_characters
      get :index, controller_params(query: "\"test_custom_text:'aaa\'a' or test_custom_text:'aaa\"aa'\"")
      assert_response 400
    end

    def test_tickets_status
      tickets = @account.tickets.select { |x|  [2,3].include?(x.status) }
      get :index, controller_params(query: '"status:2 OR status:3"')
      assert_response 200
      response = parse_response @response.body
      pattern = tickets.map { |ticket| index_ticket_pattern(ticket) }
      match_json({results: pattern, total: tickets.size})
    end

    def test_tickets_nested_condition
      tickets = @account.tickets.select { |x|  [3,2].include?(x.status) }.select { |x|  [1,2].include?(x.priority) }
      get :index, controller_params(query: '"(status:2 OR status:3) AND (priority:1 or priority:2)"')
      assert_response 200
      response = parse_response @response.body
      pattern = tickets.map { |ticket| index_ticket_pattern(ticket) }
      match_json({results: pattern, total: tickets.size})
    end
  end
end