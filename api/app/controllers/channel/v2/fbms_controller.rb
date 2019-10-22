# Temporary controller needs to be removed once the facebook poller moved to fbms
module Channel::V2
  class FbmsController < ApiApplicationController
    include ChannelAuthentication

    skip_before_filter :check_privilege, :load_object, :after_load_object
    before_filter :channel_client_authentication
    before_filter :validate_parameters

    def update_post_id
      @fb_post.post_id = cname_params[:post_id]
      @fb_post.save!
      head 200
    rescue StandardError => e
      Rails.logger.error("Error inside #{self.class.name} - #{action_name} - #{e.message}")
      head 500
    end

    def validate_parameters
      raise "Required params are not present" if cname_params.blank? || cname_params[:note_id].blank? || cname_params[:post_id].blank?
      @fb_post = current_account.facebook_posts.fetch_postable(cname_params[:note_id]).first
      raise "FB post entry is not found for the note id #{cname_params[:note_id]}" if @fb_post.blank?
      true
    rescue StandardError => e
      Rails.logger.error("Error inside #{self.class.name} - validating params - #{e.message}")
      render_request_error :validation_failure, 403
    end

  end
end