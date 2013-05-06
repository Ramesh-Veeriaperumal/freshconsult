module Mobile::Actions::Article

	JSON_OPTIONS = { 
		:only=> [ :id, :title, :desc_un_html ]
  }


  def to_mob_json
  	to_json JSON_OPTIONS
  end

end