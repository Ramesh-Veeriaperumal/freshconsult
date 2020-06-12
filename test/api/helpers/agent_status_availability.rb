module AgentStatusAvailabilityTestHelper
  def sample_show
    {
      'data': {
        'agent_ref': 'https://ocrbranch2.freshpo.com/api/v2/agents/13796',
        'status': {
          'id': 1441
        },
        'channel_availability': [
          {
            'channel': 'freshdesk',
            'available': false,
            'logged_in': true,
            'round_robin_enabled': false
          },
          {
            'channel': 'freshchat',
            'available': false,
            'logged_in': false,
            'round_robin_enabled': false
          },
          {
            'channel': 'freshcaller',
            'available': false,
            'logged_in': false,
            'round_robin_enabled': false
          }
        ]
      }
    }
  end
end
