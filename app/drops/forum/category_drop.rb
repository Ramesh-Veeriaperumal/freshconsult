class Forum::CategoryDrop < BaseDrop
  
  include Rails.application.routes.url_helpers
  
  self.liquid_attributes += [:name, :description]
  
  def initialize(source)
    super source
  end
  
  def id
    source.id
  end
  
  def url
    support_discussion_path(@source)
  end

  def forums_count
    @forums_count ||= @source.forums.visible(portal_user).size
  end

  def forums
    @forums ||= @source.forums.visible(portal_user)
  end
  
end