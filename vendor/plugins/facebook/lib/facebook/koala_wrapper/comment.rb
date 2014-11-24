class Facebook::KoalaWrapper::Comment

  include Facebook::Core::Util
  include Facebook::Constants

  attr_accessor :comment, :comment_id, :requester, :feed_type, :description, :description_html, :created_at, 
                 :parent, :subject, :parent_post, :comments, :can_comment

  alias_attribute :feed_id, :comment_id
  
  FIELDS = "#{COMMENT_FIELDS}, comment.fields(#{COMMENT_FIELDS})"


  def initialize(fan_page)
    @account   = fan_page.account
    @fan_page  = fan_page
    @rest      = Koala::Facebook::API.new(fan_page.page_token)
    @comments  = []
  end

  def fetch(comment_id)
    @comment = @rest.get_object(comment_id, :fields => FIELDS)
    parse if @comment
  end

  def parse
    @comment            =  @comment.symbolize_keys!
    @comment_id         =  @comment[:id]
    @requester          =  @comment[:from]
    @feed_type          =  @comment[:attachment][:type] if @comment[:attachment]
    @description        =  @comment[:message]
    @description_html   =  html_content_from_comment(@comment)
    @created_at         =  Time.zone.parse(@comment[:created_time])
    @parent             =  @comment[:parent].symbolize_keys! if (@comment[:parent] and @comment[:parent][:id]!="0")
    @subject            =  truncate_subject(@description, 100)
    @parent_post        =  "#{@fan_page.page_id}_#{@comment[:id].split('_').first}"
    @comments           =  @comment[:comments]["data"] if @comment[:comments]
    @can_comment        =  @comment[:can_comment]
  end

  def visitor_post?
    @requester != @fan_page.page_id
  end
end
  
