class Facebook::KoalaWrapper::Comment
  attr_accessor :comment, :comment_id, :user, :message, :created_at
  include Facebook::Core::Util

  def initialize(fan_page)
  	@account = fan_page.account
  	@fan_page = fan_page
    @rest = Koala::Facebook::GraphAndRestAPI.new(fan_page.page_token)
  end

  def fetch(comment_id)
    @comment = @rest.get_object(comment_id)
    parse if @comment
  end

  def parse
    @comment =  @comment.symbolize_keys!
    @comment_id = @comment[:id]
    @user = facebook_user(@comment[:from])
    @message = @comment[:message]
    @created_at = Time.zone.parse(@comment[:created_time])
  end

end
