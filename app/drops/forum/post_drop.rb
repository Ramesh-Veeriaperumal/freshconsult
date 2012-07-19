class Forum::PostDrop < BaseDrop
  
  include ActionController::UrlWriter
  
  liquid_attributes << :body << :body_html << :id
  
  def initialize(source)
    super source
  end

  def user
  	source.user
  end
  
end