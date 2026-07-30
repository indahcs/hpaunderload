> chmod 400 <key>.pem 
> ssh -i vockey.pem ec2-user@<public-ip>

### Fixed Values: 

| Component | Values |
|-----------|---------|
| Application CPU request | 200m per application Pod |
| Load Job | 3 Pods |
| Load CPU request | 50m per load Pod |
| Total load CPU request | 3 × 50m = 150m |
| HPA maxReplicas | 10 |

### requests.cpu: 1100m | 1000m (default)
### pod quota: 6 (default)

### Prediction: 
1. pod limit: 6 - 3 = 3 
2. cpu req limit: 1100 - 150 = 950 / 200 = 4 pod
3. hpa limit: 10 pod
> min(3,4,10) = 3  