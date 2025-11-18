node default {

  package { 'tree':
    ensure => latest,
  }


exec { 'download_azcopy':
  command => 'wget https://aka.ms/downloadazcopy-v10-linux -O /tmp/downloadazcopy-v10-linux',
  creates => '/tmp/downloadazcopy-v10-linux',
  path    => ['/usr/bin', '/bin'],
}

exec { 'extract_azcopy':
  command => 'tar -xvf /tmp/downloadazcopy-v10-linux -C /tmp',
  creates => '/tmp/azcopy_linux_amd64_10.31.0',
  require => Exec['download_azcopy'],
  path    => ['/usr/bin', '/bin'],
}

exec { 'move_azcopy_to_bin':
  command => 'sudo mv /tmp/azcopy_linux_amd64_10.31.0/azcopy /usr/local/bin/',
  creates => '/usr/local/bin/azcopy',
  require => Exec['extract_azcopy'],
  path    => ['/usr/bin', '/bin', '/usr/local/bin'],
}

exec { 'check_azcopy_version':
  command => 'azcopy --version',
  unless  => 'azcopy --version | grep -q "10.31.0"',
  require => Exec['move_azcopy_to_bin'],
  path    => ['/usr/bin', '/bin', '/usr/local/bin'],
}



  # 🔹 Haal naam van secret op uit node-specific fact
  $secret_name = $facts['fetch_secret_name']
  $blob_key = $facts['blob_key']

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
  file { '/etc/blob_key.env':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0600',
    content => "BLOB_KEY=${blob_key}\n",
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
      source /etc/blob_key.env

      if [ -z "${API_URL:-}" ]; then
        echo "ERROR: API_URL is not set in /etc/fetch_api.env"
        exit 1
      fi

      echo "blob_key is: ${BLOB_KEY}"

      
      echo "Fetching data from $API_URL..."
      if curl -sf "$API_URL" -o /tmp/api_result.json; then
        echo "Saved to /tmp/api_result.json"
      else
        echo "Failed to fetch API data" >&2
        exit 1
      fi



      echo "Uploading /tmp/api_result.json to Azure Blob Storage using BLOB_KEY..."
      # Zorg ervoor dat BLOB_KEY de volledige URL naar de blob bevat:
      if azcopy copy "/tmp/api_result.json" "$BLOB_KEY"; then
        echo "Successfully uploaded file to $BLOB_KEY"
      else
        echo "Failed to upload file to $BLOB_KEY" >&2
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
      File['/etc/blob_key.env'],
      File['/usr/local/bin/fetch_api.sh'],
      Exec['move_azcopy_to_bin'],
    ],
  }
}
