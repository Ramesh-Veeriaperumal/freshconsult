module Helpdesk::ReorderUtility
  
  def reorder
    new_pos = ActiveSupport::JSON.decode params[:reorderlist]

    reorder_scoper.each do |reorder_item|
      new_p = new_pos[reorder_item.id.to_s]
      if reorder_item.position != new_p
        reorder_item.update_column(:position, new_p)# TODO-RAILS3 check callback
      end
    end
    respond_to do |format|
      format.html { redirect_to reorder_redirect_url }
      format.js { head 200}
    end
  end
  
end
