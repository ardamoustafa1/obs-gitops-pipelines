#!/usr/bin/env bash
set -euo pipefail

helm lint charts/platform-config
for environment in dev staging prod; do
  helm template "platform-config-${environment}" charts/platform-config --set "environment=${environment}" >/dev/null
done

if grep -R -q 'automated:' applications/prod; then
  echo 'production child Applications must not enable automated sync' >&2
  exit 1
fi

ruby <<'RUBY'
require 'yaml'
def load_yaml(file)
  YAML.safe_load(File.read(file), aliases: true)
end
components = %w[onboarding-controller notification-router developer-portal]
%w[dev staging prod].each do |environment|
  components.each do |component|
    app = load_yaml("applications/#{environment}/#{component}.yaml")
    values = load_yaml("values/#{environment}/#{component}.yaml")
    chart = app.fetch('spec').fetch('sources').first.fetch('targetRevision').to_s
    image = values.fetch('image').fetch('tag').to_s
    abort "#{environment}/#{component}: chart #{chart} != image #{image}" unless chart == image
  end
end
Dir['{bootstrap,projects,applications}/**/*.yaml'].each { |file| load_yaml(file) }
RUBY

echo 'GitOps invariants are valid.'
