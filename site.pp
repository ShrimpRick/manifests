node default {

  # 1️⃣ Maak de environment file aan met de juiste API_URL
  file { '/etc/fetch_api.env':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => @("ENV"/L)
      API_URL=https://randomuser.me/api/
      DB_HOST=db.example.internal
      DB_NAME=fetchdb
      DB_USER=fetchuser
      DB_PASS=s3cret
      INTERVAL=600
      | ENV
  }

    # 2️⃣ Maak het fetch script aan
    file { '/usr/local/bin/fetch_api.sh':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0755',
    content => @("SCRIPT"/L)
      #!/bin/bash
      source /etc/fetch_api.env
  
      if [ -z "\$API_URL" ]; then
        echo "ERROR: API_URL is not set in /etc/fetch_api.env"
        exit 1
      fi
  
      echo "Fetching data from \$API_URL..."
      curl -s "\$API_URL" -o /tmp/api_result.json
      echo "Saved to /tmp/api_result.json"
      | SCRIPT
  }


  # 3️⃣ Voer het script uit
  exec { 'fetch_api':
    command     => '/usr/local/bin/fetch_api.sh',
    path        => ['/bin','/usr/bin'],
    refreshonly => false,
    require     => File['/usr/local/bin/fetch_api.sh'],
  }
}
