class Portal::Tags::Snippet < Liquid::Tag  

  # Snippets will work only if its value is present in the below hash
  RESTRICTED_FILE_HASH = {  
                            :new_ticket_form => "/support/tickets/request_form",
                            :new_topic_form    => "/support/discussions/topics/form", 
                            :signup_form  => "/support/signups/form",
                            :login_form   => "/support/login/form",
                            :forgot_password_form => "/support/login/forgot_password",                             
                            :search_form  => "/support/search",
                            # Partials that work only in topic details page
                            :topic_reply  => "/support/discussions/topics/reply_to_post",
                            :topic_vote   => "/support/discussions/topics/topic_vote",
                            # Partials that work only in ticket details and list page
                            # Should not be exposed in documentation
                            :reset_password_form => "/password_resets/form",
                            :activation_form => "/activations/form",
                            :ticket_add_people => "/support/tickets/add_people",
                            :ticket_reply => "/support/tickets/reply",
                            :ticket_survey => "/support/tickets/ticket_survey",
                            :ticket_details => "/support/tickets/ticket_details",
                            :ticket_edit => "/support/tickets/ticket_edit",
                            :ticket_list => "/support/tickets/ticket_list",
                            :ticket_filters => "/support/tickets/filters"  }

  def initialize(tag_name, markup, tokens)
    super
    @name = markup
    @name.strip!
  end

  def render(context)
    _file_path = file_path @name    
    render_erb(context, _file_path, :registers => context.registers) unless(_file_path.blank?)
  end

  def render_erb(context, file_name, locals = {})
    context.registers[:controller].send(:render_to_string, :partial => file_name, :locals => locals)
  end

  def file_path file_name
    RESTRICTED_FILE_HASH[file_name.to_sym]
  end

end