### deployment.yaml
cpu.req = 200m

cpu.limits = 500m 
> def: 6 1000

### hpa.yaml
minReplicas = 1

maxReplicas = 10

averageUtilization = 50 (cpu)

stabilitzationWindowSeconds = 60 (behavior - scaleDown)

### load-job.yaml (load pod)
cpu.req = 50m

cpu.limits = 100m

> desiredResplicas = currentReplicas x (currentCPU/targetCPU) 
					= 1 * (250/50) 
					= 5 
					
### Prof Twist: 1100m 
Pod = 6 => 6 - 3 = 3 pod 

CPU = 1100m 

	3 * 50 = 150m 

	1100 - 150 = 950m

	950 / 200 = 4 pod 

HPA = 10 

> Prediction: min (3,4,10) = 3 pod 

### Example1: 4
Pod = 4 => 4 - 3 (pod def) = 1 pod

CPU.req = no limit 

HPA = 10 
> Prediction: min(1,10) = 1

### Example2: 6, 1000m 
Pod = 6 => 6 - 3 = 3 pod

CPU = 1000m 

	3 * 50 (cpu.req def) = 150m 

	1000 - 150 = 850m 

	850m / 200m (cpu.limit def) = 5 pod 

HPA = 10 
>Prediction: min (3,5,10) = 3 pod 

### Example3: 8, 1200m 
Pod = 8 => 8 - 3 = 5 pod 

CPU = 1200m 

	3 * 50 = 150m 

	1200 - 150 = 1050

	1050 / 200m = 5 pod 

HPA = 10

> Prediction: min (5,5,10) = 5 pod

### Example4: 10, 500m 
Pod = 10 => 10 - 3 = 7 pod 

CPU = 500m 

	3 * 50 = 150m 

	500 - 150 = 350

	350 / 200 = 1 pod 

HPA = 10 

> Prediction: min (7,1,10) = 1 pod