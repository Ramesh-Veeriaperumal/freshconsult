class PageDrop < BaseDrop

  def initialize(source)
    super source
  end
  
  def name
    source.name
  end

  def type
    source.token.to_s
  end

  def content
  	source.content
  end

end