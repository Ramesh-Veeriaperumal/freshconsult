require_relative "../../test_helper"
['ticket_helper.rb', 'canned_responses_helper.rb', 'group_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }

class CannedResponsesFlowTest < ActionDispatch::IntegrationTest
  include GroupHelper
  include TicketHelper
  include CannedResponsesHelper
  include CannedResponsesTestHelper

  def setup
    super
    before_all
  end

  def before_all
    @sample_ticket = create_ticket
    @ca_response = create_response(
      title: Faker::Lorem.sentence,
      content_html: 'Hi {{ticket.requester.name}}, Faker::Lorem.paragraph Regards, {{ticket.agent.name}}',
      visibility: Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:all_agents]
    )
  end

  def test_evaluation
    evaluated_content = evaluate_response(@ca_response, @sample_ticket)
    get "/api/_/tickets/#{@sample_ticket.display_id}/canned_responses/#{@ca_response.id}", nil, @write_headers
    assert_response 200
    body = ActiveSupport::JSON.decode(response.body)
    match_custom_json(body['canned_response'], canned_responses_evaluated_pattern(true, @ca_response.attachments_sharable, evaluated_content))
  end

  def test_on_alternate_path
    evaluated_content = evaluate_response(@ca_response, @sample_ticket)
    get "/api/_/tickets/#{@sample_ticket.display_id}/canned_responses?id=#{@ca_response.id}", nil, @write_headers
    assert_response 200
    body = ActiveSupport::JSON.decode(response.body)
    match_custom_json(body['canned_response'], canned_responses_evaluated_pattern(true, @ca_response.attachments_sharable, evaluated_content))
  end
end