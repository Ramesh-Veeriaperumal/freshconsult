#Remove this class after completly migrating to realtime facebook
class Facebook::Fql::Posts
  
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

  def fetch
    until_time = @fan_page.fetch_since  
    
    query =  "SELECT post_id, actor_id, updated_time FROM stream WHERE source_id=#{@fan_page.page_id} and
                  (created_time > #{@fan_page.fetch_since} or updated_time > #{@fan_page.fetch_since})"
    query << " and actor_id != #{@fan_page.page_id}" if @fan_page.import_only_visitor_posts
    query << " and actor_id = #{@fan_page.page_id}"  if @fan_page.import_only_company_posts
    
    if query
      feeds = @rest.fql_query(query)
      unless feeds.blank?
        until_time = feeds.collect {|f| f["updated_time"]}.compact.max 
        unless until_time.blank?
          fb_attr = {:fetch_since => until_time}
          fb_attr[:last_error] = nil unless  @fan_page.last_error.nil?
          @fan_page.update_attributes(fb_attr)
        end
      end
      process_posts_via_koala(feeds)
    end
  end
  
  
  def get_comment_updates(fetch_since)
    @fan_page.fb_posts.find_in_batches(:batch_size => 500,
                                      :conditions => [ "social_fb_posts.postable_type = ? and social_fb_posts.msg_type = ? and created_at > ?",
    'Helpdesk::Ticket','post',(Time.now - 7.days).to_s(:db)]) do |retrieved_posts|

      retrieved_posts_id = retrieved_posts.map { |post|  "'#{post.post_id}'" }.join(',')

      query = "SELECT id, fromid, attachment, text, time, parent_id, post_fbid, can_comment FROM comment where post_id in
                   (#{retrieved_posts_id}) and time > #{fetch_since}"
      comments = @rest.fql_query(query)
      @fan_page.update_attribute(:last_error, nil) unless @fan_page.last_error.nil?
      process_comments(comments)    
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
  
  def process_comments(comments)
    comments.each do |comment|
      comment.symbolize_keys!
      next if @account.facebook_posts.find_by_post_id(comment[:id])
      feed = {
        :id => comment[:id],
        :from => comment[:fromid],
        :attachment => comment[:attachment],
        :message => comment[:text],
        :created_time => "#{Time.at(comment[:time]).utc}",
        :parent => {
          :id => comment[:parent_id]
        },
        :can_comment => comment[:can_comment]
      }
      process_comment_via_koala(feed)
    end
  end
  
  def process_posts_via_koala(posts)
    posts.each do |post|
      post.symbolize_keys!
      next if @account.facebook_posts.find_by_post_id(post[:post_id])
      koala_feed = Facebook::KoalaWrapper::Post.new(@fan_page)
      koala_feed.fetch(post[:post_id])
      clazz = post_type(post[:actor_id])
      process_feed(clazz, koala_feed)
    end
  end
  
  def process_comment_via_koala(comment)
    koala_feed = Facebook::KoalaWrapper::Comment.new(@fan_page)
    koala_feed.comment = comment
    koala_feed.parse
    clazz = (comment[:parent][:id] == "0") ? POST_TYPE[:comment] : POST_TYPE[:reply_to_comment]
    process_feed(clazz, koala_feed)
  end
  
  def process_feed(clazz, feed)
    ("facebook/core/"+"#{clazz}").camelize.constantize.new(@fan_page, feed).send("process", nil, @fan_page.realtime_subscription)
  end
  
  def post_type(from)
    (@fan_page.page_id == from) ? POST_TYPE[:status] : POST_TYPE[:post]
  end
    
end
