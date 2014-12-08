class Facebook::KoalaWrapper::Post  
  
  include Facebook::Core::Util
  include Facebook::Constants

  attr_accessor :post, :post_id, :feed_type, :requester, :description, :description_html, :subject,
                 :created_at, :comments, :can_comment, :post_type
                 
  alias_attribute :feed_id, :post_id
  
  FIELDS = "#{POST_FIELDS}, comments.fields(#{COMMENT_FIELDS}, comments.fields(#{COMMENT_FIELDS}))"

  def initialize(fan_page)
    @account  = fan_page.account
    @fan_page = fan_page
    @rest     = Koala::Facebook::API.new(fan_page.page_token)
    @comments = []
  end

  def fetch(post_id)
    @post = @rest.get_object(post_id, :fields => FIELDS)
    parse if @post
  end

  def parse
    @post             =   @post.symbolize_keys!
    @post_id          =   @post[:id]
    @feed_type        =   @post[:type]
    @requester        =   @post[:from] 
    @description      =   @post[:message].to_s
    @description_html =   html_content_from_feed(@post)
    @subject          =   truncate_subject(@description, 100)
    @created_at       =   Time.zone.parse(@post[:created_time])
    @comments         =   @post[:comments]["data"] if @post[:comments] && @post[:comments]["data"]
    @can_comment      =   true
    @post_type        =   POST_TYPE_CODE[:post]
  end

  def company_post?
    !visitor_post?
  end
  
  def visitor_post?
    requester_fb_id != @fan_page.page_id.to_s
  end  
  
  def requester_fb_id
    @post[:from].is_a?(Hash) ? @post[:from]["id"] : @post[:from]
  end

end
