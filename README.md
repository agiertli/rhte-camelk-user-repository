# Cloud Native Integration with camel-k: Beyond Demo 

Welcome to Cloud Native Integration with camel-k lab. We are excited to have you. The focus of this lab is to share field experience from real, production, camel-k deployment. We will not be focusing on the creation of the complex camel integration. Instead, we will be focusing on everything else - building, deploying, testing, troubleshooting and customizing. The aim is to cover a full lifecycle of developing a camel-k application. From the initial bootstrapping all the way to production deployment.
Let's get down to it, and most importantly, let's have some fun.

# Lab environment

The lab setup is backed by ArgoCD - there is single parent app in the `tooling` namespace which deploys following services:

 - AMQ 7
 - camelk
 - gitea
 - nexus
 - sealed secrets

You, as a user, have _view_ access to `tooling` namespace, which allows you to get all the information - such as connection URLs for AMQ, camel-k operator logs for troubleshooting, etc.

Final Argo Application, called `namespaces` configures user namespaces and permission. Each user (or team) have following namespaces created with admin permissions:
 - userN-dev
 - userN-prod


## Lab 1 - Local development

### Intro

`camel-k` is a cloud native integration framework. It builds on top of camel, quarkus and targets Cloud (kubernetes, OpenShift) as its target runtime. `camel-k` comes with `kamel` cli tool which enables developer to deploy integration onto cloud. By default, `kamel` requires cloud access. But what if you are in early stages of development and you just want to test your integration locally? What if the components you want to integrate with, are not yet available in the cloud platform? 

There are two options how to start developing camel-k integration locally without depending on cloud access:

 * kamel local
   -  https://camel.apache.org/camel-k/1.10.x/running/local.html
 * camel/jbang
   -   https://camel.apache.org/manual/camel-jbang.html

### Task
Test the `camel/jbang` cli tooling to understand how the local development experience looks like:
 
  - Install JBang as per https://www.jbang.dev/download/
  - Install `camel` cli as per https://camel.apache.org/manual/camel-jbang.html
  - Initialize `ArtemisIntegration` using `camel` cli and run it
    - You should see similar output in the console log `2022-11-29 20:37:28.693  INFO 72000 --- [ - timer://java] ArtemisIntegration.java:14               : Hello Camel from java`

Throughout this lab, we will be developing a very simple integration which will talk to Artemis broker. Since we are still in the early stages of development, we will spin up an artemis instance on our local machines using docker (or podman) and then we will change our `ArtemisIntegration` so it will talk to the locally running broker instance.

 - Start Artemis broker instance using `docker` or `podman`:
   - `docker run -e AMQ_USER=admin -e AMQ_PASSWORD=password1! -p 8161:8161 -p 5672:5672 --name artemis quay.io/artemiscloud/activemq-artemis-broker`
   - This command will start a broker allowing anonymous connections
 
 Next step is to alter our `ArtemisIntegration.java` to send generated messages to our broker. There are multiple options how to do this - you could use `camel-amqp` component, or `camel-jms` with `qpid` library on the classpath. Trouble is, these components requires you to set up a ConnectionFactory bean. While this is possible in camel-k, it doesn't create the best possible developer experience. Generally speaking, when working with (custom) beans is something which your integration heavily relies on, it should prompt you to re-think our design and decide, whether Camel on Quarkus wouldn't be more suitable option as it offers _most_ flexibility. There is no _single_ right answer, single ConnectionFactory bean certainly doesn't disqualify usage of camel-k, but it's good to be aware of all the options.

 Instead of implementing our custom ConnectionFactory bean, we will be using `Kamelet`. Kamelets are additional layer of abstraction of camel components. They are hiding the camel component complexity and exposing strict interface to its consumers. Their consumption doesn't require deep camel knowledge - only the knowledge of the interface exposed by the particular Kamelet. They are also built for cloud native deployment, so the transition from locally running route using `camel` to fully fledged `camel-k` integration will be straightforward.

  - Execute `camel catalog kamelets | grep amqp`  to locate  amqp compatible kamelet
  - Use `camel doc <kamelet-name>` to familiarize yourself with the AMQP Sink Kamelet
  - Change the `ArtemisIntegration.java` as follows:
   - remove `;` after the `log` command and add another step in the route using `to` DSL
   - Use following kamelet endpoint syntax:
    - `kamelet:\<kamelet-name>?kameletOption=kameletValue`. Use following values:
     - destination type - `topic`
     - destionation name - `userN-dev` (replace `N` with appropriate number)
     - remoteURI - `amqp://localhost:5672`
   - Run the `ArtemisIntegration.java` again, you should see following in the logs:

    
    2022-11-29 21:11:47.678  INFO 74446 --- [ - timer://java] ArtemisIntegration.java:14               : Hello Camel from java
    2022-11-29 21:11:48.088  INFO 74446 --- [localhost:5672]] org.apache.qpid.jms.JmsConnection        : Connection ID:5104f9e4-5b58-4a28-8834-fd80a998ad99:1 connected to server: amqp://localhost:5672
    


### Summary

`kamel local` or `camel` cli tools allows developers to work on the integrations locally which can be useful in early stages of development. If your integration depends on 3rd party services (be it AMQ Broker, Kafka cluster, etc) you could mock those locally by using `podman` or `docker`. Engineering is working to improve the local development experience, especially the "mocking" part. `Kamelets` can be extremely useful if you want to hide complexity of the underlying camel components and enable non-camel developers to integrate with services easily.

## Lab 2 - Customizing Kamelets

## Lab 3 - Running first camel-k integration

## Lab 4 - Evolution to KameletBindings

## Lab 5 - Traditional Continuos Delivery

## Lab 6 - GitOps styled Continuos Delivery