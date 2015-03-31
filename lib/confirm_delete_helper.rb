module ConfirmDeleteHelper

	SUPPORTED_DIALOGS = [
		"Solution::Category", "Solution::Folder", "Solution::Article", 
		"Forum", "ForumCategory", "Topic"
	]

	def confirm_delete(item, url, options = {})
		return "" unless SUPPORTED_DIALOGS.include? item.class.name
		link_to t('delete').html_safe, url, confirm_delete_defaults(item, url).merge(options)
	end

	def confirm_delete_defaults(item, url)
		{
			:class => 'btn confirm-delete',
			:rel => 'confirmdelete',
			
			"data-warning-message" => "<b>#{t('delete_confirm.hard_delete')}</b>".html_safe,
			
			"data-details-message" => deletion_message(item).html_safe,
			"data-destroy-url" => url,
			"data-item-title" => item_title(item),
			"data-dialog-id" => "deletion_#{dom_id(item)}",

			"data-delete-msg" => deletion_hint(item),
			"data-delete-title-msg" => deletion_title(item),

			"data-title" => t('delete_confirm.confirm'),
			"data-width" => '500px',
			"data-close-label" => t('cancel'),
			"data-submit-label" => t('delete_permanently'),

			"data-confirmation" => true
		}
	end

	def deletion_message(item)
		respond_to?("#{item.class.name.parameterize.underscore}_delete_message") ?
			send("#{item.class.name.parameterize.underscore}_delete_message", item) : default_deletion_message
	end

	def item_title(item)
		item[:name] || item[:title] || ""
	end

	def deletion_hint(item)
		t('delete_confirm.confirm_msg', :item_type => t("deletion_titles.#{item.class.name.parameterize.underscore}"))
	end

	def deletion_title(item)
		t('delete_confirm.confirm_title', :item_type => t("deletion_titles.#{item.class.name.parameterize.underscore}"))
	end

	def solution_article_delete_message(article)
		t('solution.info8')
	end

	def solution_folder_delete_message(folder)
		t('folder.delete_confirm', :count => folder.articles.size)
	end

	def solution_category_delete_message(category)
		return t('solution_category.info1') if (category.folders.size == 0) && (category.articles.size == 0)
		t('solution_category.delete_confirm', :folders => category.folders.size, :articles => category.articles.size)
	end

	def topic_delete_message(topic)
		t('topics.delete_confirm', :count => ([0, topic.posts_count - 1].max))
	end

	def forum_delete_message(forum)
		t('forum.delete_confirm', :count => forum.topics_count)
	end

	def forumcategory_delete_message(forum_category)
		return t('forum_confirm_msg1').html_safe if (forum_category.forums.size == 0) && (forum_category.topics.size == 0)
		t('forum_category.delete_confirm', :forums => forum_category.forums.size, :topics => forum_category.topics.size)
	end

end