class Support::Discussions::PostsController < SupportController

	include SpamAttachmentMethods
	include CloudFilesHelper
	include Community::Moderation

	before_filter { |c| c.requires_feature :forums }
	before_filter :check_forums_state
 	before_filter { |c| c.check_portal_scope :open_forums }
  before_filter :require_user
 	before_filter :load_topic
 	before_filter :find_post, :except => :create
 	before_filter :verify_user, :only => :destroy
 	before_filter :verify_topic_user, :only => [:toggle_answer]

	def create
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

		params[:post].merge!(post_request_params)

		if current_user.customer? and current_account.features_included?(:spam_dynamo)
			sqs_create
		else
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
		end
		rescue ActiveRecord::RecordInvalid
		respond_to do |format|
			format.html do
				flash[:bad_reply] = 'Please post a valid message...'
				redirect_to support_discussions_topic_path(:id => params[:topic_id], :page => params[:page] || '1')
			end
			format.xml {
				return render :xml => @post.errors.to_xml, :status => 400
			}
		end
	end

	def sqs_create
		post_params = params[:post].clone.delete_if {|k,v| k == "attachments"}
		post_params[:topic] = { :id => @topic.id }

		sqs_post = SQSPost.new(post_params)
		sqs_post[:attachments] = processed_attachments
		sqs_post[:cloud_file_attachments] = params["cloud_file_attachments"] || []
		sqs_post[:portal] = current_portal.id
		sqs_post_saved = sqs_post.save

		if sqs_post_saved
			respond_to do |format|
				format.html {
					flash[:notice] = t('.flash.portal.discussions.posts.spam_check')
					redirect_to support_discussions_topic_path(:id => params[:topic_id], :page => params[:page] || '1')
				}
				format.json {
					return render :json => sqs_post
				}
			end
		else
			respond_to do |format|
				format.html do
					flash[:bad_reply] = 'Please post a valid message...'
					redirect_to support_discussions_topic_path(:id => params[:topic_id], :page => params[:page] || '1')
				end
				format.xml {
					return render :xml => sqs_post.errors.to_xml, :status => 400
				}
			end
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

	def edit
		head 200
	end

	def update
		redirect_to support_discussions_topic_path(:id => params[:topic_id], :anchor => @post.dom_id, :page => params[:page] || '1')
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
			wrong_portal and return unless current_portal.has_forum_category?(@forum_category)
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
