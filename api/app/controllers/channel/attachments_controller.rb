module Channel
  class AttachmentsController < ::Ember::AttachmentsController
    include ChannelAuthentication

    skip_before_filter :check_privilege, :check_item_permission
    before_filter :channel_client_authentication


    def create
      super
    end

    def show
      options = { expires: 1.days, secure: true, response_content_type: @item.content_content_type, response_content_disposition: 'attachment'}
      attachment_content = @item.content
      redir_url = AwsWrapper::S3Object.url_for(attachment_content.path("original".to_sym), attachment_content.bucket_name, options)
      respond_to do |format|
      	format.all do
        	redirect_to redir_url
     	end
      end
    end
  end
end
