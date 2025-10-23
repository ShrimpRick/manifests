class fetch_api (
  String $api_url,
  Integer $interval_seconds = 300,
  Hash $db = {},
  Optional[String] $target_ip = undef,
) {

  # detecteer IP automatisch als target_ip niet is meegegeven
  $resolved_ip = $target_ip ? {
    undef   => $facts['networking']['interfaces'][$facts['networking']['primary']]['ip'],
    default => $target_ip,
  }

  package { ['python3','python3-venv','python3-pip']:
    ensure => installed,
  }

  # Installeer Python libs
  exec { 'install_python_libs':
    command => '/usr/bin/python3 -m pip install --upgrade pip requests psycopg2-binary',
    path    => ['/usr/bin','/bin'],
    unless  => '/usr/bin/python3 -c "import requests, psycopg2"',
    require => Package['python3','python3-pip'],
  }

  # Python script
  file { '/usr/local/bin/fetch_api.py':
    ensure  => file,
    mode    => '0755',
    owner   => 'root',
    group   => 'root',
    content => @("PYTHON"/L)
      #!/usr/bin/env python3
      import os, time, json, requests, psycopg2

      API_URL = os.getenv('FETCH_API_URL', '${api_url}')

      DB_HOST = os.getenv('FETCH_DB_HOST', '${db['host']         || 'localhost'}')
      DB_PORT = int(os.getenv('FETCH_DB_PORT', '${db['port']     || '5432'}'))
      DB_NAME = os.getenv('FETCH_DB_NAME', '${db['name']         || 'fetchdb'}')
      DB_USER = os.getenv('FETCH_DB_USER', '${db['user']         || 'fetchuser'}')
      DB_PASS = os.getenv('FETCH_DB_PASS', '${db['pass']         || ''}')

      def write_to_db(payload):
          conn = psycopg2.connect(host=DB_HOST, port=DB_PORT, dbname=DB_NAME, user=DB_USER, password=DB_PASS)
          cur = conn.cursor()
          cur.execute("""
            CREATE TABLE IF NOT EXISTS api_data (
              id SERIAL PRIMARY KEY,
              fetched_at TIMESTAMP DEFAULT now(),
              data JSONB
            )
          """)
          cur.execute("INSERT INTO api_data (data) VALUES (%s)", [json.dumps(payload)])
          conn.commit()
          cur.close()
          conn.close()

      def main():
          try:
              r = requests.get(API_URL, timeout=15)
              r.raise_for_status()
              data = r.json()
              write_to_db(data)
              print("✅ Data opgeslagen in database")
          except Exception as e:
              print("⚠️ Fout bij ophalen of opslaan:", e)

      if __name__ == "__main__":
          main()
      | PYTHON
    require => Exec['install_python_libs'],
  }

  # Systemd service
  file { '/etc/systemd/system/fetch_api.service':
    ensure  => file,
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => @("UNIT"/L)
      [Unit]
      Description=Fetch API data and store in database

      [Service]
      Type=oneshot
      Environment="FETCH_API_URL=${api_url}"
      Environment="FETCH_DB_HOST=${db['host']         || 'localhost'}"
      Environment="FETCH_DB_PORT=${db['port']         || '5432'}"
      Environment="FETCH_DB_NAME=${db['name']         || 'fetchdb'}"
      Environment="FETCH_DB_USER=${db['user']         || 'fetchuser'}"
      Environment="FETCH_DB_PASS=${db['pass']         || ''}"
      ExecStart=/usr/local/bin/fetch_api.py

      [Install]
      WantedBy=multi-user.target
      | UNIT
    require => File['/usr/local/bin/fetch_api.py'],
  }

  # Systemd timer
  file { '/etc/systemd/system/fetch_api.timer':
    ensure  => file,
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => @("TIMER"/L)
      [Unit]
      Description=Run fetch_api every ${interval_seconds} seconds

      [Timer]
      OnBootSec=30s
      OnUnitActiveSec=${interval_seconds}s
      Unit=fetch_api.service

      [Install]
      WantedBy=timers.target
      | TIMER
    require => File['/etc/systemd/system/fetch_api.service'],
  }

  # Reload systemd en start timer
  exec { 'systemd-daemon-reload':
    command     => '/bin/systemctl daemon-reload',
    refreshonly => true,
    subscribe   => [
      File['/etc/systemd/system/fetch_api.service'],
      File['/etc/systemd/system/fetch_api.timer'],
    ],
  }

  service { 'fetch_api.timer':
    ensure    => running,
    enable    => true,
    require   => Exec['systemd-daemon-reload'],
  }

  # Schrijf target IP naar bestand (optioneel)
  file { '/etc/fetch_target_ip':
    ensure  => file,
    mode    => '0644',
    content => "${resolved_ip}\n",
    require => Service['fetch_api.timer'],
  }

}
