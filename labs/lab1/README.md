# Lab 1 - Local development

## Intro

`camel-k` is a cloud native integration framework:
- builds on top of camel, quarkus and targets Cloud (kubernetes, OpenShift) as its target runtime. 
- comes with `kamel` cli tool which enables developer to deploy integration onto cloud. By default, `kamel` requires cloud access. 

<br/>

__But what if you are in early stages of development and you just want to test your integration locally?__

__What if the components you want to integrate with, are not yet available in the cloud platform?__ 

<br/>

There are two options how to start developing camel-k integration locally without depending on cloud access:

 * kamel local
   -  https://camel.apache.org/camel-k/1.10.x/running/local.html
 * camel/jbang
   -   https://camel.apache.org/manual/camel-jbang.html


## Task

__1. Test the `camel/jbang` cli tooling to understand how the local development experience looks like:__

- SKIP NEXT 2 STEPS IF USING DEVSPACES
- Install JBang as per https://www.jbang.dev/download/
- Install `camel` cli as per https://camel.apache.org/manual/camel-jbang.html
- Create a `ArtemisIntegration.java` camel Route using `camel` cli and run it
  ```
  $ camel init ArtemisIntegration.java

  $ camel run ArtemisIntegration.java
  ```
- You should see similar output in the console log 
  ```
  2022-11-29 20:37:28.693  INFO 72000 --- [ - timer://java] ArtemisIntegration.java:14               : Hello Camel from java
  ```

<br/>

Throughout this lab, we will be developing a very __simple integration which will talk to an Artemis broker__. 

Inside your workspace IDE, there is already artemis container up and running with following characteristics:
   - `AMQ_USER=admin`
   - `AMQ_PASSWORD=password1!`
   - Access to the artemis pod with dev spaces is done using `artemis-amqp-service`.

<br/>
 
__2. Connect `ArtemisIntegration` to the local Artemis__

Next step is to alter our `ArtemisIntegration.java` to send generated messages to our broker. 
 
There are multiple options how to do this:
- `camel-amqp` component
- `camel-jms` with `qpid` library on the classpath. 

Trouble is, `camel-amqp` is not yet fully supported at the time of writing this lab (12/2022) and `camel-jms` forces you to set up a ConnectionFactory bean manually, via code. 

While this is possible in camel-k, it doesn't create the best possible developer experience. Generally speaking, when working with (custom) beans is something which your integration heavily relies on, it should prompt you to re-think the design and decide, whether Camel on Quarkus wouldn't be more suitable option as it offers the _most_ flexibility. There is no _single_ right answer, single ConnectionFactory bean certainly doesn't disqualify usage of camel-k, but it's good to be aware of all the options.

Instead of implementing our custom ConnectionFactory bean, we will be using a `Kamelet`. Kamelets are additional layers of abstraction of camel components. They are hiding the camel component complexity and exposing strict interface to its consumers. Their consumption doesn't require deep camel knowledge - only the knowledge of the interface exposed by the particular Kamelet. They are also built for cloud native deployment, so the transition from locally running route using `camel` to fully fledged `camel-k` integration will be straightforward. 

<br/>

__Finish the Lab 1 by following steps below:__

  - Locate amqp compatible kamelet
    ```
    $ camel catalog kamelet | grep amqp
    ```
  - Familiarize yourself with the __AMQP Sink Kamelet__
    ```
    $ camel doc jms-amqp-10-sink
    ```
  - Change the `ArtemisIntegration.java` as follows:
    - remove `;` after the `log` command and add another step in the route using `to` DSL
    - Use following kamelet endpoint syntax:
      - `kamelet:<kamelet-name>?kameletOption=kameletValue`. Use following values:
      - destination type - `topic`
      - destination name - `userN-dev` (replace `N` with appropriate number)
      - remoteURI - `amqp://artemis-amqp-service:5672`
   - Run the `ArtemisIntegration.java` again, you should see following in the logs:

      ```
      2022-11-29 21:11:47.678  INFO 74446 --- [ - timer://java] ArtemisIntegration.java:14               : Hello Camel from java
      2022-11-29 21:11:48.088  INFO 74446 --- [p-service:5672]] org.apache.qpid.jms.JmsConnection        : Connection ID:53273bd1-8d00-4c64-8988-cecd79b82dd8:8 connected to server: amqp://artemis-amqp-service:5672
      ```

<br/>

## Summary

- `kamel local` or `camel` cli tools allow developers to work on the integrations locally which can be useful in early stages of development. 

- If your integration depends on 3rd party services (be it AMQ Broker, Kafka cluster, etc) you could mock those locally by using `podman` or `docker`. Engineering is working to improve the local development experience, especially the "mocking" part. 

- `Kamelets` can be extremely useful if you want to hide complexity of the underlying camel components and enable non-camel developers to integrate with services easily.