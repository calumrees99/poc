### Introduction
This PoC displays how istio handles a faulty version of a service in a subset and how a circuit breaker can be used to restrict connection trottling. Below I've created a guide on how to use this repo and share what the expected outputs looks like. If you like a graph, you can also use Kiali to visabiliy see the graphics of how it looks and I particaully found it useful when troubleshooting!

This sandbox environment consists of:
Subset v1:
- nginx-v1

Subset v2: # This is to showcase how you can have 2 instances of a pod running, 1 working and 1 faulty.
- nginx-v2 
- nginx-fault # This originally get's deployed with the working configuration.

We are using fortio as our client and will running commands from it to verify the state of our service mesh traffic.

### Prereqs:
1) Watch this video, to understand the concept of why we need a circuit breaker: https://www.youtube.com/watch?v=ADHcBxEXvFA
2) Install & Start minikube.
3) install istio to your cluster: https://istio.io/latest/docs/setup/install/helm/
4) Install Kiali with add-ons to your cluster: 
    - https://kiali.io/docs/installation/quick-start/
    - https://istio.io/latest/docs/ops/integrations/prometheus/
    - https://istio.io/latest/docs/ops/integrations/grafana/
    - https://istio.io/latest/docs/ops/integrations/jaeger/

### Setup and test sandbox:
1) Apply the inital kubectl manifests:
    
    kubectl apply -f ../istio-circuit-breaker/0-inital-deployment

2) Connect to the Fortio pod and test a single connection.

    export FORTIO_POD=$(kubectl get pods -n fortio -l app=fortio -o 'jsonpath={.items[0].metadata.name}')
    kubectl exec -n fortio "$FORTIO_POD" -c fortio -- /usr/bin/fortio curl -quiet http://nginx.nginx

    Should return:
        HTTP/1.1 200 OK                          
        server: envoy
        date: Fri, 24 Mar 2023 10:44:19 GMT
        content-type: application/octet-stream
        content-length: 0
        x-envoy-upstream-service-time: 1

3) Change the load to 10 connections and 1000 requests:

    kubectl exec -n fortio "$FORTIO_POD" -c fortio -- /usr/bin/fortio load -c 10 -qps 0 -n 1000 -loglevel Warning http://nginx.nginx

    Returns:
        Code 200 : 1000 (100.0 %)

That's the first part done. We can now see that our v1 and v2 subsets are deployed and working.

### Inject fault into the system:
Now we need to apply the faulty configmap and attach it to the nginx-fault pod.

1) Apply the faulty configmap and attach it to the nginx-fault
    kubectl apply -f ../istio-circuit-breaker/1-inject-fault   
2) Run the load:
    kubectl exec -n fortio "$FORTIO_POD" -c fortio -- /usr/bin/fortio load -c 10 -qps 0 -n 1000 -loglevel Warning http://nginx.nginx

    Errors are being returned for the nginx-fault pod.
        Code 200 : 997 (99.7 %)
        Code 503 : 3 (0.3 %)

    This is actually a small sample size, but as you increse the load, you'll notice more 503's.

Exact ammount of errors will vary for test to test, but as you can see. We are now getting 503 errors from our nginx-fault pod. So it isn't being removed from load balancing. To do that, we need to following the steps below.

### Add circuit break
1) Apply the circuit break:
    kubectl apply -f ../istio-circuit-breaker/2-add-circuit-break 
    
2) Run the load:    
    kubectl exec -n fortio "$FORTIO_POD" -c fortio -- /usr/bin/fortio load -c 10 -qps 0 -n 1000 -loglevel Warning http://nginx.nginx

Now you can see no errors being returned!
    Code 200 : 1000 (100.0 %)

We've now mitigated the errors we we're previously having. For the next part, we are going to look at the connection pools, which are configurable to prevent hanging connections which can also lead to a cascading failure. 

3) Run command to see the overflow:
    kubectl exec -n fortio "$FORTIO_POD" -c istio-proxy -- pilot-agent request GET stats | grep nginx | grep pending

    cluster.outbound|80|v1|nginx.nginx.svc.cluster.local.circuit_breakers.default.remaining_pending: 100
    cluster.outbound|80|v1|nginx.nginx.svc.cluster.local.circuit_breakers.default.rq_pending_open: 0
    cluster.outbound|80|v1|nginx.nginx.svc.cluster.local.circuit_breakers.high.rq_pending_open: 0
    cluster.outbound|80|v1|nginx.nginx.svc.cluster.local.upstream_rq_pending_active: 0
    cluster.outbound|80|v1|nginx.nginx.svc.cluster.local.upstream_rq_pending_failure_eject: 0
    cluster.outbound|80|v1|nginx.nginx.svc.cluster.local.upstream_rq_pending_overflow: 0 <--- Notice how this is 0
    cluster.outbound|80|v1|nginx.nginx.svc.cluster.local.upstream_rq_pending_total: 128
    cluster.outbound|80|v2|nginx.nginx.svc.cluster.local.circuit_breakers.default.remaining_pending: 100
    cluster.outbound|80|v2|nginx.nginx.svc.cluster.local.circuit_breakers.default.rq_pending_open: 0
    cluster.outbound|80|v2|nginx.nginx.svc.cluster.local.circuit_breakers.high.rq_pending_open: 0
    cluster.outbound|80|v2|nginx.nginx.svc.cluster.local.upstream_rq_pending_active: 0
    cluster.outbound|80|v2|nginx.nginx.svc.cluster.local.upstream_rq_pending_failure_eject: 0
    cluster.outbound|80|v2|nginx.nginx.svc.cluster.local.upstream_rq_pending_overflow: 0 <--- Notice how this is 0
    cluster.outbound|80|v2|nginx.nginx.svc.cluster.local.upstream_rq_pending_total: 129
    cluster.outbound|80||nginx.nginx.svc.cluster.local.circuit_breakers.default.remaining_pending: 100
    cluster.outbound|80||nginx.nginx.svc.cluster.local.circuit_breakers.default.rq_pending_open: 0
    cluster.outbound|80||nginx.nginx.svc.cluster.local.circuit_breakers.high.rq_pending_open: 0
    cluster.outbound|80||nginx.nginx.svc.cluster.local.upstream_rq_pending_active: 0
    cluster.outbound|80||nginx.nginx.svc.cluster.local.upstream_rq_pending_failure_eject: 0
    cluster.outbound|80||nginx.nginx.svc.cluster.local.upstream_rq_pending_overflow: 0 
    cluster.outbound|80||nginx.nginx.svc.cluster.local.upstream_rq_pending_total: 0

Take note of the upstream_rq_pending_overflow. You can see that this is currently 0, which means the destination has been configured to handle all the connections we've sent and that no connections have been flagged for circuit breaking.

### Modify the connection settings

Next we can test and watch the circuit breaking in action.

1) Apply updated connection settings
    kubectl apply -f ../istio-circuit-breaker/3-modify-circuit-break

2) Test with our load:

    kubectl exec -n fortio "$FORTIO_POD" -c fortio -- /usr/bin/fortio load -c 10 -qps 0 -n 1000 -loglevel Warning http://nginx.nginx
    
    Now returns majority 503: 
        Code 200 : 96 (9.6 %)
        Code 503 : 904 (90.4 %)

The majority of requests are returning 503's, this is because we've configured the circuit break to open very often (for demostartion purposes). We can verify how often during step 3.

3) Run the below command to verify the connections:
    kubectl exec -n fortio "$FORTIO_POD" -c istio-proxy -- pilot-agent request GET stats | grep nginx | grep pending

    Output:
    cluster.outbound|80|v1|nginx.nginx.svc.cluster.local.circuit_breakers.default.remaining_pending: 1
    cluster.outbound|80|v1|nginx.nginx.svc.cluster.local.circuit_breakers.default.rq_pending_open: 0
    cluster.outbound|80|v1|nginx.nginx.svc.cluster.local.circuit_breakers.high.rq_pending_open: 0
    cluster.outbound|80|v1|nginx.nginx.svc.cluster.local.upstream_rq_pending_active: 0
    cluster.outbound|80|v1|nginx.nginx.svc.cluster.local.upstream_rq_pending_failure_eject: 0
    cluster.outbound|80|v1|nginx.nginx.svc.cluster.local.upstream_rq_pending_overflow: 31 <--- Now you can see the circuit breaker in action.
    cluster.outbound|80|v1|nginx.nginx.svc.cluster.local.upstream_rq_pending_total: 135
    cluster.outbound|80|v2|nginx.nginx.svc.cluster.local.circuit_breakers.default.remaining_pending: 1
    cluster.outbound|80|v2|nginx.nginx.svc.cluster.local.circuit_breakers.default.rq_pending_open: 0
    cluster.outbound|80|v2|nginx.nginx.svc.cluster.local.circuit_breakers.high.rq_pending_open: 0
    cluster.outbound|80|v2|nginx.nginx.svc.cluster.local.upstream_rq_pending_active: 0
    cluster.outbound|80|v2|nginx.nginx.svc.cluster.local.upstream_rq_pending_failure_eject: 0
    cluster.outbound|80|v2|nginx.nginx.svc.cluster.local.upstream_rq_pending_overflow: 414 <--- Now you can see the circuit breaker in action.
    cluster.outbound|80|v2|nginx.nginx.svc.cluster.local.upstream_rq_pending_total: 222
    cluster.outbound|80||nginx.nginx.svc.cluster.local.circuit_breakers.default.remaining_pending: 1
    cluster.outbound|80||nginx.nginx.svc.cluster.local.circuit_breakers.default.rq_pending_open: 0
    cluster.outbound|80||nginx.nginx.svc.cluster.local.circuit_breakers.high.rq_pending_open: 0
    cluster.outbound|80||nginx.nginx.svc.cluster.local.upstream_rq_pending_active: 0
    cluster.outbound|80||nginx.nginx.svc.cluster.local.upstream_rq_pending_failure_eject: 0
    cluster.outbound|80||nginx.nginx.svc.cluster.local.upstream_rq_pending_overflow: 0
    cluster.outbound|80||nginx.nginx.svc.cluster.local.upstream_rq_pending_total: 0

You can now see in upstream_rq_pending_overflow, there are many connections that have been handled by the circuit breaker!

### Summary

We've succesfully shown how istio can eject a pod and use a circt break to handle connections. The next part is to configure with the configuration with production values.