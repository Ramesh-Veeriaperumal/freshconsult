namespace :seed_sample do

  USER_AGENTS = YAML.load_file('db/sample_data/user_agents.yml')

  desc "This task creates portal tickets with meta info (browser info) loaded" 
  task :portal_tickets, [:account_id] => :environment do |t, args|
    account_id = args[:account_id] || ENV["ACCOUNT_ID"] || Account.first.id
    Sharding.select_shard_of(account_id) do 
      account = Account.find(account_id).make_current
      (rand(2..10)).times do
        create_portal_ticket
      end
      create_portal_ticket(true, false)
      create_portal_ticket(false)
      Account.reset_current_account
    end
  end

  def create_portal_ticket(include_meta = true, valid_data = true)
    ticket = Account.current.tickets.build(portal_ticket_params[:ticket])
    ticket.meta_data = include_meta ? (valid_data ? valid_meta_info : invalid_meta_info) : empty_meta_info
    ticket.save_ticket
    ticket
  end

  def portal_ticket_params
    {
      ticket: {
        email: Faker::Internet.email, 
        name: Faker::Name.name, 
        subject: Faker::Lorem.sentence(3), 
        ticket_body_attributes: {
          description_html: Faker::Lorem.paragraph
        }
      }
    }
  end

  def valid_meta_info
    { user_agent: USER_AGENTS.sample, referrer: Faker::Internet.url }
  end

  def invalid_meta_info
    { user_agent: Faker::Lorem.sentence(2), referrer: Faker::Lorem.sentence(5) }
  end

  def empty_meta_info
    { user_agent: '', referrer: '' }
  end

end
