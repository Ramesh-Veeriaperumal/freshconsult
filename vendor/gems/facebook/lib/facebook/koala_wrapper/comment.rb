class Facebook::KoalaWrapper::Comment

  include Facebook::Core::Util
  include Facebook::Constants
  include Social::Util

  attr_accessor :comment, :comment_id, :requester, :feed_type, :description, :description_html, :created_at, 
                 :parent, :subject, :parent_post, :comments, :can_comment, :post_type

  alias_attribute :feed_id, :comment_id
  
  FIELDS = "#{COMMENT_FIELDS}, comments.fields(#{COMMENT_FIELDS})"


  def initialize(fan_page)
    @account          = fan_page.account
    @fan_page         = fan_page
    @rest             = Koala::Facebook::API.new(fan_page.page_token)
    @comments         = []
  end

  def fetch(comment_id)
    @comment = @rest.get_object(comment_id, :fields => FIELDS)
    parse if @comment
  end

  def parse
    @comment            =  @comment.symbolize_keys!
    @comment[:message]  =  remove_utf8mb4_char(@comment[:message])
    @comment_id         =  @comment[:id]
    @requester          =  @comment[:from]
    @feed_type          =  @comment[:attachment][:type] if @comment[:attachment]
    @description        =  @comment[:message]
    @description_html   =  html_content_from_comment(@comment)
    @created_at         =  Time.zone.parse(@comment[:created_time])
    @parent             =  @comment[:parent].symbolize_keys! if (@comment[:parent] and @comment[:parent][:id]!="0")
    @subject            =  truncate_subject(@description, 100)
    @comments           =  @comment[:comments]["data"] if @comment[:comments]
    @can_comment        =  @comment[:can_comment]
    @post_type          =  @parent.blank? ? POST_TYPE_CODE[:comment] : POST_TYPE_CODE[:reply_to_comment]
    @parent_post        =  @comment[:object] ? "#{@fan_page.page_id}_#{@comment[:object]['id']}" : "#{@fan_page.page_id}_#{@comment[:id].split('_').first}"
  end

  def visitor_post?
    @requester["id"] != @fan_page.page_id.to_s
  end
end
  
