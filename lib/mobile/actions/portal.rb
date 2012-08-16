module Mobile::Actions::Portal
	def to_mob_json
    options = {
      :only => [ :name, :preferences ],
      :methods => [ :logo_url, :fav_icon_url ]
    }
    to_json options
  end
end