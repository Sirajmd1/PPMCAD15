# AWS Cost Optimization Playbook

A practical, reusable reference for cutting AWS spend without breaking things. Work top to bottom: lay the foundation first, grab the quick wins, then go domain by domain. Each item has an **Effort** and **Impact** rating so you can pick battles.

> **Rule of thumb:** You can't optimize what you can't see. Spend the first week on visibility (tagging + Cost Explorer), not on turning things off. The single most common mistake is deleting/downsizing blindly and causing an outage that costs more than the savings.

**Legend** 

Effort: 🟢 low / 🟡 medium / 🔴 high

Impact: ⭐ small / ⭐⭐ meaningful / ⭐⭐⭐ large

---

## 0. Foundation: visibility before action

You currently have no tagging policy and unclear ownership. Fix this first - every later step depends on it.

| Action | Effort | Impact | Notes |
|---|---|---|---|
| Define a **mandatory tagging policy** (`Owner`, `Team`, `Environment`, `CostCenter`, `Project`) | 🟡 | ⭐⭐⭐ | Tags are how you attribute cost. Without them, every report is a guess. |
| Enforce tags with **AWS Organizations Tag Policies** + **SCPs** | 🟡 | ⭐⭐ | Block resource creation that lacks required tags, or auto-flag for cleanup. |
| Activate **cost allocation tags** in Billing console | 🟢 | ⭐⭐⭐ | Tags only show up in cost reports *after* you activate them (and only apply going forward). |
| Turn on **Cost Explorer** and the **Cost and Usage Report (CUR)** to S3 + Athena | 🟢 | ⭐⭐ | CUR with resource IDs enabled is the source of truth for deep analysis. |
| Set up **AWS Budgets** with alerts at 80% / 100% / forecasted-overrun | 🟢 | ⭐⭐ | Catches runaway spend before the invoice does. |

**Do this first, every time you start:** look at Cost Explorer grouped by *Service*, then by *Tag/Account*. The top 3-5 line items are where 80% of your savings live. Don't optimize a $40/month service while a $12,000/month one sits untouched.

---

## 1. Quick wins

These are the "just do it" items - minimal risk, fast payback.

- **Delete orphaned resources** 🟢 ⭐⭐ - unattached EBS volumes, old snapshots, unused Elastic IPs (they bill when *not* attached), idle load balancers, unattached NAT gateways. Trusted Advisor and Compute Optimizer surface most of these.
- **Set retention on every CloudWatch Log Group** 🟢 ⭐⭐⭐ - new log groups default to *never expire*. This is silent, compounding waste. (See Observability section.)
- **Right-size obvious over-provisioning** 🟢 ⭐⭐ - Compute Optimizer flags instances running at <10% CPU. Start with non-prod.
- **Stop non-production at night/weekends** 🟢 ⭐⭐⭐ - dev/test/staging rarely needs to run 168 hrs/week. Running them ~50 hrs/week (business hours) is a ~70% cut on that spend. (See Compute section.)
- **Move old snapshots to Archive / delete by policy** 🟢 ⭐ - EBS snapshot sprawl is a classic zombie cost.
- **Review Trusted Advisor cost checks** 🟢 ⭐⭐ - it does the hunting for you.

---

## 2. Compute (usually the biggest line item)

### 2a. Scheduled scale-down for non-production
Non-prod environments don't need 24/7 uptime.

- **EC2 Instance Scheduler** 🟢 ⭐⭐⭐ - simplest option for plain on/off. Define a schedule (e.g. up 8am–8pm weekdays), tag instances with the schedule name, done. Best starting point.
- **Auto Scaling Groups** 🟡 ⭐⭐ - for workloads that should *scale with demand* rather than just on/off. Use scheduled scaling actions for predictable patterns, target-tracking for variable load.
- **Kubernetes / HPA** 🟡 ⭐⭐ - scale deployments to zero (or near-zero) for non-prod workloads during off business hours. Pair with **Cluster Autoscaler / Karpenter** so the *nodes* shrink too - scaling pods down saves nothing if the EC2 nodes stay up.

### 2b. Right-sizing
- **AWS Compute Optimizer** 🟢 ⭐⭐⭐ - analyzes utilization and recommends right-sizing for EC2, EBS, Lambda, and ECS-on-Fargate. Free. Review monthly, act on non-prod first, then prod with a canary.
- Move down instance generations/sizes where CPU + memory headroom allows. 
- Move to Newer generations (e.g. m7 vs m5) are often cheaper *and* faster.

### 2c. Graviton (ARM) migration
- Switch managed services like Lambda, RDS, Aurora, ElastiCache, OpenSearch workloads to **Graviton** wherever the runtime supports ARM64.
- **Savings:** AWS lists Graviton instances at up to **~20% lower cost** and **up to ~40% better price-performance** than comparable x86; real-world customer results commonly land in the **20–30% cost reduction** range. Use the **Graviton Savings Dashboard** to model your specific savings before committing.
- **Effort** 🟡 - easy for interpreted/managed runtimes (Python, Node, Java, Go, .NET Core, most managed databases); harder if you have compiled native dependencies or x86-only container images. Build multi-arch images.

### 2d. Pricing commitments (the biggest single lever for steady-state)
Once you've right-sized, *then* commit - never commit to waste.

- **Savings Plans / Reserved Instances** 🟡 ⭐⭐⭐ - for predictable, always-on baseline load. Up to ~70% off On-Demand for 1- or 3-year commitments. Start with a **1-year Compute Savings Plan** at ~60–70% of your stable baseline; extend once you have data.
- **Spot Instances** 🟡 ⭐⭐⭐ - up to ~90% off for fault-tolerant, interruptible work: batch jobs, CI/CD runners, stateless workers, ML training. Not for stateful or latency-critical prod.
- **Strategy:** cover the floor with Savings Plans, the variable middle with On-Demand, and the bursty/fault-tolerant top with Spot.

---

## 3. Availability Zone usage in non-production

Multi-AZ redundancy costs money (duplicate compute + cross-AZ data transfer). Non-prod usually doesn't need it.

- **EC2** 🟢 ⭐ - pin non-prod instances to a single AZ instead of spreading.
- **RDS** 🟢 ⭐⭐ - disable Multi-AZ for non-prod databases (you roughly halve the instance cost).
- **Kubernetes** 🟡 ⭐ - constrain non-prod pods to one AZ to cut cross-AZ traffic charges.

> ⚠️ **Never** do this in production. Multi-AZ is a resilience control, not waste. Single-AZ in prod trades a recurring cost for an availability risk that will eventually be far more expensive.

---

## 4. Networking & content delivery

Data transfer is the cost most teams forget - it doesn't show up as a service you provisioned.

### CloudFront / edge
- **Compression** 🟢 ⭐ - enable gzip/brotli to shrink bytes transferred to clients.
- **Caching** 🟡 ⭐⭐ - tune cache policies and TTLs so fewer requests hit the origin. Higher cache-hit ratio = lower origin compute + lower data transfer.
- **Origin Shield** 🟡 ⭐ - adds a caching layer that reduces origin load and absorbs traffic spikes; net cost win when origin egress is significant.
- **Image optimization** 🟡 ⭐ - serve right-sized images per device.

### General data transfer hygiene
- Keep traffic **in-region and in-AZ** where possible - cross-AZ and cross-region transfer is billed.
- Use **VPC Gateway Endpoints** for S3 and DynamoDB (free) to avoid routing that traffic through NAT gateways. **NAT gateway data processing is a frequent hidden cost** - audit what's flowing through it.
- Serve static assets via CloudFront/S3 rather than from EC2.

---

## 5. Storage & data lifecycle

### S3
- **Lifecycle policies** 🟢 ⭐⭐⭐ - automatically transition aging data: Standard → Standard-IA → Glacier Instant/Flexible → Deep Archive, and expire what you don't need. Define by `prefix` or tag.
- **S3 Intelligent-Tiering** 🟢 ⭐⭐ - best when access patterns are unknown/unpredictable; AWS moves objects between tiers automatically with no retrieval fees on frequent/infrequent tiers. Low operational overhead.
- **Delete incomplete multipart uploads** 🟢 ⭐ - add a lifecycle rule; these accumulate invisibly.
- **Turn off versioning where you don't need it**, or expire noncurrent versions 🟢 ⭐.

### EBS
- Switch **gp2 → gp3** 🟢 ⭐⭐ - gp3 is ~20% cheaper and lets you provision IOPS/throughput independently.
- Delete unattached volumes and aged snapshots on a schedule (Data Lifecycle Manager) 🟢 ⭐.

---

## 6. Databases

- **RDS/Aurora right-sizing + Graviton** 🟡 ⭐⭐ - see Compute section; managed DBs support Graviton with minimal effort.
- **Aurora Serverless v2** 🟡 ⭐⭐ - for spiky or intermittent workloads, scales capacity automatically; can beat fixed provisioning for non-steady load.
- **Reserved Instances for RDS** 🟡 ⭐⭐ - for steady prod databases.
- **Stop non-prod RDS instances** 🟢 ⭐⭐ - RDS can be stopped for up to 7 days at a time (automation can restart+restop to extend).
- **Storage autoscaling, not over-provisioning** 🟢 ⭐ - let storage grow rather than pre-allocating.

---

## 7. Observability cost optimization ⭐⭐⭐ (the one everyone misses)

This is the section to read twice. Observability - logs, metrics, traces - quietly becomes one of the largest line items because it scales with traffic and with the number of services, not with anything you consciously provisioned. **CloudWatch alone can consume up to ~30% of a monthly AWS bill**, and the same applies to Datadog/Splunk/New Relic. The fix is almost never "monitor less" - it's "be intentional about *what*, *where*, and *how long*."

There are three cost levers across all three pillars: **volume** (how much you ingest), **cardinality** (how many unique series/fields you create), and **retention** (how long you keep it). Attack all three.

### 7a. The single biggest wins (do these first)
1. **Set retention on every log group.** CloudWatch log groups default to *never expire*. Most operational logs are useless after 14–30 days; ship anything you need long-term to S3/Glacier, which is far cheaper than CloudWatch storage. Setting retention + fixing cardinality routinely cuts CloudWatch bills by **30–50%**.
2. **Kill high-cardinality custom metrics.** CloudWatch custom metrics cost **$0.30 each per month** (first 10k). A metric with a dimension like `UserID`, `RequestID`, or `SessionID` creates a *separate paid metric per unique value* - this is the #1 cause of surprise observability bills. **Aggregate at the service / environment / endpoint level, never per-user or per-request.**
3. **Stop shipping the same data to multiple destinations.** Sending identical logs to CloudWatch *and* Splunk *and* S3 multiplies ingestion cost without adding insight. Pick one system of record per data type and route deliberately.

### 7b. Logs
- **Filter at the source, before ingestion.** This is where the real savings is - you pay per GB ingested.
  - **CloudWatch Logs:** use **Subscription Filters** (with regex/filter patterns) to forward only what matters to downstream destinations (Lambda, Kinesis Firehose, Splunk). Set **Log Group retention** everywhere.
- **Use the CloudWatch Logs Infrequent Access log class** for logs you rarely query - lower ingestion price for logs you keep "just in case."
- **Cut log verbosity at the app level.** Drop `DEBUG`/`INFO` chatter in production; structure logs (JSON) so you can filter cheaply instead of storing everything.
- **Lambda log tiering** - for very high-volume accounts, tiered ingestion pricing brings per-GB costs down sharply; consolidate noisy function logging.

### 7c. Metrics
- **Reduce cardinality** - the dominant cost driver. Drop labels you don't query (e.g. in EKS, drop low-layer `pod`/`container` labels if you only chart at cluster/service level). High cardinality also distorts dashboards and triggers false alarms, so this improves quality *and* cost.
- **Prometheus relabeling (`metric_relabel_configs`)** - drop noisy/irrelevant metrics *at scrape time*, before ingestion. PromQL aggregation after the fact still ingests everything first, so relabeling is the cheaper lever. Same principle applies at the **remote-write** stage (Thanos/Mimir/Loki).
- **Collect only metrics that matter** - define your Golden Signals (latency, traffic, errors, saturation) and SLI/SLOs first; scrape to those, not "everything just in case."
- **Tune scrape/collection granularity** - 1-second resolution everywhere is rarely needed. Coarser intervals for non-critical metrics cut volume directly.
- **Disable detailed monitoring where you don't use it** - EC2 detailed (1-min) monitoring is billable; basic (5-min) is free.

### 7d. Traces
- **Sample, don't capture everything.** 100% trace capture is almost never necessary. Head-based sampling (e.g. 5-10%) plus tail-based sampling that keeps all *errors and slow traces* gives you the signal at a fraction of the cost.
- **Bound trace retention** - traces age out of usefulness fast.

---

## 8. Serverless & containers

- **Lambda:** right-size memory (Compute Optimizer / Lambda Power Tuning) - memory and CPU scale together, so the cheapest setting isn't always the lowest memory. Move to **Graviton (arm64)** for ~20% off. Cut log verbosity (see Observability).
- **Fargate:** right-size task CPU/memory; use **Fargate Spot** for fault-tolerant tasks; consider Graviton-backed Fargate.
- **EKS:** **Karpenter** for efficient just-in-time node provisioning and consolidation; mix Spot + on-demand; scale non-prod to zero off-hours.

---

## 9. Governance & continuous practice (this is what makes it stick)

Cost optimization is not a project, it's a habit. One-time cleanups regress within months.

| Tool / practice | Cadence | Purpose |
|---|---|---|
| **AWS Cost Explorer** | Weekly glance, monthly deep-dive | Find top cost drivers, track trends, spot anomalies. |
| **AWS Cost Anomaly Detection** | Always-on | ML alerts on unexpected spend spikes before the invoice. |
| **AWS Budgets** | Always-on | Hard alerts at thresholds; per-team/per-project budgets via tags. |
| **AWS Compute Optimizer** | Monthly | Right-sizing recommendations across EC2/EBS/Lambda/Fargate. |
| **AWS Trusted Advisor** | Monthly | Idle resources, low-utilization, commitment opportunities. |
| **Tag compliance review** | Monthly | Untagged = unattributed = unmanaged. Chase down owners. |
| **Savings Plan / RI coverage review** | Quarterly | Adjust commitments as baseline shifts; avoid over- or under-committing. |
| **Observability cost review** | Monthly | It grows silently; the only pillar that re-bloats on its own. |

**Make ownership explicit.** Assign each major cost center a named owner (this is what the tagging policy enables). Costs without owners never get optimized.

---

## 10. The repeatable monthly routine

A 60-minute loop you can run forever:

1. **Look** - Cost Explorer, last month grouped by service, then by tag. Note the top 5 movers (up and down).
2. **Hunt** - Trusted Advisor + Compute Optimizer recommendations. Triage idle/oversized resources.
3. **Verify tags** - anything untagged in the top spenders? Assign an owner.
4. **Observability check** - any log group without retention? Any custom metric exploding in count? Any duplicated log pipeline?
5. **Commitment check** (quarterly) - is Savings Plan / RI coverage still matched to baseline?
6. **Act on non-prod first**, then prod with a canary and a rollback plan.
7. **Record** what you changed and the expected saving, so you can confirm it landed next month.

---