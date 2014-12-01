class Discussions::ForumsController < ApplicationController

	helper DiscussionsHelper
	helper AutocompleteHelper

	skip_before_filter :check_privilege, :verify_authenticity_token, :only => [:index, :show]
	before_filter :portal_check, :only => [:index, :show]

	include Helpdesk::ReorderUtility

	rescue_from ActiveRecord::RecordNotFound, :with => :RecordNotFoundHandler

	before_filter { |c| c.requires_feature :forums }
	before_filter { |c| c.check_portal_scope :open_forums }

	before_filter :set_selected_tab
	before_filter :find_or_initialize_forum, :except => [:index, :new, :create, :reorder]
	before_filter :fetch_monitorship, :load_topics, :only => :show
	before_filter :set_customer_forum_params, :only => [:create, :update]
	before_filter :fetch_selected_customers, :only => :edit


	def new
		@forum = scoper.new
		respond_to do |format|
			format.html
			format.xml  { render :xml => @forum }
		end
	end

	def create
		@forum_category = current_account.forum_categories.find(params[:forum][:forum_category_id])
		@forum = @forum_category.forums.build(params[:forum])
		@forum.account_id ||= current_account.id
		if @forum.save
			respond_to do |format|
				format.html { redirect_to(discussions_forum_path(@forum), :notice => I18n.t('forum.forum_created')) }
				format.xml  { render :xml => @forum,:status => 200 }
				format.json  { render :json => @forum,:status => :created }
			end
		else
			respond_to do |format|
				format.html {  render :action => 'new' }
				format.xml  {  render :xml => @forum.errors ,:status => 500}
			end
		end
	end


	def update
		@forum.forum_category_id = params[:forum][:forum_category_id] if new_forum_category?
		if @forum.update_attributes(params[:forum])
			respond_to do |format|
				format.html { redirect_to discussions_forum_path(@forum) }
				format.xml  { head 200 }
				format.json { head 200 }
			end
		else
			respond_to do |format|
				format.html {render :action => 'edit'}
				format.xml  {render :xml => @forum.errors }
			end
		end
	end


	def show

		@page_title = @forum.name

		@topics = @topics.paginate(
							          :page => params[:page],
							          :per_page => 10
						          )

		respond_to do |format|
			format.html
			format.xml  { render :xml => @forum.to_xml(:include => :topics) }
			format.json  { render :json => @forum.to_json(:include => :topics) }
			format.atom
		end
	end

	def destroy
		@forum.backup_forum_topic_ids
		@forum.destroy
		respond_to do |format|
			format.html { redirect_to(discussions_path, :notice => I18n.t('forum.forum_deleted')) }
			format.xml  {head :ok}
			format.json  {head :ok}
		end
	end


	protected

		def scoper
			current_account.forums
		end

		def set_selected_tab
			@selected_tab = :forums
		end

		def find_or_initialize_forum
		  @forum = params[:id] ? scoper.find(params[:id]) : nil
		end

		def RecordNotFoundHandler
			flash[:notice] = I18n.t(:'flash.forum.page_not_found')
			redirect_to discussions_path
		end

		def reorder_scoper
			current_account.forum_categories.find(params[:category_id]).forums
		end

		def fetch_monitorship
			@monitorship = @forum.monitorships.count(:conditions => ["user_id = ? and active = ?", current_user.id, true])
		end

		def reorder_redirect_url
			discussions_path
		end

		def load_topics

			@topics = params[:order].eql?('popular') ? @forum.topics.as_list_view.sort_by_popular : @forum.topics.as_list_view.newest

			unless params[:filter].blank?
				stamps = params[:filter].delete('-').split(',')
				@topics = @topics.find(:all,:conditions => [filter_conditions, stamps])
			end
		end

		def new_forum_category?
			params[:forum][:forum_category_id] && current_account.forum_categories.find_by_id(params[:forum][:forum_category_id]).present?
		end

		def filter_conditions
			conditions = "stamp_type IN (?)"
			conditions << "OR stamp_type IS NULL" if params[:filter].include?('-')
			conditions
		end

	private

		def portal_check
			if current_user.nil? || current_user.customer?
				@forum = params[:id] ? current_account.portal_forums.find(params[:id]) : nil
				return redirect_to support_discussions_forum_path(@forum)
			elsif !privilege?(:view_forums)
				access_denied
			end
		end

		def set_customer_forum_params
			params[:forum][:customer_forums_attributes] = {}
			params[:forum][:customer_forums_attributes][:customer_id] = (params[:customers] ? params[:customers].split(',') : [])
		end

		def fetch_selected_customers
			@customer_id = @forum.customer_forums.collect { |cf| cf.customer_id.to_s }
		end

end
