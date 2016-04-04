class PopulateScoreboardLevelsData < ActiveRecord::Migration
  def self.up
    
    execute <<-SQL
      DELETE FROM scoreboard_levels;
    SQL

  	execute <<-SQL
      INSERT INTO scoreboard_levels 
        (account_id, name, points, created_at, updated_at) 
        SELECT id, 'Beginner', 100, created_at, created_at FROM accounts;
    SQL
    execute <<-SQL
      INSERT INTO scoreboard_levels 
        (account_id, name, points, created_at, updated_at) 
        SELECT id, 'Intermediate', 2500, created_at, created_at FROM accounts;
    SQL
    execute <<-SQL
      INSERT INTO scoreboard_levels 
        (account_id, name, points, created_at, updated_at) 
        SELECT id, 'Professional', 10000, created_at, created_at FROM accounts;
    SQL
    execute <<-SQL
      INSERT INTO scoreboard_levels 
        (account_id, name, points, created_at, updated_at) 
        SELECT id, 'Expert', 25000, created_at, created_at FROM accounts;
    SQL
    execute <<-SQL
      INSERT INTO scoreboard_levels 
        (account_id, name, points, created_at, updated_at) 
        SELECT id, 'Master', 50000, created_at, created_at FROM accounts;
  	SQL
  	execute <<-SQL
  	  INSERT INTO scoreboard_levels 
        (account_id, name, points, created_at, updated_at) 
        SELECT id, 'Guru', 100000, created_at, created_at FROM accounts;
    SQL
  end

  def self.down
  	execute <<-SQL
		  DELETE FROM scoreboard_levels;
	  SQL
  end
end
