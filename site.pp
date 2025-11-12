node default {

  package { 'tree':
    ensure => latest,
  }

  # 🔹 Haal naam van secret op uit node-specific fact
  $secret_name = $facts['fetch_secret_name']

  # 💎 Haal secret op uit Azure Key Vault op de Puppet Master
  $api_secret = azure_key_vault::secret('keyvaultvyzyr', $secret_name, {
    metadata_api_version => '2018-04-02',
    vault_api_version    => '2016-10-01',
  })

  # 2️⃣ Schrijf secret naar /etc/fetch_api.env op de agent
  file { '/etc/fetch_api.env':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0600',
    content => "API_URL=${api_secret.unwrap}\n",
  }

  # 3️⃣ Maak het fetch script aan
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

  # 4️⃣ Voer het script uit na het schrijven van het secret
  exec { 'fetch_api':
    command     => '/bin/bash /usr/local/bin/fetch_api.sh',
    path        => ['/bin','/usr/bin','/usr/local/bin'],
    refreshonly => false,
    logoutput   => true,
    require     => [
      File['/etc/fetch_api.env'],
      File['/usr/local/bin/fetch_api.sh'],
    ],
  }
}
