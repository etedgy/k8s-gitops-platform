# Troubleshooting Playbook: latency 200 ms → 5 s, everything "green"

**Scenario.** All pods `Running`/`Ready`, CPU ~35 %, memory ~55 %, no recent
deployments — yet p50/p99 latency jumped from ~200 ms to ~5 s.

## The one thing that tells us where to look

The pods are healthy and **not** resource-bound (CPU 35 %, mem 55 %), and nothing
changed in the app. A process that is busy *waiting* rather than *working* burns
almost no CPU. So the time is being spent **off-CPU, blocked on something
downstream** — a dependency, a lock, a connection pool, DNS, or the network.
The suspiciously round **~5 s** is a strong hint: it's close to a common client
timeout/retry boundary, which points at a dependency that got slow (or a pool
that's exhausted and requests are queueing for a connection).

So the investigation goes **outward from the app**, not into it.

## Order of investigation

### 0. Confirm & scope (first 2 minutes)
- Confirm it's real and not a monitoring artifact: look at the latency dashboard
  (RED metrics — Rate/Errors/Duration). Is it p50 too, or only p99? All routes or
  one? All pods or a subset? One AZ/node or everywhere?
- Check error rate and traffic **rate** alongside latency. A traffic spike with
  flat CPU still points downstream; flat traffic + rising latency points at a
  dependency degrading on its own.
- Establish the "since when" and line it up against a change calendar —
  *no app deploy* ≠ *no change*. Config/flag flips, a DB migration, a
  dependency's own deploy, cert rotation, or a cron/batch job are all suspects.

```bash
# Is it errors or pure latency? Which pods?
kubectl -n web-prod get deploy,hpa,pods -o wide
kubectl -n web-prod top pods            # confirm the "not CPU/mem bound" claim per-pod
# Recent changes to the running spec (even without a "deploy"):
kubectl -n web-prod rollout history deploy/prod-web
kubectl -n web-prod get events --sort-by=.lastTimestamp | tail -30
```

### 1. Follow the request path — where is the time spent?
Use **distributed tracing** (the fastest answer if we have it): open a slow trace
and read which span grew. Is it a DB query span, a Redis call, an outbound HTTP
call, or time *before* our handler even runs (queueing)?

If no tracing, decompose latency with metrics/logs:
- App: request-duration histogram **broken down by route and by downstream call**.
- Is the added ~4.8 s inside a DB call? A cache call? An external API? Or in
  time-to-first-byte / connection acquisition (pool wait)?

### 2. Interrogate the top suspects (most-likely first)

**a) Datastore / dependency slowness (most common cause of this exact profile)**
```bash
# Postgres: are there slow queries, lock waits, or a connection ceiling?
SELECT state, wait_event_type, count(*) FROM pg_stat_activity GROUP BY 1,2;
SELECT * FROM pg_stat_activity WHERE state='active' ORDER BY query_start LIMIT 20;
-- long-running / blocked queries, and are we near max_connections?
```
Hypotheses: a missing index after data growth, a lock from a long transaction or
migration, autovacuum/bloat, a failover to a slower replica, or `max_connections`
saturation making clients queue.

**b) Connection-pool exhaustion (app is fine, it's starved of connections)**
- Symptom: latency = pool-wait time; CPU stays low because threads are parked.
- Check pool metrics (in-use vs max, wait count/time). A dependency that got
  slightly slower holds connections longer → pool drains → everyone queues →
  latency cliffs to the pool timeout. Classic non-linear 200 ms→5 s jump.

**c) A specific dependency: Redis / RabbitMQ / external API**
```bash
redis-cli --latency-history         # Redis RTT; also INFO commandstats, slowlog
redis-cli info clients               # blocked clients / maxclients
# RabbitMQ: queue depth & consumer lag
rabbitmqctl list_queues name messages consumers messages_ready
```
Hypotheses: Redis evictions/`maxmemory` thrash, a hot key, RabbitMQ backlog with
slow/failed consumers, or an upstream 3rd-party API that slowed down.

**d) DNS / network / noisy neighbor**
```bash
kubectl -n kube-system logs -l k8s-app=kube-dns --tail=100   # CoreDNS errors/latency
kubectl -n web-prod exec deploy/prod-web -- sh -c 'time nslookup <db-host>'
# Is one node hot / throttled / losing packets? Is CNI or the node NIC saturated?
kubectl top nodes
```
Hypotheses: CoreDNS overload/timeouts (adds seconds via retries), a saturated
node, or **CPU throttling on a neighbor** (check `container_cpu_cfs_throttled`).

**e) The app's own internals**
- GC pauses / thread-pool or event-loop saturation, a slow N+1 pattern triggered
  by data growth, or a hot lock. Check GC and runtime metrics, and grab a couple
  of goroutine/thread dumps or a profile if the above came up empty.

## Immediate mitigation (buy time while diagnosing)
Do these in parallel with investigation — restoring service beats root cause.
- **Scale out** the app to add pool/handler capacity: `kubectl -n web-prod scale
  deploy/prod-web --replicas=N` (or bump HPA max). Helps if we're queueing.
- **Shed load / protect the dependency**: enable rate limiting, and make sure
  timeouts + circuit breakers are short so slow calls fail fast instead of
  piling up into 5 s waits and thread exhaustion.
- **Relieve the dependency**: kill the offending long/blocking query or
  transaction; fail over / restart the degraded node/replica; if a bad cron or
  batch job is the cause, pause it.
- **Roll back the *real* change** if step 0 found one (flag flip, config, a
  dependency's deploy) — even though our app wasn't redeployed.
- If a single node/pod is the outlier, `cordon`+`drain` the node or delete the
  bad pod so the Service routes around it.

## Follow-up (after the fire is out)
- Write the incident timeline & root cause; feed the fix back:
  the missing index, a right-sized connection pool, saner timeouts/retries with
  jitter + circuit breakers, CoreDNS autoscaling / node-local DNS cache.
- Close the **observability gap** that made this slow to diagnose: add
  distributed tracing if it was missing, per-dependency latency panels, pool
  saturation metrics, and an SLO burn-rate alert on **latency** (not just CPU).
- Add capacity guardrails: HPA on a latency/RPS custom metric or a queue-depth
  metric, not CPU alone (CPU never moved here — a CPU-only HPA would never have
  reacted).
- Add a load/soak test that reproduces dependency slowness so we catch the
  pool-exhaustion cliff before prod does.

## Summary hypothesis ranking
1. **Downstream datastore slowdown** (missing index / lock / failover / near
   max_connections) → **connection-pool exhaustion** → queued requests. *Best
   fit for low CPU + round-number 5 s.*
2. Redis/RabbitMQ/external dependency degradation.
3. DNS (CoreDNS) or network/node saturation adding ret/timeout seconds.
4. App-internal contention (GC, locks, N+1 from data growth).
