class Facebook::KoalaWrapper::Post
  attr_accessor :post, :post_id, :requester, :description, :description_html, :subject
  attr_accessor :created_at, :create_ticket, :comments
  include Facebook::Core::Util

  def initialize(fan_page)
  	@account = fan_page.account
  	@fan_page = fan_page
    @rest = Koala::Facebook::GraphAndRestAPI.new(fan_page.page_token)
  end

  def fetch(post_id)
    @post = @rest.get_object(post_id)
    parse if @post
  end

  def parse
    @post =  @post.symbolize_keys!
    @post_id = @post[:id]
    @requester = facebook_user(@post[:from])
    @description = @post[:message]
    @description_html = get_html_content_from_feed(@post)
    @subject = truncate_subject(@description, 100)
    @created_at = Time.zone.parse(@post[:created_time])
    company_post = (@post[:from][:id].to_s == @fan_page.page_id.to_s)
    import_company_post = (company_post && @fan_page.import_company_posts)
    import_visitors_post = (!company_post && @fan_page.import_visitor_posts)
    @create_ticket = (import_company_post || import_visitors_post)
    @comments = @post[:comments]["data"]  if @post[:comments] && @post[:comments]["data"]
  end

end
