class ApiTicketFieldsController < ApiApplicationController
  def index
    @account = current_account
    super
  end

  private

    def scoper
      current_account.ticket_fields.includes(:nested_ticket_fields)
    end
end
