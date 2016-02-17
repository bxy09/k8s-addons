#!/bin/bash

# Copyright 2015 The Kubernetes Authors All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# deploy the add-on services after the cluster is available

set -e

DNS_SERVER_IP=${DNS_SERVER_IP:-"192.168.3.10"}
DNS_DOMAIN=${DNS_DOMAIN:-"cluster.local"}
DNS_REPLICAS=${DNS_REPLICAS:-1}
KUBE_API=${KUBE_API:-"192.168.100.11:8080"}

PRJ_ROOT=$(dirname "${BASH_SOURCE}")/
KUBECTL="kubectl -s ${KUBE_API}"

function init {
  echo "Creating kube-system namespace..."
  # use kubectl to create kube-system namespace
  NAMESPACE=`eval "${KUBECTL} get namespaces | grep kube-system | cat"`

  if [ ! "$NAMESPACE" ]; then
    ${KUBECTL} create -f namespace.yaml
    echo "The namespace 'kube-system' is successfully created."
  else
    echo "The namespace 'kube-system' is already there. Skipping."
  fi

  echo
}

function deploy_dns {
  echo "Deploying DNS on Kubernetes"
  sed -e "s/{{ pillar\['dns_replicas'\] }}/${DNS_REPLICAS}/g;s/{{ pillar\['dns_domain'\] }}/${DNS_DOMAIN}/g;" "${PRJ_ROOT}/dns/skydns-rc.yaml.in" > skydns-rc.yaml
  sed -e "s/{{ pillar\['dns_server'\] }}/${DNS_SERVER_IP}/g" "${PRJ_ROOT}/dns/skydns-svc.yaml.in" > skydns-svc.yaml

  KUBEDNS=`eval "${KUBECTL} get services --namespace=kube-system | grep kube-dns | cat"`

  if [ ! "$KUBEDNS" ]; then
    # use kubectl to create skydns rc and service
    ${KUBECTL} --namespace=kube-system create -f skydns-rc.yaml
    ${KUBECTL} --namespace=kube-system create -f skydns-svc.yaml

    echo "Kube-dns rc and service is successfully deployed."
    rm skydns-rc.yaml
    rm skydns-svc.yaml
  else
    echo "Kube-dns rc and service is already deployed. Skipping."
  fi

  echo
}

function deploy_dashboard {
  echo "Deploying Kubernetes Dashboard..."

  KUBEUI=`eval "${KUBECTL} get services --namespace=kube-system | grep kubernetes-dashboard | cat"`

  if [ ! "$KUBEUI" ]; then
    # use kubectl to create kube-ui rc and service
    ${KUBECTL} --namespace=kube-system create \
        -f ${PRJ_ROOT}/dashboard/dashboard-controller.yaml
    ${KUBECTL} --namespace=kube-system create \
        -f ${PRJ_ROOT}/dashboard/dashboard-service.yaml

    echo "Kube-dashboard rc and service is successfully deployed."
  else
    echo "Kube-dashboard rc and service is already deployed. Skipping."
  fi

  echo
}

function deploy_fluentd-elasticsearch {
  echo "Deploying fluentd-elasticsearch..."

  KUBEUI=`eval "${KUBECTL} get services --namespace=kube-system | grep elasticsearch-logging | cat"`

  if [ ! "$KUBEUI" ]; then
    # use kubectl to create kube-ui rc and service
    ${KUBECTL} --namespace=kube-system create \
        -f ${PRJ_ROOT}/fluentd-elasticsearch/es-controller.yaml
    ${KUBECTL} --namespace=kube-system create \
        -f ${PRJ_ROOT}/fluentd-elasticsearch/es-service.yaml
    ${KUBECTL} --namespace=kube-system create \
        -f ${PRJ_ROOT}/fluentd-elasticsearch/kibana-controller.yaml
    ${KUBECTL} --namespace=kube-system create \
        -f ${PRJ_ROOT}/fluentd-elasticsearch/kibana-service.yaml
    ${KUBECTL} --namespace=kube-system create \
        -f ${PRJ_ROOT}/fluentd-elasticsearch/fluentd-controller.yaml
    ${KUBECTL} --namespace=kube-system create \
        -f ${PRJ_ROOT}/fluentd-elasticsearch/fluentd-service.yaml

    echo "Fluentd-elasticsearch rc and service is successfully deployed."
  else
    echo "Fluentd-elasticsearch rc and service is already deployed. Skipping."
  fi

  echo
}

init
deploy_dns
deploy_dashboard
deploy_fluentd-elasticsearch
