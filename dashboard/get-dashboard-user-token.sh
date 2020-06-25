# To list services and get the URL for the dashboard
# kubectl get services --namespace kubernetes-dashboard

kubectl -n kubernetes-dashboard describe secret $(kubectl -n kubernetes-dashboard get secret | grep admin-user | awk '{print $1}')