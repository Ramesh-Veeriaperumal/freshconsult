class Discussions::ModerationController < ApplicationController

	helper DiscussionsHelper

	include Community::ModerationCount

	before_filter :set_selected_tab

	before_filter :dynamo_feature_check, :only => :index

	before_filter :fetch_counts_mysql, :only => :index
	before_filter :default_scope, :only => :index
	before_filter :load_posts, :only => :index
	before_filter :load_post, :only => [:approve, :mark_as_spam, :ban, :restore_contact]
	before_filter { |c| c.requires_feature :forums }

	REPORT = { :ham => true, :spam => false }

	def index
		@page_title = t('discussions.moderation.page_title')
	end

	def approve
		redirect_filter = @post.spam? ? :spam : :waiting
		report_post(@post, REPORT[:ham]) if @post.spam?
		@post.approve!

		respond_back(discussions_moderation_filter_path(:filter => redirect_filter))
	end

	def ban
		# Remove Contact
		@post.user.update_attribute(:deleted, true)

		# Mark other posts by the same user as spam
		@post.user.posts.each do |p|
			unless p.spam?
				p.mark_as_spam!
				report_post(p, REPORT[:spam])
			end
		end

		respond_back
	end

	def empty_folder

		current_account.posts.unpublished_spam.update_all({ :trash => true })

		Resque.enqueue(Workers::Community::EmptyModerationTrash, {:account_id => current_account.id, :user_id => current_user.id })

		flash[:notice] = t('discussions.moderation.flash.empty_folder')
		redirect_to discussions_path
	end

	def mark_as_spam
		@post.mark_as_spam!
		report_post(@post, REPORT[:spam])

		respond_back

	end

	def spam_multiple
		if params[:ids].present?
			current_account.topics.find(params[:ids]).each do |item|
				item.posts.first.mark_as_spam!
				report_post(item.posts.first, REPORT[:spam])
			end
	  	flash[:notice] = I18n.t('topic.bulk_spam')
    end
		redirect_to :back
	end

	private

		def default_scope
			if params[:filter].blank?
				if current_account.features?(:moderate_all_posts) || current_account.features?(:moderate_posts_with_links)
					params[:filter] = :waiting
				else
					params[:filter] = :spam
				end
			end
		end

		def respond_back(html_redirect = :back)
			fetch_counts_mysql

			respond_to do |format|
				format.html { redirect_to html_redirect}
				format.js
			end
		end

		def set_selected_tab
			@selected_tab = :forums
			@page_title = t('discussions.moderation.spam_folder')
		end

		def load_posts
			@posts = current_account.posts.send(filter_scope).include_topics_and_forums.paginate(:page => [params[:page].to_i, 1].max )
		end

		def filter_scope
			@moderation_scope ||= Post::SPAM_SCOPES.fetch(params[:filter].to_s.downcase.to_sym, Post::SPAM_SCOPES[:waiting])
		end


		def load_post
			@post = current_account.posts.find(params[:id])
		end

		def report_post(post, type)
			Resque.enqueue(Workers::Community::ReportPost, {
					:id => post.id,
					:account_id => post.account_id,
					:report_type => type
			})
		end

		def dynamo_feature_check
			return unless current_account.features_included?(:spam_dynamo)
			redirect_to request.path.gsub('/discussions/moderation', '/discussions/unpublished')
		end
end