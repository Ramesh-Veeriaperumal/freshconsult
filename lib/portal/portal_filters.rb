module PortalFilters
	include ActionView::Helpers::TagHelper
	include ActionView::Helpers::DateHelper
	include ActionView::Helpers::UrlHelper
	
	# ActionView::Base.default_form_builder = FormBuilders::RedactorBuilder
	
	# Forum based helpers 
	# Have to move these into their respective pages
	def bold content
		content_tag :strong, content
	end

	def day_and_time date_time
		date_time.to_s :long_day_with_time
	end

	def time_ago date_time 
		"#{distance_of_time_in_words_to_now date_time} ago"
	end

	# rendering partial if its corresponding db_file is not available
	def portal_render local_file, db_file = ""
		# render_to_string :partial => local_file, :locals => { :dynamic_template => db_file }
	end

	# Top page login, signup and user welcome information
	def welcome_navigation portal
		output = []
		
		# Showing welcome text before login link		
		output << %(<div class="welcome"> #{ t('header.welcome') })

		# Showing logged in user name or displaying as Guest
		output << %(<b>#{ portal['user'] || t('header.guest') }</b> </div> )

		# Showing portal login link or signout link based on user logged in condition 
		if portal['user']			
			output << %(<b><a href="#{ portal['logout_path'] }">#{ t('header.signout') }</a></b>)
		else
			output << %(<b><a href="#{ portal['login_path'] }">#{ t('header.login') }</a></b>)
			# Showing signup url based on customer portal settings feature
			output << %(or <b><a href="#{ portal['signup_path'] }">#{ t('signup') }</a></b>) if portal['can_signup_feature?']
		end

		output.join(" ")
	end


	# Ticket info for list view
	def default_info(ticket)
		output = []
		unless ticket.requester.nil? or User.current.eql?(ticket.requester)
			output << %(#{I18n.t('ticket.portal_created_on', { :username => h(ticket.requester.name), :date => ticket.created_on })})
		else
			output << %(#{I18n.t('ticket.portal_created_on_same_user', { :date => ticket.created_on })})
		end

		output << %(#{I18n.t('ticket.assigned_agent')}: <span class='emphasize'> #{ticket.agent.name}</span>) unless ticket.agent.blank?
		
		output.join(" ")
	end

	# Pageination filter for generating the pagination links
	def default_pagination(paginate, previous_label = "&laquo; #{I18n.t('previous')}", next_label = "#{I18n.t('next')} &raquo;")
	    html = []
	    if paginate['parts'].size > 0
		    html << %(<div class="pagination"><ul>)
		    if paginate['previous']
		    	html << %(<li class="prev">#{link_to(previous_label, paginate['previous']['url'])}</li>)
		    else
		    	html << %(<li class="prev disabled"><a>#{previous_label}</a></li>)
		    end

		    for part in paginate['parts']
		      if part['is_link']
		        html << %(<li>#{link_to(part['title'], part['url'])}</li>)        
		      elsif part['title'].to_i == paginate['current_page'].to_i
		        html << %(<li class="disabled gap"><a>#{part['title']}</a></li>)        
		      else
		        html << %(<li class="active"><a>#{part['title']}</a></li>)
		      end	      
		    end

		    if paginate['next']
		    	html << %(<li class="next">#{link_to(next_label, paginate['next']['url'])}</li>)
		    else
		    	html << %(<li class="next disabled"><a>#{next_label}</a></li>)
		   	end

		    html << %(</ul></div>)
		end		
	    html.join(' ')
	    # windowed_links
	end

	def windowed_links
      prev = nil

      visible_page_numbers(0, 100).inject [] do |links, n|
        # detect gaps:
        links << %(<a>&hellip;</a>) if prev and n > prev + 1
        links << %(<a>#{n}</a>)
        prev = n
        links
      end
    end

	def visible_page_numbers current_page, total_pages
	    inner_window, outer_window = 4, 1
	    window_from = current_page - inner_window
	    window_to = current_page + inner_window
	    
	    # adjust lower or upper limit if other is out of bounds
	    if window_to > total_pages
	      window_from -= window_to - total_pages
	      window_to = total_pages
	    end
	    if window_from < 1
	      window_to += 1 - window_from
	      window_from = 1
	      window_to = total_pages if window_to > total_pages
	    end
	    
	    visible   = (1..total_pages).to_a
	    left_gap  = (2 + outer_window)...window_from
	    right_gap = (window_to + 1)...(total_pages - outer_window)
	    visible  -= left_gap.to_a  if left_gap.last - left_gap.first > 1
	    visible  -= right_gap.to_a if right_gap.last - right_gap.first > 1

	    visible    
	  end

	# Applicaiton link helpers
	# !PORTALCSS move this area INTO link_helpers later
	def login_via_google label
		link_to(label, "/auth/open_id?openid_url=https://www.google.com/accounts/o8/id", :class => "btn btn-google") if Account.current.features? :google_signin
	end
	
	def login_via_twitter label
		link_to(label, "/auth/twitter", :class => "btn btn-twitter") if Account.current.features? :twitter_signin
	end

	def login_via_facebook label
		link_to(label, "/sso/facebook", :class => "btn btn-facebook") if Account.current.features? :facebook_signin
	end
	
	# Topic specific filters

	# Follow/unfollow button 
	# To modify label the liquid can be modified as so
	# {{ topic | follow_topic_button : "Click to follow", "Click to unfollow" }}
	def follow_topic_button topic, follow_label = "Follow", unfollow_label = "Unfollow"
		if User.current
			_monitoring = !Monitorship.count(:id, 
							:conditions => ['user_id = ? and topic_id = ? and active = ?', 
							User.current.id, topic['id'], true]).zero?

			link_to _monitoring ? unfollow_label : follow_label, topic['toggle_follow_url'], 
				"data-remote" => true, "data-method" => :put, 
				:class => "btn btn-small #{_monitoring ? 'active' : ''}",
				"data-toggle" => "button",
				"data-button-active-label" => unfollow_label, 
				"data-button-inactive-label" => follow_label
		end
	end

end
