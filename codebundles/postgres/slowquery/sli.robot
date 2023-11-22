*** Settings ***
Metadata    Author    Harsh Mishra
Documentation    Checks for Long runnning queries in Postgres Clusters within Kubernetes
Force Tags    Postgres  Kubernetes  Zalando  Patroni
Metadata    Display Name    Postgres Slowquery Inspection
Metadata    Supports    Kubernetes,AKS,EKS,GKE,OpenShift,Postgres,Zalando
Library    RW.Core
Library    RW.CLI
Library    String

Suite Setup    Suite Initialization

*** Tasks ***
Queries executing more than ${TIME_INTERVAL} milliseconds
    [Documentation]    Returns Total No Of Queries Running For More Than ${TIME_INTERVAL} Seconds on the cluster
    [Tags]    postgres query inspection slowquery zalando patroni
    ${query}=    Set Variable    SELECT COUNT(*) FROM (SELECT pid,user,pg_stat_activity.query_start,now() - pg_stat_activity.query_start AS query_time,query,state,wait_event_type,wait_event FROM pg_stat_activity WHERE (now() - pg_stat_activity.query_start) > interval '\\''${TIME_INTERVAL} milliseconds'\\'') AS foo
    ${cmd}=    Set Variable    for pod in $(${KUBERNETES_DISTRIBUTION_BINARY} get pods -n ${NAMESPACE} --no-headers -l cluster-name=${CLUSTER_NAME_POSTGRES} 2> /dev/null | awk '{print $1};') ;do kubectl exec -n postgres-database --context ${CONTEXT} $pod -- psql -U ${PGUSER} -d ${DATABASE} -c '${query}' --tuples-only ; done > /tmp/psqlout && awk \'{Total=Total+$1} END{print Total}\' /tmp/psqlout
    ${value}=    RW.CLI.Run Cli
    ...    cmd=${cmd}
    ...    env=${env}
    ...    render_in_commandlist=false
    ...    include_in_history=false
    ...    secret_file__kubeconfig=${kubeconfig}
    
    ${value}=    Convert To String    ${value.stdout}
    ${value}=    Strip String    ${value}
    ${value}=    Convert To Integer    ${value}
    
    RW.Core.Push Metric
    ...    value=${value}
    
*** Keywords ***
Suite Initialization
    ${kubeconfig}=    RW.Core.Import Secret
    ...    kubeconfig
    ...    type=string
    ...    description=The kubernetes kubeconfig yaml containing connection configuration used to connect to cluster(s).
    ...    pattern=\w*
    ...    example=For examples, start here https://kubernetes.io/docs/concepts/configuration/organize-cluster-access-kubeconfig/

    ${NAMESPACE}=    RW.Core.Import User Variable    NAMESPACE
    ...    type=string
    ...    description=The name of the Kubernetes namespace to scope actions and searching to.
    ...    pattern=\w*
    ...    example=my-namespace
    ...    default=postgres-database

    ${CONTEXT}=    RW.Core.Import User Variable    CONTEXT
    ...    type=string
    ...    description=Which Kubernetes context to operate within.
    ...    pattern=\w*
    ...    example=my-main-cluster
    ...    default=sandbox-cluster-1

    ${KUBERNETES_DISTRIBUTION_BINARY}=    RW.Core.Import User Variable    KUBERNETES_DISTRIBUTION_BINARY
    ...    type=string
    ...    description=Which binary to use for Kubernetes CLI commands.
    ...    enum=[kubectl,oc]
    ...    example=kubectl
    ...    default=kubectl

    ${TIME_INTERVAL}=    RW.Core.Import User Variable    TIME_INTERVAL
    ...    type=integer
    ...    description=Time interval (milliseconds) to measure in Range 1 to 604800 both included
    ...    example=1000
    ...    default=1000

    ${CLUSTER_NAME_POSTGRES}=    RW.Core.Import User Variable    CLUSTER_NAME_POSTGRES
    ...    type=string
    ...    description=The Postgres Cluster name or the name of cluster as defined in Zalando Manifests. For example, https://docs.runwhen.com/public/runwhen-authors/sandbox-resources/postgres-operator-and-test-database
    ...    pattern=\w*
    ...    example=acid-minimal-cluster
    ...    default=acid-minimal-cluster
    
    ${DATABASE}=    RW.Core.Import User Variable    DATABASE 
    ...    type=string
    ...    description=The database to inspect for long running queries
    ...    pattern=\w*
    ...    example=postgres
    ...    default=foo
    
    ${PGUSER}=    RW.Core.Import User Variable    PGUSER
    ...    type=string
    ...    description=database user
    ...    pattern=\w*
    ...    example=postgres
    ...    default=postgres

    ${HOME}=    RW.Core.Import User Variable    HOME

    Set Suite Variable    ${kubeconfig}    ${kubeconfig}
    # Set Suite Variable    ${kubectl}    ${kubectl}
    Set Suite Variable    ${KUBERNETES_DISTRIBUTION_BINARY}    ${KUBERNETES_DISTRIBUTION_BINARY}
    Set Suite Variable    ${CONTEXT}    ${CONTEXT}
    Set Suite Variable    ${NAMESPACE}    ${NAMESPACE}
    Set Suite Variable    ${HOME}    ${HOME}
    Set Suite Variable    ${TIME_INTERVAL}    ${TIME_INTERVAL}
    Set Suite Variable    ${CLUSTER_NAME_POSTGRES}   ${CLUSTER_NAME_POSTGRES}
    Set Suite Variable    ${PGUSER}    ${PGUSER}
    Set Suite Variable    ${DATABASE}    ${DATABASE}
    Set Suite Variable
    ...    ${env}
    ...    {"KUBECONFIG":"./${kubeconfig.key}", "KUBERNETES_DISTRIBUTION_BINARY":"${KUBERNETES_DISTRIBUTION_BINARY}", "CONTEXT":"${CONTEXT}", "NAMESPACE":"${NAMESPACE}", "HOME":"${HOME}", "TIME_INTERVAL":"${TIME_INTERVAL}", "PGUSER":"${PGUSER}", "CLUSTER_NAME_POSTGRES": "${CLUSTER_NAME_POSTGRES}", "DATABASE": "${DATABASE}"}
