*** Settings ***
Metadata    Author    Harsh Mishra
Documentation    Checks for blocking queries in Postgres Clusters within Kubernetes
Force Tags    Postgres  Kubernetes  Zalando
Metadata    Display Name    Postgres Blocking Query Inspection
Metadata    Supports    Kubernetes,AKS,EKS,GKE,OpenShift,Postgres,Zalando
Library    RW.Core
Library    RW.CLI
Library    String

Suite Setup    Suite Initialization

*** Tasks ***
Get Blocked Queries in Postgres Cluster
    [Documentation]    Fetches list of blocked queries on Postgres Clusters
    [Tags]    postgres query inspection slowquery zalando
    ${query}=    Set Variable    SELECT activity.pid,activity.usename,activity.query,blocking.pid AS blocking_id,blocking.query AS blocking_query FROM pg_stat_activity AS activity JOIN pg_stat_activity AS blocking ON blocking.pid\=ANY(pg_blocking_pids(activity.pid));
    ${cmd}=    Set Variable    for pod in $(${KUBERNETES_DISTRIBUTION_BINARY} get pods -n ${NAMESPACE} --no-headers -l cluster-name=${CLUSTER_NAME_POSTGRES} 2> /dev/null | awk '{print $1};') ;do echo -e \"Query Statistics for Pod: $pod \\n\" && kubectl exec -n postgres-database --context ${CONTEXT} $pod -- psql -U ${PGUSER} -d ${DATABASE} -c '\\x' -c '${query}'> /tmp/psqlout && cat /tmp/psqlout; done
    
    ${stdout}=    RW.CLI.Run Cli
    ...    cmd=${cmd}
    ...    env=${env}
    ...    render_in_commandlist=true
    ...    include_in_history=true
    ...    secret_file__kubeconfig=${kubeconfig}

    ${commands_used}=    RW.CLI.Pop Shell History
    RW.Core.Add Pre To Report    Commands Used \n ${commands_used}
    RW.Core.Add Pre To Report    ${stdout.stdout}
    ${mitigation_query}=    Set Variable    SELECT pg_cancel_backend(activity.pid) FROM pg_stat_activity AS activity JOIN pg_stat_activity AS blocking ON blocking.pid\=ANY(pg_blocking_pids(activity.pid));
    ${mitigation_commands}=    Set Variable    for pod in $(${KUBERNETES_DISTRIBUTION_BINARY} get pods -n ${NAMESPACE} --no-headers -l cluster-name=${CLUSTER_NAME_POSTGRES} 2> /dev/null | awk '{print $1};') ;do kubectl exec -n postgres-database --context ${CONTEXT} $pod -- psql -U ${PGUSER} -d ${DATABASE} -c '${query}'> /tmp/psqlout && cat /tmp/psqlout; done
    
    ${suggestions}=    Set Variable    \#\# Mitigations\n- **To Terminate Specific backends** \n``SELECT pg_cancel_backend(<pid of the process>)``\n- **To Terminate All Blocked backends**\n``${mitigation_commands}``

    RW.Core.Add To Report
    ...    obj=${suggestions}
        
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
    # Set Suite Variable    ${PGPASSWORD}    ${PGPASSWORD}
    Set Suite Variable    ${DATABASE}    ${DATABASE}
    Set Suite Variable
    ...    ${env}
    ...    {"KUBECONFIG":"./${kubeconfig.key}", "KUBERNETES_DISTRIBUTION_BINARY":"${KUBERNETES_DISTRIBUTION_BINARY}", "CONTEXT":"${CONTEXT}", "NAMESPACE":"${NAMESPACE}", "HOME":"${HOME}", "TIME_INTERVAL":"${TIME_INTERVAL}", "PGUSER":"${PGUSER}", "CLUSTER_NAME_POSTGRES": "${CLUSTER_NAME_POSTGRES}", "DATABASE": "${DATABASE}"}
