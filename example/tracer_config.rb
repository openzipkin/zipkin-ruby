ZIPKIN_TRACER_CONFIG = {
  service_name: 'example_service',
  service_port: 3000,
  json_api_host: 'http://localhost:9411'
}.freeze

ZIPKIN_TRACER_CONFIG_WITH_WORKER = ZIPKIN_TRACER_CONFIG.merge(
  traceable_workers: [:MyWorker]
)

