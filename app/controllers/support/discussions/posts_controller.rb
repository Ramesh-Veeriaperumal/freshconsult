class Support::Discussions::PostsController < SupportController
	before_filter { |c| c.requires_feature :forums }
 	before_filter { |c| c.check_portal_scope :open_forums }
  before_filter :require_user
 	before_filter :load_topic
 	before_filter :find_post, :except => :create

	def create
		@post = @topic.posts.new(params[:post])
		if @topic.locked?
			respond_to do |format|
				format.html do
					flash[:notice] = 'This topic is locked.'[:locked_topic]
					redirect_to support_discussions_topic_path(:id => params[:topic_id], :page => params[:page] || '1')
				end
				format.xml do
					return render :text => 'This topic is locked.'[:locked_topic], :status => 400
				end
			end
			return
		end

		@forum = @topic.forum
		@post  = @topic.posts.build(params[:post])
		@post.user = current_user
		@post.account_id = current_account.id
		@post.save!
		create_attachments
		respond_to do |format|
		  format.html do
		    redirect_to "#{support_discussions_topic_path(:id => params[:topic_id])}/page/last#post-#{@post.id}"
		  end
		  format.xml { 
		  	return render :xml => @post 
		  }
		end
		rescue ActiveRecord::RecordInvalid
		flash[:bad_reply] = 'Please post a valid message...'[:post_something_message]
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
	   	return unless @post.respond_to?(:attachments)
	    (params[:post][:attachments] || []).each do |a|
	      	@post.attachments.create(:content => a[:resource], :description => a[:description], :account_id => @post.account_id)
	    end
	end

	def edit
		render :partial => "/support/discussions/topics/edit_post"
	end

	def update
	    @post.attributes = params[:post]
	    @post.save!
		rescue ActiveRecord::RecordInvalid
			flash[:error] = 'An error occurred'[:error_occured_message]
		ensure
		respond_to do |format|
		  format.html do
		    redirect_to support_discussions_topic_path(:id => params[:topic_id], :anchor => @post.dom_id, :page => params[:page] || '1')
		  end
		end
	end

	def destroy
	    @post.destroy
	    flash[:notice] = I18n.t('flash.post.deleted')[:post_deleted_message, h(@post.topic.title)]
	    respond_to do |format|
	      format.html do
	        redirect_to support_discussions_topic_path(:id => params[:topic_id], :page => params[:page] || '1')
	      end
	    end
	end

private
	def load_topic
		@topic = scoper.find_by_id(params[:topic_id])
		@forum = @topic.forum
		@forum_category = @forum.forum_category

		wrong_portal unless(main_portal? || (@forum_category.id.to_i == current_portal.forum_category_id)) #Duplicate
		raise(ActiveRecord::RecordNotFound) unless (@forum.account_id == current_account.id)
		redirect_to send(Helpdesk::ACCESS_DENIED_ROUTE) unless @forum.visible?(current_user)		
	end

	def find_post     
		@post = Post.find_by_id_and_topic_id(params[:id], params[:topic_id]) || raise(ActiveRecord::RecordNotFound)
		(raise(ActiveRecord::RecordNotFound) unless (@post.account_id == current_account.id)) || @post
		redirect_to send(Helpdesk::ACCESS_DENIED_ROUTE) unless @post.topic.forum.visible?(current_user)
    end

	def scoper
	    current_account.portal_topics
	end
end