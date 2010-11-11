class Support::GuidesController < ApplicationController
  layout 'support/default'

  before_filter { |c| c.requires_permission :portal_knowledgebase }

  def index
    @guides = Helpdesk::Guide.visible.display_order.all(:conditions => { :account_id => current_account.id })
  end

  def show
    @guide = Helpdesk::Guide.find(params[:id])
    raise ActiveRecord::RecordNotFound unless @guide && (@guide.account_id == current_account.id)
  end
end
