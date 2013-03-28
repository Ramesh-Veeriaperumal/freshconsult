class Forum::CategoryDrop < BaseDrop
  
  include ActionController::UrlWriter
  
  liquid_attributes << :name << :description
  
  def initialize(source)
    super source
  end
  
  def id
    source.id
  end
  
  def url
    support_discussions_path
  end

  def forums_count
    @forums_count ||= @source.forums.visible(portal_user).size
  end

  def forums
    @forums ||= @source.forums.visible(portal_user)
  end
  
end