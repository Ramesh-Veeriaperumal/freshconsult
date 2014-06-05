module DiscussionsHelper
	include Helpdesk::TicketsHelperMethods

	def discussions_breadcrumb(page = :home)
		_output = []
		_output << pjax_link_to(t('discussions.all_categories'), categories_discussions_path)
		case page
			when :category
				_output << @forum_category.name
			when :forum
				_output << category_link(@forum, page)
				_output << truncate(@forum.name, :length => 40)
			when :topic
				_output << category_link(@forum, page)
				_output << forum_link(@forum)
			else
		end
		"<div class='breadcrumb'>#{_output.map{ |bc| "<li>#{bc}</li>" }.join("")}</div>".html_safe
	end

	def forum_link forum
		options = { :title => forum.name } if forum.name.length > 40
		pjax_link_to(truncate(forum.name, :length => 40), discussions_forum_path(forum.id), (options || {}))
	end

	def category_link(forum, page)
		truncate_length = ( (page == :forum) ? 75 : 40 )
		forum_category_name = forum.forum_category.name 
		options = { :title => forum_category_name } if forum_category_name.length > truncate_length
		pjax_link_to(truncate(forum.forum_category.name, :length => truncate_length), 
			 			"/discussions/#{forum.forum_category_id}", (options || {}))
	end

	def more_user_avatar(count, href, options={})
		return "" if count <=0
		options[:class] = "#{options[:class]} more-users-link"
		link_to "...", href, options
	end

	def forum_category_list
		op = []
		current_account.forum_categories_from_cache.each do |category|
			forums = category.forums
			op << %(<li class="cm-sb-cat-item">)
			op << %(<i class="forum_expand"></i>) unless forums.blank?
			op << pjax_link_to(category.name, discussion_path(category), {
									:"data-category-id" => category.id,
									:id => "sb-discussions-category-#{category.id}"
								})
			op << forum_list(forums, category.id)
			op << %(</li>)
		end
		op.join('').html_safe
	end

	def forum_list forums, category_id
		op = []
		op << %( <ul class="forum_list" id="#{category_id}_forums"> )
		forums.each do |forum|
			op << %( <li class="forum_list_item" id="#{forum.id}_forum"> )
			op << pjax_link_to( "#{forum.name} (#{forum.topics_count})",
													discussions_forum_path(forum), {
														:"data-forum-id" => forum.id,
														:"data-category-id" => category_id,
														:id => "sb-discussions-forum-#{forum.id}"
												})
			op << %( </li> )
		end
		op << %( </ul> )
		op.join('').html_safe
	end

	def sidebar_toggle(extra_classes="")
		font_icon("sidebar-list",
								:size => 21,
								:class => "cm-sb-toggle #{extra_classes}",
								:id => "cm-sb-toggle").html_safe
	end

	def moderation_count(counts)
		if counts[:waiting] > 0
			return pjax_link_to t('discussions.moderation.index.waiting') + " (#{counts[:waiting]}) ", discussions_moderation_filter_path(:waiting), :class => 'mini-link mr20'
		elsif counts[:spam] > 0
			return pjax_link_to t('discussions.moderation.index.title') + " (#{@counts[:spam]}) ", discussions_moderation_filter_path(:spam), :class => 'mini-link mr20'
		end
	end

	def moderation_enabled?
		current_account.features?(:moderate_all_posts) || current_account.features?(:moderate_posts_with_links)
	end

  def list_discussions_panel(default_btn = :topic)
    _op = ""
    _op << %(<ul class="list-actions-right">
  	           <li class="list-default-btns">)

  	_op << %(<a href="#" class="btn" id="categories_reorder_btn">
               #{font_icon "reorder", :size => 13}
               #{t('topic.reorder')}
  				   </a>) if privilege?(:manage_forums)

  	_op << new_discussions_button(default_btn)
    _op << %(</li>
             <li class="list-reorder-btns">
               <a href="#" class="btn btn-primary" id="categories_submit_btn">Done</a>
               <a href="#" class="btn btn-link" id="categories_cancel_btn">cancel</a>
             </li>
            </ul>)
    _op.html_safe
  end

  def new_discussions_button(default_btn = :topic)
    category = [t('topic.add_category'), new_discussion_path]
    forum    = [t('topic.add_forum'),    new_discussions_forum_path(btn_default_params(:forum))]
    topic    = [t("topic.add_topic"),    new_discussions_topic_path(btn_default_params(:topic))]
    opts     = {:"data-pjax" => "#body-container"}

    if privilege?(:manage_forums)
      topic = nil unless privilege?(:create_topic)
      case default_btn
        when :category
          btn_dropdown_menu(category, [forum, topic], opts)
        when :forum
          btn_dropdown_menu(forum, [category, topic], opts)
        else
          if privilege?(:create_topic)
          	btn_dropdown_menu(topic, [category, forum], opts)
          else
          	btn_dropdown_menu(forum, [category], opts)
          end
      end
    elsif privilege?(:create_topic)
      pjax_link_to(topic[0], topic[1], :class => 'btn')
  	else
  		""
    end
  end

  def btn_default_params(type)
    case type
      when :forum
        { :forum_category_id => @forum_category.id } if @forum_category.present?
      when :topic
        { :forum_id => @forum.id } if @forum.present?
      else
    end
  end

  # Topic page
  def topic_sort
    %(<div class="dropdown" id="topic-sort-menu">
        <a href="#" class="dropdown-toggle" id="sorted_by" data-toggle="dropdown">
          #{ t('topic.sorted_by') } :
          <strong> #{ t("topic.#{params[:order].to_s}") }</strong>
          <span class="caret"></span>
        </a>
        #{ topic_sort_dropdown }
      </div>).html_safe
  end

  def topic_sort_dropdown
    sort_items = ["recent", "popular"].map {|s|
                    [t("topic.#{s}"), "#", params[:order].eql?(s), { :"data-value" => s, :id => "#{s}-sort", :rel => "topic-sort-item" }] }

    dropdown_menu(sort_items)
  end

end
