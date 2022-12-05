# Cloud Native Integration with camel-k: Beyond Demo 

Welcome to Cloud Native Integration with camel-k lab. We are excited to have you. The focus of this lab is to share field experience from real, production, camel-k deployment. We will not be focusing on the creation of the complex camel integration. Instead, we will be focusing on everything else - building, deploying, testing, troubleshooting and customizing. The aim is to cover a full lifecycle of developing a camel-k application. From the initial bootstrapping all the way to production deployment.
Let's get down to it, and most importantly, let's have some fun.

# Lab Goals

The primary goal of this lab is to **_enable Red Hat consultants and architects to deliver camel-k projects for our customers beyond the demo scope_**. We want our attendees to understand all the parts of the camel-k development lifecycle. Including initial local development, dev deployment, troubleshooting, extending the out of the box bits, production deployment. The primary difference between demo and a the _real_ engagement is the environment and its constraints - such as authentication, security, internet access, immutability, supportability, etc.. The lessons learned in this lab are based on _real_ engagement at large UK customer (Motability) which went successfully live. 


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
 
 Next step is to alter our `ArtemisIntegration.java` to send generated messages to our broker. There are multiple options how to do this - you could use `camel-amqp` component, or `camel-jms` with `qpid` library on the classpath. Trouble is, `camel-amqp` is not yet fully supported at the time of writing this lab (12/2022) and `camel-jms` forces you to set up a ConnectionFactory bean manually, via code. While this is possible in camel-k, it doesn't create the best possible developer experience. Generally speaking, when working with (custom) beans is something which your integration heavily relies on, it should prompt you to re-think the design and decide, whether Camel on Quarkus wouldn't be more suitable option as it offers _most_ flexibility. There is no _single_ right answer, single ConnectionFactory bean certainly doesn't disqualify usage of camel-k, but it's good to be aware of all the options.

 Instead of implementing our custom ConnectionFactory bean, we will be using `Kamelet`. Kamelets are additional layer of abstraction of camel components. They are hiding the camel component complexity and exposing strict interface to its consumers. Their consumption doesn't require deep camel knowledge - only the knowledge of the interface exposed by the particular Kamelet. They are also built for cloud native deployment, so the transition from locally running route using `camel` to fully fledged `camel-k` integration will be straightforward. Finish the Lab 1 by following steps below:

  - Execute `camel catalog kamelets | grep amqp`  to locate  amqp compatible kamelet
  - Use `camel doc <kamelet-name>` to familiarize yourself with the AMQP Sink Kamelet
  - Change the `ArtemisIntegration.java` as follows:
   - remove `;` after the `log` command and add another step in the route using `to` DSL
   - Use following kamelet endpoint syntax:
    - `kamelet:<kamelet-name>?kameletOption=kameletValue`. Use following values:
     - destination type - `topic`
     - destionation name - `userN-dev` (replace `N` with appropriate number)
     - remoteURI - `amqp://localhost:5672`
   - Run the `ArtemisIntegration.java` again, you should see following in the logs:

    
    2022-11-29 21:11:47.678  INFO 74446 --- [ - timer://java] ArtemisIntegration.java:14               : Hello Camel from java
    2022-11-29 21:11:48.088  INFO 74446 --- [localhost:5672]] org.apache.qpid.jms.JmsConnection        : Connection ID:5104f9e4-5b58-4a28-8834-fd80a998ad99:1 connected to server: amqp://localhost:5672
    


### Summary

`kamel local` or `camel` cli tools allows developers to work on the integrations locally which can be useful in early stages of development. If your integration depends on 3rd party services (be it AMQ Broker, Kafka cluster, etc) you could mock those locally by using `podman` or `docker`. Engineering is working to improve the local development experience, especially the "mocking" part. `Kamelets` can be extremely useful if you want to hide complexity of the underlying camel components and enable non-camel developers to integrate with services easily.

## Lab 2 - Customizing Kamelets

### Intro

Red Hat ships many kamelets with the camel-k operator out of the box:
```
$  oc get kamelet -n tooling | wc -l
      82
```

Kamelets are not as flexible as the camel components which they are based on. If the underlying camel component supports hundreds of parameters, but corresponding kamelet only expose couple, chances are, the out of the box kamelet will not be directly useful at your customer or for your use case.

People often don't realize that kamelet can, and even should be, extended and customized. This is how you can ge the best experience out of using them - by tailoring them precisely for your particular use case. And this is what we are going to do in the Lab 2.

### Task

The company standards dictates the integration with any Artemis broker needs to happen only via authenticated user and one-way ssl is enforced. The out of the box kamelet doesn't support neither authentication nor ssl. 

First, let's take a look at how we can support basic(username+password) authentication against Artemis broker.


 - Inspect the out of the box kamelet to understand its internal mechanics:
   - `oc get kamelet jms-amqp-10-sink -n tooling -o yaml | oc neat > custom-sink-kamelet.yaml`
 - Inspect the [ConnectionFactory constructor](https://github.com/apache/qpid-jms/blob/main/qpid-jms-client/src/main/java/org/apache/qpid/jms/JmsConnectionFactory.java) and see whether there isn't a constructor suitable for our purposes. Consider adding new `username` and `password` kamelet properties and also new ConnectionFactory constructor parameters
 - camel-k will cleverly "guess" which ConnectionFactory constructor to call based on the number and types of the parameters. Order matters(!)
 - After applying the changes to the kamelet yaml file,  make sure to alter these two attributes as well:
   - `namespace: userN-dev`
   - `name: custom-jms-amqp-10-sink`
 - Apply the custom kamelet in your namespace, i.e. `oc apply -f custom-sink-kamelet.yaml -n userN-dev`
 - Test your kamelet by changing `ArtemisIntegration.java` against a _real_ Artemis broker. 
   - You can find out the Broker service url like this  :
     -   `oc get svc -n tooling | grep artemis-no-ssl`
   - TIP: Correct syntax to call services outside of current namespace is `<service>.<pod_namespace>.svc.cluster.local`
   - Use following credentials to connect, simply pass them as kamelet endpoint parameters:
     - `username: admin`
     - `password: password1!`
 - Run the integration like `kamel run ArtemisIntegration.java` - notice, we are now running the integration on a cluster
 - If everything went well, you should similar output in the logs:
   ```
   2022-12-01 21:29:52,693 INFO  [org.apa.qpi.jms.JmsConnection] (AmqpProvider :(1556):[amqp://rhte-artemis-no-ssl-0-svc.tooling.svc.cluster.local:5672]) Connection ID:ef32e5da-b4a2-4172-bae8-50b0c03b216a:1556 connected to server: amqp://rhte-artemis-no-ssl-0-svc.tooling.svc.cluster.local:5672   
   ``` 


Next, let's add support for one-way ssl:

When you check the `dependencies` section of the `jms-amqp-10-sink` kamelet, you will notice that it's based on the QPID client. QPID allows to specify most of the client properties directly inside the Connection URI, see [official documentation](https://qpid.apache.org/releases/qpid-jms-1.7.0/docs/index.html) for more details. At the very least, we need to supply URL as follows:

`amqps://host:port?transport.trustStoreLocation=/path/to/client/truststore&transport.trustStorePassword=truststorePassword!&transport.verifyHost=false`

Unfortunately it's not so straightforward to pass this value in a camel-k. Any query parameter inside remoteURI will be treated as a kamelet property (and not remoteURI query parameter). In our case it would mean that `truststorePassword` would not be passed to the underlying ConnectionFactory (you are free to try this out;)). Potential solution could be to use [RAW](https://camel.apache.org/manual/faq/how-do-i-configure-endpoints.html) feature of Camel and pass our remoteURI value as RAW(remoteURI). Unfortunately RAW [doesn't seem to work](https://github.com/apache/camel-kamelets/issues/1200) in camel-k 1.8 operator version. So we need to get a bit more creative..:

 - Add three more Kamelet parameters:
   - verifyHost (type: string, default:false)
   - trustStoreLocation (type:string)
   - trustStorePassword (type:string)
 - Change the way `remoteURI` is defined in Kamelet definition:

    - 
    ```      
              - key: remoteURI
              value: '{{remoteURI}}?transport.trustStoreLocation={{trustStoreLocation}}&transport.trustStorePassword={{trustStorePassword}}&transport.verifyHost={{verifyHost}}'
    ``` 

By defining the remoteURI query parameters directly in the Kamelet definition, we will bypass camel property parser which was causing the `trustStorePassword` param to "be lost".  
 
The final step before we attempt to run this new ssl-based integration is to inject the client truststore into the integration pod - see file `client.ts` in your user git repository.  First, you need to create secret based on the contents of this file. `kamel` binary allows us to reference a secret and mount it to a specified location using `--resource secret:secretName@/where/you/want/to/mount/it` syntax. See [documentation](https://camel.apache.org/camel-k/1.10.x/configuration/runtime-resources.html) for more details. Consider mounting it somewhere under `/etc`.

Here are the new parameter values you need to update in your `ArtemisIntegration.java`:
 - URI scheme is now `amqps` (as opposed amqp)
 - Get the new _ssl_ service name from `tooling` namespace - beware, the port is also different!
 - truststorePassword is `password1!`
- trustStoreLocation should match whatever you passed via `kamel run --resource ..`

## Lab 3 - KameletBinding evolution

### Intro

So far we have been developing our integrations in Java. There are other DSL out there (such as groovy, javascript, and even yaml) but development of such Integration is still fairly technical task and it requires camel knowledge. However with well designed (reusable, configurable) Kamelets it's possible to deploy an integration using slightly different way - by utilizing `KameletBinding`. As the name suggests, it's a OpenShift custom resource which allows you to bind source/sink kamelets (or camel components) in declarative way. This opens a new possibilities for camel-k. KameletBindings enables non-camel experts to deploy and configure Integration. This doesn't mean using of camel-k doesn't require deep technical and integration knowledge - somebody _still_ has to develop and maintain the Kamelets, but once that is done, the adoption of KameletBinding (especially when combined with templating engine such as `helm`) will be very straightfoward. It has another advantages - the fact it's a OpenShift CR means we don't have to deal with `kamel` cli anymore to run an integration. We can directly apply the file on OpenShift and it will result into running Integration. This also greatly fits into today's GitOps ways of working.


### Task

In this lab we will turn our Java based integration in the Kamelet Binding. We will use `helm` to generate multiple Kamelet Bindings with ease. We will generate N bindings (where N is number of groups-1) to generate messages for every group in this lab. Then we will add one more binding which will simply read all the messages you as a group received. The output of the helm chart should produce this:

![Helm chart design for Group1](helm-chart-design.svg "Helm Chart design for Group1")

The actual helm templates were already developed for you, as it would be too time consuming to cover it as part of this lab. While helm and KameletBindings go really well together - because it's really easy to template the bindings, Kamelets also heavily depends on using `{{ camel-k-placeholders }}` which conflicts with `{{ helm-placeholders }}`, so figuring out the syntax is a major PITA.

First, let's start by secret provisioning. If you finished previous lab, you should already have secret containing `client.ts` available in `userN-dev` namespace. If not, make sure to create it now, i.e.: 

`oc create secret generic my-artemis-secret --from-file=client.ts`

We will need one more secret though - previously, our Java integration contained some hardcoded values with sensitive information (such as broker credentials). This is of course not feasible in beyond demo scenario! Let's create _another_ secret which will contain:

 - broker username (admin)
 - broker password (password1!)
 - broker connection url (we will be using `amqps` url from previous lab)
 - truststore password (password1!)

 You can use `utils/create-secrets.sh` and `utils/artemis-secret.yaml` to assist with this task.

Next, go and explore `charts/templates` - that's where all the magic happens. We are defining few custom Kamelets (based on the work from previous labs), but most importantly we are templating the creation of Kamelet Bindings. Understand how _binary_ (vs "normal") secrets are handled. We are also using [traits](https://camel.apache.org/camel-k/1.8.x/traits/traits.html) which is a camel-k feature which allows us to enable additional super powers on top of our integrations. Usage of `Container` trait is almost inevitable in OCP environment. If you study `kamelet-bindings.yaml` you will notice it is completely generic and supports _any_ two Kamelets and _any_ properties.

This is a very powerful concept as you can use this as a base template to define integrations for many different systems. However, if this was a real-world scenario, this helm chart wouldn't be so useful without the accompanying documentation. The only way how to make the consumption of such helm chart easy, is to make sure its consumers can focus on just supplying helm values, and not to deal with the underlying templates (which are still fairly complex and technical).


Final task is to change `dev/values.yaml` in such a way that will create the appropriate bindings as per the Helm Diagram screenshot. There are scripts ready for you in `utils` to test the helm chart. The result should look similar to this:


```
oc get klb -n user1-dev
NAME                           PHASE   REPLICAS
rhte-camelk.group1.to.group2   Ready   1
rhte-camelk.group1.to.group3   Ready   1
rhte-camelk.group1.to.group4   Ready   1
rhte-camelk.group1.to.group5   Ready   1
rhte-camelk.group1.to.group6   Ready   1
rhte-camelk.group1.to.group7   Ready   1
rhte-camelk.group1.to.log      Ready   1
```

The number of "groupN.to.groupM" bindings can differ based on the number of actual groups present in the lab. Don't forget to check the integration logs to make sure there are no errors. You can use `kamel get` and `kamel log`, or plain `oc`. 

## Lab 4 - Traditional Continuos Delivery

## Lab 5 - GitOps styled Continuos Delivery