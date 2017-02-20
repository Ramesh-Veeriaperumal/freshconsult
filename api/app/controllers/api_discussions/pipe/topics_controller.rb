module ApiDiscussions::Pipe
  class TopicsController < ApiDiscussions::TopicsController

    def create
      user_id = params[cname][:user_id]
      @item.user_id = user_id
      post = @item.posts.build(params[cname].select { |x| DiscussionConstants::TOPIC_COMMENT_CREATE_FIELDS.flat_map(&:last).include?(x) })
      post.user_id = user_id
      post.created_at = params[cname][:created_at]
      post.updated_at = params[cname][:updated_at]
      assign_parent post, :topic, @item

      assign_protected
      if @item.save
        render_201_with_location
      else
        render_custom_errors
      end
    end

    private

      def validate_params
        return false if create? && !load_forum
        params[cname].permit(*(get_fields("DiscussionConstants::PIPE_CREATE_TOPIC_FIELDS")))
        @topic_validation = ApiDiscussions::Pipe::TopicValidation.new(params[cname], @item)
        valid = @topic_validation.valid?
        render_errors @topic_validation.errors, @topic_validation.error_options unless valid
      end
  end
end
