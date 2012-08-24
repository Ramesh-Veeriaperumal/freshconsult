require 'html2textile'
module Mobile::Actions::Article

	JSON_OPTIONS = { 
		:only=> [ :id, :title, :desc_un_html ], 
		:methods => [ :textile_desc ] 
  }

  def textile_desc
    unless self.description.empty?
      parser = HTMLToTextileParser.new
      parser.feed self.description
      content = parser.to_textile 
    end
  end

  def to_mob_json
  	to_json JSON_OPTIONS
  end

end