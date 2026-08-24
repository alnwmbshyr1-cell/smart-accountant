# KEDA autoscaling for Redis Stream workers

## الفكرة

يقرأ KEDA تأخر Consumer Group أو عدد Pending Entries في Redis Stream ويحوّله إلى External Metric تستخدمه HPA لزيادة عدد Workers عندما يتجاوز backlog العتبة. هذه الآلية لا تستبدل Circuit Breaker أو DLQ؛ فهي تزيد قدرة الاستهلاك فقط ولا تعالج dependency خارجية بطيئة أو متعثرة.

## الموارد

يحتوي `backend/ops/kubernetes/redis-stream-worker-autoscaling.yml` على Deployment وPodDisruptionBudget وTriggerAuthentication وScaledObject. الإعداد المرجعي يبدأ من replicas مساوية لـ2، ويتوسع حتى 20، ويستخدم `pendingEntriesCount: "100"` و`activationPendingEntriesCount: "10"` مع Redis TLS. يجب توفير Secret خارجي باسم `smart-accountant-redis` يحوي `REDIS_ADDRESS` و`REDIS_PASSWORD`; لا تضع القيم داخل Git.

```bash
kubectl apply --dry-run=client -f backend/ops/kubernetes/redis-stream-worker-autoscaling.yml
kubectl diff -f backend/ops/kubernetes/redis-stream-worker-autoscaling.yml
kubectl apply -f backend/ops/kubernetes/redis-stream-worker-autoscaling.yml
kubectl get scaledobject security-webhook-worker
kubectl get hpa -l app.kubernetes.io/name=security-webhook-worker
```

## الضبط

اختر `pendingEntriesCount` من throughput العامل المقاس، وليس رقماً عشوائياً. استخدم `pollingInterval` قصيراً بما يكفي للاستجابة دون تحميل Redis، و`cooldownPeriod` و`scaleDown.stabilizationWindowSeconds` لمنع flapping. احتفظ بـ`minReplicaCount` أكبر من أو يساوي 2 للخدمات الحرجة، وحدد `maxReplicaCount` بناءً على سعة Redis والـdownstream rate limit. ابدأ في staging مع backlog اصطناعي، راقب desired/current replicas، ثم اختبر drain وscale-down.

## Grafana وSLOs

أضف أو اربط لوحات desired replicas وcurrent replicas وqueue depth وpending age وmessages processed per second وCircuit state وrejections وDLQ rate. لا تعتبر scale-up نجاحاً إذا زاد عدد Pods بينما استمر backlog أو زاد DLQ. راقب أيضاً CPU وmemory وRedis latency وconnection count.

معايير قبول مبدئية هي: توسع عند تجاوز backlog للعتبة، عدم تكرار الرسائل عند إعادة توزيع Pods، بقاء Redis ضمن حدود الاتصال، عدم فتح Circuit بسبب ضغط داخلي غير معالج، وتناقص backlog بعد عودة downstream. عدّل القيم وفق baseline الحقيقي للخدمة.

## أمان وتشغيل

استخدم Redis TLS وACL وSecret Manager، وامنح TriggerAuthentication أقل صلاحية قراءة مطلوبة. طبّق NetworkPolicy إن كانت متاحة، واجعل probes لا تكشف أسراراً. استخدم `runAsNonRoot` و`readOnlyRootFilesystem` وPodDisruptionBudget. لا تختبر الحمل أو failure injection في الإنتاج.

## References

[1] [KEDA Redis Streams scaler](https://keda.sh/docs/2.20/scalers/redis-streams/)
[2] [KEDA TriggerAuthentication](https://keda.sh/docs/2.20/concepts/authentication/)
[3] [Kubernetes Horizontal Pod Autoscaler](https://kubernetes.io/docs/concepts/workloads/autoscaling/horizontal-pod-autoscale/)
