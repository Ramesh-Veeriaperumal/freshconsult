module Chat::Constants

  AGENT_SCOPE = [
    [ 'global', 1 ], 
    [ 'group',  2 ], 
    [ 'agent', 3 ]
  ]
 
  SCOPE_TOKENS_BY_KEY = Hash[*AGENT_SCOPE.map { |i| [i[1], i[0]] }.flatten]

  CHAT_PRIVILEGES = [:livechat_admin_tasks,:livechat_manage_visitor,:livechat_view_transcripts,
                     :livechat_edit_transcripts,:livechat_delete_transcripts,:livechat_accept_chat,
                     :livechat_initiat_agent_chat,:livechat_view_visitors,:livechat_intiate_visitor_chat,
                     :livechat_shadow_chat,:livechat_export_transcripts,:livechat_manage_shortcodes,:livechat_view_reports]


end
