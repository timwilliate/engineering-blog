---
layout: post
title: "Doing Docker Metrics"
subtitle: "How To Do Production Ready Docker Metrics"
header-img: "img/mon-city_garden.jpg"
authors: 
    -
        name: "Stuart Wong"
        githubProfile : "cgswong"
        twitterHandle : "cgswong"
        avatarUrl : "https://avatars2.githubusercontent.com/u/6033436?v=3"
tags: [docker, sysadmin, metrics, devops, tutorial]
---

As our usage of [Docker](http://www.docker.com) grows and we provision more container hosts, collecting metrics and monitoring containers and hosts has become a necessity. This post will walk you through how to glue together a few components to deploy a monitoring solution for Docker. All components are intentionally plug-and-play, so if things need to be changed any component can be (relatively) easily swapped out for an alternative.

## Some assumptions
First, we assume that Docker is installed, configured and running on your hosts. We further assume that you can connect to your Docker hosts with a web browser. It's worth noting some of our other requirements at this point since there may be some questions as to why certain decisions were made.

  * Ease of deployment - We believe in fail fast, and succeed fast. We wanted an immediate solution to get up and running quickly, run some tests and make a quick, but informed decision.
  * Scalability - Success tends to have its own set of problems, namely scale. The solution needed to scale at all levels, handling both data velocity, volume and query demands.
  * Availability - This goes without saying since we plan on doing notifications from the system and not just support analysis and planning.

With that said, lets get to the good stuff!

## Components for Docker Metrics and Monitoring
There are three components to our Docker monitoring setup: cAdvisor, InfluxDB, and Grafana.

[cAdvisor or Container Advisor](https://github.com/google/cadvisor) - A Google developed tool that provides host and container metrics. It's a host daemon that collects, aggregates, processes and exports information about running containers. We run it within a container on each host with various host volumes exposed which allow it to collect metrics from the Docker containers running on the host. It provides an available dashboard with a default 60 second data aggregation interval. It has a few options for back ends which can be used to store the data for longer term retrieval and analysis.

[InfluxDB](http://influxdb.com/) - An open source distributed time series database which we use for longer term storage and analysis of the data from cAdvisor. It's still under development but works fine and does have scale-out capabilities, though for the time being we are using a single container instance until we can upgrade to a stable 0.9.x version.
We would have liked to standardize on the soon to be released 0.9.x version, however, at this time **[cAdvisor](https://github.com/google/cadvisor/issues/743) does not yet support the InfluxDB 0.9.x API**. Though there are other non-completed features which also affect the UI component, this is the primary reason we will be using the 0.8.x version at this time.

[Grafana](http://grafana.org/) - A nice open source web based UI which allows us to visualize all the metrics data. We create various dashboards which allow us to run queries against InfluxDB and chart them accordingly in a very nice layout.

## Putting things together
Now that you have an overview of the different components lets put things together.

1.  We start first with our [InfluxDB container](https://registry.hub.docker.com/u/tutum/influxdb/) using the below fleet/systemd unit:

    ```
    [Unit]
    Description=InfluxDB Service

    Requires=docker.service
    After=docker.service

    [Service]
    Restart=always
    RestartSec=5s

    ExecStartPre=-/usr/bin/docker rm -f %p
    ExecStartPre=/usr/bin/docker pull tutum/influxdb:latest

    ExecStart=/usr/bin/docker run --publish=8083:8083 --publish=8086:8086 \
      --name=%p tutum/influxdb:latest

    ExecStop=/usr/bin/docker stop %p
    ExecStopPost=-/usr/bin/docker rm -f %p

    [Install]
    WantedBy=multi-user.target

    [X-Fleet]
    MachineID=[your_machine_ID]
    ```

    You can just extract and use the above `docker run` command if you prefer. I provide the above systemd unit for a more complete, "production-ready" example. You will notice the **[X-Fleet]** section is specific to [`fleet`](https://github.com/coreos/fleet), which is our container scheduler on CoreOS hosts (hence the `MachineID` which comes from `cat /etc/machine-id`). In a true production environment you would not hardcode the host using `MachineID` as I've done above, but in my test setup I'm not using any service discovery mechanisms. For further production readiness you would use a data volume container or other means of persisting the storage when the container is restarted.

    To run the unit and create the required database for cAdvisor:

    ```sh
    fleetctl start influxdb.service
    sleep 10
    curl -X POST 'http://[influxdb_hostname]:8086/db?u=root&p=root' -d '{"name": "cadvisor"}'
    ```

    The `sleep 10` is there to allow InfluxDB a few seconds to be ready as Docker will need to `pull` (download) the image, and the InfluxDB itself time to start. The `curl` statement creates a database for storing the cAdvisor data, called **"cadvisor"** with a default configuration - the credentials to log into InfluxDB are as shown, i.e. **root/root**.  Be sure to replace `[influxdb_hostname]` with the actual IP or DNS resolvable hostname of your InfluxDB container host.

    Note that the InfluxDB dashboard can be accessed via the exposed **UI port 8083**, i.e., type `http://[influxdb_hostname]:8083` in your web browser. Port **8086 is for API access**, as used by the `curl` statement and cAdvisor. If you are doing clustering you will need to also expose the cluster ports, 8090 and 8099.

2.  We now start the [cAdvisor container](https://registry.hub.docker.com/u/google/cadvisor/) across all our hosts, using the this fleet/systemd unit:

    ```
    [Unit]
    Description=Google Container Advisor (cAdvisor)

    Requires=docker.service
    After=docker.service

    [Service]
    Restart=always
    RestartSec=5s

    ExecStartPre=-/usr/bin/docker rm -f %p
    ExecStartPre=/usr/bin/docker pull google/cadvisor:latest

    ExecStart=/usr/bin/docker run --volume=/:/rootfs:ro --volume=/var/run:/var/run:rw \
      --volume=/sys:/sys:ro --volume=/var/lib/docker/:/var/lib/docker:ro \
      --publish=8080:8080 --name=%p google/cadvisor:latest --logtostderr \
      -storage_driver=influxdb -storage_driver_host=[influxdb_hostname]:8086 \
      -storage_driver_db=cadvisor -storage_driver_user=root -storage_driver_password=root

    ExecStop=/usr/bin/docker stop %p
    ExecStopPost=-/usr/bin/docker rm -f %p

    [Install]
    WantedBy=multi-user.target

    [X-Fleet]
    Global=true
    ```

    To run the unit file:

    ```sh
    fleetctl start cadvisor.service
    ```

    The `Global=true` in the `fleet` specific section indicates that this unit will be started across all Docker container hosts. Again, ensure you replace the `[influxdb_hostname]` in the Docker run statement with the appropriate value for your InfluxDB host.

    Here we are exposing required Docker host volumes to the container so it can read the host and container metrics from the Docker host. We are also publishing the **cAdvisor port to enable the built-in dashboard (on port 8080)**. You can refer to the cAdvisor documentation on the specific command line options but here we are just providing the InfluxDB details, i.e., the storage driver type ('influxdb'), host, database name ('cadvisor'), database user ('root') and database password ('root').

    You can access the cAdvisor dashboard for each host by entering the URL `http://[cadvisor_hostname]:8080` in your web browser.

    ![cAdvisor Home Page](/img/cadvisor-01.png)

    ![cAdvisor Metrics 1](/img/cadvisor-02.png)

    ![cAdvisor Metrics 2](/img/cadvisor-03.png)

3.  Install the Grafana dashboard using the fleet/systemd unit:

    ```
    [Unit]
    Description=Grafana UI Service

    Requires=docker.service
    Wants=influxdb.service
    After=docker.service
    After=influxdb.service
    BindsTo=influxdb.service

    [Service]
    Restart=on-failure
    RestartSec=5

    ExecStartPre=-/usr/bin/docker rm -f %p
    ExecStartPre=/usr/bin/docker pull grafana/grafana:latest

    ExecStart=/usr/bin/docker run --publish=3000:3000 \
      --env INFLUXDB_HOST=%H --env INFLUXDB_PORT=8086 --env INFLUXDB_NAME=cadvisor \
      --env INFLUXDB_USER=root --env INFLUXDB_PASS=root \
      --name=%p grafana/grafana:latest

    ExecStop=/usr/bin/docker stop %p
    ExecStopPost=-/usr/bin/docker rm -f %p

    [Install]
    WantedBy=multi-user.target

    [X-Fleet]
    MachineOf=influxdb.service
    ```

    To run the unit file:

    ```sh
    fleetctl start grafana.service
    ```

    We use the [official Grafana 2.x container image](https://registry.hub.docker.com/u/grafana/grafana/), using environment variables to connect to the `cadvisor` InfluxDB database. By using the `fleet` specific `MachineOf` unit statement we pin the container to the same host as the InfluxDB container. The Grafana dashboard can now be accessed via your web browser at `http://[grafana_hostname]:3000`.

## Connecting to Grafana and creating dashboards
Once your full stack is up, you'll then need to connect Grafana to your `cadvisor` database within InfluxDB and create some useful graphs.

1.  Start by opening a web page to `http://[grafana_hostname]:3000` and log in using the default Grafana credentials, **admin/admin**. _You will need to change this password and enable the appropriate authentication and authorization mechanisms for a production deployment_.

    ![Grafana Home](/img/grafana-home.jpg)

2.  Create a new data source connection to the `cadvisor` InfluxDB database by first exposing the data source menu by clicking on the Grafana fireball icon in the top left hand corner of the UI, then selecting _Data Sources_ -> _Add New_

    ![Grafana New Data Source](/img/grafana-newds.png)

    Enter the appropriate information:

    **Add data source settings**  
    Name: influxdb  
    Type: InfluxDB 0.8.x  
    Default (checked)  

    **Http settings**  
    Url: http://[influxdb_hostname]:8086  
    Basic Auth (enabled)  
    User: root  
    Password: root  

    **InfluxDB Details**  
    Database: cadvisor  
    User: root  
    Password: root  

    ![Grafana Creating a Data Source](/img/grafana-ds.png)

3.  Now comes what may be the hardest part: creating useful dashboards. Click on the _Home_ icon (top left corner) and select _+New_ to create a new dashboard.

    ![Grafana Dashboard](/img/grafana-dash.jpg)

    Hover over, and select the thin green icon bar (top far left, below fireball) and _Add Panel_ -> _Graph_ from the displayed sub-menus.

    ![Grafana New Dashboard](/img/grafana-newdash.jpg)

    Select the _no title (click here)_ and _edit_ from the displayed sub-menu.

    ![Grafana Creating a Graph](/img/grafana-graph.png)

    Now we can create a quick first graph. In the _series_ section fill in 'stats', then 'Limit' in the _alias_ section. Use 'fs\_limit' as the value for _mean_ in the _select_ section. Click on _+Add query_ to add an additional query/graph line and enter 'Usage' in the _alias_ section and 'fs\_usage' as the value for _mean_ in the _select_ section here. You will see values being plotted as soon as we enter values, and by now you will realize we are doing a simple *file system limit vs usage graph*.

    ![Grafana Writing a Query](/img/grafana-query.png)

    To complete our graph let's give it a better name, and more meaningful unit values. Click on _General_ and give your graph a name, for example 'File System'. Then click on 'Axes & Grid' and use the 'byte' unit for the _Left Y_ axis unit.

    ![Grafana Naming a Graph](/img/grafana-name.png)

    ![Grafana Axis Units](/img/grafana-axis.png)

    Once complete, ensure you click the _Save_ icon (near top left of screen) to save your dashboard. By default Grafana 2.x saves dashboards to it's embedded sqlite3 database though they can be exported and imported as well. You can also use other supported storage backends.

## Conclusion
You've now built a Docker metrics collection system with a single Grafana dashboard for file system statistics. We've only just begun so relevant dashboards are still being built, but check out the [Grafana reference docs](http://docs.grafana.org/reference/graph/) to get better acquainted with it's capabilities. You can look out for future posts on more of the components being used in our platform solution such as [Heapster](https://github.com/GoogleCloudPlatform/heapster), which we are looking at for tying together all the cAdvisor agents and provide a cluster-view, and our take on persistent storage in a Docker environment.

I hope this has proven useful to you. Please keep in touch and let us know your thoughts and what you might be working on as well.

Good luck!
