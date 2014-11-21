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
			"<a href='#{solution_category_folder_article_path(@article.folder.category_id, @article.folder_id, @article)}'> #{h(@article.title)}</a>"
		end

		def add_watcher
			return unless @article.user.agent? and @article.user.active?
			Helpdesk::WatcherNotifier.send_later(:deliver_notify_new_watcher,
																						@ticket,
																						@ticket.subscriptions.create( {:user_id => @article.user.id} ),
																						Va::Constants::AUTOMATIONS_MAIL_NAME)
		end

		def add_to_article_ticket
			ArticleTicket.create(:article_id => @article.id, :ticket_id => @ticket.id, :account_id => current_account.id)
		end

end