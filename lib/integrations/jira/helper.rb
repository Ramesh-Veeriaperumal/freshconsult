module Integrations::Jira::Helper
  
  def exclude_attachment?(installed_app)
    installed_app.configs[:inputs]["exclude_attachment_sync"].to_s.to_bool
  end

  def allow_notes?(installed_app)
    installed_app.configs[:inputs]["fd_comment_sync"] != Integrations::Jira::Constant::DO_NOTHING
  end
end