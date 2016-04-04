class PopulatingDraftsFromArticle < ActiveRecord::Migration

  shard :all

  def migrate(direction)
    self.send(direction)
  end

  def up
    Account.find_in_batches(:batch_size => 100) do |accounts|
      accounts.each do |account|
        Account.reset_current_account
        migrate_for_account(account) 
      end
    end   
  end

  def down
    query_list = []
    query_list << "delete from solution_drafts;"
    query_list << "delete from solution_draft_bodies;"
    query_list.each do |query|
      ActiveRecord::Base.connection.execute query
    end
  end

  def migrate_for_account(current_account)
    current_account.make_current
    drafts_folder_update(current_account)
    create_draft_for_existing(current_account)
  end

  def drafts_folder_update(account)
    default_folder = account.solution_folders.where(:is_default => true).first
    default_folder.articles.update_all(:status => Solution::Article::STATUS_KEYS_BY_TOKEN[:draft])
  end

  def create_draft_for_existing(account)
    draft_articles = account.solution_articles.where('status = ?', Solution::Article::STATUS_KEYS_BY_TOKEN[:draft])
    draft_articles.each do |article|
      unless article.draft.present?
        article.create_draft_from_article
      end
    end
  end
    
end
