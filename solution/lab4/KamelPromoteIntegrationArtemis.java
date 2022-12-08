// camel-k: language=java

import org.apache.camel.builder.RouteBuilder;

public class KamelPromoteIntegrationArtemis extends RouteBuilder {

    @Override
    public void configure() throws Exception {

        // Write your routes here, for example:
        from("timer:java?period={{time:1000}}").routeId("{{routeId}}")
            .setBody()
                .simple("Hello Camel from ${routeId}")
            .log("${body}")
           .to("kamelet:custom-jms-amqp-10-sink?destinationType={{destinationType}}&destinationName={{destination}}&remoteURI={{broker-url}}&trustStoreLocation=/etc/ssl/jms-sink/client.ts&trustStorePassword={{trustStorePassword}}&username={{username}}&password={{password}}");
    }
}
