# 04 Identity and RBAC

After handover, the customer's operations team must be able to run the platform, and nobody should have more access than their job needs. On OpenShift that's two layers: an **identity provider** (who you are) configured in the cluster's OAuth server, and **RBAC** (what you may do), granted to groups.

## Background

- OpenShift has its own OAuth server. Identity providers are configured on one resource: `oauth/cluster`.
- Common providers: **LDAP** (customer Active Directory), **OpenID Connect** (Entra ID, Keycloak), **htpasswd** (local file, fine for labs and break-glass).
- `kubeadmin` is a temporary bootstrap user. On a real cluster you remove it once an identity provider and a cluster-admin group work: `oc delete secret kubeadmin -n kube-system`. **Don't do this on CRC.**
- Grant access to **groups**, synced from LDAP or created locally, never to named users.

## Steps

```bash
cd 04-identity-rbac
./add-users.sh                     # alice, bob, carol, and groups ops, delivery, auditors
oc apply -n rack-demo -f rbac.yaml
./check-access.sh                  # nine checks, all should say ok
```

Then log in as each user to feel the difference (open a second terminal so you stay cluster-admin in the first):

```bash
oc login -u alice -p Lab-Pass-2026 https://api.crc.testing:6443
oc get pods -n rack-demo           # works
oc logs deploy/rack-demo -n rack-demo   # works
oc get secrets -n rack-demo        # Forbidden
oc rollout restart deploy/rack-demo -n rack-demo   # works
oc delete deploy/rack-demo -n rack-demo            # Forbidden
```

Log back in as `kubeadmin` afterwards.

## Cluster-wide roles worth knowing

| Grant | Command |
| --- | --- |
| Cluster admin to a group | `oc adm policy add-cluster-role-to-group cluster-admin platform-admins` |
| Read-only on the whole cluster | `oc adm policy add-cluster-role-to-group cluster-reader auditors` |
| Stop ordinary users creating projects | remove `self-provisioner` from `system:authenticated:oauth` |
| Who can do X? | `oc adm policy who-can delete pods -n rack-demo` |

## On a cluster without htpasswd

Create a secret and add a provider. Note that `oc apply` on `oauth/cluster` replaces the whole provider list, so include the existing providers too:

```bash
htpasswd -c -B -b users.htpasswd alice Lab-Pass-2026
oc create secret generic lab-htpasswd -n openshift-config --from-file=htpasswd=users.htpasswd
oc edit oauth cluster          # add an HTPasswd provider pointing at lab-htpasswd
```

## Checks

- [ ] `check-access.sh` reports all nine checks ok.
- [ ] Logged in as alice, you can restart but not delete the deployment.
- [ ] You can say how you'd connect the customer's Active Directory (LDAP provider plus group sync) and why kubeadmin goes.

## Interview line

> "At handover I connect the cluster to the customer's directory through the OAuth server, sync their groups, bind roles to groups only, and remove kubeadmin. Operations can see logs and restart services but can't read secrets; auditors get view. I prove it with `oc auth can-i` per group and put the results in the acceptance evidence."
