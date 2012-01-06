module Helpdesk::ReorderUtility
  
  def reorder
    new_pos = ActiveSupport::JSON.decode params[:reorderlist]

    reorder_scoper.each do |reorder_item|
      new_p = new_pos[reorder_item.id.to_s]
      if reorder_item.position != new_p
        reorder_item.position = new_p
        reorder_item.save
      end
    end
    redirect_to reorder_redirect_url    
  end
  
end
