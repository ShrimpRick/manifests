node default {

  # 1️⃣ Controleer dat de env file bestaat (gemaakt door Terraform)
  file { '/etc/fetch_api.env':
    ensure => file,
    owner  => 'root',
    group  => 'root',
    mode   => '0644',
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
      File['/etc/fetch_api.env'],
      File['/usr/local/bin/fetch_api.sh'],
    ],
  }
}
