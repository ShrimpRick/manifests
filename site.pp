# /etc/puppetlabs/code/environments/production/manifests/site.pp

node default {
  # Zorg dat het env-bestand bestaat
  file { '/etc/fetch_api.env':
    ensure => present,
  }

  # Maak het script dat de API-call doet
  file { '/usr/local/bin/fetch_api.sh':
    ensure  => file,
    mode    => '0755',
    content => @("API")
      #!/bin/bash
      source /etc/fetch_api.env
      echo "Fetching data from \$API_URL..."
      curl -s "\$API_URL" -o /tmp/api_result.json
      echo "Saved to /tmp/api_result.json"
      | API
  }

  # Run het script
  exec { 'fetch_api':
    command => '/usr/local/bin/fetch_api.sh',
    path    => ['/bin','/usr/bin'],
    refreshonly => false,
    require => File['/usr/local/bin/fetch_api.sh'],
  }
}
