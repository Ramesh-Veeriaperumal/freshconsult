class TopicsController < ApplicationController

	include CloudFilesHelper
	rescue_from ActiveRecord::RecordNotFound, :with => :RecordNotFoundHandler

	skip_before_filter :check_privilege, :verify_authenticity_token, :only => :show
	before_filter :find_forum_and_topic, :except => :index
	before_filter :portal_check, :only => :show
	before_filter :fetch_monitorship, :only => :show

	before_filter { |c| c.requires_feature :forums }
	before_filter { |c| c.check_portal_scope :open_forums }

	before_filter :set_selected_tab


	# @WBH@ TODO: This uses the caches_formatted_page method.  In the main Beast project, this is implemented via a Config/Initializer file.  Not
	# sure what analogous place to put it in this plugin.  It don't work in the init.rb
	#caches_formatted_page :rss, :show
	# cache_sweeper :posts_sweeper, :only => [:create, :update, :destroy]


	def index
		respond_to do |format|
			format.html { redirect_to forum_path(params[:forum_id]) }
			format.xml do
				@topics = Topic.paginate_by_forum_id(params[:forum_id], :order => 'sticky desc, replied_at desc', :page => params[:page])
				render :xml => @topics.to_xml
			end
		end
	end

	def new
		redirect_to new_discussions_topic_path
	end

	def show
		respond_to do |format|
			format.html do
				redirect_to discussions_topic_path(@topic)
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

	def create
		topic_saved, post_saved = false, false
		# this is icky - move the topic/first post workings into the topic model?
		Topic.transaction do
			@topic  = @forum.topics.build(topic_param)
			assign_protected
			@post       = @topic.posts.build(post_param)
			@post.topic = @topic
			if privilege?(:view_admin)
				@post.user = (topic_param[:import_id].blank? || params[:email].blank?) ? current_user : current_account.all_users.find_by_email(params[:email])
			end
			@post.user  ||= current_user
			@post.account_id = current_account.id
			# only save topic if post is valid so in the view topic will be a new record if there was an error
			@topic.body_html = @post.body_html # incase save fails and we go back to the form
			build_attachments
			topic_saved = @topic.save if @post.valid?
			post_saved = @post.save if topic_saved
		end

		if topic_saved && post_saved
			respond_to do |format|
				format.html { redirect_to discussions_topic_path(@topic) }
				format.xml  { render  :xml => @topic }
				format.json  { render  :json => @topic }
			end
	 else
			respond_to do |format|
				format.html { render :action => "new" }
				format.xml  { render  :xml => @topic.errors }
				format.json  { render  :json => @topic.errors }
			end
		end
	end

	def update
		topic_saved, post_saved = false, false
		Topic.transaction do
			@topic.attributes = topic_param
			assign_protected
			@post = @topic.posts.first
			@post.attributes = post_param
			@topic.body_html = @post.body_html
			build_attachments
			topic_saved = @topic.save
			post_saved = @post.save
		end

		if topic_saved && post_saved
			respond_to do |format|
				format.html { redirect_to discussions_topic_path(@topic) }
				format.xml  { head 200 }
				format.json { head 200 }
			end
		else
			respond_to do |format|
			 format.html { render :action => "edit" }
			end
		end
	end

	def destroy
		@topic.destroy
		flash[:notice] = (I18n.t('flash.topic.deleted', :title => h(@topic.title))).html_safe
		respond_to do |format|
			format.html { redirect_to  after_destroy_path }
			format.xml  { head 200 }
			format.json  { head 200 }
		end
	end

	def edit
		redirect_to edit_discussions_topic_path(@topic)
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

	 def update_stamp
		if  @topic.update_attributes(:stamp_type => params[:stamp_type])
			respond_to do |format|
				format.html { redirect_to discussions_topic_path(@topic) }
				format.xml  { head 200 }
			end
		 end
	end

	def remove_stamp
		if @topic.update_attributes(:stamp_type => nil)
		 respond_to do |format|
			format.html { redirect_to discussions_topic_path(@topic) }
			format.xml  { head 200 }
		end
	 end
 end


	def vote
		unless @topic.voted_by_user?(current_user)
			@vote = Vote.new(:vote => params[:vote] == "for")
			@vote.user_id = current_user.id
			@topic.votes << @vote
			@topic.reload
			render :partial => "forum_shared/topic_vote", :object => @topic
		end
	end

	def destroy_vote
		@votes = Vote.find(:all, :conditions => ["user_id = ? and voteable_id = ?", current_user.id, params[:id]] )
		@votes.first.destroy
		@topic.reload
		render :partial => "forum_shared/topic_vote", :object => @topic
	end

	def update_lock
		@topic.locked = !@topic.locked
		@topic.save!
		respond_to do |format|
			format.html { redirect_to discussions_topic_path(@topic) }
			format.xml  { head 200 }
		end
	end

	def users_voted
		render :partial => "forum_shared/topic_voted_users", :object => @topic
	end


	def build_attachments
		post_attachments = params[:post].nil? ? [] : params[:post][:attachments]
		attachment_builder(@post, post_attachments, params[:cloud_file_attachments] )
	end

	protected

		def assign_protected
			if @topic.new_record?
				if privilege?(:view_admin)
					@topic.user = (topic_param[:import_id].blank? || params[:email].blank?) ? current_user : current_account.all_users.find_by_email(params[:email])
				end
				@topic.user ||= current_user
			end
			@topic.account_id = current_account.id
			# admins and moderators can sticky and lock topics
			return unless privilege?(:view_admin) or current_user.moderator_of?(@topic.forum)
			@topic.sticky, @topic.locked = params[:topic][:sticky], params[:topic][:locked]
			# only admins can move
			return unless privilege?(:view_admin)
			@topic.forum_id = params[:topic][:forum_id] if params[:topic][:forum_id]
		end

		def find_forum_and_topic
			(wrong_portal and return) unless(main_portal? ||
						(params[:category_id].to_i == current_portal.forum_category_id)) #Duplicate

			@forum_category = scoper.find(params[:category_id])
			@forum = @forum_category.forums.find(params[:forum_id])
			raise(ActiveRecord::RecordNotFound) unless (@forum.account_id == current_account.id)
			@topic = @forum.topics.find(params[:id]) if params[:id]
		end

		def scoper
			current_account.forum_categories
		end

		def fetch_monitorship
			@monitorship = @topic.monitorships.count(:conditions => ["user_id = ? and active = ?", current_user.id, true])
		end

		def set_selected_tab
			@selected_tab = :forums
		end

		def topic_param
			param = params[:topic].symbolize_keys
			param.delete_if{|k, v| [:body_html].include? k }
			return param
		end

		def post_param
			param = params[:topic].symbolize_keys
			param.delete_if{|k, v| [:title,:sticky,:locked].include? k }
			return param
		end

		def RecordNotFoundHandler
			flash[:notice] = I18n.t(:'flash.topic.page_not_found')
			redirect_to discussions_path
		end

		private

		def portal_check
			if current_user.nil? || current_user.customer?
				@topic = params[:id] ? current_account.portal_topics.find(params[:id]) : nil
				return redirect_to support_discussions_topic_path(@topic)
			elsif !privilege?(:view_forums)
				access_denied
			end
		end
#    def authorized?
#      %w(new create).include?(action_name) || @topic.editable_by?(current_user)
#    end
end
