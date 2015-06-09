#Remove this class after completly migrating to realtime facebook
class Facebook::Graph::Posts
  
  include Social::Constants
  include Facebook::Constants
  
  def initialize(fb_page, options = {})
    @account = options[:current_account]  || fb_page.account
    @rest = Koala::Facebook::API.new(fb_page.page_token)
    @fan_page = fb_page
  end
  
  def fetch_latest_posts
    posts = @rest.get_connections('me', 'feed')
    unless posts.blank?
      process_graph_feeds(posts)
      updated_time = Time.zone.parse(posts.first[:updated_time])       
      @fan_page.update_attributes({:fetch_since => updated_time.to_i}) unless updated_time.blank?
    end
  end
  
  private
  
  def process_graph_feeds(posts)
    posts.each do |post|
      post.symbolize_keys!
      next if @account.facebook_posts.find_by_post_id(post[:id])
      koala_feed = Facebook::KoalaWrapper::Post.new(@fan_page)
      koala_feed.post = post
      koala_feed.parse
      clazz = post_type(koala_feed.requester_fb_id)
      process_feed(clazz, koala_feed)
    end
  end
  
  def process_feed(clazz, feed)
    ("facebook/core/"+"#{clazz}").camelize.constantize.new(@fan_page, feed).send("process")
  end
  
  def post_type(from)
    (@fan_page.page_id == from) ? POST_TYPE[:status] : POST_TYPE[:post]
  end
    
end
