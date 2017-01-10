module ControllerCucumberHelper

  def log_in(user)
    params = {:user_session => {:email => user.email, :password => "test1234"}}
    post support_login_path, params, @headers
  end

  def login_admin()
    @agent = get_admin
    log_in(@agent)
  end

  def get_admin()
    users = @account.account_managers
    users.each do |user|
      return user if user.can_view_all_tickets? and user.privilege?(:manage_canned_responses) and !user.agent.occasional?
    end
    add_test_agent(@account)
  end

  def logout
    get logout_url
  end

  def set_request_headers
    @headers = { 'HTTP_HOST' => 'localhost.freshpo.com'}
    host!('localhost.freshpo.com')
  end
  
  def assert_redirection(path)
    assert last_response.redirection?
    uri = URI.parse(last_response.location)
    assert_equal path, uri.path
  end


  def ticket_dynamo_table_create
    hash_key = "ticket_account"
    params = {
    table_name: Helpdesk::Ticket::DEFAULT_TABLE_NAME,
    key_schema: [
        {
            attribute_name: hash_key,
            key_type: "HASH" #Primary key 
        }
    ],
    attribute_definitions: [
        {
            attribute_name: hash_key,
            attribute_type: "S"
        }
    ],
    provisioned_throughput: { 
        read_capacity_units: 2,
        write_capacity_units: 2
      }
    }

    begin
      $dynamo_v2_client.create_table(params)
    rescue  Aws::DynamoDB::Errors::ServiceError => error
      puts "Unable to create table:"
      puts "#{error.message}"
    end
    
  end

  def delete_ticket_dynamo_table
    if $dynamo_v2_client.list_tables.table_names.include?(Helpdesk::Ticket::DEFAULT_TABLE_NAME)
      $dynamo_v2_client.delete_table(:table_name => Helpdesk::Ticket::DEFAULT_TABLE_NAME)
    end
  end

end

World(ControllerCucumberHelper)