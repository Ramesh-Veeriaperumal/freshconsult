Todo:
------
1. The mount point config for [app dir mount](https://docs.docker.com/docker-for-mac/osxfs-caching/#performance-implications-of-host-container-file-system-consistency)

Mac Setup:
----------
5. Build helpkit App
    ```
    $ docker-compose -f docker/helpkit.yml build
    ```

6. Create a local volume for rubyGems for reusability
    ```
    $ docker volume create --name rubyGems
    ```

7. Restore Gems
    Use the rubygems backup instead of installing all of them from scratch
        - Download [gems tar](https://drive.google.com/a/freshdesk.com/file/d/0B_WU6NuDIojBLTFDODlmWkxiRWc/view?usp=sharing)
    ```    
    $ cd <folder where the dowloaded tar is present>
    $ docker run --rm -v rubyGems:/gems -v $(pwd):/backup ruby:2.2 bash -c "cd /gems/ && tar xvJf /backup/helpkit_2_2_rubygems_full_05_07_17.tar.gz --strip 1"
    ```    


Helpkit One Time Setup:
----------------------
1. Setup DB
    ``` 
    $ cd <directory containing helpkit code>
    $ docker-compose -f docker/helpkit.yml run helpkit bash -c "mysql -u root -h mysql56  -e 'CREATE DATABASE IF NOT EXISTS helpkit1' && bundle exec rake db:bootstrap"
    ```    

    Note: 
        - The setup slows down when we partitions are being added to the tables. You can run

        $ ....
        $ Adding auto increment to id columns
            partition of tables.
        
        $ tail -f log/development.log #to see the progress when the process looks stuck to you 


Running the App:
----------------
1. Run the App:
    ```
    $ docker-compose -f docker/helpkit.yml up helpkit   #will run the web server
    ```    

    Note : If you havent done step (6) from 'Mac Setup' or if the tar file is outdated then the above command will install the missing the gems

2. How to run common commands -
    ```
    $ docker-compose -f docker/helpkit.yml up helpkit  #starts the web server
    $ docker-compose -f docker/helpkit.yml run helpkit bundle exec rails c
    $ docker-compose -f docker/helpkit.yml run helpkit bash 
    $ docker-compose -f docker/helpkit.yml run helpkit <any command you want to run>
    ```    

3. Debugging the app using pry
    - https://stackoverflow.com/questions/35211638/how-to-debug-a-rails-app-in-docker-with-pry
    - https://stackoverflow.com/questions/31669226/rails-byebug-did-not-stop-application/32690885#32690885