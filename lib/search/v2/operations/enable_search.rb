# Register tenant details in ES on account create
#
class Search::V2::Operations::EnableSearch

  def initialize(args)
    args.symbolize_keys!

    @account_id = args[:document_id]
  end
  
  #(*) Create aliases
  #(*) Push data for ES models
  def perform
    Sharding.select_shard_of(@account_id) do
      Sharding.run_on_slave do
        Account.reset_current_account
        account = Account.find(@account_id).make_current

        Search::V2::Tenant.new(account.id).bootstrap
        
        # Push initially bootstrapped data to ES
        #
        account.users.visible.find_in_batches(:batch_size => 300) do |users|
          update_in_es(users)
        end
        account.tickets.visible.find_in_batches(:batch_size => 300) do |tickets|
          update_in_es(tickets)
        end
        account.solution_articles.visible.find_in_batches(:batch_size => 300) do |articles|
          update_in_es(articles)
        end
        account.topics.find_in_batches(:batch_size => 300) do |topics|
          update_in_es(topics)
        end
        account.posts.find_in_batches(:batch_size => 300) do |posts|
          update_in_es(posts)
        end
        account.companies.find_in_batches(:batch_size => 300) do |companies|
          update_in_es(companies)
        end
        account.notes.visible.exclude_source('meta').find_in_batches(:batch_size => 300) do |notes|
          update_in_es(notes)
        end
        account.tags.find_in_batches(:batch_size => 300) do |tags|
          update_in_es(tags)
        end

      end
    end
  end
  
  private
    
    def update_in_es(items)
      items.each do |item|
        item.sqs_manual_publish
      end
    end
end