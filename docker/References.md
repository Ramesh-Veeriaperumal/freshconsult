Services:
---------
- Choice of images:
    - redis:3.2-alpine 
        - 'alpine' images are smallest images
    - bitnami/memcached:1.4.39-r0 
        - this image provides better log support compared to the official image

- Starting the services:   
    - They can be started using docker-compose also. Refer "docker/service.yml" for the settings.
		```
        $ docker-compose -f docker/service.yml up -d redis32
        $ docker-compose -f docker/service.yml up -d mysql57
        $ docker-compose -f docker/service.yml up -d memcached14 # -d starts the service as a daemon  
        ```

    - One drawback :
        - In Compose file version 3, we cant specify cpu or memmory limits. 
            - For more info, please refer https://github.com/docker/compose/issues/4513#issuecomment-281478365
        - We didnt want starting of the services to be tied to a repo

- Localstack - Local AWS Services
    - https://github.com/localstack/localstack
    - https://lobster1234.github.io/2017/04/05/working-with-localstack-command-line/
    - https://medium.com/@takezoe/atlassians-localstack-how-to-develop-aws-based-application-in-the-local-environment-vol-2-3d51bf7889f9


Create Ruby gems Backup:
-----------------------
File Naming convention : helpkit_2_2_rubygems_full_(dd)_(mm)_(yy).tar.gz
```
$ docker run --rm -v rubyGems:/gems -v $(pwd):/backup ruby:2.2 tar cvJf /backup/helpkit_2_2_rubygems_full_05_07_17.tar.gz /gems
 ```

- Links
    - https://www.healthcareblocks.com/blog/persistent-ruby-gems-docker-container
	- https://www.digitalocean.com/community/tutorials/how-to-share-data-between-docker-containers
    - https://docs.docker.com/engine/tutorials/dockervolumes/#backup-restore-or-migrate-data-volumes

The correct way to do SSH Forwarding :
-------------------------------------
- Some of our gems are downloaded from private git repos which are fetched via ssh.
- This needs an authenticated ssh key to be used to pull the repo

Few ways of achieving this:
1. Mounting the ssh directory inside the container
    - relies on the host environment to be setup properly
2. Copying the ssh key into the container
    - Bad if we intend to build and share the image
3. SSH Forwarding using another container - Recommended way if we intend to share images
    - Setup
    	```
        $ git clone git://github.com/uber-common/docker-ssh-agent-forward
        $ cd docker-ssh-agent-forward
        $ make
        $ make install
        ```

    - Start agent forward service
        ```
        $ pinata-ssh-forward

	    #Example Run
        
        FDLMC1465:helpkit Arvind$ pinata-ssh-forward
        ssh-agent
        Connection to 127.0.0.1 port 2244 [tcp/nmsserver] succeeded!
        4096 SHA256:<>/<> .ssh/github_fdlmc1465 (RSA) #This is the key u added in step (2) of Mac setup
        2048 SHA256:<>/<>+d8 .ssh/aws_id_rsa (RSA)
        Agent forwarding successfully started.
        Run "pinata-ssh-mount" to get a command-line fragment that
        can be added to "docker run" to mount the SSH agent socket.

        For example:
        docker run -it $(pinata-ssh-mount) uber/ssh-agent-forward ssh -T git@github.com
        FDLMC1465:helpkit Arvind$
        ```

    - Sample Docker compose file    
        ```
        volumes:
        ssh-agent:
            external: true 

        services:
        helpkit:
            build: .
            container_name: helpkit
            command: ./docker/docker-start.sh #reference based on where we are running the docker-compose command from
            volumes:
            - ssh-agent:/ssh-agent #https://github.com/docker/for-mac/issues/410

        environment:
        - SSH_AUTH_SOCK=/ssh-agent/ssh-agent.sock   
        ```

    - Links :
        - https://github.com/avsm/docker-ssh-agent-forward
        - https://github.com/uber-common/docker-ssh-agent-forward
        - https://hub.docker.com/r/uber/ssh-agent-forward/
    


