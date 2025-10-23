node default {
  class { 'fetch_api':
    api_url => 'https://api.open-meteo.com/v1/forecast?latitude=52.52&longitude=13.41&current_weather=true',
  }
}
