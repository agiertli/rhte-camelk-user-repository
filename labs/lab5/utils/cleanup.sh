DEV_NAMESPACE=user5-dev
PROD_NAMESPACE=user5-prod

kamel reset --namespace=$DEV_NAMESPACE
kamel reset --namespace=$PROD_NAMESPACE

oc delete secret truststore-secret -n $DEV_NAMESPACE
oc delete secret truststore-secret  -n $PROD_NAMESPACE

oc delete secret artemis-credentials-secret truststore-secret -n $DEV_NAMESPACE
oc delete secret artemis-credentials-secret truststore-secret  -n $PROD_NAMESPACE