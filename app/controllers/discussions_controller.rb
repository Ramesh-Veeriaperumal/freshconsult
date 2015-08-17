class DiscussionsController < ApplicationController

	include ModelControllerMethods
	include Helpdesk::ReorderUtility
	include Community::ModerationCount

	skip_before_filter :check_privilege, :verify_authenticity_token, :only => [:index, :show]
	before_filter :portal_check, :only => [:index, :show]
	before_filter :check_no_topics, :only => [:index]

	rescue_from ActiveRecord::RecordNotFound, :with => :RecordNotFoundHandler

	before_filter { |c| c.requires_feature :forums }
	before_filter { |c| c.check_portal_scope :open_forums }
	before_filter :set_selected_tab
	before_filter :content_scope

	before_filter :fetch_spam_counts, :only => [:index, :your_topics, :sidebar]

	def index
		@topics = current_account.topics.as_activities.paginate(:page => params[:page])
		respond_back
	end

	def your_topics
		@topics, ids = [], {:topic => [], :forum => []}
		
		current_user.monitorships.active_monitors.each do |m|
			ids[m.monitorable_type.underscore.to_sym] << m.monitorable_id
		end
		unless ids[:topic].blank? and ids[:forum].blank?
			@topics = current_account.topics.as_activities.following(ids).paginate(:page => params[:page])
		end
		respond_back
	end

	def new
	end

	def show

		@forums = @forum_category.forums.all(:order => 'position')
		@page_title = @forum_category.name

		respond_to do |format|
			format.html
			format.xml  { render :xml => @forum_category.to_xml(:include => fetch_forum_scope) }
			format.json  { render :json => @forum_category.to_json(
			          :except => [:account_id,:import_id],
			          :include => fetch_forum_scope) }
			format.atom
	    end
	end

	def create
		if @obj.save
			flash[:notice] = create_flash
			respond_to do |format|
				format.html { redirect_to discussion_path(@obj) }
				format.xml { render :xml => @obj, :status => :created, :location => discussion_path(@obj) }
				format.json { render :json => @obj, :status => :created, :location => discussion_path(@obj) }
			end
		else
			create_error
			respond_to do |format|
				format.html  { render :action => 'new' }
				format.xml { render :xml => @obj.errors, :status => :unprocessable_entity }
			end
		end
	end

	def edit
	end

	def categories
		@topics_count = current_account.topics.count
    respond_to do |format|
      format.html {
      	@forum_categories = portal_scoper.all(:include => :portals)
      }
      format.any(:json, :xml)  { 
      	# To remove unused eager loading in API request. Temp HACK
      	@forum_categories = portal_scoper.all
      	render request.format.to_sym => @forum_categories 
      }
      
    end
	end

	def sidebar
		respond_to do |format|
			format.js { render :partial => '/discussions/shared/sidebar_categories' }
		end
	end

	protected

		def cname
			@cname ||= "forum_category"
		end

		def content_scope
			@content_scope = ''
		end

		def portal_scoper
			current_account.forum_categories
		end

		def scoper
			current_account.forum_categories
		end

		def reorder_scoper
			current_portal.portal_forum_categories
		end

		def reorder_redirect_url
			discussions_path
		end

		def redirect_url
			@obj.destroyed? ? categories_discussions_path : discussion_path(@obj)
		end

		def portal_category?
			wrong_portal unless(main_portal? ||
				(params[:id] && params[:id].to_i == current_portal.forum_category_id))
		end

		def set_selected_tab
			@selected_tab = :forums
		end

		def fetch_forum_scope
			:forums
		end

		def RecordNotFoundHandler
			flash[:notice] = I18n.t(:'flash.forum_category.page_not_found')
			redirect_to discussions_path
		end

		private

		def check_no_topics
			unless current_account.topics.count > 0
				redirect_to categories_discussions_path
			end
		end

		def portal_check
			if current_user.nil? || current_user.customer?
				return redirect_to support_discussions_path
			elsif !privilege?(:view_forums)
				access_denied
			end
		end

		def respond_back
			if request.xhr? and !request.headers['X-PJAX']
				render :partial => 'discussions/shared/topic', :collection => @topics
			else
				render :action => :index
			end
		end

end
