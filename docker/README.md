Mac Setup:
----------
1. Docker
    - Install [docker](https://docs.docker.com/engine/installation/)
    - Change the proxy settings. [Open Issue](https://github.com/docker/for-mac/issues/1809)
        - Docker --> Preferences -> Proxies --> No Proxy 
    - Change CPU/Memory settings 
        - Docker --> Preferences -> Advanced
            - Change as you see fit.

2. Download Repo    
    - [Create new ssh keys](https://help.github.com/articles/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent/#generating-a-new-ssh-key)
    - Add the private key to ssh config. Edit ~/.ssh/config and add the following line
    	```
        IdentityFile ~/.ssh/<gitHubKeyName>  
        ```        
    - [Upload](https://help.github.com/articles/adding-a-new-ssh-key-to-your-github-account/) them to github.com and [Test](https://help.github.com/articles/testing-your-ssh-connection/) the connection
    - Download the helpkit code 
    	```
        $ git clone -b falcon-master --single-branch git@github.com:freshdesk/helpkit.git
        ```

3. Services needed to run helpkit
    - Mysql 5.6 
    - Redis 3.2
    - Memcache(Optional)
    - [Local AWS](https://github.com/localstack/localstack)(Optional)
        - S3
        - SQS 
        - DynamoDB

4. Pull and build docker images for all the services: 
    ```
    $ cd <directory containing helpkit code>/helpkit
    $ docker/bin/setup
    ```

Start Services:
--------------

    $ cd <directory containing helpkit code>/helpkit
    $ docker/bin/start


Helpkit One Time Setup:
----------------------

1. Mac Setup
    - edit /etc/hosts on your Mac to include "localhost.freshdesk-dev.com" to point to localhost


2. AWS Local Setup - Needs to run everytime we restart the container ( no need to run if you used `docker/bin/start` to start services )
    ``` 
    $ cd <directory containing helpkit code>
    $ bundle exec rake localstack:create
    ```    


Running the App:
----------------

        

More notes and write up @ [Reference.md](References.md)
