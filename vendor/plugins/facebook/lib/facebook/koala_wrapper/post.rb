class Facebook::KoalaWrapper::Post
  attr_accessor :post, :post_id, :requester, :description, :description_html, :subject, :feed_type
  attr_accessor :created_at, :create_ticket, :comments
  include Facebook::Core::Util

  def initialize(fan_page)
  	@account = fan_page.account
  	@fan_page = fan_page
    @rest = Koala::Facebook::GraphAndRestAPI.new(fan_page.page_token)
  end

  # Adding page_id param is just an hack for this facebook bug
  # https://developers.facebook.com/bugs/695633340458716/
  # https://developers.facebook.com/bugs/256674844497023
  # side affects will create duplicate ticket if not present
  def fetch(post_id,page_id=nil)
    @post = @rest.get_object(post_id)
    if @post
      @post =  @post.symbolize_keys!
      # Overiding post in case of wrong post_id
      @post[:id] = "#{page_id}_#{post_id}" if !post_id.include?("_") && page_id
      parse 
    end
  end

  def parse
    @post_id = @post[:id]
    @feed_type = @post[:type]
    @requester = facebook_user(@post[:from])
    @description = @post[:message].to_s
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
