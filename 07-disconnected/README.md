# 07 Disconnected installs: mirroring images with oc-mirror

Many customer sites give the platform no internet access. Everything the cluster needs (OpenShift release images, operator catalogs, your own images) has to be copied in and served from a registry inside the site. This module practises the copy step with `oc-mirror` v2.

## How it fits together

```
connected machine                 carried in (disk, transfer)      site
-----------------                 ---------------------------      ----
oc-mirror to-disk  ──► mirror/*.tar ───────────────────────────►  oc-mirror to-registry
                                                                  ──► local registry (mirror-registry / Quay / Harbor)
                                                                  ──► cluster uses it through:
                                                                      IDMS / ITMS   (redirect image pulls)
                                                                      CatalogSource (operator catalog)
                                                                      additionalTrustBundle (registry CA)
```

- **ImageDigestMirrorSet (IDMS) / ImageTagMirrorSet (ITMS):** tell every node "when you need an image from quay.io/…, pull it from the local registry instead". oc-mirror generates them.
- **CatalogSource:** points OLM at the mirrored operator catalog. Disable the default online catalogs: `oc patch operatorhub cluster --type merge -p '{"spec":{"disableAllDefaultSources":true}}'`.
- **Install time:** the same mirror settings go into `install-config.yaml` as `imageDigestSources` and `additionalTrustBundle` (see module 06).

## Steps

### 1. Get oc-mirror

Download `oc-mirror` for your OS from https://mirror.openshift.com/pub/openshift-v4/clients/ocp/ (same version folder as `oc`), extract, put on `PATH`. On a Mac, check whether your version has a macOS build; otherwise run it in a Linux container as in module 06.

### 2. Read the image set

[`imageset-config.yaml`](imageset-config.yaml) selects one OpenShift version, two operators and two extra images. Set the channel and version to what you run (`oc get clusterversion` on CRC shows it).

### 3. Dry run (no big download)

```bash
cd 07-disconnected
./mirror.sh dry-run
wc -l working-dir/working-dir/dry-run/mapping.txt     # how many images
```

Try removing `minVersion/maxVersion`, or adding a second operator, and compare the image count. That's the sizing conversation you'll have before every shipment.

### 4. Optional: the real thing

```bash
./mirror.sh to-disk                                   # tens of GB; needs disk space and time
# then, on the site side, with a registry running (e.g. Red Hat's mirror-registry):
./mirror.sh to-registry registry.rack01.customer.example:8443
oc apply -f mirror/working-dir/cluster-resources/
```

`mirror/` and `working-dir/` are in `.gitignore`.

## Things that go wrong on site

| Symptom | Usual cause |
| --- | --- |
| `ImagePullBackOff`, image from quay.io | Missing IDMS entry, or the image wasn't in the image set |
| `x509: certificate signed by unknown authority` | Registry CA not in `additionalTrustBundle` / `image.config.openshift.io` |
| Operator not in OperatorHub | CatalogSource missing, or the default sources still enabled and failing |
| Upgrade blocked | The target version wasn't mirrored, or no update graph (OSUS) on site |

## Checks

- [ ] Dry run completes and you can say roughly how many images one version plus two operators is.
- [ ] You can explain IDMS, CatalogSource and the trust bundle without notes.

## Interview line

> "For a disconnected site I keep an image set config in Git listing the exact OpenShift version, operators and our own images. oc-mirror downloads that to disk on the connected side; on site it's pushed into a local registry, and the generated mirror sets and catalog sources point the cluster at it. Upgrades are the same process: mirror the next version first, then upgrade."
