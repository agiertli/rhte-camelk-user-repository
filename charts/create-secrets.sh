oc process -f artemis-secret.yaml \
-p USER_NAMESPACE=<TODO> \
-p USERNAME=<TODO> \
-p PASSWORD=<TODO> \
-p TRUSTSTORE_PASSWORD=<TODO> \
-p BROKER_URL=<TODO> \
| oc apply -f -