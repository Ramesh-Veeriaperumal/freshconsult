# frozen_string_literal: true

class Ember::Freshcaller::Calls::TicketsController < Ember::TicketsController
  include TicketConcern

  def show
    render 'ember/tickets/show'
  end

  private

    def scoper
      current_account.freshcaller_calls
    end

    def load_object
      @fc_call = scoper.find_by_fc_call_id(params[:id])
      return log_and_render_404 unless @fc_call

      @item = @fc_call.ticket || @fc_call.note.try(:notable)
      log_and_render_404 unless @item
    end

    def validate_url_params
      params.permit(*ApiConstants::DEFAULT_PARAMS)
    end

    def self.decorator_name
      ::TicketDecorator
    end
end
