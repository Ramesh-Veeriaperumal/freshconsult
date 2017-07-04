['users_test_helper.rb','tickets_test_helper.rb','companies_test_helper.rb'].each { |file| require "#{Rails.root}/test/api/helpers/#{file}" }
['contact_fields_helper.rb','ticket_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }
module SearchTestHelper
  include TicketsTestHelper
  include UsersTestHelper
  include CompaniesTestHelper
  include ContactFieldsHelper

  def create_search_ticket(params)
    cc_emails = params[:cc_emails] || []
    fwd_emails = params[:fwd_emails] || []
    test_ticket = Helpdesk::Ticket.new(:status => params[:status],
                                       :display_id => params[:display_id], 
                                       :priority => params[:priority], 
                                       :requester_id => default_requester_id,
                                       :subject => params[:subject],
                                       :responder_id => params[:responder_id],
                                       :source => params[:source],
                                       :cc_email => Helpdesk::Ticket.default_cc_hash.merge(cc_emails: cc_emails, fwd_emails: fwd_emails),
                                       :created_at => params[:created_at],
                                       :account_id => @account.id,
                                       :custom_field => params[:custom_field])
    test_ticket.build_ticket_body(:description => Faker::Lorem.paragraph)
    test_ticket.group_id = params[:group_id]
    test_ticket.save_ticket
    test_ticket
  end

  def create_search_contact(params)
    test_contact = User.new(:name => params[:name],
                           :email => params[:email], 
                           :customer_id => params[:customer_id], 
                           :mobile => params[:mobile],
                           :phone => params[:phone],
                           :helpdesk_agent => params[:helpdesk_agent] || false,
                           :account_id => @account.id,
                           :custom_field => params[:custom_field])
    test_contact.save
    test_contact
  end

  def create_search_company(params)
    test_company = Company.new(:name => params[:name],
                           :description => params[:description],
                           :domains => params[:domains],
                           :account_id => @account.id,
                           :custom_field => params[:custom_field])
    test_company.save
    test_company
  end

  def default_requester_id
    @id ||= @account.all_contacts.first.id
  end

  def ticket_statuses
    @statuses ||= @account.ticket_statuses.map(&:status_id)
  end

  def clear_es(acid)
    ES_V2_SUPPORTED_TYPES.keys.each do |es_type|
      Search::V2::IndexRequestHandler.new(es_type, 1, nil).remove_by_query({ account_id: acid })
    end
  end

  def write_data_to_es(acid)
    Sharding.select_shard_of(acid) do
      Account.find(acid).make_current
      Account.current.users.find_in_batches(:batch_size => 300) do |users|
        users.map(&:sqs_manual_publish_without_feature_check)
      end
      Account.current.tickets.find_in_batches(:batch_size => 300) do |tickets|
        tickets.map(&:sqs_manual_publish_without_feature_check)
      end
      Account.current.notes.exclude_source(['meta', 'tracker']).find_in_batches(:batch_size => 300) do |notes|
        notes.map(&:sqs_manual_publish_without_feature_check)
      end
      Account.current.archive_tickets.find_in_batches(:batch_size => 300) do |archive_tickets|
        archive_tickets.map(&:sqs_manual_publish_without_feature_check)
      end
      Account.current.archive_notes.exclude_source('meta').find_in_batches(:batch_size => 300) do |archive_notes|
        archive_notes.map(&:sqs_manual_publish_without_feature_check)
      end
      Account.current.solution_articles.find_in_batches(:batch_size => 300) do |articles|
        articles.map(&:sqs_manual_publish_without_feature_check)
      end
      Account.current.topics.find_in_batches(:batch_size => 300) do |topics|
        topics.map(&:sqs_manual_publish_without_feature_check)
      end
      Account.current.posts.find_in_batches(:batch_size => 300) do |posts|
        posts.map(&:sqs_manual_publish_without_feature_check)
      end
      Account.current.companies.find_in_batches(:batch_size => 300) do |companies|
        companies.map(&:sqs_manual_publish_without_feature_check)
      end
      Account.current.tags.find_in_batches(:batch_size => 300) do |tags|
        tags.map(&:sqs_manual_publish_without_feature_check)
      end
    end
    sleep(5)
  end
end
