module Helpdesk::DashboardHelper

  def eval_activity_data(data)
    unless data['eval_args'].nil?
      data['eval_args'].each_pair do |k, v|
        data[k] = send(v[0].to_sym, v[1])
      end
    end
    
    data
  end
  
  def responder_path(args_hash)
    link_to(h(args_hash['name']), user_path(args_hash['id']))
  end
  
  def comment_path(args_hash, link_display = 'comment')
    link_to(link_display, "#{helpdesk_ticket_path args_hash['ticket_id']}##{args_hash['comment_id']}")
  end
  
  def email_response_path(args_hash)
    comment_path(args_hash, 'email response')
  end

end
