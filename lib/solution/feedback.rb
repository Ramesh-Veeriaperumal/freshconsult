module Solution::Feedback

	private

		ALLOWED_MESSAGES = 1..4
		def generate_ticket_params
			params[:helpdesk_ticket] ||= {}
			params[:helpdesk_ticket][:subject] = "Article Feedback - #{@article.title}"
			params[:helpdesk_ticket][:ticket_body_attributes] = { :description_html => feedback_ticket_body }
		end

		def feedback_ticket_body
			feedback = ""
			feedback << %(<strong>Feedback for: #{link_to_article}</strong>)
			feedback << chosen_feedback if params[:message] && params[:message].size
			feedback << formatted_content if params[:helpdesk_ticket_description].present?
			feedback.html_safe
		end

	  def chosen_feedback
			choices_text = "<ul>"
			params[:message].each do |m|
				next unless ALLOWED_MESSAGES.include?(m.to_i)
				choices_text << %(<li>#{I18n.t("solution.feedback_message_#{m}")}</li>)
			end
			choices_text << "</ul>"
			choices_text
	  end

		def formatted_content
			"<br>" + h(params[:helpdesk_ticket_description]).gsub("\n", "<br />\n")
		end

		def link_to_article
      (Portal.current || Account.current).multilingual? ?
			   "<a href='#{solution_article_version_url(@article.parent_id, "#{Language.current.code}")}'> #{h(@article.title)}</a>" :
         "<a href='#{solution_article_url(@article.parent_id)}'> #{h(@article.title)}</a>" 
		end

		def add_watcher
			return unless current_account.add_watcher_enabled?
			return unless @article.user.agent? and @article.user.active?
			return if @ticket.subscriptions.exists?(user_id: @article.user.id)

			subscription = @ticket.subscriptions.create( {:user_id => @article.user.id} )
			Helpdesk::WatcherNotifier.send_later(:deliver_notify_new_watcher,
																						@ticket,
																						subscription,
                                            Va::Constants::AUTOMATIONS_MAIL_NAME, locale_object: subscription.user)
		end

		def add_to_article_ticket
			article_ticket = @ticket.build_article_ticket(:article_id => @article.current_article.id)
			article_ticket.save
		end
end
