# Presenter Script — Lightwell + AAP Patch Demo

Estimated total runtime: ~60-75 minutes (or pick individual demos)

---

## Opening (~2 min)

> Let me set the stage. Every organisation running production systems faces the same problem: a new CVE drops, you have hundreds — maybe thousands — of hosts, and you need to answer three questions fast.
>
> **Where am I exposed? What do I do right now? And how do I prove I fixed it?**
>
> Today I'm going to show you how Red Hat answers all three — automatically — using four products working together:
>
> - **RHTPA** — Red Hat Trusted Profile Analyzer — stores SBOMs and correlates them against new CVEs in seconds.
> - **Project Lightwell** — resolves vulnerabilities upstream and publishes fixes to package repositories.
> - **CME** — Common Mitigation Enumeration — a defensive control taxonomy that lets you apply and verify compensating controls while you wait for a fix, and proves the risk reduction with CVSS attenuation scoring.
> - **AAP** — Ansible Automation Platform — ties it all together. Event-Driven Ansible listens for events, Controller orchestrates the workflows, and everything runs under governance with a full audit trail.
>
> We have a fleet of RHEL 10 nodes. They all have SBOMs uploaded to RHTPA — that's our baseline. Now let's see what happens when a vulnerability arrives.

---

## Demo 1: "The CVE Arrives" (~15 min)

> A new CVE has just been disclosed — CVE-2026-31419, a use-after-free vulnerability in the Linux kernel bonding driver. CVSS 7.0 — local access, high complexity, but leads to full confidentiality, integrity, and availability impact. There's no fix yet. Red Hat is working on it, but right now we have an active threat.
>
> Here's where Event-Driven Ansible comes in. We have a rulebook listening for vulnerability events. I'm going to fire a CVE disclosure webhook — in production, this would come from your vulnerability feed or your SIEM.

**[Run: `./demo/trigger_cve_disclosure.sh`]**

> That webhook just hit our EDA rulebook. EDA evaluated the event type — it's a CVE disclosure — and automatically launched the "SBOM Correlate and Mitigate" workflow in Controller.
>
> Let's switch to Controller and watch.

**[Show Controller: Workflow "SBOM Correlate and Mitigate" running]**

> The first job is **CVE Correlation**. This is querying RHTPA — our SBOM store — asking: "Which of my hosts have `python-cryptography` installed?" RHTPA doesn't need to scan anything. The SBOMs are already there. It's a lookup, not a scan. Seconds, not hours.

**[Show: correlate_cve job output]**

> And here's the result — an exposure report. Three out of four nodes are running the vulnerable version. We now have a dynamic inventory of affected hosts, and this report is published to our report server for the security team.

**[Show: Exposure report on report server]**

> So within seconds of the CVE being disclosed, we know exactly where we're exposed. No spreadsheet. No manual audit. RHTPA gave us the answer immediately because we had SBOMs already in place.

### Alternative: Splunk path (optional, ~3 min)

> Now let me show you the same thing through a SIEM integration. Instead of a direct webhook, the CVE event lands in Splunk first. A saved search detects it, fires a webhook to a second EDA rulebook on port 5001, and the same workflow kicks off. Same result, different entry point — proving EDA can sit behind whatever event source your SOC already uses.

**[Run: `./demo/inject_splunk_cve.sh`]**

---

## Demo 2: "Compensate While We Wait" (~15 min)

> Now we're in the hard part. We know we're exposed, but there's no patch yet. What do most organisations do here? They write a Jira ticket, they send an email, and they hope for the best. That's not good enough.
>
> This is where CME comes in — Common Mitigation Enumeration. CME is a taxonomy of defensive controls. The next job in our workflow is querying the CME MCP server: "Given this CVE, this CVSS vector, and these CWE categories — what compensating controls can I apply right now to reduce my exposure?"

**[Show: cme_mitigate job running in Controller]**

> CME came back with a set of controls — things like network segmentation rules, kernel hardening parameters, filesystem restrictions. These aren't theoretical. These are concrete, automatable controls that directly mitigate the attack vectors in the CVSS vector.
>
> Now watch — the playbook is applying those controls across our affected hosts automatically. Firewall rules. Audit policies. Kernel parameters. Each one verified after application.

**[Show: cme_mitigate job output — controls being applied]**

> And here's the part I really want you to see. The **verification job** runs next. It checks that every control is actually in place — not just that we ran the playbook, but that the system state matches what we expect. And then it does CVSS attenuation scoring.

**[Show: cme_verify job output]**

> Look at this posture report. Our original CVSS was 7.0. After applying compensating controls, the attenuated score is significantly lower. We haven't patched yet — the vulnerability still exists — but we've provably reduced the risk. That's the difference between "we're working on it" and "here's mathematical proof that our exposure is reduced."

**[Show: Posture report on report server]**

> This is what you show your CISO at 2 AM when a zero-day drops and there's no patch. Not a promise — evidence.

---

## Demo 3: "Lightwell Fixes It — OS Package" (~20 min)

> Time passes. Lightwell has been working upstream. The fix is ready. Red Hat publishes RHSA-2026:25191 — the patched kernel is now available in the dnf repository.
>
> Another event fires — this time it's an "RHSA available" notification.

**[Run: `./demo/trigger_rhsa_available.sh`]**

> EDA picks it up and launches the second workflow: "Patch Test and Deploy." Notice we don't just blindly patch production. There's a governance process here.

**[Show: Controller workflow "Patch Test and Deploy" running]**

> **Step one: Container test.** Before we touch a single VM, we install the patched kernel into a UBI10 container and run a validation suite — smoke test, Grype vulnerability scan, and userspace integrity checks. This proves the patch actually fixes the CVE and doesn't break anything, all in an isolated environment.

**[Show: container_test job output]**

> **Step two: Patch and verify.** Now we roll out `dnf update kernel` to the fleet — staged, with health checks after each host. The playbook updates the kernel, verifies the new version is installed, and uploads a fresh SBOM to RHTPA.

**[Show: patch_and_verify job output]**

> **Step three: Close the loop.** This is where the audit trail comes together. The playbook uploads the post-patch SBOMs to RHTPA, removes the compensating controls that are no longer needed, and generates a final compliance report showing the full lifecycle: when we detected the CVE, what we did while we waited, when we patched, and proof that we're clean.

**[Show: close_loop job output and final report on report server]**

> That report is your evidence for auditors, for compliance, for your CISO. The entire lifecycle — from disclosure to remediation — documented automatically, with no manual steps.

---

## Demo 4: "App Dependencies — The Other Half" (~25 min)

> Now let me show you why this matters beyond OS packages. Most real-world vulnerabilities today aren't in RPMs on the host — they're in application dependencies. Log4j. Spring4Shell. These are libraries baked into your application at build time. You can't fix them with `dnf update`.
>
> We have a Python application — `config-service` — running on our fleet. It depends on `pyyaml` version 6.0.1, which has CVE-2026-52891. Lightwell has published a fixed version — pyyaml 6.0.2 — to an internal PyPI index.
>
> The remediation model is completely different. Instead of patching a live system, we need to update the dependency pin in the source code, rebuild the entire application through CI/CD, and redeploy it.
>
> Watch.

**[Run: `./demo/trigger_app_dependency_fix.sh cicd`]**

> EDA fires, and the workflow does something different this time. It goes to our Gitea instance, updates `requirements.txt` to pin `pyyaml>=6.0.2`, and triggers a CI/CD pipeline. Gitea Actions builds the new container image, runs the test suite, and does a `pip-audit` security scan.
>
> Once the build passes, Controller deploys the rebuilt application to every target node and validates the service is healthy.

**[Show: Gitea Actions pipeline running, then Controller deployment]**

> Same automation platform. Same governance model. Completely different remediation path. That's the key message: Lightwell + AAP handles both models — host patching AND application rebuild pipelines. Complete coverage.

### GitOps variant (optional, ~5 min)

> And if your team prefers a GitOps workflow — where changes go through pull requests with review and approval — we support that too. Instead of pushing directly, Controller opens a PR. CI runs automatically on the PR. It can auto-merge or wait for manual approval. Then the deployment follows.

**[Run: `./demo/trigger_app_dependency_fix.sh gitops`]**

---

## Demo 5: "The other ecosystem — Maven" (~25 min)

> Demo 4 was Python. Same platform, same GitOps gate — now a Java application. `simple-webapp` is a Quarkus REST service. It pins `gson` 2.8.9 in `pom.xml`. Lightwell published 2.11.0 to an internal Maven repository, not PyPI.
>
> Watch the PR. It edits a Maven property, not `requirements.txt`. After you merge, Gitea Actions builds the container with Maven and uploads a second SBOM to TPA named `simple-webapp`.
>
> Two pipeline documents in TPA. Two ecosystems. The question for later is: which packages, which repos.

**[Run: `./demo/trigger_app_dependency_fix.sh maven`]**

**[Show: Gitea PR on simple-webapp, Maven index :8082, TPA documents config-service and simple-webapp]**

---

## Closing (~2 min)

> Let me bring it all together. What you just saw was a fully automated CVE lifecycle — from the moment a vulnerability is disclosed to the moment it's remediated and proven clean.
>
> **No manual triage.** RHTPA told us exactly where we were exposed, instantly, because SBOMs were already in place.
>
> **No hoping for the best.** CME gave us provable compensating controls with CVSS attenuation scoring while we waited for a fix.
>
> **No cowboy patching.** Controller orchestrated testing, staged rollout, and verification under governance.
>
> **No compliance gaps.** Every step generated evidence — reports, SBOMs, audit trails — automatically.
>
> And this works for both remediation models — OS packages via `dnf` and application dependencies via CI/CD rebuild, Python *and* Java. That's the full picture.
>
> RHTPA, Lightwell, CME, and Ansible Automation Platform. Four products, one lifecycle, zero manual steps.
