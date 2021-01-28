# Istio Mesh with external NLB SSL Termination
The following example should help to setup an istio Mesh with an external NLB Proxy
acting as an SSL termination

## Setup Istio
```bash
curl -L https://istio.io/downloadIstio | ISTIO_VERSION=1.8.2 TARGET_ARCH=x86_64 sh -
cd istio-1.8.2/
<!--bin/istioctl install --set profile=demo -y-->-->
kubectl label namespace default istio-injection=enabled
kubectl apply -f samples/bookinfo/platform/kube/bookinfo.yaml
kubectl get services
kubectl get pods
kubectl exec "$(kubectl get pod -l app=ratings -o jsonpath='{.items[0].metadata.name}')" -c ratings -- curl -s productpage:9080/productpage | grep -o "<title>.*</title>"
kubectl apply -f samples/bookinfo/networking/bookinfo-gateway.yaml
istioctl analyze
```

## Update AWS Load Balancer Controller
```bash
helm repo add eks https://aws.github.io/eks-charts
help repo update
kubectl apply -k "github.com/aws/eks-charts/stable/aws-load-balancer-controller//crds?ref=master"
helm install aws-load-balancer-controller eks/aws-load-balancer-controller --set clusterName=eks-workshop
```

## Setup Istio Ingress Gateway
```bash
bin/istioctl manifest generate --set profile=demo >../original-manifest.yaml
# edit Create custom-manifest.yaml based on original-manifest.yaml -- SEE BELOW 
diff original-manifest.yaml custom-manifest.yaml                                                                                                 
# 6275a6276,6284
# >   annotations:
# >       service.beta.kubernetes.io/aws-load-balancer-type: "nlb-ip"
# >       service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled: "true"
# >       # Note that the backend talks over HTTP.
# >       service.beta.kubernetes.io/aws-load-balancer-backend-protocol: http
# >       # TODO: Fill in with the ARN of your certificate.
# >       service.beta.kubernetes.io/aws-load-balancer-ssl-cert: "arn:aws:acm:us-east-2:276631003671:certificate/e1b7748e-e4dd-4ecf-93e1-a458ef6cddd3"
# >       # Only run SSL on the port named "https" below.
# >       service.beta.kubernetes.io/aws-load-balancer-ssl-ports: "https"
cat custom-manifest.yaml | kubectl delete -f -
cat custom-manifest.yaml | kubectl apply -f -
kubectl -n istio-system describe service istio-ingressgateway
```

## Setup httpbin service
```bash
kubectl apply -f samples/httpbin/httpbin.yaml
kubectl apply -f - <<EOF
apiVersion: networking.istio.io/v1alpha3
kind: Gateway
metadata:
  name: httpbin-gateway
spec:
  selector:
    istio: ingressgateway # use Istio default gateway implementation
  servers:
  - port:
      number: 443
      name: http
      protocol: HTTP
    hosts:
    - "httpbin.pabcol.myinstance.com"
EOF

kubectl apply -f - <<EOF
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: httpbin
spec:
  hosts:
  - "httpbin.pabcol.myinstance.com"
  gateways:
  - httpbin-gateway
  http:
  - match:
    - uri:
        prefix: /status
    - uri:
        prefix: /delay
    route:
    - destination:
        port:
          number: 8000
        host: httpbin
EOF
```

## Enable new nodegroup with SSM functionality enabled
```bash
cd eksctl
eksctl create nodegroup --include=nodegroup-3 --config-file=eks-init.yaml
k scale deploy istio-egressgateway --replicas=0 --namespace=istio-system
k scale deploy istio-ingressgateway --replicas=0 --namespace=istio-system
k scale deploy istiod --replicas=0 --namespace=istio-system
eksctl delete nodegroup --cluster eks-workshop --name=nodegroup-2
k scale deploy istio-egressgateway --replicas=1 --namespace=istio-system
k scale deploy istio-ingressgateway --replicas=1 --namespace=istio-system
k scale deploy istiod --replicas=1 --namespace=istio-system
cd -
``` 

## Test
```bash 
export INGRESS_HOST=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
export INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="http2")].port}')
export SECURE_INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="https")].port}')
export TCP_INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="tcp")].port}')
export INGRESS_HOST=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
curl -s -I -HHost:httpbin.example.com "http://$INGRESS_HOST:$INGRESS_PORT/status/200"
curl -s -I -HHost:httpbin.example.com "http://$INGRESS_HOST:$INGRESS_PORT/headers"
```

## Dashboard
```
kubectl apply -f samples/addons
kubectl rollout status deployment/kiali -n istio-system
```

## custom-manifest.yaml - KEY MODIFICATIONS:
```yaml
apiVersion: v1
kind: Service
metadata:
  annotations: null
  labels:
    app: istio-ingressgateway
    install.operator.istio.io/owning-resource: unknown
    istio: ingressgateway
    istio.io/rev: default
    operator.istio.io/component: IngressGateways
    release: istio
  name: istio-ingressgateway
  annotations:
      service.beta.kubernetes.io/aws-load-balancer-type: "nlb-ip"
      service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled: "true"
      # Note that the backend talks over HTTP.
      service.beta.kubernetes.io/aws-load-balancer-backend-protocol: http
      # TODO: Fill in with the ARN of your certificate.
      service.beta.kubernetes.io/aws-load-balancer-ssl-cert: "arn:aws:acm:us-east-2:276631003671:certificate/e1b7748e-e4dd-4ecf-93e1-a458ef6cddd3"
      # Only run SSL on the port named "https" below.
      service.beta.kubernetes.io/aws-load-balancer-ssl-ports: "https"
  namespace: istio-system
spec:
  ports:
  - name: status-port
    port: 15021
    protocol: TCP
    targetPort: 15021
  - name: http2
    port: 80
    protocol: TCP
    targetPort: 8080
  - name: https
    port: 443
    protocol: TCP
    targetPort: 8443
  - name: tcp
    port: 31400
    protocol: TCP
    targetPort: 31400
  - name: tls
    port: 15443
    protocol: TCP
    targetPort: 15443
  selector:
    app: istio-ingressgateway
    istio: ingressgateway
  type: LoadBalancer
  
---
```