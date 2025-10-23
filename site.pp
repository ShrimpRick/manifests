node default {
  file { '/etc/fetch_api.env':
    ensure => present,
  }

  file { '/usr/local/bin/fetch_api.sh':
    ensure  => file,
    mode    => '0755',
    content => @("API"/L)
      #!/bin/bash
      source /etc/fetch_api.env
      echo "Fetching data from \$API_URL..."
      curl -s "\$API_URL" -o /tmp/api_result.json
      echo "Saved to /tmp/api_result.json"
      | API
  }

  exec { 'fetch_api':
    command     => '/usr/local/bin/fetch_api.sh',
    path        => ['/bin','/usr/bin'],
    refreshonly => false,
    require     => File['/usr/local/bin/fetch_api.sh'],
  }
}
