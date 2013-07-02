module ForumHelperMethods

	# Savage Beast application_helper methods moved here

	def feed_icon_tag(title, url)
		(@feed_icons ||= []) << { :url => url, :title => title }
		link_to image_tag('/images/feed-icon.png', :size => '14x14', :style => 'margin-right:5px', :alt => "Subscribe to #{title}"), url
	end

	def search_posts_title
		returning(params[:q].blank? ? 'Recent Posts'[] : "Searching for"[] + " '#{h params[:q]}'") do |title|
			title << " "+'by {user}'[:by_user,h(User.find(params[:user_id]).display_name)] if params[:user_id]
			title << " "+'in {forum}'[:in_forum,h(Forum.find(params[:forum_id]).name)] if params[:forum_id]
		end
	end

	def search_posts_path(rss = false)
		options = params[:q].blank? ? {} : {:q => params[:q]}
		options[:format] = 'rss' if rss
		[[:user, :user_id], [:forum, :forum_id]].each do |(route_key, param_key)|
			return send("#{route_key}_posts_path", options.update(param_key => params[param_key])) if params[param_key]
		end
		options[:q] ? search_all_posts_path(options) : send("all_posts_path", options)
	end

end