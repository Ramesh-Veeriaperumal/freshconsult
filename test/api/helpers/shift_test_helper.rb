module ShiftTestHelper
  VALID_SHIFTS = [
      { name: Faker::Lorem.characters(10), time_zone: 'IST',
        work_days: [{ day: 'monday', start_time: '10:00', end_time: '12:00' }], agents: [{ id: 1 }] },
      { name: Faker::Lorem.characters(10), time_zone: 'IST',
        work_days: [{ day: 'tuesday', start_time: '10:00', end_time: '12:00' }], agents: [{ id: 1 }] },
      { name: Faker::Lorem.characters(10), time_zone: 'IST',
        work_days: [{ day: 'wednesday', start_time: '10:00', end_time: '12:00' }], agents: [{ id: 1 }] },
      { name: Faker::Lorem.characters(10), time_zone: 'IST',
        work_days: [{ day: 'thursday', start_time: '10:00', end_time: '12:00' }], agents: [{ id: 1 }] },
      { name: Faker::Lorem.characters(10), time_zone: 'IST',
        work_days: [{ day: 'friday', start_time: '10:00', end_time: '12:00' }], agents: [{ id: 1 }] }].freeze

  INVALID_SHIFTS = [
      { name: Faker::Lorem.characters(10), time_zone: 'IST',
        work_days: [{ day: 'mondays', start_time: '10:00', end_times: '12:00' }], agents: [{ id: 1 }] },
      { name: Faker::Lorem.characters(10), time_zonez: 'IST',
        work_days: [{ days: 'tuesday', start_timez: '10:00', end_time: '12:00' }], agents: [{ id: 1 }] },
      { name: Faker::Lorem.characters(10), time_zone: 'IST',
        work_days: [{ day: 'wednesday', start_times: '10:00', end_time: '12:00' }], agents: [{ id: 1 }] },
      { name: Faker::Lorem.characters(10), time_zonez: 'IST',
        work_days: [{ day: 'thursday', start_times: '10:00', end_time: '12:00' }], agents: [{ id: 1 }] },
      { name: Faker::Lorem.characters(10), time_zonez: 'IST',
        work_days: [{ day: 'thursday', start_times: '10:00', end_time: '12:00' }], agent_ids: [{ id: 1 }] }].freeze

  def sample_index
    {"data":[{"id":1,"name":"IND shift","time_zone":"IST","work_days":[{"day":"monday","start_time":"10:00","end_time":"12:00"}],
        "agents":[{"id":1}]},{"id":2,"name":"US shift","time_zone":"IST",
                              "work_days":[{"day":"monday","start_time":"10:00","end_time":"12:00"}],
        "agents":[{"id":1},{"id":44},{"id":45}]},{"id":3,"name":"Can shift","time_zone":"IST",
                                                  "work_days":[{"day":"monday","start_time":"10:00","end_time":"12:00"}],
        "agents":[{"id":1},{"id":44}]},{"id":4,"name":"Africa shift","time_zone":"IST",
                                        "work_days":[{"day":"monday","start_time":"10:00","end_time":"12:00"}],
        "agents":[{"id":1}]},{"id":5,"name":"Aus shift","time_zone":"IST",
                              "work_days":[{"day":"monday","start_time":"10:00","end_time":"12:00"}],
        "agents":[{"id":1}]},{"id":6,"name":"UAE shift","time_zone":"IST",
                              "work_days":[{"day":"monday","start_time":"10:00","end_time":"12:00"}],
        "agents":[{"id":1}]}],"meta":{"total_items":6,"total_pages":1,"current_page":1}}
  end

  def sample_show
    {"id":1,"name":"IND shift","time_zone":"IST","work_days":[{"day":"monday","start_time":"10:00","end_time":"12:00"}],"agents":[{"id":1}]}
  end
end
