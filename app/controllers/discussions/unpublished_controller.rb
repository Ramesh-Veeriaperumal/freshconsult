class Discussions::UnpublishedController < ApplicationController

	helper DiscussionsHelper

	include Community::Moderation::Prefetch
	include Community::Moderation::CleanUp
	include Community::Moderation::MoveToDB
	include Community::Moderation::MoveToDynamo
	include Community::ModerationCount
	include SpamAttachmentMethods
	include SpamPostMethods

	before_filter { |c| c.requires_feature :forums }
	before_filter :set_selected_tab
	before_filter :default_scope, :only => :index
	before_filter :load_posts, :only => :index
	before_filter :fetch_spam_counts, :only => [:index, :moderation_count]
	before_filter :load_spam_post, :only => [:approve, :ban, :restore_contact, :delete_unpublished]
	before_filter :load_post, :only => :mark_as_spam
	before_filter :load_topic_posts, :only => :topic_spam_posts


	def index
		@page_title = t('discussions.moderation.page_title')
	end

	def more
		@spam_posts = filter_scope.next(params[:next])
		fetch_associations

		respond_back
	end

	def topic_spam_posts
		respond_to do |format|
			format.html { render :layout => false }
			format.js
		end
	end

	def moderation_count
		render :layout => false
	end

	private

		def set_selected_tab
			@selected_tab = :forums
			@page_title = t('discussions.moderation.spam_folder')
		end

		def default_scope
			if params[:filter].blank?
				if current_account.features_included?(:moderate_all_posts) || current_account.features_included?(:moderate_posts_with_links)
					params[:filter] = :unpublished
				else
					params[:filter] = :spam
				end
			end
		end

		def load_posts
			@spam_posts = filter_scope.last_month
			fetch_associations
		end

		def filter_scope
			@moderation_scope ||= Post::SPAM_SCOPES_DYNAMO.fetch(params[:filter].to_s.downcase.to_sym, Post::SPAM_SCOPES_DYNAMO[:unpublished])
		end

		def load_spam_post
			@spam_post = spam_scope.find_post(params[:timestamp])
		end

		def spam_scope
			Post::SPAM_SCOPES_DYNAMO.values.include?(params[:scope].constantize) ? 
				params[:scope].constantize : Post::SPAM_SCOPES_DYNAMO.values.first
		end

		def load_post
			@post = current_account.posts.find(params[:id])
		end

		def load_topic_posts
			@spam_posts = filter_scope.topic_spam(params[:id], last)
			fetch_users(collect(:user_id))
		end

		def respond_back(html_redirect = :back)
			fetch_spam_counts

			respond_to do |format|
				format.html { redirect_to html_redirect}
				format.js
			end
		end

		def last
			JSON.parse(params[:last]) if params[:last]
		end
end
