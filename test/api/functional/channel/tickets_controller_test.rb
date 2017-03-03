require_relative '../../test_helper'

module Channel
  class TicketsControllerTest < ActionController::TestCase
    include TicketsTestHelper

    CUSTOM_FIELDS = %w(number checkbox decimal text paragraph dropdown country state city date).freeze

    VALIDATABLE_CUSTOM_FIELDS =  %w(number checkbox decimal text paragraph date)

    CUSTOM_FIELDS_VALUES_INVALID = { 'number' => '1.90', 'decimal' => 'dd', 'checkbox' => 'iu', 'text' => Faker::Lorem.characters(300), 'paragraph' =>  12_345, 'date' => '31-13-09' }

    ERROR_PARAMS =  {
      'number' => [:datatype_mismatch, expected_data_type: 'Integer', prepend_msg: :input_received, given_data_type: String],
      'decimal' => [:datatype_mismatch, expected_data_type: 'Number'],
      'checkbox' => [:datatype_mismatch, expected_data_type: 'Boolean', prepend_msg: :input_received, given_data_type: String],
      'text' => [:'Has 300 characters, it can have maximum of 255 characters'],
      'paragraph' => [:datatype_mismatch, expected_data_type: String, prepend_msg: :input_received, given_data_type: Integer],
      'date' => [:invalid_date, accepted: 'yyyy-mm-dd']
    }

    def setup
      super
      before_all
    end

    @@before_all_run = false

    def before_all
      @account.sections.map(&:destroy)
      return if @@before_all_run
      @account.ticket_fields.custom_fields.each(&:destroy)
      Helpdesk::TicketStatus.find(2).update_column(:stop_sla_timer, false)
      @@ticket_fields = []
      @@custom_field_names = []
      @@ticket_fields << create_dependent_custom_field(%w(test_custom_country test_custom_state test_custom_city))
      @@ticket_fields << create_custom_field_dropdown('test_custom_dropdown', ['Get Smart', 'Pursuit of Happiness', 'Armaggedon'])
      @@choices_custom_field_names = @@ticket_fields.map(&:name)
      CUSTOM_FIELDS.each do |custom_field|
        next if %w(dropdown country state city).include?(custom_field)
        @@ticket_fields << create_custom_field("test_custom_#{custom_field}", custom_field)
        @@custom_field_names << @@ticket_fields.last.name
      end
      @account.launch :add_watcher
      @account.save
      @@before_all_run = true
    end

    def wrap_cname(params = {})
      { ticket: params }
    end

    def ticket_params_hash
      cc_emails = [Faker::Internet.email, Faker::Internet.email]
      subject = Faker::Lorem.words(10).join(' ')
      description = Faker::Lorem.paragraph
      email = Faker::Internet.email
      tags = [Faker::Name.name, Faker::Name.name]
      @create_group ||= create_group_with_agents(@account, agent_list: [@agent.id])
      params_hash = { email: email, cc_emails: cc_emails, description: description, subject: subject,
                      priority: 2, status: 3, type: 'Problem', responder_id: @agent.id, source: 1, tags: tags,
                      due_by: 14.days.since.iso8601, fr_due_by: 1.day.since.iso8601, group_id: @create_group.id }
      params_hash
    end

    def test_create_without_default_fields_required_except_requester
      params = { email: Faker::Internet.email }
      post :create, construct_params({ version: 'private' }, params)
      t = Helpdesk::Ticket.last
      match_json(ticket_pattern(params, t))
      match_json(ticket_pattern({}, t))
      result = parse_response(@response.body)
      assert_equal true, response.headers.include?('Location')
      assert_equal "http://#{@request.host}/api/v2/tickets/#{result['id']}", response.headers['Location']
      assert_response 201
    end

    def test_create_without_default_fields_required
      params = {}
      post :create, construct_params({ version: 'private' }, params)
      assert_response 400
      match_json([bad_request_error_pattern('requester_id', :fill_a_mandatory_field, field_names: 'requester_id, phone, email, twitter_id, facebook_id')])
    end

    def test_create_with_all_default_fields_required_invalid
      default_non_required_fields = Helpdesk::TicketField.where(required: false, default: 1)
      default_non_required_fields.map { |x| x.toggle!(:required) }
      params_hash = { 
                subject: 1,
                description: 1,
                group_id: "z",
                product_id: "y",
                responder_id: "x",
                status: 999,
                priority: 999,
                type: "Test",
                email: Faker::Internet.email
              }
      post :create, construct_params({ version: 'private' }, params_hash)
      match_json([bad_request_error_pattern('description',  :datatype_mismatch, expected_data_type: String, prepend_msg: :input_received, given_data_type: 'Integer'),
                  bad_request_error_pattern('subject',  :datatype_mismatch, expected_data_type: String, prepend_msg: :input_received, given_data_type: 'Integer'),
                  bad_request_error_pattern('group_id', :datatype_mismatch, expected_data_type: 'Positive Integer', prepend_msg: :input_received, given_data_type: 'String'),
                  bad_request_error_pattern('responder_id', :datatype_mismatch, expected_data_type: 'Positive Integer', prepend_msg: :input_received, given_data_type: 'String'),
                  bad_request_error_pattern('product_id', :datatype_mismatch, expected_data_type: 'Positive Integer', prepend_msg: :input_received, given_data_type: 'String'),
                  bad_request_error_pattern('priority', :not_included, list: '1,2,3,4'),
                  bad_request_error_pattern('status', :not_included, list: '2,3,4,5,6,7'),
                  bad_request_error_pattern('type', :not_included, list: 'Question,Incident,Problem,Feature Request')])
      assert_response 400
    ensure
      default_non_required_fields.map { |x| x.toggle!(:required) }
    end

    def test_create_without_custom_fields_required
      params = ticket_params_hash
      Helpdesk::TicketField.where(name: [@@custom_field_names]).update_all(required: true)
      post :create, construct_params({ version: 'private' }, params)
      Helpdesk::TicketField.where(name: [@@custom_field_names]).update_all(required: false)
      match_json(ticket_pattern(params, Helpdesk::Ticket.last))
      match_json(ticket_pattern({}, Helpdesk::Ticket.last))
      result = parse_response(@response.body)
      assert_equal true, response.headers.include?('Location')
      assert_equal "http://#{@request.host}/api/v2/tickets/#{result['id']}", response.headers['Location']
      assert_response 201
    end

    def test_create_with_custom_fields_required_invalid
      params = ticket_params_hash.merge(custom_fields: {})
      VALIDATABLE_CUSTOM_FIELDS.each do |custom_field|
        params[:custom_fields]["test_custom_#{custom_field}"] = CUSTOM_FIELDS_VALUES_INVALID[custom_field]
      end
      post :create, construct_params({ version: 'private' }, params)
      assert_response 400
      pattern = []
      VALIDATABLE_CUSTOM_FIELDS.each do |custom_field|
        pattern << bad_request_error_pattern("test_custom_#{custom_field}", *(ERROR_PARAMS[custom_field]))
      end
      match_json(pattern)
    end
  end
end
