GOGS_USER=gogs
GOGS_PWD=gogs
GOGS_DOMAIN=$(oc get route gogs -o template --template='{{.spec.host}}')


for i in {1..10};
do

  _RETURN=$(curl -o /tmp/curl.log -sL --post302 -w "%{http_code}" http://$GOGS_DOMAIN/user/sign_up --form user_name=gogs --form password=$GOGS_PWD --form retype=$GOGS_PWD --form email=admin@gogs.com)

    if [ $_RETURN == "200" ] || [ $_RETURN == "302" ]
    then
      echo "SUCCESS: Created gogs admin user"
      break
    elif [ $_RETURN != "200" ] && [ $_RETURN != "302" ] && [ $i == 10 ]; then
      echo "ERROR: Failed to create Gogs admin"
      cat /tmp/curl.log
      exit 255
    fi

  sleep 10
done


cat <<EOF > /tmp/data.json

{
  "clone_addr": "https://github.com/OpenShiftDemos/openshift-tasks.git",
  "uid": 1,
  "repo_name": "openshift-tasks"
}

EOF


_RETURN=$(curl -o /tmp/curl.log -sL -w "%{http_code}" -H "Content-Type: application/json" -u $GOGS_USER:$GOGS_PWD -X POST http://$GOGS_DOMAIN/api/v1/repos/migrate -d @/tmp/data.json)


if [ $_RETURN != "201" ] ;then
     echo "ERROR: Failed to import openshift-tasks GitHub repo"
     cat /tmp/curl.log
     exit 255
fi

sleep 5

cat <<EOF > /tmp/data.json

{
  "type": "gogs",
  "config": {
    "url": "https://openshift.default.svc.cluster.local/apis/build.openshift.io/v1/namespaces/$CICD_NAMESPACE/buildconfigs/tasks-pipeline/webhooks/QfK5U1mn/generic",
    "content_type": "json"
  },
  "events": [
    "push"
  ],
  "active": true
}

EOF

_RETURN=$(curl -o /tmp/curl.log -sL -w "%{http_code}" -H "Content-Type: application/json" -u $GOGS_USER:$GOGS_PWD -X POST http://$GOGS_DOMAIN/api/v1/repos/gogs/openshift-tasks/hooks -d @/tmp/data.json)

 if [ $_RETURN != "201" ] ; then
  echo "ERROR: Failed to set webhook"
  cat /tmp/curl.log
  exit 255
fi