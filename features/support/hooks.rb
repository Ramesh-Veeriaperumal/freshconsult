Before('@db_clean') do
  DatabaseCleaner.clean_with(:truncation,
                               pre_count: true, reset_ids: false)
end

Before('@ticket_dynamo_clean') do
  delete_ticket_dynamo_table
end

Before do
  create_test_account
  set_request_headers
  SpamCounter.stubs(:count).returns(0)
  Account.current.features.marketplace.destroy
  Sidekiq::Worker.clear_all
end

Before('@admin') do
  login_admin
  @account.make_current
end

Before('@link_tickets') do
  ticket_dynamo_table_create
  Helpdesk::Ticket.any_instance.stubs(:manual_publish_to_rmq).returns(true)
end

After('@link_tickets') do
  Helpdesk::Ticket.any_instance.unstub(:manual_publish_to_rmq)
end

After do
  logout
end