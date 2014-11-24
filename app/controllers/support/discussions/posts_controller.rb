class Support::Discussions::PostsController < SupportController

	include CloudFilesHelper
	include Community::Moderation
	before_filter { |c| c.requires_feature :forums }
	before_filter :check_forums_state
 	before_filter { |c| c.check_portal_scope :open_forums }
  before_filter :require_user
 	before_filter :load_topic
 	before_filter :find_post, :except => :create
 	before_filter :verify_user, :only => [:update, :edit, :destroy]
 	before_filter :verify_topic_user, :only => [:toggle_answer]

	def create
		params[:post].merge!(post_request_params)

		@post = @topic.posts.new(params[:post])
		if @topic.locked? and !@topic.published?
			respond_to do |format|
				format.html do
					flash[:notice] = 'This topic is locked.'
					redirect_to support_discussions_topic_path(:id => params[:topic_id], :page => params[:page] || '1')
				end
				format.xml do
					return render :text => 'This topic is locked.', :status => 400
				end
			end
			return
		end

		@forum = @topic.forum
		@post  = @topic.posts.build(params[:post])
		@post.user = current_user
		@post.account_id = current_account.id
		@post.portal = current_portal.id
		@post.save!
		create_attachments
		respond_to do |format|
		  format.html do
				flash[:notice] = flash_msg_on_post_create
		    redirect_to "#{support_discussions_topic_path(:id => params[:topic_id])}/page/last#post-#{@post.id}"
		  end
		  format.xml {
		  	return render :xml => @post
		  }
		end
		rescue ActiveRecord::RecordInvalid
		flash[:bad_reply] = 'Please post a valid message...'
		respond_to do |format|
		  format.html do
		  	redirect_to support_discussions_topic_path(:id => params[:topic_id], :page => params[:page] || '1')
		  end
		  format.xml {
		  	return render :xml => @post.errors.to_xml, :status => 400
		  }
		end
	end

  def create_attachments
  	if @post.respond_to?(:cloud_files)
	    (params[:cloud_file_attachments] || []).each do |attachment_json|
	      @post.cloud_files.create(build_cloud_files(attachment_json))
	    end
	  end
   	return unless @post.respond_to?(:attachments)
    (params[:post][:attachments] || []).each do |a|
      	@post.attachments.create(:content => a[:resource], :description => a[:description], :account_id => @post.account_id)
    end
  end

  def show
  end

	def edit
		render :partial => "/support/discussions/topics/edit_post"
	end

	def update
	    @post.attributes = params[:post]
	    @post.save!
		rescue ActiveRecord::RecordInvalid
			flash[:error] = 'An error occurred'
		ensure
		respond_to do |format|
		  format.html do
		    redirect_to support_discussions_topic_path(:id => params[:topic_id], :anchor => @post.dom_id, :page => params[:page] || '1')
		  end
		end
	end

	def destroy
	    @post.destroy
	    flash[:notice] = (I18n.t('flash.topic.deleted', :title => h(@post.topic.title))).html_safe
	    respond_to do |format|
	      format.html do
	        redirect_to support_discussions_topic_path(:id => params[:topic_id], :page => params[:page] || '1')
	      end
	    end
	end

	def toggle_answer
		@post.toggle_answer
		respond_to do |format|
	      format.html do
	        redirect_to support_discussions_topic_path(params[:topic_id])
	      end
	      format.xml { head 200 }
	    end
	end

	def best_answer
		@answer = @topic.answer
		render :layout => false
	end

private
	def load_topic
		@topic = scoper.find_by_id(params[:topic_id])
		if @topic.nil?
			flash[:notice] = I18n.t('portal.topic_deleted')
			redirect_to support_discussions_path
		else
			@forum = @topic.forum
			@forum_category = @forum.forum_category
			wrong_portal unless(main_portal? || (@forum_category.id.to_i == current_portal.forum_category_id)) #Duplicate
			raise(ActiveRecord::RecordNotFound) unless (@forum.account_id == current_account.id)
			redirect_to send(Helpdesk::ACCESS_DENIED_ROUTE) unless @forum.visible?(current_user)
		end
	end

	def find_post
		@post = Post.find_by_id_and_topic_id(params[:id], params[:topic_id]) || raise(ActiveRecord::RecordNotFound)
		(raise(ActiveRecord::RecordNotFound) unless (@post.account_id == current_account.id)) || @post
		redirect_to send(Helpdesk::ACCESS_DENIED_ROUTE) unless @post.topic.forum.visible?(current_user)
    end

	def scoper
	    current_account.portal_topics
	end

	def post_request_params
		{
			:request_params => {
				:user_ip => request.remote_ip,
				:referrer => request.referrer,
				:user_agent => request.env['HTTP_USER_AGENT']
			}
		}
	end

	def verify_user
		redirect_to send(Helpdesk::ACCESS_DENIED_ROUTE) unless @post.user == current_user
	end

	def verify_topic_user
		redirect_to send(Helpdesk::ACCESS_DENIED_ROUTE) unless (current_user.agent? || @topic.user == current_user)
	end
end
