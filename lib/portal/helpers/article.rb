module Portal::Helpers::Article

	def article_attachments article
		output = []

		if(article.attachments.size > 0 or article.cloud_files.size > 0)
			output << %(<div class="cs-g-c attachments" id="article-#{ article.id }-attachments">)

			article.attachments.each do |a|
				output << attachment_item(a.to_liquid)
			end
			(article.cloud_files || []).each do |c|
				output << cloud_file_item(c.to_liquid)
			end

			output << %(</div>)
		end

		output.join('').html_safe
	end

	def article_list folder, limit = 5, reject_article = nil
		if(folder.present? && folder['articles_count'] > 0)
			articles = folder['articles']
			articles.reject!{|a| a['id'] == reject_article['id']} if(reject_article != nil)
				output = []
			output << %(<ul>#{ articles.take(limit).map { |a| article_list_item a.to_liquid } }</ul>)
			if articles.size > limit
				output << %(<a href="#{folder['url']}" class="see-more">)
				output << %(#{ I18n.t('portal.article.see_all_articles', :count => folder['articles_count']) })
				output << %(</a>)
			end
			output.join("")
		end
	end

	def link_to_see_all_articles folder
		label = I18n.t('portal.article.see_all_articles', :count => folder['articles_count'])
		link_to label, folder['url'], :title => label, :class => "see-more"
	end

	def related_articles_list article, limit = 5
		output = []
		output << %(<ul>#{ article.related_articles.take(limit).map { |a| article_list_item(a.to_liquid) } }</ul>)
		output.join("")
	end

	def related_articles article, limit=10, container='related_articles'
		return "" unless Account.current.active?
		output = []
		output << %(<div id="#{container}">)
		output << %(<div class="cs-g-c">)
		output << %(<section class="article-list">)
		output << %(<h3 class="list-lead">#{I18n.t('portal.article.related_articles')}</h3>)
		url = "/support/search/articles/#{article.id}/related_articles?container=#{container}&limit=#{limit}"
		url.prepend("/#{Language.current.code}") if Account.current.multilingual?
		output << %(<ul rel="remote" 
			data-remote-url="#{url}" 
			id="related-article-list"></ul>)
		output << %(</section></div></div>)
		output.join("")	
	end

	def more_articles_in_folder folder
		%( <h3 class="list-lead">
			#{I18n.t('portal.article.more_articles', :article_name => folder['name'])}
		</h3>)
	end

	def article_list_item article
		output = <<HTML
			<li>
				<div class="ellipsis">
					<a href="#{article['url']}">#{h(article['title'])}</a>
				</div>
			</li>
HTML
		output.html_safe
	end

	def article_voting article
		output = []
		unless article.voted_by_user?
			if article.personalized_articles?
				output << %(<div id="article-author">#{profile_image(article.user)})
				output << %(<span class="muted">#{article.user.first_name} #{t('feedback.solution_article_author')}</span>)
				output << %(</div>)
			end
			output << %(<p class="article-vote" id="voting-container" 
											data-user-id="#{User.current.id if User.current}" 
											data-article-id="#{article.id}"
											data-language="#{Language.current.code}">
										#{t('feedback.title')})
			output << article_voting_up(article)
			output << %(<span class="vote-down-container">)
			output << article_voting_down(article)
			output << %(</span>)
			output << %(</p>)
			output << article_feedback_link
			output << article_feedback(article)
		end

		output.join('').html_safe
	end

	def article_voting_up(article)
		output = []
		output << %(<span data-href="#{article.thumbs_up_url}" class="vote-up a-link" id="article_thumbs_up" 
									data-remote="true" data-method="put" data-update="#voting-container" 
									data-user-id="#{User.current.id if User.current}"
									data-article-id="#{article.id}"
									data-language="#{Language.current.code}"
									data-update-with-message="#{t('feedback.up_vote_thank_you_message')}">
								#{t('feedback.upvote')})				
		output << %(</span>)
		output.join('').html_safe
	end

	def article_voting_down(article)
		output = []
		output << %(<span data-href="#{article.thumbs_down_url}" class="vote-down a-link" id="article_thumbs_down" 
									data-remote="true" data-method="put" data-update="#vote-feedback-form" 
									data-user-id="#{User.current.id if User.current}"
									data-article-id="#{article.id}"
									data-language="#{Language.current.code}"
									data-hide-dom="#voting-container" data-show-dom="#vote-feedback-container">
								#{t('feedback.downvote')})
		output << %(</span>)
		output.join('').html_safe
	end

	def article_feedback_link
		output = []
		output << %(<a class="hide a-link" id="vote-feedback-form-link" data-hide-dom="#vote-feedback-form-link" data-show-dom="#vote-feedback-container">#{t('feedback.link')})
		output << %(</a>)
		output.join('').html_safe
	end

	def article_feedback(article)
		output = []
		output << %(<div id="vote-feedback-container")
		if article.personalized_articles?
			output << %(class="hide vote-feedback">)
		else
			output << %(class="hide">)
		end				
		output << %(	<div class="lead">#{t('feedback.downvote_feedback_messasge')}</div>)
		output << %(	<div id="vote-feedback-form">)
		output << %(		<div class="sloading loading-small loading-block"></div>)
		output << %(	</div>)
		output << %(</div>)
		output.join('').html_safe
	end

  def common_properties(meta)
    properties = {
      title: meta['title'],
      url: meta['canonical']
    }
    properties['description'] = meta['short_description'] if meta['short_description'] && !meta['short_description'].empty?
    properties['image'] = meta['image_url'] if meta['image_url']
    properties
  end

  def og_properties(meta)
    og_properties = common_properties(meta)
    portal = Portal.current || Account.current.main_portal
    og_properties[:site_name] = trim_string(portal.name) || trim_string(portal.product.name) || Account.current.name
    og_properties[:type] = 'article'
    og_properties
  end

  def trim_string(str)
    if str.nil?
      return nil
    elsif !str.strip.empty?
      return str.strip
    end
    nil
  end

  def twitter_properties(meta)
    twitter_properties = common_properties(meta)
    twitter_properties[:card] = 'summary'
    twitter_properties
  end

  def og_article_properties(meta)
    article_properties = {}
    article_properties[:author] = meta['author'] if meta['author']
    article_properties
  end

  def og_meta_tags(meta)
    meta_tags = []
    og_properties(meta).each do |key, value|
      meta_tags << %( <meta property="og:#{key}" content="#{value}" /> )
    end
    og_article_properties(meta).each do |key, value|
      meta_tags << %( <meta property="article:#{key}" content="#{value}" /> )
    end
    twitter_properties(meta).each do |key, value|
      meta_tags << %( <meta name="twitter:#{key}" content="#{value}" /> )
    end
    meta_tags.join('').html_safe
  end
end
