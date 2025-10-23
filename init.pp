class fetch_api (
  String $api_url = 'https://api.example.com/data',
) {

  package { ['python3', 'python3-requests']:
    ensure => installed,
  }

  file { '/usr/local/bin/fetch_api.py':
    ensure  => file,
    mode    => '0755',
    owner   => 'root',
    group   => 'root',
    content => @(PYTHON)
      #!/usr/bin/env python3
      import requests, json, os, sys

      api_url = os.getenv('API_URL', '${api_url}')

      try:
          print(f"Fetching from {api_url}...")
          response = requests.get(api_url, timeout=10)
          response.raise_for_status()
          data = response.json()
          with open('/tmp/api_data.json', 'w') as f:
              json.dump(data, f, indent=2)
          print("✅ Data saved to /tmp/api_data.json")
      except Exception as e:
          print("❌ API fetch failed:", e)
      | PYTHON
  }

  exec { 'run_fetch_api':
    command     => '/usr/local/bin/fetch_api.py',
    refreshonly => false,
    path        => ['/usr/bin', '/bin', '/usr/local/bin'],
    require     => File['/usr/local/bin/fetch_api.py'],
  }

}
