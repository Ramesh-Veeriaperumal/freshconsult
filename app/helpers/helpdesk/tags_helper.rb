module Helpdesk::TagsHelper

  def sort_menu
    %(
      <div class="fd-menu" id="SortMenu" style="display:none; margin-left:-5px; margin-top:18px;">
        <ul>
          <li>
            <a class="wf_order tag_sort" href="#" data-wf-order="activity" >
              #{t('.usage')}
            </a>
          </li>
          <li>
            <a class="wf_order tag_sort" href="#" data-wf-order="name" >
              #{t('.name')}
            </a>
          </li>

        </ul>
        <span class="seperator"></span>
        <ul>
          <li>
            <a class="wf_order_type tag_sort_type" href="#" data-wf-order-type="asc" >
               #{t('.asc')}
            </a>
          </li>
          <li>
            <a class="wf_order_type tag_sort_type" href="#" data-wf-order-type="desc" >
               #{t('.desc')}
            </a>
          </li>
        </ul>
      </div>
      <a class="drop-right nav-trigger" href="#" menuid="#SortMenu">
        #{t('ticket.sort_by')} <b class="current_sort">  #{t('.usage')} </b>
      </a>
    ).html_safe
  end

  def tag_search_text
    return @tags.first.name if params[:tag_id].present? and @tags.present?
    params[:name] || ""
  end


end
