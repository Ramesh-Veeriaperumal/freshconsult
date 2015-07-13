class Discussions::TopicsController < ApplicationController

	include CloudFilesHelper
	helper DiscussionsHelper

	rescue_from ActiveRecord::RecordNotFound, :with => :RecordNotFoundHandler

	skip_before_filter :check_privilege, :verify_authenticity_token, :only => [ :show, :reply ]
	before_filter :require_user, :only => :reply
	before_filter :find_topic, :except => [:index, :create, :new, :destroy_multiple]
	before_filter :portal_check, :only => :show
	before_filter :fetch_monitorship, :only => :show
	before_filter :set_page, :only => :show
	before_filter :after_destroy_path, :only => :destroy

	before_filter { |c| c.requires_feature :forums }
	before_filter { |c| c.check_portal_scope :open_forums }

	before_filter :set_selected_tab

	COMPONENTS = [:voted_users, :participating_users, :following_users]
	POSTS_PER_PAGE = 10

	def new
		@topic = current_account.topics.new
	end

	def create
		# this is icky - move the topic/first post workings into the topic model?
		forum = current_account.forums.find(params[:topic][:forum_id])
		@topic  = forum.topics.build(topic_param)
		assign_protected
		@post       = @topic.posts.build(post_param)
		@post.topic = @topic
		if privilege?(:view_admin)
			@post.user = (topic_param[:import_id].blank? || params[:email].blank?) ? current_user : current_account.all_users.find_by_email(params[:email])
		end
		@post.user  ||= current_user
		@post.account_id = current_account.id
		@post.portal = current_portal.id
		# only save topic if post is valid so in the view topic will be a new record if there was an error
		@topic.body_html = @post.body_html # incase save fails and we go back to the form
		build_attachments

		if @topic.save
			respond_to do |format|
				format.html { redirect_to discussions_topic_path(@topic) }
				format.xml  { render  :xml => @topic }
				format.json  { render  :json => @topic }
			end
		else
			respond_to do |format|
				format.html { render :action => "new" }
				format.xml  { render  :xml => @topic.errors }
				format.json  { render  :json => @topic.errors.fd_json }
			end
		end
	end

	def edit
		if @topic.merged_topic_id?
			flash[:notice] = I18n.t('discussions.topic_merge.merge_error_for_locked', 
												:title => h(@topic.merged_into.title), 
												:topic_link => discussions_topic_path(@topic.merged_topic_id)).html_safe 
			redirect_to discussions_topic_path(@topic)
		end
	end

	def update
		@topic.attributes = topic_param
		assign_protected
		@post = @topic.first_post
		@post.attributes = post_param
		@topic.body_html = @post.body_html
		build_attachments
		
		if @topic.save
			respond_to do |format|
				format.html { redirect_to discussions_topic_path(@topic) }
				format.xml  {head :ok}
				format.json  {head :ok}
			end
		else
			respond_to do |format|
				format.html { render :action => "edit" }
			end
		end
	end

	def destroy
		@first_post = @topic.posts.first
		@topic.destroy
		respond_to do |format|
			format.html do
				flash[:notice] = I18n.t('flash.topic.deleted', :title => h(@topic.title)).html_safe
				redirect_to  @after_destroy_path 
			end
			format.js
		    format.xml  {head :ok}
			format.json  {head :ok}
		end
	end

	def show
		respond_to do |format|
			format.html do

				if @topic.published?
					load_posts
					@post  = Post.new
				end

				@first_post = @topic.posts.first

				@page_title = @topic.title
			end
			format.xml do
				render :xml => @topic.to_xml(:include => :posts)
			end
			format.json do
				render :json => @topic.to_json(:include => :posts)
			end
			format.rss do
				@posts = @topic.posts.published.find(:all, :order => 'created_at desc', :limit => 25)
				render :action => 'show', :layout => false
			end
		end
	end

	def destroy_multiple
		if params[:ids].present?
			current_account.topics.find(params[:ids]).each do |item|
				item.destroy
			end

			flash[:notice] = I18n.t('topic.bulk_delete')
		end
		redirect_to :back
	end

	def component
		if COMPONENTS.include? (params[:name] || "").to_sym
			render :partial => "discussions/topics/components/#{params[:name]}"
		else
			render_404
		end
	end

	def toggle_lock
		@topic.locked = !@topic.locked
		@topic.save!
		respond_to do |format|
			format.html { redirect_to discussions_topic_path(@topic) }
			format.xml  { head 200 }
			format.json  { head 200 }
		end
	end


	def update_stamp
		if  @topic.update_attributes(:stamp_type => params[:stamp_type])
			respond_to do |format|
				format.js
				format.html { redirect_to discussions_topic_path(@topic) }
				format.xml  { head 200 }
				format.json { head 200 }
			end
    else
			result = @topic.errors
			respond_to do |format|
				format.js
				format.html { redirect_to discussions_topic_path(@topic) }
				format.xml  { render :xml => result.to_xml, :status => :bad_request }
				format.json  { render :json => result.fd_json, :status => :bad_request }
			end
		end
	end

	def latest_reply
		render :layout => false
	end

	def users_voted
		@object = @topic
		render :partial => 'discussions/shared/users_voted'
	end
	
	def reply
		if current_user.agent?
			path = discussions_topic_path(params[:id])
		else
			path = support_discussions_topic_path(params[:id])
		end
		path << "/page/last#reply-to-post"
		redirect_to path
	end

	private

		def load_posts
			@posts = @topic.posts.published.find(:all, :include => [:attachments, :user]).paginate :page => params[:page], :per_page => POSTS_PER_PAGE
		end

		def assign_protected
			if @topic.new_record?
				if privilege?(:view_admin)
					@topic.user = (topic_param[:import_id].blank? || params[:email].blank?) ? current_user : current_account.all_users.find_by_email(params[:email])
				end
				@topic.user ||= current_user
			end
			@topic.account_id = current_account.id
			# admins and moderators can sticky and lock topics
			return unless privilege?(:edit_topic, @topic)
			@topic.sticky, @topic.locked = params[:topic][:sticky], params[:topic][:locked]
			# only admins can move
			return unless privilege?(:manage_forums)
			@topic.forum_id = params[:topic][:forum_id] if params[:topic][:forum_id]
		end

		def build_attachments
			post_attachments = params[:post].nil? ? [] : params[:post][:attachments]
			attachment_builder(@post, post_attachments, params[:cloud_file_attachments])
		end

		def after_destroy_path
			first_post = @topic.posts.first
			if first_post.spam?
				@after_destroy_path = discussions_moderation_filter_path(:filter => :spam)
			elsif !first_post.published?
				@after_destroy_path = discussions_moderation_filter_path(:filter => :waiting)
			else
				@after_destroy_path = discussions_forum_path(@forum)
			end
		end

		def find_topic
			# To remove unused eager loading in API request. Temp HACK
			@topic = [:json, :xml].include?(request.format.to_sym) ? current_account.topics.find(params[:id]) 
								: current_account.topics.find(params[:id], :include => [:user, :forum])
			@forum = @topic.forum
			@category = @forum.forum_category
		end

		def portal_check
			if current_user.nil? || current_user.customer?
				return redirect_to topic_portal_path
			elsif !privilege?(:view_forums)
				access_denied
			end
		end

		def topic_portal_path
			path = support_discussions_topic_path(@topic)
			path << "/page/#{params[:page]}" if params[:page].present?
			path
		end

		def set_page
			params[:page] = ([(@topic.posts.count.to_f / POSTS_PER_PAGE).ceil, 1].max) if params[:page] == 'last'
		end


		def fetch_monitorship
			@monitorship = @topic.monitorships.count(:conditions => ["user_id = ? and active = ?", current_user.id, true])
		end


		def RecordNotFoundHandler
			flash[:notice] = I18n.t(:'flash.topic.page_not_found')
			redirect_to discussions_path
		end

		def set_selected_tab
			@selected_tab = :forums
		end

		def topic_param
			@topic_params ||= params[:topic].symbolize_keys.delete_if{|k, v| [:body_html,:forum_id].include? k }
		end

		def post_param
			@post_params ||= params[:topic].symbolize_keys.delete_if{|k, v| [:title,:sticky,:locked].include? k }
		end
end
