#Installed Calico VPC CNI plugin following https://docs.aws.amazon.com/eks/latest/userguide/calico.html
```
kubectl apply -f https://raw.githubusercontent.com/aws/amazon-vpc-cni-k8s/release-1.7/config/v1.7/calico.yaml
kubectl get daemonset calico-node --namespace kube-system
```

#Upgrade CNI drivers (from: https://docs.aws.amazon.com/eks/latest/userguide/cni-upgrades.html)
```
#Check running Version
kubectl describe daemonset aws-node --namespace kube-system | grep Image | cut -d "/" -f 2

#Confirm running version (aws-node-5wth8 is the name of some of the running aws pods)
kubectl describe pods/aws-node-5wth8 --namespace kube-system | grep amazon-k8s-cni

#Upgrade (.x is the latest version from https://github.com/aws/amazon-vpc-cni-k8s/tree/master/config)
curl -o aws-k8s-cni.yaml https://raw.githubusercontent.com/aws/amazon-vpc-cni-k8s/release-1.x/config/v1.x/aws-k8s-cni.yaml
sed -i -e 's/us-west-2/us-east-2/' aws-k8s-cni.yaml
kubectl apply -f aws-k8s-cni.yaml

#Reconfirm running version (aws-node-5wth8 is the name of some of the running aws pods)
kubectl describe pods/aws-node-5wth8 --namespace kube-system | grep amazon-k8s-cni

```