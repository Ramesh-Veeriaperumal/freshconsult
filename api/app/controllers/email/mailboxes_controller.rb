module Email
  class MailboxesController < ApiApplicationController
    def destroy
      if @item.primary_role
        render_errors(error: :cannot_delete_primary_email)
      else
        @item.destroy
        head 204
      end
    end

    private

      def scoper
        current_account.all_email_configs
      end
  end
end
