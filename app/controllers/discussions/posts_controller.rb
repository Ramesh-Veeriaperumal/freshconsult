class Discussions::PostsController < ApplicationController

	helper DiscussionsHelper
	include CloudFilesHelper
	before_filter :find_post, :except =>  [:monitored, :create]

	before_filter :find_topic, :check_lock, :only => :create

	before_filter { |c| c.requires_feature :forums }
	before_filter { |c| c.check_portal_scope :open_forums }

	def edit
		render :layout => false
	end

	def update
		@post.attributes = params[:post]
		@post.save!
		rescue ActiveRecord::RecordInvalid
			flash[:error] = 'An error occurred'
		ensure
			respond_to do |format|
				format.html { redirect_to :back }
				format.js
				format.xml  {head :ok}
				format.json  {head :ok}
			end
	end

	def create
		build_post

		respond_to do |format|
			format.html do
				redirect_to "/discussions/topics/#{@topic.id}/page/last##{dom_id(@post)}"
			end
			format.xml { render :xml => @post }
			format.json { render :json => @post, :status=>:created}
		end

	rescue ActiveRecord::RecordInvalid
		invalid_message
	end

	def destroy
		@post.destroy
		respond_to do |format|
			format.js
			format.xml  {head :ok}
			format.json  {head :ok}
		end
	end

	def toggle_answer
		@post.toggle_answer
		respond_to do |format|
			format.html { redirect_to :back }
			format.xml  { head :created, :location => topic_url(:forum_id => @forum, :id => @topic, :format => :xml) }
		end
	end

	def best_answer
		@answer = @topic.answer
		render :layout => false
	end

	def users_voted
		@object = @post
		render :partial => "discussions/shared/users_voted"
	end

	private

	def find_post
		@post = Post.find_by_id_and_topic_id(params[:id], params[:topic_id]) || raise(ActiveRecord::RecordNotFound)
		(raise(ActiveRecord::RecordNotFound) unless (@post.account_id == current_account.id)) || @post
		@topic = @post.topic
	end

	def find_topic
		@topic = current_account.topics.find(params[:topic_id])
	end

	def check_lock
		# Agents can still reply even if locked.
		# This check is only for API

		unless (params[:post][:import_id].blank? || params[:email].blank?)
			if @topic.locked?
				render :text => 'This topic is locked.', :status => 400
				return false
			end
		end

	end

	def build_post

		@post  = @topic.posts.build(params[:post])
		if privilege?(:view_admin)
			@post.user = (params[:post][:import_id].blank? || params[:email].blank?) ? current_user : current_account.all_users.find_by_email(params[:email])
		end

		@post.user ||= current_user
		@post.account_id = current_account.id
		@post.portal = current_portal.id
		build_attachments
		@post.save!
	end

	def build_attachments
		attachment_builder(@post, params[:post][:attachments], params[:cloud_file_attachments] )
	end

	def invalid_message
		respond_to do |format|
			format.html do
				flash[:error] = 'Please post a valid message...'
				redirect_to :back
			end
			format.xml { render :xml => @post.errors.to_xml, :status => 400 }
		end
	end

end
