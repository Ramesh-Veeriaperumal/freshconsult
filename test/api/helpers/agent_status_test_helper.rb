module AgentStatusTestHelper
  def sample_index
  [
      "default": false,
      "id": 1,
      "name": "test",
      "state": "inactive",
      "icon": 1234,
      "type": "unproductive"
  ]
  end

  def sample_show
    {
      "default": false,
      "id": 1,
      "name": "test",
      "state": "active",
      "icon": "U+1F605",
      "type": "productive"
    }
  end
end
