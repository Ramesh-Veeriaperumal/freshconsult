class Discussions::ModerationController < ApplicationController


	before_filter :set_selected_tab
	before_filter :load_post, :only => [:approve, :mark_as_spam]
	before_filter { |c| c.requires_feature :forums }

	REPORT = { :ham => true, :spam => false }

	def index
		@posts = current_account.posts.unpublished_spam.paginate(:page => (params[:page] || 1))
	end

	def approve
		@post.published = true
		@post.save

		report_post(REPORT[:ham])
	end

	def empty_folder

		current_account.posts.unpublished_spam.update_all({ :trash => true })

		Resque.enqueue(Workers::Community::EmptyModerationTrash, {:account_id => current_account.id, :user_id => current_user.id })

		flash[:notice] = t('discussions.moderation.flash.empty_folder')
		redirect_to categories_path
	end

	def mark_as_spam
		@post.published = false, 
		@post.spam = true
		@post.save
		@post.topic.update_attributes(:published => false) if @post.original_post?

		report_post(REPORT[:spam])
		redirect_to :back
	end

	private

		def set_selected_tab
			@selected_tab = :forums
			@page_title = t('discussions.moderation.spam_folder')
		end

		def load_post
			@post = current_account.posts.find(params[:id])
		end

		def report_post(type)
			Resque.enqueue(Workers::Community::ReportPost, {
					:id => @post.id,
					:account_id => @post.account_id,
					:report_type => type
			})
		end

end
