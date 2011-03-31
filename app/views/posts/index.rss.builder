xml.instruct! :xml, :version => "1.0" 
xml.rss :version => "2.0" do
  xml.channel do
    xml.title "Articles"
    xml.description "Lots of articles"
    xml.link formatted_posts_url(:rss)
    
    for article in @posts
      xml.item do
        xml.title article.topic.title
        xml.description article.body
        xml.pubDate article.created_at.to_s(:rfc822)
        xml.link category_forum_topic_post_url(article.topic.forum.forum_category_id,article.topic.forum_id,article.topic_id,article)
        xml.guid category_forum_topic_post_url(article.topic.forum.forum_category_id,article.topic.forum_id,article.topic_id,article)
      end
    end
  end
end