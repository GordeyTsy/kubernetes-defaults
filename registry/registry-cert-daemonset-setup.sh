#!/bin/bash
kubectl delete -f registry-cert-daemonset.yaml
kubectl apply -f registry-cert-daemonset.yaml
kubectl rollout restart ds/registry-cert-installer
kubectl rollout status ds/registry-cert-installer
