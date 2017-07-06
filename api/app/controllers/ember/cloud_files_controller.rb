module Ember
  class CloudFilesController < ApiApplicationController
    skip_before_filter :check_privilege, only: [:destroy]
    before_filter :check_destroy_permission, only: [:destroy]

    protected

      def scoper
        current_account.cloud_files
      end
  end
end
