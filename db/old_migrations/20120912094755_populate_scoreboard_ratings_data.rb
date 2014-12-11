class PopulateScoreboardRatingsData < ActiveRecord::Migration
  def self.up
  	
  	execute <<-SQL
		DELETE FROM scoreboard_ratings;
	SQL

  	execute <<-SQL
      INSERT INTO scoreboard_ratings 
        (account_id, resolution_speed, score, created_at, updated_at) 
        SELECT id, 1, 10, created_at, created_at FROM accounts;
    SQL
    execute <<-SQL
      INSERT INTO scoreboard_ratings 
        (account_id, resolution_speed, score, created_at, updated_at) 
        SELECT id, 2, 5, created_at, created_at FROM accounts;
    SQL
    execute <<-SQL
      INSERT INTO scoreboard_ratings 
        (account_id, resolution_speed, score, created_at, updated_at) 
        SELECT id, 3, -5, created_at, created_at FROM accounts;
    SQL
    execute <<-SQL
      INSERT INTO scoreboard_ratings 
        (account_id, resolution_speed, score, created_at, updated_at) 
        SELECT id, 101, 5, created_at, created_at FROM accounts;
    SQL
    execute <<-SQL
      INSERT INTO scoreboard_ratings 
        (account_id, resolution_speed, score, created_at, updated_at) 
        SELECT id, 102, 10, created_at, created_at FROM accounts;
  	SQL
  	execute <<-SQL
  	  INSERT INTO scoreboard_ratings 
        (account_id, resolution_speed, score, created_at, updated_at) 
        SELECT id, 103, -10, created_at, created_at FROM accounts;
    SQL
  end

  def self.down
  	execute <<-SQL
		DELETE FROM scoreboard_ratings;
	SQL
  end
end
