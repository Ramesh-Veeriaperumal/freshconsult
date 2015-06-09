module ArticleBodyMigration
  class << self

    def migrate(shard_name)
      problematic_articles_by_account = {}
      Sharding.run_on_shard("shard_1") do
        Sharding.run_on_slave do
          ShardMapping.find_in_batches(:batch_size => 100, :conditions => ['shard_name = ?', shard_name]) do |smaps|
            smaps.each do |smap| 
              problematic_articles = migrate_article_bodies(smap.account_id)
              problematic_articles_by_account[smap.account_id] = problematic_articles if problematic_articles.present?
            end
          end
        end
      end
      problematic_articles_by_account
    end

    def migrate_article_bodies(account_id)
      Account.reset_current_account
      Sharding.select_shard_of account_id do
        p "***** Migration started for ##{account_id} *****"
        account = Account.find_by_id(account_id)
        next if account.blank?
        account.make_current
        p "***** Migration completed for ##{account_id} *****"
        populate_article_bodies
      end
    end

    private

    def populate_article_bodies
      problematic_articles = []
      Account.current.solution_articles.find_in_batches(:batch_size => 100, :include => [:article_body]) do |articles|
        articles.each do |article|
          next unless article.original_article_body.blank?
          article_body = article.build_article_body(
            :account => Account.current,
            :description => article.description,
            :desc_un_html => article.desc_un_html)
          problematic_articles << article.id unless article_body.save
          print '.'
        end
      end
      problematic_articles
    end
  end
end