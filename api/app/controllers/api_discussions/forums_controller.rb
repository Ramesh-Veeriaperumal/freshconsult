module ApiDiscussions
  class ForumsController < ApiApplicationController
    include ApiDiscussions::DiscussionsForum
          
    before_filter { |c| c.requires_feature :forums }        
    skip_before_filter :check_privilege, :verify_authenticity_token, :only => [:show, :index]
    before_filter :portal_check, :only => [:show, :index]

    protected

    private

    def portal_check
      access_denied if current_user.nil? || current_user.customer? || !privilege?(:view_forums)
    end
    
  end
end