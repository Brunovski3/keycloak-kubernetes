#!/usr/bin/env bash
# Puxa os manifests que estão RODANDO no host OCI (nada retocado, sem recriação).
#
# Uso: ./pull-from-server.sh <host-ssh> [repo-dir]
#   ./pull-from-server.sh ubuntu@100.x.x.x .
#
# O que copia:
#   1. /etc/rancher/k3s/config.yaml          — config server/agent do cluster
#   2. /var/lib/rancher/k3s/server/manifests — autodeploy: HelmCharts (traefik,
#      tailscale-operator, n8n...), CRDs e manifests aplicados ao cluster
#
# O que NUNCA copia (chaves de cluster):
#   server/token, server/tls, server/cred, agent/*
#
# Os arquivos caem em ./local-export/ (fora do Git). Revise, limpe segredos
# e TRANSPORTE o conteúdo pros diretórios finais do repo. local-export/ está
# no .gitignore justamente pra nunca subir cru.
set -euo pipefail

HOST="${1:?Uso: $0 <host-ssh> [dest]}"
DEST="${2:-.}"

K3S_MAN="local-export/k3s-manifests"
K3S_CONF="local-export/k3s-config"

mkdir -p "$K3S_MAN" "$K3S_CONF"

echo "⇒ rsync: config.yaml do k3s"
rsync -av --rsync-path="mkdir -p /tmp/k3s-export && rsync" \
  "$HOST:/etc/rancher/k3s/config.yaml" "$K3S_CONF/" || {
  echo "  (sem config.yaml — pulei)"; }

echo "⇒ rsync: autodeploy manifests"
rsync -av "$HOST:/var/lib/rancher/k3s/server/manifests/" "$K3S_MAN/" || {
  echo "  (sem manifests — cluster usa um host path diferente? inspecione)"; }

echo
echo "⇒ Varredura de segredos (kind: Secret e credentials):"
found=0
while IFS= read -r f; do
  echo "  ⚠ POSSÍVEL SEGREDO: $f"
  found=1
done < <(grep -rlE 'kind:[[:space:]]*Secret|stringData|password:|clientSecret' "$K3S_MAN" "$K3S_CONF" 2>/dev/null || true)

echo
if [ "$found" = "0" ]; then
  echo "✓ Nenhum segredo aparente. Confira na mão mesmo assim."
else
  echo "✗ Revise os arquivos marcados acima ANTES de mover pro repo. Genere via secretKeyRef, joga o valor no gerenciador de segredos, nunca no Git."
fi
echo "OK — revise em $DEST/local-export/"
