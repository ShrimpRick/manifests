node default {

  package { 'tree':
    ensure => latest,
  }

  # 💎 Key Vault secret ophalen
  azure_key_vault_secret { '/etc/fetch_api.env':
    vault_name      => 'my-keyvault',
    secret_name     => $::custom_data['API_URL'],
    subscription_id => 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx',
    tenant_id       => 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx',
    ensure          => present,
    value_file      => '/etc/fetch_api.env',
  }

  # 2️⃣ Maak het fetch script aan
  file { '/usr/local/bin/fetch_api.sh':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0755',
    content => @(SCRIPT/L)
      #!/bin/bash
      set -euo pipefail

      source /etc/fetch_api.env

      if [ -z "${API_URL:-}" ]; then
        echo "ERROR: API_URL is not set in /etc/fetch_api.env"
        exit 1
      fi

      echo "Fetching data from $API_URL..."
      if curl -sf "$API_URL" -o /tmp/api_result.json; then
        echo "Saved to /tmp/api_result.json"
      else
        echo "Failed to fetch API data" >&2
        exit 1
      fi
    | SCRIPT
  }

  # 3️⃣ Voer het script uit
  exec { 'fetch_api':
    command     => '/bin/bash /usr/local/bin/fetch_api.sh',
    path        => ['/bin','/usr/bin','/usr/local/bin'],
    refreshonly => false,
    logoutput   => true,
    require     => [
      Azure_key_vault_secret['/etc/fetch_api.env'],
      File['/usr/local/bin/fetch_api.sh'],
    ],
  }
}
