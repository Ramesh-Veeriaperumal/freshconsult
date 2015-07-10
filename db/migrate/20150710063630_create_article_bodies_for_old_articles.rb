class CreateArticleBodiesForOldArticles < ActiveRecord::Migration
  shard :all

  def migrate(direction)
    self.send(direction)
  end

  def self.up
    Solution::Article.find_in_batches(:batch_size => 100, :include => [:article_body]) do |articles|
      articles.each do |article|
        next unless article.original_article_body.blank?
        article_body = article.build_article_body(
                          :account => article.account,
                          :description => article.read_attribute('description'),
                          :desc_un_html => article.read_attribute('desc_un_html'))
        article_body.save
       end
    end
  end

  def self.down
  end
end

