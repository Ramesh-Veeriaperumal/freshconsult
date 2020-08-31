class SearchSidekiq::CreateAlias
  include Sidekiq::Worker

  sidekiq_options :queue => :es_alias_queue, :retry => 0, :failures => :exhausted

  def perform(args)
    args.symbolize_keys!
    account = Account.current
    account.create_es_enabled_account(:account_id => account.id)

    if args[:sign_up]
      account.users.visible.find_in_batches(:batch_size => 300) do |users|
        users.each { |user| user.update_es_index }
      end
      account.tickets.visible.find_in_batches(:batch_size => 300) do |tickets|
        tickets.each { |ticket| ticket.update_es_index }
      end
      account.solution_articles.visible.find_in_batches(:batch_size => 300) do |articles|
        articles.each { |article| article.update_es_index }
      end
      account.topics.find_in_batches(:batch_size => 300) do |topics|
        topics.each { |topic| topic.update_es_index }
      end
      account.companies.find_in_batches(:batch_size => 300) do |companies|
        companies.each { |company| company.update_es_index }
      end
      account.notes.visible.exclude_source('meta').find_in_batches(:batch_size => 300) do |notes|
        notes.each { |note| note.update_es_index }
      end
      account.tags.find_in_batches(:batch_size => 300) do |tags|
        tags.each { |tag| tag.update_es_index }
      end
      account.scn_automations.find_in_batches(:batch_size => 300) do |callers|
        callers.each { |caller| caller.update_es_index }
      end
      account.canned_responses.find_in_batches(:batch_size => 300) do |callers|
        callers.each { |caller| caller.update_es_index }
      end
    end
  end
end