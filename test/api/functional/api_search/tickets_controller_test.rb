require_relative '../../test_helper'
module ApiSearch
  class TicketsControllerTest < ActionController::TestCase
    include SearchTestHelper

    CUSTOM_FIELDS = %w(number checkbox decimal text paragraph date).freeze
    CHOICES = ['Get Smart', 'Pursuit of Happiness', 'Armaggedon'].freeze

    def setup
      super
      initial_setup
    end

    @@initial_setup_run = false

    def initial_setup
      return if @@initial_setup_run
      @account.tags.destroy_all
      CUSTOM_FIELDS.each do |custom_field|
        create_custom_field("test_custom_#{custom_field}", custom_field)
      end
      create_custom_field_dropdown('test_custom_dropdown', CHOICES)
      create_custom_field('priority', 'number', '06')
      create_custom_field('status', 'text', '14')
      clear_es(@account.id)
      30.times { create_search_ticket(ticket_params_hash) }
      write_data_to_es(@account.id)
      @@initial_setup_run = true
    end

    def wrap_cname(params)
      { api_search: params }
    end

    def ticket_params_hash
      types = ['Question', 'Incident', 'Problem', 'Feature Request']
      tags = %w(tag1 tag2 tag3 TAG4 TAG5 TAG6)
      special_chars = ['!', '#', '$', '%', '&', '(', ')', '*', '+', ',', '-', '.', '/', ':', ';', '<', '=', '>', '?', '@', '[', '\\', ']', '^', '_', '`', '{', '|', '}', '~']
      cc_emails = [Faker::Internet.email, Faker::Internet.email]
      subject = Faker::Lorem.words(10).join(' ')
      description = Faker::Lorem.paragraph
      email = Faker::Internet.email
      priority = rand(4) + 1
      status = ticket_statuses[rand(ticket_statuses.size)]
      custom_fields = { test_custom_dropdown_1: CHOICES[rand(CHOICES.size)], test_custom_date_1: rand(10).days.until, test_custom_number_1: rand(10) - 5, test_custom_checkbox_1: rand(5) % 2 ? true : false, test_custom_text_1: Faker::Lorem.word + ' ' + special_chars.join, test_custom_paragraph_1: Faker::Lorem.paragraph }
      group = create_group_with_agents(@account, agent_list: [@agent.id])
      n = rand(10)
      custom_fields[:test_custom_date_1] = nil if n == 9
      custom_fields[:test_custom_dropdown_1] = nil if n == 8
      custom_fields[:test_custom_number_1] = nil if n == 7
      custom_fields[:test_custom_text_1] = nil if n == 6
      params_hash = { email: email, cc_emails: cc_emails, description: description, subject: subject,
                      priority: priority, status: status, type: types[rand(4)], responder_id: rand(4) + 1, source: 1, tags: [tags[rand(6)], tags[rand(6)]].uniq,
                      due_by: (n + 14).days.since.iso8601, fr_due_by: (n + 1).days.since.iso8601, group_id: group.id, custom_field: custom_fields,
                      created_at: n.days.until.iso8601, updated_at: (n + 2).days.until.iso8601 }
      params_hash[:tags] = [] if n == 5
      params_hash[:group_id] = nil if n == 4
      params_hash[:agent_id] = nil if n == 3
      params_hash
    end

    def construct_sections(field_name)
      sections = []
      if field_name == 'type'
        create_custom_field('section_number', 'number', '19')
        create_custom_field('section_checkbox', 'checkbox', '09')
        create_custom_field('section_decimal', 'decimal', '19')
        create_custom_field('section_text', 'text', '79')
        create_custom_field('section_paragraph', 'paragraph', '09')
        create_custom_field('section_date', 'date', '09')
        sections = [{ title: 'section1',
                      value_mapping: %w[Question],
                      ticket_fields: %w[section_number section_checkbox section_decimal section_text section_paragraph section_date]
                    }]
      end
      sections
    end

    def test_tickets_invalid_query_format
      get :index, controller_params(query: 'priority:1 OR priority:2')
      assert_response 400
      match_json([bad_request_error_pattern('query', :query_format_invalid)])
    end

    def test_tickets_max_query_length
      q = '"' + 'a' * 512 + '"'
      get :index, controller_params(query: q)
      assert_response 400
      match_json([bad_request_error_pattern('query', :too_long, max_count: ApiSearchConstants::QUERY_SIZE, current_count: q.length, element_type: :characters)])
    end

    def test_tickets_query_without_operators
      get :index, controller_params(query: '"priority:111 status:1111 group_id:1111"')
      assert_response 400
    end

    def test_tickets_query_with_invalid_string
      get :index, controller_params(query: '"priority:111 xxx"')
      assert_response 400
    end

    def test_tickets_invalid_priority_status_group_and_group
      get :index, controller_params(query: '"priority:111 OR status:1111 OR group_id:1111"')
      assert_response 400
      match_json([bad_request_error_pattern('priority', :not_included, list: '1,2,3,4'),
                  bad_request_error_pattern('status', :not_included, list: '2,3,4,5,6,7')])
    end

    def test_tickets_invalid_fields_in_query
      get :index, controller_params(query: '"priority:111 OR status:1111 OR group_id:1111 OR xxx:yyy OR sample_decimal:2"')
      assert_response 400
      match_json([bad_request_error_pattern('xxx', :invalid_field), bad_request_error_pattern('sample_decimal', :invalid_field)])
    end

    def test_tickets_with_page_and_per_page
      get :index, controller_params(query: '"priority:111 OR status:1111 OR group_id:1111"', page: 2, per_page: 20)
      assert_response 400
      match_json([bad_request_error_pattern('per_page', :invalid_field)])
    end

    def test_tickets_with_invalid_page
      get :index, controller_params(query: '"priority:111 OR status:1111 OR group_id:1111"', page: 11)
      assert_response 400
      match_json([bad_request_error_pattern('page', :per_page_invalid, max_value: 10)])
    end

    def test_tickets_custom_fields
      tickets = @account.tickets.select { |x| x.custom_field['test_custom_number_1'] == 1 || x.custom_field['test_custom_checkbox_1'] == false || x.custom_field['test_custom_checkbox_1'].nil? || x.priority == 2 }
      get :index, controller_params(query: '"test_custom_number:1 OR test_custom_checkbox:false OR priority:2"')
      assert_response 200
      pattern = tickets.map { |ticket| index_ticket_pattern(ticket) }
      match_json(results: pattern, total: tickets.size)
    end

    def test_tickets_custom_fields_invalid_values
      get :index, controller_params(query: '"(test_custom_number:a OR test_custom_checkbox:b) OR priority:c OR test_custom_checkbox:d OR test_custom_checkbox:e"')
      assert_response 400
      match_json([bad_request_error_pattern('priority', :not_included, list: '1,2,3,4'),
                  bad_request_error_pattern('test_custom_number', :array_datatype_mismatch, expected_data_type: 'Integer'),
                  bad_request_error_pattern('test_custom_checkbox', :array_datatype_mismatch, expected_data_type: 'Boolean')])
    end

    def test_tickets_custom_fields_string_value_for_custom_number
      get :index, controller_params(query: '"test_custom_number:\'123\'"')
      assert_response 400
    end

    def test_tickets_custom_fields_string_value_for_group_id
      get :index, controller_params(query: '"group_id:\'123\'"')
      assert_response 400
    end

    def test_tickets_filter_using_negative_number_in_custom_field
      ticket = @account.tickets.select { |x| x if x.custom_field['test_custom_number_1'].to_i < 0 }.first
      val = ticket.custom_field['test_custom_number_1']
      tickets = @account.tickets.select { |x| x if x.custom_field['test_custom_number_1'].to_i == val }
      get :index, controller_params(query: '"test_custom_number:' + val.to_s + '"')
      assert_response 200
      pattern = tickets.map { |ticket| index_ticket_pattern(ticket) }
      match_json(results: pattern, total: tickets.size)
    end

    def test_tickets_filter_query_with_leading_and_trialing_spaces
      ticket = @account.tickets.select { |x| x if x.custom_field['test_custom_number_1'].to_i < 0 }.first
      val = ticket.custom_field['test_custom_number_1']
      tickets = @account.tickets.select { |x| x if x.custom_field['test_custom_number_1'].to_i == val }
      get :index, controller_params(query: '"  ( test_custom_number:' + val.to_s + '  )  "')
      assert_response 200
      pattern = tickets.map { |ticket| index_ticket_pattern(ticket) }
      match_json(results: pattern, total: tickets.size)
    end

    def test_tickets_filter_using_custom_checkbox
      tickets = @account.tickets.select { |x| x.custom_field['test_custom_checkbox_1'] == true }
      get :index, controller_params(query: '"test_custom_checkbox:true"')
      assert_response 200
      pattern = tickets.map { |ticket| index_ticket_pattern(ticket) }
      match_json(results: pattern, total: tickets.size)
    end

    def test_tickets_priority
      tickets = @account.tickets.select { |x| [1, 2].include?(x.priority) }
      get :index, controller_params(query: '"priority:1 OR priority:2"')
      assert_response 200
      pattern = tickets.map { |ticket| index_ticket_pattern(ticket) }
      match_json(results: pattern, total: tickets.size)
    end

    def test_tickets_case_indepdent_keywords_and_opertors
      tickets = @account.tickets.select { |x| [1, 2].include?(x.priority) }
      get :index, controller_params(query: '"PRIORITY:1 or priority:2"')
      assert_response 200
      pattern = tickets.map { |ticket| index_ticket_pattern(ticket) }
      match_json(results: pattern, total: tickets.size)
    end

    def test_tickets_custom_text_special_characters
      text = @account.tickets.map(&:test_custom_text_1).compact.last(2)
      tickets = @account.tickets.select { |x| text.include?(x.test_custom_text_1) }
      get :index, controller_params(query: "\"test_custom_text:'#{text[0]}' or test_custom_text:'#{text[1]}'\"")
      assert_response 200
      pattern = tickets.map { |ticket| index_ticket_pattern(ticket) }
      match_json(results: pattern, total: tickets.size)
    end

    def test_tickets_custom_text_invalid_special_characters
      get :index, controller_params(query: "\"test_custom_text:'aaa\'a' or test_custom_text:'aaa\"aa'\"")
      assert_response 400
    end

    def test_tickets_status
      tickets = @account.tickets.select { |x| [2, 3].include?(x.status) }
      get :index, controller_params(query: '"status:2 OR status:3"')
      assert_response 200
      pattern = tickets.map { |ticket| index_ticket_pattern(ticket) }
      match_json(results: pattern, total: tickets.size)
    end

    def test_tickets_nested_condition
      tickets = @account.tickets.select { |x| [3, 2].include?(x.status) }.select { |x| [1, 2].include?(x.priority) }
      get :index, controller_params(query: '"(status:2 OR status:3) AND (priority:1 or priority:2)"')
      assert_response 200
      pattern = tickets.map { |ticket| index_ticket_pattern(ticket) }
      match_json(results: pattern, total: tickets.size)
    end

    def test_tickets_custom_fields_named_after_default_fields
      tickets = @account.tickets.select { |x| [1, 2].include?(x.priority) }
      get :index, controller_params(query: '"status:aaa"')
      assert_response 400
      match_json([bad_request_error_pattern('status', :not_included, list: '2,3,4,5,6,7')])
    end

    def test_tickets_invalid_date_format
      tickets = @account.tickets.select { |x| [1, 2].include?(x.priority) }
      get :index, controller_params(query: '"created_at:>\'20170707\'"')
      assert_response 400
      match_json([bad_request_error_pattern('query', :query_format_invalid)])
    end

    def test_tickets_invalid_date_format
      tickets = @account.tickets.select { |x| [1, 2].include?(x.priority) }
      get :index, controller_params(query: '"ddate:>\'2017-07-07\'"')
      assert_response 400
      match_json([bad_request_error_pattern('ddate', :invalid_field)])
    end

    def test_tickets_valid_date
      d1 = (Date.today - 1).iso8601
      tickets = @account.tickets.select { |x| x.created_at.to_date.iso8601 <= d1 }
      get :index, controller_params(query: '"created_at :< \'' + d1 + '\'"')
      assert_response 200
      pattern = tickets.map { |ticket| index_ticket_pattern(ticket) }
      match_json(results: pattern, total: tickets.size)
    end

    def test_tickets_created_on_a_day
      d1 = Date.today.to_date.iso8601
      tickets = @account.tickets.select { |x| x.created_at.to_date.iso8601 == d1 }
      get :index, controller_params(query: '"created_at: \'' + d1 + '\'"')
      assert_response 200
      pattern = tickets.map { |ticket| index_ticket_pattern(ticket) }
      match_json(results: pattern, total: tickets.size)
    end

    def test_tickets_fr_due_by_on_a_day
      d1 = Date.today.to_date.iso8601
      tickets = @account.tickets.select { |x| x.frDueBy.to_date.iso8601 == d1 }
      get :index, controller_params(query: '"fr_due_by: \'' + d1 + '\'"')
      assert_response 200
      pattern = tickets.map { |ticket| index_ticket_pattern(ticket) }
      match_json(results: pattern, total: tickets.size)
    end

    def test_tickets_due_by_on_a_day
      d1 = Date.today.to_date.iso8601
      tickets = @account.tickets.select { |x| x.due_by.to_date.iso8601 == d1 }
      get :index, controller_params(query: '"due_by: \'' + d1 + '\'"')
      assert_response 200
      pattern = tickets.map { |ticket| index_ticket_pattern(ticket) }
      match_json(results: pattern, total: tickets.size)
    end

    def test_tickets_custom_date_on_a_day
      d1 = Date.today.to_date.iso8601
      tickets = @account.tickets.select { |x| x.test_custom_date_1 && x.test_custom_date_1.to_date.iso8601 == d1 }
      get :index, controller_params(query: '"test_custom_date: \'' + d1 + '\'"')
      assert_response 200
      pattern = tickets.map { |ticket| index_ticket_pattern(ticket) }
      match_json(results: pattern, total: tickets.size)
    end

    def test_tickets_updated_on_a_day
      d1 = Date.today.to_date.iso8601
      tickets = @account.tickets.select { |x| x.updated_at.to_date.iso8601 == d1 }
      get :index, controller_params(query: '"updated_at: \'' + d1 + '\'"')
      assert_response 200
      pattern = tickets.map { |ticket| index_ticket_pattern(ticket) }
      match_json(results: pattern, total: tickets.size)
    end

    def test_tickets_valid_range
      d1 = (Date.today - 8).iso8601
      d2 = (Date.today - 1).iso8601
      tickets = @account.tickets.select { |x| x.created_at.to_date.iso8601 >= d1 && x.created_at.to_date.iso8601 <= d2 }
      get :index, controller_params(query: '"(created_at :> \'' + d1 + '\' AND created_at :< \'' + d2 + '\')"')
      assert_response 200
      pattern = tickets.map { |ticket| index_ticket_pattern(ticket) }
      match_json(results: pattern, total: tickets.size)
    end

    def test_tickets_valid_range_and_filter
      d1 = (Date.today - 8).iso8601
      d2 = (Date.today - 1).iso8601
      tickets = @account.tickets.select { |x| (x.created_at.to_date.iso8601 >= d1 && x.created_at.to_date.iso8601 <= d2) && x.priority == 2 }
      get :index, controller_params(query: '"(created_at :> \'' + d1 + '\' AND created_at :< \'' + d2 + '\') AND priority:2 "')
      assert_response 200
      pattern = tickets.map { |ticket| index_ticket_pattern(ticket) }
      match_json(results: pattern, total: tickets.size)
    end

    def test_tickets_custom_date_valid_range_and_filter
      d1 = (Date.today - 8).iso8601
      d2 = (Date.today - 1).iso8601
      tickets = @account.tickets.select { |x| x.custom_field['test_custom_date_1'] && (x.custom_field['test_custom_date_1'].to_date.iso8601 >= d1 && x.custom_field['test_custom_date_1'].to_date.iso8601 <= d2) && x.priority == 2 }
      get :index, controller_params(query: '"(test_custom_date :> \'' + d1 + '\' AND test_custom_date :< \'' + d2 + '\') AND priority:2 "')
      assert_response 200
      pattern = tickets.map { |ticket| index_ticket_pattern(ticket) }
      match_json(results: pattern, total: tickets.size)
    end

    def test_tickets_valid_range_fr_due_by
      d1 = (Date.today - 8).iso8601
      d2 = (Date.today - 1).iso8601
      tickets = @account.tickets.select { |x| x.frDueBy.to_date.iso8601 >= d1 && x.frDueBy.to_date.iso8601 <= d2 }
      get :index, controller_params(query: '"(fr_due_by :> \'' + d1 + '\' AND fr_due_by :< \'' + d2 + '\')"')
      assert_response 200
      pattern = tickets.map { |ticket| index_ticket_pattern(ticket) }
      match_json(results: pattern, total: tickets.size)
    end

    def test_tickets_valid_range_due_by
      d1 = (Date.today - 8).iso8601
      d2 = (Date.today - 1).iso8601
      tickets = @account.tickets.select { |x| x.due_by.to_date.iso8601 >= d1 && x.due_by.to_date.iso8601 <= d2 }
      get :index, controller_params(query: '"(due_by :> \'' + d1 + '\' AND due_by :< \'' + d2 + '\')"')
      assert_response 200
      pattern = tickets.map { |ticket| index_ticket_pattern(ticket) }
      match_json(results: pattern, total: tickets.size)
    end

    def test_tickets_valid_type
      tickets = @account.tickets.select { |x| ['Question', 'Feature Request'].include?(x.ticket_type) }
      get :index, controller_params(query: '"type: \'Feature Request\' OR type:Question"')
      assert_response 200
      pattern = tickets.map { |ticket| index_ticket_pattern(ticket) }
      match_json(results: pattern, total: tickets.size)
    end

    def test_tickets_invalid_type
      get :index, controller_params(query: '"type: \'Feature Request\' OR type:Question123"')
      assert_response 400
      match_json([bad_request_error_pattern('type', :not_included, list: @account.ticket_type_values.map(&:value).join(','))])
    end

    def test_tickets_valid_type_and_priority
      tickets = @account.tickets.select { |x| ['Question', 'Feature Request'].include?(x.ticket_type) && x.priority == 2 }
      get :index, controller_params(query: '"(type: \'Feature Request\' OR type:Question) AND priority:2"')
      assert_response 200
      pattern = tickets.map { |ticket| index_ticket_pattern(ticket) }
      match_json(results: pattern, total: tickets.size)
    end

    def test_tickets_valid_tag
      tickets = @account.tickets.select { |x| x.tag_names.include?('tag1') || x.tag_names.include?('TAG4') }
      get :index, controller_params(query: '"tag:tag1 or tag:\'TAG4\'"')
      assert_response 200
      pattern = tickets.map { |ticket| index_ticket_pattern(ticket) }
      match_json(results: pattern, total: tickets.size)
    end

    def test_tickets_tag_case_sensitive
      get :index, controller_params(query: '"tag:tag4"')
      assert_response 200
      response = parse_response @response.body
      assert response['total'] == 0
    end

    def test_tickets_tag_case_sensitive
      get :index, controller_params(query: '"tag:' + 'a' * 33 + '"')
      assert_response 400
      match_json([bad_request_error_pattern('tag', :array_too_long, max_count: ApiConstants::TAG_MAX_LENGTH_STRING, element_type: :characters)])
    end

    def test_tickets_custom_dropdown_valid_choice
      choice = CHOICES[rand(3)]
      tickets = @account.tickets.select { |x| x.custom_field['test_custom_dropdown_1'] == choice }
      get :index, controller_params(query: '"test_custom_dropdown:\'' + choice + '\'"')
      assert_response 200
      pattern = tickets.map { |ticket| index_ticket_pattern(ticket) }
      match_json(results: pattern, total: tickets.size)
    end

    def test_tickets_custom_dropdown_invalid_choice
      get :index, controller_params(query: '"test_custom_dropdown:aaabbbccc"')
      assert_response 400
      match_json([bad_request_error_pattern('test_custom_dropdown', :not_included, list: CHOICES.join(','))])
    end

    def test_tickets_custom_dropdown_combined_condition
      choice = CHOICES[rand(3)]
      tickets = @account.tickets.select { |x| x.custom_field['test_custom_dropdown_1'] == choice && [3, 4].include?(x.status) && [2, 3].include?(x.priority) }
      get :index, controller_params(query: '"test_custom_dropdown:\'' + choice + '\' AND (status:3 OR status:4) AND (priority:2 OR priority:3)"')
      assert_response 200
      pattern = tickets.map { |ticket| index_ticket_pattern(ticket) }
      match_json(results: pattern, total: tickets.size)
    end

    def test_tickets_agent_id
      agent_id = rand(4) + 1
      tickets = @account.tickets.select { |x| x.responder_id == agent_id }
      get :index, controller_params(query: '"agent_id:' + agent_id.to_s + '"')
      assert_response 200
      pattern = tickets.map { |ticket| index_ticket_pattern(ticket) }
      match_json(results: pattern, total: tickets.size)
    end

    def test_tickets_agent_id_combined_condition
      tickets = @account.tickets.select { |x| [1, 3].include?(x.responder_id) && x.priority > 2 }
      get :index, controller_params(query: '"(agent_id:1 OR agent_id:3) AND (priority:3 OR priority:4)"')
      assert_response 200
      pattern = tickets.map { |ticket| index_ticket_pattern(ticket) }
      match_json(results: pattern, total: tickets.size)
    end

    def test_tickets_invalid_agent_id
      get :index, controller_params(query: '"agent_id:100"')
      assert_response 200
      response = parse_response @response.body
      assert response['total'] == 0
    end

    def test_tickets_invalid_agent_id_format
      get :index, controller_params(query: '"agent_id:abc"')
      assert_response 400
      match_json([bad_request_error_pattern('agent_id', :array_datatype_mismatch, expected_data_type: 'Positive Integer')])
    end

    # Null Checks
    def test_custom_dropdown_null
      tickets = @account.tickets.select { |x| x.test_custom_dropdown_1.nil? }
      get :index, controller_params(query: '"test_custom_dropdown: null"')
      assert_response 200
      pattern = tickets.map { |ticket| index_ticket_pattern(ticket) }
      match_json(results: pattern, total: tickets.size)
    end

    def test_custom_number_null
      tickets = @account.tickets.select { |x| x.test_custom_number_1.nil? }
      get :index, controller_params(query: '"test_custom_number: null"')
      assert_response 200
      pattern = tickets.map { |ticket| index_ticket_pattern(ticket) }
      match_json(results: pattern, total: tickets.size)
    end

    def test_custom_text_null
      tickets = @account.tickets.select { |x| x.test_custom_text_1.nil? }
      get :index, controller_params(query: '"test_custom_text: null"')
      assert_response 200
      pattern = tickets.map { |ticket| index_ticket_pattern(ticket) }
      match_json(results: pattern, total: tickets.size)
    end

    def test_custom_date_null
      tickets = @account.tickets.select { |x| x.test_custom_date_1.nil? }
      get :index, controller_params(query: '"test_custom_date: null"')
      assert_response 200
      pattern = tickets.map { |ticket| index_ticket_pattern(ticket) }
      match_json(results: pattern, total: tickets.size)
    end

    def test_group_id_null
      tickets = @account.tickets.select { |x| x.group_id.nil? }
      get :index, controller_params(query: '"group_id: null"')
      assert_response 200
      pattern = tickets.map { |ticket| index_ticket_pattern(ticket) }
      match_json(results: pattern, total: tickets.size)
    end

    def test_agent_id_null
      tickets = @account.tickets.select { |x| x.responder_id.nil? }
      get :index, controller_params(query: '"agent_id: null"')
      assert_response 200
      pattern = tickets.map { |ticket| index_ticket_pattern(ticket) }
      match_json(results: pattern, total: tickets.size)
    end

    def test_tags_null
      tickets = @account.tickets.select { |x| x.tags.empty? }
      get :index, controller_params(query: '"tag: null"')
      assert_response 200
      pattern = tickets.map { |ticket| index_ticket_pattern(ticket) }
      match_json(results: pattern, total: tickets.size)
    end

    def test_type_null
      tickets = @account.tickets.select { |x| x.ticket_type.nil? }
      get :index, controller_params(query: '"type: null"')
      assert_response 200
      pattern = tickets.map { |ticket| index_ticket_pattern(ticket) }
      match_json(results: pattern, total: tickets.size)
    end

    def test_tickets_invalid_query_format_with_date
      get :index, controller_params(query: '"created_at < : \'2017-01-01\'"')
      assert_response 400
      match_json([bad_request_error_pattern('query', :query_format_invalid)])
    end

    def test_tickets_invalid_query_format_with_string
      get :index, controller_params(query: '"created_at < : \'aaa\'"')
      assert_response 400
      match_json([bad_request_error_pattern('query', :query_format_invalid)])
    end

    def test_tickets_invalid_query_format_with_number
      get :index, controller_params(query: '"created_at <: 123"')
      assert_response 400
      match_json([bad_request_error_pattern('query', :query_format_invalid)])
    end

    def test_deprecate_section_fields
      sections = construct_sections('type')
      create_section_fields(3, sections)
      get :index, controller_params(query: '"section_number:123 or section_checkbox:true or section_text:aaa or section_date:\'2017-01-01\'"')
      assert_response 400
      match_json([bad_request_error_pattern('section_number', :invalid_field),
                  bad_request_error_pattern('section_checkbox', :invalid_field),
                  bad_request_error_pattern('section_text', :invalid_field),
                  bad_request_error_pattern('section_date', :invalid_field)])
    end    
  end
end
