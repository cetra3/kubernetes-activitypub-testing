
# Kubernetes ActivityPub Testing Environment

This repository is a kubernetes ( using [k3s](https://k3s.io/) ) cluster that allows you to test activitypub federation between services.  Currently it contains opinionated helm charts for `mastodon` and `pixelfed`.

This will create a kubernetes cluster which can host federated software under their own domain and talk to eachother

It will create apps that run at `https://mastodon.k3s.local`, `https://pixelfed.k3s.local` etc..

It isn't *entirely* a turnkey solution... yet.  To talk to them from your PC you will need to adjust your DNS/hosts and install a CA Certificate (Instructions below)

## Requirements

You will need:

* A fast-ish PC running linux to run everything w/ root access
* Docker & Docker Compose: https://docs.docker.com/compose/install/linux
* kubectl: https://kubernetes.io/docs/tasks/tools/
* helm: https://helm.sh/docs/intro/install/
* Just: https://github.com/casey/just

## Setup

The docker compose stack runs a local docker registry and also `k3s`.  To start it up, run:

```
docker compose up -d
```

Once it's started up, you can copy the kubernetes config to your pc by running (note: this will overwrite your existing `~/.kube/config`):

```
just get-k3s-config
```

Once started, you can install the nginx ingress controller & cert/trust-manager using the following `just` command:

```
just services
```

Then you can startup mastodon

```
just mastodon
```

To login, you need to use the email `testodon@kubernetes.default.svc` and the password from the output of this command:

```
just get-mastodon-password
```

To startup pixelfed, you need to first publish a pixelfed docker image to the local registry. Hopefully there are official images soon!  There are notes on how to do that below

# Publishing Docker Images

To publish a docker image.  Updated your `/etc/hosts` to add `registry` as a localhost:

```
127.0.0.1 registry
```

Then you can tag images as `registry:5000/<image_name>` to publish them to the registry to be used within kubernetes:

A contrived example:

```
docker pull hello-world
docker tag hello-world registry:5000/hello-world
docker push registry:5000/hello-world
```

## Pixelfed

Pixelfed needs to be built & pushed to run. Setup the registry as above & then follow these instructions

First, clone pixelfed in another dir:

```
git clone git@github.com:pixelfed/pixelfed.git
cd pixelfed
```

Then build the image:
```
docker build -t registry:5000/pixelfed -f contrib/docker/Dockerfile.apache
```

Then push it
```
docker push registry:5000/pixelfed
```

Then you can start the helm chart:
```
just pixelfed
```

# Connecting

You will need to adjust your local dev machine to include a CA Certificate and some DNS settings:

## CA Certificate

The `just cert-manager` command spools up a `cert-manager` environment, creates a self-signed key and then creates a root CA key from that self-signed key. 

You can use the following command to grab the ca public cert:

```
just get-ca-cert
```

### Installing the cert in your system

On Ubuntu:

```
sudo apt-get install -y ca-certificates
sudo cp k3s.ca.crt /usr/local/share/ca-certificates
sudo update-ca-certificates
```

On Arch:

```
sudo trust anchor --store k3s.ca.crt
```

## DNS

You need to add some DNS entries in. 

The easiest way is adding some static entries into `/etc/hosts` but you can also use dnsmasq

### With `/etc/hosts`

Get the ingress external IP from nginx:

```
kubectl get service ingress-nginx-controller --namespace=ingress-nginx
```

It should output something similar to:

```
NAME                       TYPE           CLUSTER-IP     EXTERNAL-IP   PORT(S)                      AGE
ingress-nginx-controller   LoadBalancer   10.43.50.116   172.22.0.3    80:31770/TCP,443:32581/TCP   129m
```

Add in the hosts you care about into `/etc/hosts`:

```
172.22.0.3 mastodon.k3s.local pixelfed.k3s.local <another_service>.k3s.local
```

### With `dnsmasq`

Using the following guide: https://blog.thesparktree.com/local-development-with-wildcard-dns

Install dnsmasq:

```
# ubuntu
sudo apt install dnsmasq
# arch
sudo pacman -S dnsmasq
```

Get the ingress external IP from nginx:

```
kubectl get service ingress-nginx-controller --namespace=ingress-nginx
```

It should output something similar to:

```
NAME                       TYPE           CLUSTER-IP     EXTERNAL-IP   PORT(S)                      AGE
ingress-nginx-controller   LoadBalancer   10.43.50.116   172.22.0.3    80:31770/TCP,443:32581/TCP   129m
```

Create a file at `/etc/dnsmasq.conf` with the following (changing your external IP):

```
listen-address=127.0.0.2
address=/k3s.local/172.22.0.3
no-resolv
domain-needed
bogus-priv
bind-interfaces
cache-size=1000
neg-ttl=3600
server=8.8.8.8
server=8.8.4.4
```

This points all the *.k3s.local* domains to `172.22.0.3`.

Edit `/etc/systemd/resolved.conf`:

```
[Resolve]
DNS=127.0.0.2
Domains=~k3s.local
```

Started up services:

```
sudo systemctl enabled dnsmasq
sudo systemctl start dnsmasq
sudo systemctl restart systemd-resolved
```

Checked with:

```
resolvectl status
```

