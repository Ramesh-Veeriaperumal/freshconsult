module Portal::Helpers::DiscussionsHelper

	# Default topic filter that shows up in the topic list
	def default_topic_filters forum
		output = []
		output << %(<ul class="nav nav-pills nav-filter">)
			forum.allowed_filters.each do |f|
				output << %(<li class="#{forum.current_topic_filter == f[:name] ? "active" : ""}">)
				output << link_to(t("forums_order.#{f[:name]}"), f[:url])
				output << %(</li>)
			end
		output << %(</ul>)
	end

	# Follow/unfollow button
	# To modify label the liquid can be modified as so
	# {{ topic | follow_topic_button : "Click to follow", "Click to unfollow" }}
	def follow_topic_button topic, follow_label = t('portal.topic.follow'), unfollow_label = t('portal.topic.following')
		follow_button(topic, follow_label, unfollow_label)
	end

	def follow_forum_button forum, follow_label = t('portal.topic.follow'), unfollow_label = t('portal.topic.following')
		follow_button(forum, follow_label, unfollow_label) if forum.type_name == 'announcement'
	end

	def follow_button current_obj, follow_label, unfollow_label
		if User.current
			_monitoring = current_obj['followed_by_current_user?']

			link_to _monitoring ? unfollow_label : follow_label, current_obj['toggle_follow_url'],
				"data-remote" => true, "data-method" => :put,
				:id => "topic-monitor-button",
				:class => "btn btn-small #{_monitoring ? 'active' : ''}",
				"data-toggle" => "button",
				"data-button-active-label" => unfollow_label,
				"data-button-inactive-label" => follow_label
		end
	end

	def my_topic_info topic
		if topic.has_comments
			post = topic.last_post.to_liquid
			"#{I18n.t('portal.topic.my_topic_reply', :post_name => h(post.user.name), :created_on => time_ago(post.created_on))}"
		else
			topic_brief(topic)
		end
	end

	def topic_info_with_votes topic
		output = []
		output << topic_brief(topic)
		output << last_post_brief(topic.to_liquid) if topic.has_comments
		output << bold(topic_votes(topic)) if(topic.votes > 0)
		output.join(", ")
	end

	def topic_votes topic
		pluralize topic.votes, "vote"
	end

	def topic_icon topic
		output = []
		output << %(<span id="sticky-topic-icon" data-toggle="tooltip" title="#{t('discussions.topics.sticky')}"><span class="icon-sticky"></span></span>) if topic.source.sticky?
		output.join('')
	end

	def topic_small_icon topic
		output = []
		output << %(<span id="sticky-small-topic-icon" data-toggle="tooltip" title="#{t('discussions.topics.sticky')}"><span class="icon-sticky-small"></span></span>) if topic.source.sticky?
		output.join('')
	end

	def topic_labels topic
		return "" if topic.merged?
		output = []
		output << %(<div class="topic-labels">)
		output << %(<span class="label label-answered">
				#{t('topic.questions.answered')}</span>) if topic['answered?']

		output << %(<span class="label label-solved">
				#{t('topic.problems.solved')}</span>) if topic['solved?']

		output << %(<span class="label label-#{topic['stamp']}">
				#{t('topic.ideas_stamps.'+topic['stamp'])}</span>) if topic['stamp'].present?

		output << %(</div>)
		output.join('')
	end

	def post_topic_in_portal portal, post_topic = false
		output = []
		output << %(<section class="lead">)
		if portal['facebook_portal']
			output << %(<a href="" class="solution_c">#{I18n.t('portal.login')}</a>)
		else
			output << I18n.t('portal.login_or_signup', 
				:login => "<a href=\"#{portal['topic_reply_url']}\">#{I18n.t('portal.login')}</a>",
				:signup => "<a href=\"#{portal['signup_url'] }\">#{I18n.t('portal.signup')}</a>") if
						portal['can_signup_feature']
		end
		if post_topic
			output << I18n.t("portal.to_post_topic")
		else
			output << I18n.t("portal.to_post_comment")
		end

		output << %(</section>)

		output.join('')
	end

	def link_to_topic_edit topic, label = I18n.t("topic.edit")
		if User.current == topic.user && !topic.merged?
			link_to label, topic['edit_url'], :title => label, :class => "btn btn-small"
		end
	end

	def link_to_mark_as_solved topic, solve_label = I18n.t("forum_shared.post.mark_as_solved"), unsolve_label = I18n.t("forum_shared.post.mark_as_unsolved")
		if User.current == topic.user && topic.forum.problems?
			link_to topic['solved?'] ? unsolve_label : solve_label, topic['toggle_solution_url'],
						"data-method" => :put,
						:class => "btn btn-small"
		end
	end

	def link_to_merged_topic topic
		link_to topic.merged_into['title'], topic.merged_topic_url
	end

	def merged_list topic
		list = "<ul>"
		topic.source.merged_topics.each do |merged|
			list << "<li>" + link_to_topic(merged.to_liquid) + "</li>"
		end
		list << "</ul>"
		list.html_safe
	end

	def merged_topics topic
		return "" unless topic.has_merged_topics?
		output = []
		output << %(<div class="list-lead">)
		output << I18n.t('portal.topic.merge_note', :count => topic.source.merged_topics.map(&:id).size)
		output << %(</div>)
		output << merged_list(topic)
		output.join('')
	end

	def link_to_see_all_topics forum
		label = I18n.t('portal.topic.see_all_topics', :count => forum['topics_count'])
		link_to label, forum['url'], :title => label, :class => "see-more"
	end

	def post_actions post
		output = []
		if User.current == post.user
		output << %(<span class="pull-right post-actions" id="post-actions-#{post["id"]}">
						<a href="#{ post["edit_url"] }" data-remote="true" data-type="GET" data-loadonce
								 	data-update="#post-#{post["id"]}-edit" data-show-dom="#post-#{post["id"]}-edit"
								    data-hide-dom="#post-#{post["id"]}-description">
									<i class="icon-edit-post"></i>
						</a>
						<a href="#{ post["delete_url"] }" data-method="delete"
				     			data-confirm="This post will be delete permanently. Are you sure?">
				     			<i class="icon-delete-post"></i>
				     		</a>
					</span>)
		elsif post.user_can_mark_as_answer?
			label = post.answer? ? t('forum_shared.post.unmark_answer') : t('forum_shared.post.mark_answer')
			unless post.topic.answered? and !post.answer?
				output << %(<div class="pull-right post-actions">
										<a 	href="#{post['toggle_answer_url']}"
												data-method="put"
												class="tooltip"
												title="#{label}">
											<i class="icon-#{post.answer? ? 'unmark' : 'mark'}-answer"></i>
										</a>
									</div>)
			else
				output << %(<div class="pull-right post-actions">
			                	<a 	href="#{post.best_answer_url}"
														data-target="#best_answer"  rel="freshdialog"
														title="#{label}"
														data-submit-label="#{label}" data-close-label="#{t('cancel')}"
														data-submit-loading="#{t('ticket.updating')}..."
														data-width="700px"
														class="tooltip"
														title="#{label}">
														<i class="icon-mark-answer"></i>
												</a>
									</div>)
			end
		end
		output.join('')
	end

	def post_attachments post
		output = []

		if(post.attachments.size > 0)
			output << %(<div class="cs-g-c attachments" id="post-#{ post.id }-attachments">)

			post.attachments.each do |a|
				output << attachment_item(a.to_liquid)
			end

			output << %(</div>)
		end

		output.join('').html_safe
	end

	# No content information for forums
	def filler_for_forums portal
		%( <div class='no-results'> #{I18n.t('portal.no_forums_info_1')} </div>
		   <div class='no-results'> #{ I18n.t('portal.no_forums_info_2',
		   		:start_topic_link => link_to_start_topic(portal))} </div> )
	end

	def link_to_forum_with_count forum, *args
		link_opts = link_args_to_options(args)
		label = " #{h(forum['name'])} <span class='item-count'>#{forum['topics_count']}</span>".html_safe
		content_tag :a, label, { :href => forum['url'], :title => h(forum['name']) }.merge(link_opts)
	end

	def link_to_start_topic portal, *args
		link_opts = link_args_to_options(args)
		label = link_opts.delete(:label) || I18n.t('portal.topic.start_new_topic')
		content_tag :a, label, { :href => portal['new_topic_url'], :title => h(label) }.merge(link_opts)
	end

	def topic_list forum, limit = 5
		if(forum['topics_count'] > 0)
			topics = forum['topics']
			output = []
			output << %(<ul>#{ topics.take(limit).map { |t| topic_list_item t.to_liquid } })
			if topics.size > limit
				output << %(<a href="#{forum['url']}" class="see-more">)
				output << %(#{ I18n.t('portal.topic.see_all_topics', :count => forum['topics_count']) })
				output << %(</a>)
			end
			output << %(</ul>)
			output.join("")
		end
	end

	def topic_list_item topic
		output = <<HTML
			<li>
				<div class="ellipsis">
					<a href="#{topic['url']}">#{h(topic['title'])}</a>
				</div>
				<div class="help-text">
					#{ topic_info topic }
				</div>
			</li>
HTML
		output.html_safe
	end

	def topic_info topic
		output = []
		output << topic_brief(topic)
		output << %(<div> #{last_post_brief(topic.to_liquid)} </div>) if topic.has_comments
		output.join(", ")
	end

	def fb_topic_info topic
		if topic.has_comments
			post = topic.last_post.to_liquid
			%(#{I18n.t('portal.topic.fb_reply_info',
				:reply_url => topic.last_post_url,
				:user_name => h(post.user.name),
				:created_on => time_ago(post.created_on)
				)}
			)
		else
			%(#{h(topic.user.name)}, <br>#{time_ago topic.created_on}.)
		end
	end

	def last_post_brief topic, link_label = t('portal.topic.last_reply')
		if topic.last_post.present?
			post = topic.last_post.to_liquid
			%(#{I18n.t('portal.topic.last_post_brief',
					:last_post_url => topic.last_post_url,
					:link_label => h(link_label),
					:user_name => h(post.user.name),
					:created_on => time_ago(post.created_on))
				})
		end
	end

	def topic_brief topic
		%(#{I18n.t('portal.topic.topic_brief', :user_name => h(topic.user.name), :created_on => time_ago(topic.created_on))})
	end

	# Options list for forums in new and edit topics page
	def forum_options
		_forum_options = []
		current_portal.forum_categories.each do |c|
			_forums = c.forums.visible(current_user).reject(&:announcement?).map{ |f| [f.name, f.id] }
			_forum_options << [ c.name, _forums ] if _forums.present?
		end
		_forum_options
	end

	def more_topics_list topic
		topic_count = 10
		forum = topic.forum

		return "" unless forum.topics.published_and_unmerged.count > 1
		
		output = []
		output << %(<div class='list-lead'>
									#{t('portal.topic.more_topic')} 
									<span class='folder-name'>#{h(forum.name)}</span>
								</div>
							<ul>)
		parent_topic_id = topic.merged? ? topic.parent.id : 0
		forum.topics.unmerged.take(topic_count).each do |o_topic|
			output << %(<li class="cs-g-3">
										<div class="ellipsis">
											#{link_to_topic(o_topic.to_liquid)}
										</div>
									</li>) if topic.id != o_topic.id && o_topic.id != parent_topic_id
		end
		output << '</ul>'
		output << link_to_see_all_topics(forum.to_liquid) if forum.topics_count > topic_count
		output.join('').html_safe
	end

	def topic_best_answer best_answer
		output = []
		output << '<hr /><div class="best-answer-info"><section class="user-comment'
		output << ' comment-by-agent' if best_answer.user.is_agent
		output << %(" id="post-#{best_answer.id}">
									<div class="best-answer-tick pull-left">
										<i class="icon-best-answer"></i>
									</div>
									<div class="answer-comment">
										<div class='best-badge'>#{t('portal.topic.best_answer')}</div>
										<div class="user-info">
											#{profile_image(best_answer.user,'user-thumb-image','25px','25px')}
											<div class="user-details">
												<strong>#{h(best_answer.user.name)}</strong>
												#{t('portal.said')} #{time_ago(best_answer.created_on)}
											</div>
										</div>
										<div class="answer-desc" id="post-#{best_answer.id}-description">
											<div class="p-desc">#{best_answer.source.body_html}</div>
											#{post_attachments(best_answer.to_liquid)}
										</div>
									<div>
								</section></div>)
		output.join('').html_safe
	end

	protected

		def link_to_topic topic
			link_to topic['title'], topic.topic_url
		end

end