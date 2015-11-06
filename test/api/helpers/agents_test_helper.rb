module Helpers::AgentsTestHelper
  def agent_pattern(expected_output = {}, agent)
    user = {
      active: agent.user.active,
      created_at: agent.user.created_at,
      email: agent.user.email,
      job_title: expected_output['job_title'] || agent.user.job_title,
      language: expected_output['language'] || agent.user.language,
      last_login_at: agent.user.last_login_at,
      mobile: expected_output['mobile'] || agent.user.mobile,
      name: agent.user.name,
      phone: agent.user.phone,
      time_zone: agent.user.time_zone,
      updated_at: agent.user.updated_at
    }

    {
      available_since: expected_output[:available_since] || agent.active_since,
      available: expected_output[:available] || agent.available,
      created_at: agent.created_at,
      id: Fixnum,
      occasional: expected_output[:occasional] || agent.occasional,
      signature_html: expected_output[:signature_html] || agent.signature_html,
      ticket_scope: expected_output[:ticket_scope] || agent.ticket_permission,
      updated_at: agent.updated_at,
      user: expected_output[:user] || user
    }
  end
end
