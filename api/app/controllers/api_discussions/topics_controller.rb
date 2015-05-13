module ApiDiscussions
  class TopicsController < ApiApplicationController

    before_filter { |c| c.requires_feature :forums }        
    skip_before_filter :check_privilege, :verify_authenticity_token, :only => [:show]
    before_filter :portal_check, :only => [:show]
    before_filter :set_forum_id, :only => [:create, :update]
    
    def create
      post  = @topic.posts.build(params[cname].symbolize_keys.delete_if{|x| !(ApiConstants::CREATE_POST_FIELDS.values.flatten.include?(x))})
      # why? we can set only body_html, created_at, updated_at here. so, is processing the keys necessary?
      assign_user_and_parent post, :topic, @topic
      super
    end

    def update
      post = @topic.first_post
      post.attributes = @topic.attributes.extract!(:created_at, :updated_at)
      post.body_html = params[cname][:body_html] if params[cname].has_key?(:body_html)
      super
    end

    protected

    def load_association
      @posts = @topic.posts
    end

    def set_custom_errors
      @error_options = {:remove => :posts}
    end

    def manipulate_params
      params[cname][:body_html] = params[cname].delete(:message_html) if params[cname].has_key?(:message_html)
      @email = params[cname].delete(:email) if params[cname].has_key?(:email)
    end

    def assign_user_and_parent item, parent, value
      if @email.present?
        item.user = current_account.all_users.find_by_email(@email)
      else
        item.user_id ||= (params[cname][:user_id] || current_user.id)
      end
      if item.has_attribute?(parent.to_sym)
        item.send(:write_attribute, parent, value[parent]) if value.has_key?(parent)
      else
        item.association(parent.to_sym).writer(value)
      end
    end


		private

		def portal_check
			access_denied if current_user.nil? || current_user.customer? || !privilege?(:view_forums)
		end

		def set_forum_id 
      assign_user_and_parent @topic, :forum_id, params[cname]
		end

		def validate_params
      fields = get_fields("ApiConstants::#{action_name.upcase}_TOPIC_FIELDS")
			params[cname].permit(*(fields.map(&:to_s)))
			topic = ApiDiscussions::TopicValidation.new(params[cname], @item)
			unless topic.valid?
				@errors = format_error(topic.errors)
				render :template => '/bad_request_error', :status => 400
			end
		end

    def scoper
      current_account.topics
    end
  end
end