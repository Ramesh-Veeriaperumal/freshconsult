module Mobile::Actions::Article

	JSON_OPTIONS = { 
		:only=> [ :id, :title, :desc_un_html,:description ]
  }


  def to_mob_json
  	to_json JSON_OPTIONS
  end

  def to_mob_json_search
    JSON_OPTIONS[:only] << :description
  	to_json JSON_OPTIONS
  end

end